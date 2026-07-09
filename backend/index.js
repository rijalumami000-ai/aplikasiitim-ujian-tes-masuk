const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('./db');
const { authenticateToken, requireRole } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

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

    // Ambil kelompok yang ditugaskan ke user ini
    const groupResult = await db.query('SELECT group_id FROM user_groups WHERE user_id = $1', [user.id]);
    const assignedGroups = groupResult.rows.map(row => row.group_id);

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

// GET /api/auth/me - Mendapatkan data profil pengguna yang login
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const result = await db.query('SELECT id, username, role FROM users WHERE id = $1', [req.user.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Pengguna tidak ditemukan' });
    }

    const user = result.rows[0];
    const groupResult = await db.query('SELECT group_id FROM user_groups WHERE user_id = $1', [user.id]);
    const assignedGroups = groupResult.rows.map(row => row.group_id);

    res.json({
      ...user,
      assignedGroups
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// POST /api/auth/register - Mendaftarkan penguji baru (Hanya Super User)
app.post('/api/auth/register', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { username, password, role } = req.body;

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
      'INSERT INTO users (username, password, role) VALUES ($1, $2, $3) RETURNING id, username, role',
      [username, hashedPassword, role]
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


// --- MANAJEMEN PENGGUNA (Hanya Super User) ---

// GET /api/users - Mendapatkan semua user penguji beserta kelompoknya
app.get('/api/users', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  try {
    const usersResult = await db.query(`
      SELECT u.id, u.username, u.role, 
        COALESCE(json_agg(json_build_object('id', g.id, 'name', g.group_name)) FILTER (WHERE g.id IS NOT NULL), '[]') as assigned_groups
      FROM users u
      LEFT JOIN user_groups ug ON u.id = ug.user_id
      LEFT JOIN groups g ON ug.group_id = g.id
      GROUP BY u.id, u.username, u.role
      ORDER BY u.username ASC
    `);
    res.json(usersResult.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// POST /api/users/assign-groups - Menugaskan Penguji ke Kelompok
app.post('/api/users/assign-groups', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { user_id, group_ids } = req.body;

  if (!user_id || !Array.isArray(group_ids)) {
    return res.status(400).json({ message: 'user_id dan group_ids (array) wajib diisi' });
  }

  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');

    // Hapus penugasan kelompok lama
    await client.query('DELETE FROM user_groups WHERE user_id = $1', [user_id]);

    // Tambah penugasan kelompok baru jika ada
    if (group_ids.length > 0) {
      for (const group_id of group_ids) {
        await client.query(
          'INSERT INTO user_groups (user_id, group_id) VALUES ($1, $2)',
          [user_id, group_id]
        );
      }
    }

    await client.query('COMMIT');
    res.json({ message: 'Penugasan kelompok berhasil diperbarui' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  } finally {
    client.release();
  }
});


// --- CRUD KELOMPOK (CRUD Groups) ---

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
      SELECT e.id, e.registration_number, e.name, e.group_id, g.group_name,
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

// POST /api/examinees - Menambahkan calon santri (Hanya Super User)
app.post('/api/examinees', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { registration_number, name, group_id } = req.body;

  if (!registration_number || !name) {
    return res.status(400).json({ message: 'Nomor pendaftaran dan nama wajib diisi' });
  }

  try {
    const checkExaminee = await db.query('SELECT id FROM examinees WHERE registration_number = $1', [registration_number]);
    if (checkExaminee.rows.length > 0) {
      return res.status(400).json({ message: 'Nomor pendaftaran sudah terdaftar' });
    }

    const result = await db.query(
      'INSERT INTO examinees (registration_number, name, group_id) VALUES ($1, $2, $3) RETURNING *',
      [registration_number, name, group_id]
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
  const { registration_number, name, group_id } = req.body;

  if (!registration_number || !name) {
    return res.status(400).json({ message: 'Nomor pendaftaran dan nama wajib diisi' });
  }

  try {
    const result = await db.query(
      'UPDATE examinees SET registration_number = $1, name = $2, group_id = $3 WHERE id = $4 RETURNING *',
      [registration_number, name, group_id, id]
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
        'SELECT 1 FROM user_groups WHERE user_id = $1 AND group_id = $2',
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
