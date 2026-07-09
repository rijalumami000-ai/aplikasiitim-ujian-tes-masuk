const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('./db');
const { authenticateToken, requireRole } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3002; // Menggunakan port 3002 secara default

app.use(cors());
app.use(express.json());

// --- AUTENTIKASI ---

// POST /api/auth/login - Login Pengguna
app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ message: 'Username dan password wajib diisi' });
  }

  try {
    const result = await db.query('SELECT * FROM users WHERE username = $1', [username]);
    if (result.rows.length === 0) {
      return res.status(401).json({ message: 'Username atau password salah' });
    }

    const user = result.rows[0];
    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch) {
      return res.status(401).json({ message: 'Username atau password salah' });
    }

    // Ambil kelompok (array berisi max 1 item demi kompatibilitas klien)
    const assignedGroups = user.group_id ? [user.group_id] : [];

    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      process.env.JWT_SECRET || 'supersecretjwtkey123!',
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        assignedGroups
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// GET /api/auth/me - Profil yang sedang login
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const result = await db.query('SELECT id, username, role, group_id FROM users WHERE id = $1', [req.user.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Pengguna tidak ditemukan' });
    }

    const user = result.rows[0];
    const assignedGroups = user.group_id ? [user.group_id] : [];

    res.json({
      id: user.id,
      username: user.username,
      role: user.role,
      assignedGroups
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// POST /api/auth/register - Mendaftarkan user baru (Hanya Super User)
app.post('/api/auth/register', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { username, password, role, group_id } = req.body;

  if (!username || !password || !role) {
    return res.status(400).json({ message: 'Username, password, dan role wajib diisi' });
  }

  if (role !== 'SUPER_USER' && role !== 'EXAMINER') {
    return res.status(400).json({ message: 'Role harus SUPER_USER atau EXAMINER' });
  }

  try {
    const userCheck = await db.query('SELECT id FROM users WHERE username = $1', [username]);
    if (userCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Username sudah terdaftar' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const result = await db.query(
      'INSERT INTO users (username, password, role, group_id) VALUES ($1, $2, $3, $4) RETURNING id, username, role, group_id',
      [username, hashedPassword, role, role === 'SUPER_USER' ? null : group_id]
    );

    res.status(201).json({
      message: 'Registrasi berhasil',
      user: result.rows[0]
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});


// --- MANAJEMEN PENGGUNA / PENGUJI (Hanya Super User) ---

// GET /api/users - Semua user penguji beserta nama kelompoknya
app.get('/api/users', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  try {
    const usersResult = await db.query(`
      SELECT u.id, u.username, u.role, u.group_id,
             g.group_name as group_name,
             COALESCE(
               CASE WHEN g.id IS NOT NULL THEN json_build_array(json_build_object('id', g.id, 'name', g.group_name))
               ELSE '[]'::json END, '[]'::json
             ) as assigned_groups
      FROM users u
      LEFT JOIN groups g ON u.group_id = g.id
      ORDER BY u.username ASC
    `);
    res.json(usersResult.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// PUT /api/users/:id - Mengedit pengguna penguji
app.put('/api/users/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;
  const { username, password, role, group_id } = req.body;

  if (!username || !role) {
    return res.status(400).json({ message: 'Username dan role wajib diisi' });
  }

  try {
    // Cek duplikasi username untuk ID lain
    const userCheck = await db.query('SELECT id FROM users WHERE username = $1 AND id <> $2', [username, id]);
    if (userCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Username sudah terpakai oleh akun lain' });
    }

    let query = 'UPDATE users SET username = $1, role = $2, group_id = $3';
    let params = [username, role, role === 'SUPER_USER' ? null : group_id];

    if (password && password.trim().isNotEmpty) {
      const hashedPassword = await bcrypt.hash(password, 10);
      query += ', password = $4 WHERE id = $5 RETURNING id, username, role, group_id';
      params.push(hashedPassword, id);
    } else {
      query += ' WHERE id = $4 RETURNING id, username, role, group_id';
      params.push(id);
    }

    const result = await db.query(query, params);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Pengguna tidak ditemukan' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// DELETE /api/users/:id - Menghapus pengguna penguji (Safeguard)
app.delete('/api/users/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;

  try {
    // Periksa apakah user pernah menceklis kelulusan calon santri
    const checkExams = await db.query('SELECT 1 FROM exam_results WHERE examiner_id = $1 LIMIT 1', [id]);
    if (checkExams.rows.length > 0) {
      return res.status(400).json({ 
        message: 'Tidak dapat menghapus penguji ini karena sudah pernah melakukan penilaian penempatan kelas santri.' 
      });
    }

    const result = await db.query('DELETE FROM users WHERE id = $1 RETURNING id, username', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Pengguna tidak ditemukan' });
    }

    res.json({ message: 'Pengguna berhasil dihapus' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// POST /api/users/assign-groups - Menugaskan Penguji ke Kelompok Tunggal (Banyak-ke-satu)
app.post('/api/users/assign-groups', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { user_id, group_ids } = req.body; // group_ids berupa array demi kompatibilitas klien

  if (!user_id || !Array.isArray(group_ids)) {
    return res.status(400).json({ message: 'user_id dan group_ids (array) wajib diisi' });
  }

  // Karena 1 user hanya bisa 1 kelompok, ambil indeks pertama dari array, atau set ke null jika kosong
  const groupId = group_ids.length > 0 ? group_ids[0] : null;

  try {
    const result = await db.query('UPDATE users SET group_id = $1 WHERE id = $2 RETURNING id', [groupId, user_id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Pengguna tidak ditemukan' });
    }
    res.json({ message: 'Penugasan kelompok berhasil diperbarui' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});


// --- CRUD KELOMPOK (Groups) ---

// GET /api/groups - Melihat semua kelompok (Semua Role)
app.get('/api/groups', authenticateToken, async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM groups ORDER BY group_name ASC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// POST /api/groups - Membuat kelompok baru (Hanya Super User)
app.post('/api/groups', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { group_name, description } = req.body;

  if (!group_name) {
    return res.status(400).json({ message: 'Nama kelompok wajib diisi' });
  }

  try {
    const groupCheck = await db.query('SELECT id FROM groups WHERE group_name = $1', [group_name]);
    if (groupCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Nama kelompok sudah ada' });
    }

    const result = await db.query(
      'INSERT INTO groups (group_name, description) VALUES ($1, $2) RETURNING *',
      [group_name, description]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// PUT /api/groups/:id - Mengedit kelompok (Hanya Super User)
app.put('/api/groups/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;
  const { group_name, description } = req.body;

  if (!group_name) {
    return res.status(400).json({ message: 'Nama kelompok wajib diisi' });
  }

  try {
    const result = await db.query(
      'UPDATE groups SET group_name = $1, description = $2 WHERE id = $3 RETURNING *',
      [group_name, description, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Kelompok tidak ditemukan' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// DELETE /api/groups/:id - Menghapus kelompok (Hanya Super User)
app.delete('/api/groups/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;

  try {
    const result = await db.query('DELETE FROM groups WHERE id = $1 RETURNING *', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Kelompok tidak ditemukan' });
    }
    res.json({ message: 'Kelompok berhasil dihapus' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});


// --- CRUD CALON SANTRI (Examinees) ---

// GET /api/examinees - Mendapatkan daftar calon santri beserta hasil tesnya
app.get('/api/examinees', authenticateToken, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT e.id, e.registration_number, e.name, e.gender, e.school, e.group_id, g.group_name,
             er.grade as placement, er.checked_at, u.username as examiner_name
      FROM examinees e
      LEFT JOIN groups g ON e.group_id = g.id
      LEFT JOIN exam_results er ON e.id = er.examinee_id
      LEFT JOIN users u ON er.examiner_id = u.id
      ORDER BY e.name ASC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// POST /api/examinees - Menambahkan calon santri (Hanya Super User) - Auto No Pendaftaran & Gender/School
app.post('/api/examinees', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { name, gender, school, group_id } = req.body;

  if (!name || !gender || !school) {
    return res.status(400).json({ message: 'Nama, jenis kelamin, dan sekolah wajib diisi' });
  }

  try {
    // Generate Nomor Pendaftaran secara unik (Format: PAN-xxxxxx)
    let registration_number = '';
    let isUnique = false;
    while (!isUnique) {
      registration_number = 'PAN-' + Math.floor(100000 + Math.random() * 900000);
      const checkExaminee = await db.query('SELECT id FROM examinees WHERE registration_number = $1', [registration_number]);
      if (checkExaminee.rows.length === 0) {
        isUnique = true;
      }
    }

    const result = await db.query(
      'INSERT INTO examinees (registration_number, name, gender, school, group_id) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [registration_number, name, gender, school, group_id]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// PUT /api/examinees/:id - Mengedit data calon santri (Hanya Super User)
app.put('/api/examinees/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;
  const { name, gender, school, group_id } = req.body;

  if (!name || !gender || !school) {
    return res.status(400).json({ message: 'Nama, jenis kelamin, dan sekolah wajib diisi' });
  }

  try {
    const result = await db.query(
      'UPDATE examinees SET name = $1, gender = $2, school = $3, group_id = $4 WHERE id = $5 RETURNING *',
      [name, gender, school, group_id, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Data calon santri tidak ditemukan' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// DELETE /api/examinees/:id - Menghapus data calon santri (Hanya Super User)
app.delete('/api/examinees/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;

  try {
    const result = await db.query('DELETE FROM examinees WHERE id = $1 RETURNING *', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Data calon santri tidak ditemukan' });
    }
    res.json({ message: 'Data calon santri berhasil dihapus' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});


// --- CEKLIS PENEMPATAN KELAS (Placement Check-off) ---

// POST /api/exams/placement - Melakukan ceklis penempatan kelas untuk santri
app.post('/api/exams/placement', authenticateToken, async (req, res) => {
  const { examinee_id, grade } = req.body; // grade: 'SIFIR', 'SATU', 'SP', atau null untuk hapus penempatan

  if (!examinee_id) {
    return res.status(400).json({ message: 'examinee_id wajib diisi' });
  }

  if (grade && !['SIFIR', 'SATU', 'SP'].includes(grade)) {
    return res.status(400).json({ message: 'Nilai penempatan kelas harus SIFIR, SATU, atau SP' });
  }

  try {
    // Cari data santri untuk tahu dia di kelompok mana
    const examineeResult = await db.query('SELECT group_id FROM examinees WHERE id = $1', [examinee_id]);
    if (examineeResult.rows.length === 0) {
      return res.status(404).json({ message: 'Data calon santri tidak ditemukan' });
    }

    const groupId = examineeResult.rows[0].group_id;

    // JIKA penguji biasa (EXAMINER), pastikan dia ditugaskan di kelompok santri tersebut
    if (req.user.role === 'EXAMINER') {
      const accessCheck = await db.query(
        'SELECT 1 FROM users WHERE id = $1 AND group_id = $2',
        [req.user.id, groupId]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ message: 'Akses ditolak: Anda tidak ditugaskan untuk kelompok santri ini' });
      }
    }

    // Lakukan ceklis atau hapus ceklis
    if (grade === null) {
      // Hapus hasil ujian
      await db.query('DELETE FROM exam_results WHERE examinee_id = $1', [examinee_id]);
      return res.json({ message: 'Penempatan kelas berhasil dihapus' });
    } else {
      // Upsert hasil ujian
      const result = await db.query(`
        INSERT INTO exam_results (examinee_id, grade, examiner_id, checked_at)
        VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
        ON CONFLICT (examinee_id)
        DO UPDATE SET grade = EXCLUDED.grade, examiner_id = EXCLUDED.examiner_id, checked_at = CURRENT_TIMESTAMP
        RETURNING *
      `, [examinee_id, grade, req.user.id]);

      return res.json({
        message: 'Penempatan kelas berhasil disimpan',
        examResult: result.rows[0]
      });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});


// --- REKAPITULASI HASIL (Placement Recap) ---

// GET /api/exams/recap - Mendapatkan rekapitulasi data hasil tes
app.get('/api/exams/recap', authenticateToken, async (req, res) => {
  try {
    // 1. Total Santri
    const totalResult = await db.query('SELECT COUNT(*) as count FROM examinees');
    const totalExaminees = parseInt(totalResult.rows[0].count);

    // 2. Jumlah Ternilai
    const gradedResult = await db.query('SELECT COUNT(*) as count FROM exam_results');
    const gradedExaminees = parseInt(gradedResult.rows[0].count);

    // 3. Rekap per Kelas
    const gradesBreakdownResult = await db.query(`
      SELECT grade, COUNT(*) as count 
      FROM exam_results 
      GROUP BY grade
    `);
    const breakdown = { SIFIR: 0, SATU: 0, SP: 0 };
    gradesBreakdownResult.rows.forEach(row => {
      breakdown[row.grade] = parseInt(row.count);
    });

    // 4. Rekap per Kelompok
    const groupsBreakdownResult = await db.query(`
      SELECT g.id, g.group_name,
             COUNT(e.id) as total_students,
             COUNT(er.id) as graded_students
      FROM groups g
      LEFT JOIN examinees e ON g.id = e.group_id
      LEFT JOIN exam_results er ON e.id = er.examinee_id
      GROUP BY g.id, g.group_name
      ORDER BY g.group_name ASC
    `);

    res.json({
      summary: {
        total: totalExaminees,
        graded: gradedExaminees,
        ungraded: totalExaminees - gradedExaminees,
        placeholder: totalExaminees, // Placeholder value
        grades: breakdown
      },
      groups: groupsBreakdownResult.rows.map(row => ({
        id: row.id,
        groupName: row.group_name,
        totalStudents: parseInt(row.total_students),
        gradedStudents: parseInt(row.graded_students),
        progressPercent: row.total_students > 0 ? Math.round((row.graded_students / row.total_students) * 100) : 0
      }))
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});


// Jalankan Server
app.listen(PORT, () => {
  console.log(`Server Express berjalan di port ${PORT}`);
});
