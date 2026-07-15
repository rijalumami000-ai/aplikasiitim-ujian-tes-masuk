const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const db = require('./db');
const { authenticateToken, requireRole } = require('./middleware/auth');
const PDFDocument = require('pdfkit');
const XLSX = require('xlsx');

const app = express();
const PORT = process.env.PORT || 3002;

app.use(cors());
app.use(express.json());

// Hubungkan ke database psb_alhamid untuk sinkronisasi calon santri
const psbDb = new Pool({
  connectionString: 'postgresql://postgres:Rijalumami1002@127.0.0.1:5432/psb_alhamid'
});

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
      'INSERT INTO users (username, password, role, group_id, plain_password) VALUES ($1, $2, $3, $4, $5) RETURNING id, username, role, group_id',
      [username, hashedPassword, role, role === 'SUPER_USER' ? null : group_id, password]
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

// GET /api/users - Semua user penguji
app.get('/api/users', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  try {
    const usersResult = await db.query(`
      SELECT u.id, u.username, u.role, u.group_id, u.plain_password,
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
    const userCheck = await db.query('SELECT id FROM users WHERE username = $1 AND id <> $2', [username, id]);
    if (userCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Username sudah terpakai oleh akun lain' });
    }

    let query = 'UPDATE users SET username = $1, role = $2, group_id = $3';
    let params = [username, role, role === 'SUPER_USER' ? null : group_id];

    if (password && password.trim().length > 0) {
      const hashedPassword = await bcrypt.hash(password, 10);
      query += ', password = $4, plain_password = $5 WHERE id = $6 RETURNING id, username, role, group_id';
      params.push(hashedPassword, password, id);
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

// DELETE /api/users/:id - Menghapus pengguna penguji
app.delete('/api/users/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;

  try {
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

// POST /api/users/assign-groups - Menugaskan Penguji ke Kelompok
app.post('/api/users/assign-groups', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { user_id, group_ids } = req.body;

  if (!user_id || !Array.isArray(group_ids)) {
    return res.status(400).json({ message: 'user_id dan group_ids (array) wajib diisi' });
  }

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

// GET /api/groups - Melihat semua kelompok
app.get('/api/groups', authenticateToken, async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM groups ORDER BY group_name ASC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// POST /api/groups - Membuat kelompok baru (dengan group_gender)
app.post('/api/groups', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { group_name, description, group_gender } = req.body;

  if (!group_name) {
    return res.status(400).json({ message: 'Nama kelompok wajib diisi' });
  }

  try {
    const groupCheck = await db.query('SELECT id FROM groups WHERE group_name = $1', [group_name]);
    if (groupCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Nama kelompok sudah ada' });
    }

    const result = await db.query(
      'INSERT INTO groups (group_name, description, group_gender) VALUES ($1, $2, $3) RETURNING *',
      [group_name, description, group_gender || 'PUTRA']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Terjadi kesalahan pada server' });
  }
});

// PUT /api/groups/:id - Mengedit kelompok (dengan group_gender)
app.put('/api/groups/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;
  const { group_name, description, group_gender } = req.body;

  if (!group_name) {
    return res.status(400).json({ message: 'Nama kelompok wajib diisi' });
  }

  try {
    const result = await db.query(
      'UPDATE groups SET group_name = $1, description = $2, group_gender = $3 WHERE id = $4 RETURNING *',
      [group_name, description, group_gender || 'PUTRA', id]
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

// DELETE /api/groups/:id - Menghapus kelompok
app.delete('/api/groups/:id', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { id } = req.params;

  try {
    // Hapus calon santri di kelompok ini terlebih dahulu agar data terhapus sepenuhnya
    // dan nama mereka bisa muncul kembali di daftar calon santri PSB untuk didaftarkan ulang
    await db.query('DELETE FROM examinees WHERE group_id = $1', [id]);

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


// --- SINKRONISASI CALON SANTRI DARI PSB-ALHAMID ---

// GET /api/psb/available-candidates - Mengambil nama-nama dari database PSB yang belum ditugaskan kelompok
app.get('/api/psb/available-candidates', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  try {
    // 1. Ambil nomor pendaftaran santri yang sudah terdaftar di aplikasi checklist
    const existingResult = await db.query('SELECT registration_number FROM examinees');
    const existingRegNums = existingResult.rows.map(r => r.registration_number);

    // 2. Susun clause WHERE untuk query ke database PSB
    let whereClauses = [];
    let params = [];

    if (existingRegNums.length > 0) {
      whereClauses.push('"nomorPendaftaran" NOT IN (' + existingRegNums.map((_, i) => '$' + (i + 1)).join(', ') + ')');
      params = [...existingRegNums];
    }

    const { gender } = req.query; // 'PUTRA' atau 'PUTRI'
    if (gender === 'PUTRA') {
      whereClauses.push('"jenisKelamin" IN (\'Laki-laki\', \'L\')');
    } else if (gender === 'PUTRI') {
      whereClauses.push('"jenisKelamin" IN (\'Perempuan\', \'P\')');
    }

    let query = `
      SELECT "nomorPendaftaran", "namaLengkap", "jenisKelamin", "jenjangTujuan"
      FROM "Santri"
    `;

    if (whereClauses.length > 0) {
      query += ' WHERE ' + whereClauses.join(' AND ');
    }

    // Klasifikasi pengurutan:
    // - Jenjang: MTs dulu (1) baru Aliyah (2)
    // - Gender: Laki-laki / L dulu (1) baru Perempuan / P (2)
    // - Nama: Berdasarkan Abjad A-Z
    query += `
      ORDER BY 
        CASE WHEN "jenjangTujuan" = 'MTs' THEN 1 ELSE 2 END ASC,
        CASE WHEN "jenisKelamin" IN ('Laki-laki', 'L') THEN 1 ELSE 2 END ASC,
        "namaLengkap" ASC
    `;

    const psbResult = await psbDb.query(query, params);

    // Normalisasi struktur data
    const candidates = psbResult.rows.map(row => {
      const isMale = ['Laki-laki', 'L'].includes(row.jenisKelamin);
      const isMts = row.jenjangTujuan === 'MTs';

      return {
        registration_number: row.nomorPendaftaran,
        name: row.namaLengkap,
        gender: isMale ? 'PUTRA' : 'PUTRI',
        school: isMts ? 'MTS' : 'ALIYAH'
      };
    });

    res.json(candidates);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Gagal mengambil data dari database PSB Al-Hamid' });
  }
});


// --- CRUD CALON SANTRI (Examinees) ---

// GET /api/examinees - Daftar calon santri
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

// POST /api/examinees - Memilih calon santri dari PSB dan memasukkannya ke kelompok
app.post('/api/examinees', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  const { registration_number, name, gender, school, group_id } = req.body;

  if (!registration_number || !name || !gender || !school || !group_id) {
    return res.status(400).json({ message: 'Data pendaftaran, nama, jenis kelamin, sekolah, dan kelompok wajib disertakan' });
  }

  try {
    const checkExaminee = await db.query('SELECT id FROM examinees WHERE registration_number = $1', [registration_number]);
    if (checkExaminee.rows.length > 0) {
      return res.status(400).json({ message: 'Calon santri ini sudah terdaftar dalam pengujian' });
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

// PUT /api/examinees/:id - Mengedit data calon santri
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

// DELETE /api/examinees/:id - Menghapus data calon santri
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

app.post('/api/exams/placement', authenticateToken, async (req, res) => {
  const { examinee_id, grade } = req.body;

  if (!examinee_id) {
    return res.status(400).json({ message: 'examinee_id wajib diisi' });
  }

  if (grade && !['SIFIR', 'SATU', 'SP'].includes(grade)) {
    return res.status(400).json({ message: 'Nilai penempatan kelas harus SIFIR, SATU, atau SP' });
  }

  try {
    const examineeResult = await db.query('SELECT group_id FROM examinees WHERE id = $1', [examinee_id]);
    if (examineeResult.rows.length === 0) {
      return res.status(404).json({ message: 'Data calon santri tidak ditemukan' });
    }

    const groupId = examineeResult.rows[0].group_id;

    if (req.user.role === 'EXAMINER') {
      const accessCheck = await db.query(
        'SELECT 1 FROM users WHERE id = $1 AND group_id = $2',
        [req.user.id, groupId]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ message: 'Akses ditolak: Anda tidak ditugaskan untuk kelompok santri ini' });
      }
    }

    if (grade === null) {
      await db.query('DELETE FROM exam_results WHERE examinee_id = $1', [examinee_id]);
      return res.json({ message: 'Penempatan kelas berhasil dihapus' });
    } else {
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

app.get('/api/exams/recap', authenticateToken, async (req, res) => {
  try {
    const totalResult = await db.query('SELECT COUNT(*) as count FROM examinees');
    const totalExaminees = parseInt(totalResult.rows[0].count);

    const gradedResult = await db.query('SELECT COUNT(*) as count FROM exam_results');
    const gradedExaminees = parseInt(gradedResult.rows[0].count);

    const gradesBreakdownResult = await db.query(`
      SELECT grade, COUNT(*) as count 
      FROM exam_results 
      GROUP BY grade
    `);
    const breakdown = { SIFIR: 0, SATU: 0, SP: 0 };
    gradesBreakdownResult.rows.forEach(row => {
      breakdown[row.grade] = parseInt(row.count);
    });

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
        placeholder: totalExaminees,
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


// --- ENDPOINT DOWNLOAD FILE (PDF & EXCEL) ---

// GET /api/download/pdf/group/:id - Download PDF daftar santri per kelompok
app.get('/api/download/pdf/group/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;
  try {
    // 1. Ambil info kelompok
    const groupResult = await db.query('SELECT * FROM groups WHERE id = $1', [id]);
    if (groupResult.rows.length === 0) {
      return res.status(404).json({ message: 'Kelompok tidak ditemukan' });
    }
    const group = groupResult.rows[0];

    // 2. Ambil daftar calon santri di kelompok tersebut
    const examineesResult = await db.query(`
      SELECT e.registration_number, e.name, e.gender, e.school, er.grade as placement, u.username as examiner_name
      FROM examinees e
      LEFT JOIN exam_results er ON e.id = er.examinee_id
      LEFT JOIN users u ON er.examiner_id = u.id
      WHERE e.group_id = $1
      ORDER BY e.name ASC
    `, [id]);
    const examinees = examineesResult.rows;

    // 3. Set header HTTP
    const filename = `Daftar_Santri_${group.group_name.replace(/\s+/g, '_')}.pdf`;
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);

    // 4. Buat dokumen PDF
    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    doc.pipe(res);

    // KOP Surat / Header Indah
    doc.fontSize(16).font('Helvetica-Bold').text('PANITIA UJIAN TES MASUK PONDOK PESANTREN', { align: 'center' });
    doc.fontSize(12).text('AL-HAMID CINTA MULYA', { align: 'center' });
    doc.moveDown(0.2);
    doc.fontSize(9).font('Helvetica-Oblique').text('Alamat: Cinta Mulya, Kec. Candipuro, Kabupaten Lampung Selatan', { align: 'center' });
    doc.moveDown(0.5);
    
    // Line separator ganda
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
    doc.moveDown(0.1);
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
    doc.moveDown(1.5);

    // Informasi Kelompok
    doc.fontSize(12).font('Helvetica-Bold').text(`LAPORAN KELOMPOK: ${group.group_name.toUpperCase()}`);
    doc.moveDown(0.4);
    doc.fontSize(10).font('Helvetica').text(`Kategori Gender: ${group.group_gender === 'PUTRA' ? 'PUTRA (Laki-laki)' : 'PUTRI (Perempuan)'}`);
    doc.text(`Keterangan: ${group.description || '-'}`);
    doc.moveDown(1.5);

    // Tabel Header
    doc.fontSize(10).font('Helvetica-Bold');
    const tableY = doc.y;
    
    // Background header tabel
    doc.rect(40, tableY - 5, 515, 20).fill('#e0e0e0');
    doc.fillColor('black');

    doc.text('No', 45, tableY);
    doc.text('No. Daftar', 75, tableY);
    doc.text('Nama Lengkap', 175, tableY);
    doc.text('Jenjang', 345, tableY);
    doc.text('Hasil Penempatan', 405, tableY);
    doc.text('Penguji', 495, tableY);

    // Bottom border of table header
    doc.moveTo(40, tableY + 15).lineTo(555, tableY + 15).stroke();
    doc.moveDown(1.2);

    // Render list examinees
    doc.fontSize(9).font('Helvetica');
    let currentY = tableY + 20;

    examinees.forEach((e, idx) => {
      // Cek limit halaman (A4 height is 842, margin bottom is 40)
      if (currentY > 780) {
        doc.addPage();
        currentY = 50; // reset Y
        
        doc.rect(40, currentY - 5, 515, 20).fill('#e0e0e0');
        doc.fillColor('black');
        doc.fontSize(10).font('Helvetica-Bold');
        doc.text('No', 45, currentY);
        doc.text('No. Daftar', 75, currentY);
        doc.text('Nama Lengkap', 175, currentY);
        doc.text('Jenjang', 345, currentY);
        doc.text('Hasil Penempatan', 405, currentY);
        doc.text('Penguji', 495, currentY);
        doc.moveTo(40, currentY + 15).lineTo(555, currentY + 15).stroke();
        doc.fontSize(9).font('Helvetica');
        currentY += 20;
      }

      // Horizontal divider tipis
      doc.moveTo(40, currentY + 12).lineTo(555, currentY + 12).strokeColor('#f0f0f0').stroke();
      doc.strokeColor('black'); // kembalikan warna stroke ke hitam

      doc.text(String(idx + 1), 45, currentY);
      doc.text(e.registration_number, 75, currentY);
      const displayName = e.name.length > 25 ? e.name.substring(0, 25) + '...' : e.name;
      doc.text(displayName, 175, currentY);
      doc.text(e.school, 345, currentY);
      doc.text(e.placement || 'Belum Dinilai', 405, currentY);
      doc.text(e.examiner_name || '-', 495, currentY);

      currentY += 18;
    });

    doc.end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Gagal membuat file PDF' });
  }
});

// GET /api/download/pdf/examiners - Download PDF akun login penguji (Putra/Putri dipisah)
app.get('/api/download/pdf/examiners', authenticateToken, requireRole('SUPER_USER'), async (req, res) => {
  try {
    // 1. Ambil data penguji beserta kelompoknya
    const result = await db.query(`
      SELECT u.username, u.plain_password, g.group_name, g.group_gender
      FROM users u
      LEFT JOIN groups g ON u.group_id = g.id
      WHERE u.role = 'EXAMINER'
      ORDER BY g.group_gender DESC, g.group_name ASC, u.username ASC
    `);
    const users = result.rows;

    // Pisah kelompok Putra dan Putri
    const putraUsers = users.filter(u => u.group_gender === 'PUTRA' || !u.group_gender);
    const putriUsers = users.filter(u => u.group_gender === 'PUTRI');

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="Info_Login_Penguji.pdf"');

    const doc = new PDFDocument({ margin: 40, size: 'A4' });
    doc.pipe(res);

    // KOP Surat
    doc.fontSize(16).font('Helvetica-Bold').text('PANITIA UJIAN TES MASUK PONDOK PESANTREN', { align: 'center' });
    doc.fontSize(12).text('AL-HAMID CINTA MULYA', { align: 'center' });
    doc.moveDown(0.2);
    doc.fontSize(9).font('Helvetica-Oblique').text('Alamat: Cinta Mulya, Kec. Candipuro, Kabupaten Lampung Selatan', { align: 'center' });
    doc.moveDown(0.5);
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
    doc.moveDown(0.1);
    doc.moveTo(40, doc.y).lineTo(555, doc.y).stroke();
    doc.moveDown(1.5);

    // Judul
    doc.fontSize(12).font('Helvetica-Bold').text('DAFTAR AKUN LOGIN PENGUJI (EXAMINER)', { align: 'center' });
    doc.moveDown(1.5);

    const renderSection = (title, userList) => {
      doc.fontSize(11).font('Helvetica-Bold').text(title);
      doc.moveDown(0.5);

      const tableY = doc.y;
      doc.rect(40, tableY - 5, 515, 20).fill('#e8e8e8');
      doc.fillColor('black');

      doc.fontSize(10).font('Helvetica-Bold');
      doc.text('No', 45, tableY);
      doc.text('Username', 80, tableY);
      doc.text('Password', 210, tableY);
      doc.text('Kelompok Tugas', 340, tableY);

      doc.moveTo(40, tableY + 15).lineTo(555, tableY + 15).stroke();
      doc.moveDown(1.2);

      doc.fontSize(9).font('Helvetica');
      let currentY = tableY + 20;

      if (userList.length === 0) {
        doc.text('Tidak ada data penguji.', 45, currentY);
        currentY += 20;
      } else {
        userList.forEach((u, idx) => {
          if (currentY > 780) {
            doc.addPage();
            currentY = 50;
            
            doc.rect(40, currentY - 5, 515, 20).fill('#e8e8e8');
            doc.fillColor('black');
            doc.fontSize(10).font('Helvetica-Bold');
            doc.text('No', 45, currentY);
            doc.text('Username', 80, currentY);
            doc.text('Password', 210, currentY);
            doc.text('Kelompok Tugas', 340, currentY);
            doc.moveTo(40, currentY + 15).lineTo(555, currentY + 15).stroke();
            doc.fontSize(9).font('Helvetica');
            currentY += 20;
          }

          doc.moveTo(40, currentY + 12).lineTo(555, currentY + 12).strokeColor('#f0f0f0').stroke();
          doc.strokeColor('black');

          doc.text(String(idx + 1), 45, currentY);
          doc.text(u.username, 80, currentY);
          doc.text(u.plain_password || '(Tidak Tersedia/Hashed)', 210, currentY);
          doc.text(u.group_name || 'Tanpa Kelompok', 340, currentY);

          currentY += 18;
        });
      }
      
      doc.y = currentY + 10;
      doc.moveDown(1.5);
    };

    // Render Kategori Putra
    renderSection('KATEGORI PENGUJI PUTRA', putraUsers);
    
    // Render Kategori Putri
    renderSection('KATEGORI PENGUJI PUTRI', putriUsers);

    doc.end();
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Gagal membuat file PDF' });
  }
});

// GET /api/download/excel/placements - Rekapitulasi hasil penempatan kelas dalam bentuk Excel (XLSX)
app.get('/api/download/excel/placements', authenticateToken, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT e.registration_number, e.name, e.gender, e.school, g.group_name,
             er.grade as placement, er.checked_at, u.username as examiner_name
      FROM examinees e
      LEFT JOIN groups g ON e.group_id = g.id
      LEFT JOIN exam_results er ON e.id = er.examinee_id
      LEFT JOIN users u ON er.examiner_id = u.id
      ORDER BY g.group_name ASC, e.name ASC
    `);
    const examinees = result.rows;

    const wb = XLSX.utils.book_new();

    const data = [
      ['REKAPITULASI HASIL PENEMPATAN KELAS SANTRI'],
      ['PONDOK PESANTREN AL-HAMID CINTA MULYA'],
      ['Tanggal Unduh: ' + new Date().toLocaleString('id-ID')],
      [],
      ['No', 'No. Pendaftaran', 'Nama Lengkap', 'Jenis Kelamin', 'Jenjang', 'Kelompok', 'Hasil Penempatan', 'Penguji', 'Tanggal Ceklis']
    ];

    examinees.forEach((e, idx) => {
      data.push([
        idx + 1,
        e.registration_number,
        e.name,
        e.gender,
        e.school,
        e.group_name || '-',
        e.placement || 'Belum Dinilai',
        e.examiner_name || '-',
        e.checked_at ? new Date(e.checked_at).toLocaleString('id-ID') : '-'
      ]);
    });

    const ws = XLSX.utils.aoa_to_sheet(data);

    ws['!cols'] = [
      { wch: 5 },  // No
      { wch: 18 }, // No. Pendaftaran
      { wch: 25 }, // Nama Lengkap
      { wch: 15 }, // Jenis Kelamin
      { wch: 10 }, // Jenjang
      { wch: 18 }, // Kelompok
      { wch: 18 }, // Hasil Penempatan
      { wch: 18 }, // Penguji
      { wch: 22 }  // Tanggal Ceklis
    ];

    XLSX.utils.book_append_sheet(wb, ws, 'Hasil Penempatan');

    const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename="Hasil_Penempatan_Santri.xlsx"');
    res.send(buf);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Gagal membuat file Excel' });
  }
});


// Jalankan Server
const startServer = async () => {
  try {
    // Migration: plain_password
    await db.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS plain_password VARCHAR(255)');
    console.log('Database migration: plain_password column verified/added successfully.');
    
    // Cleanup: delete orphaned examinees from previously deleted groups
    const deleteRes = await db.query('DELETE FROM examinees WHERE group_id IS NULL');
    if (deleteRes.rowCount > 0) {
      console.log(`Database cleanup: deleted ${deleteRes.rowCount} orphaned examinees with NULL group_id.`);
    }

    // Migration: alter foreign key constraint to ON DELETE CASCADE
    try {
      // 1. Drop existing fkey if it exists
      await db.query('ALTER TABLE examinees DROP CONSTRAINT IF EXISTS examinees_group_id_fkey');
      // 2. Add ON DELETE CASCADE constraint
      await db.query('ALTER TABLE examinees ADD CONSTRAINT examinees_group_id_fkey FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE');
      console.log('Database migration: examinees_group_id_fkey updated to ON DELETE CASCADE successfully.');
    } catch (fkErr) {
      console.error('Database migration error (foreign key):', fkErr);
    }
  } catch (err) {
    console.error('Database migration error:', err);
  }

  app.listen(PORT, () => {
    console.log(`Server Express berjalan di port ${PORT}`);
  });
};

startServer();

