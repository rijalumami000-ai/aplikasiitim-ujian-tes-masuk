const db = require('./db');
const bcrypt = require('bcryptjs');

const initSchema = async () => {
  const client = await db.pool.connect();
  try {
    console.log('Memulai inisialisasi skema database...');

    // Buat ENUM Types jika belum ada
    await client.query(`
      DO $$
      BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
              CREATE TYPE user_role AS ENUM ('SUPER_USER', 'EXAMINER');
          END IF;
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'class_grade') THEN
              CREATE TYPE class_grade AS ENUM ('SIFIR', 'SATU', 'SP');
          END IF;
      END$$;
    `);
    console.log('Tipe ENUM berhasil divalidasi/dibuat.');

    // Buat tabel users
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          username VARCHAR(50) UNIQUE NOT NULL,
          password VARCHAR(255) NOT NULL,
          role user_role DEFAULT 'EXAMINER',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('Tabel "users" berhasil divalidasi/dibuat.');

    // Buat tabel groups
    await client.query(`
      CREATE TABLE IF NOT EXISTS groups (
          id SERIAL PRIMARY KEY,
          group_name VARCHAR(100) UNIQUE NOT NULL,
          description TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('Tabel "groups" berhasil divalidasi/dibuat.');

    // Buat tabel user_groups (Penugasan)
    await client.query(`
      CREATE TABLE IF NOT EXISTS user_groups (
          user_id INT REFERENCES users(id) ON DELETE CASCADE,
          group_id INT REFERENCES groups(id) ON DELETE CASCADE,
          PRIMARY KEY (user_id, group_id)
      );
    `);
    console.log('Tabel "user_groups" berhasil divalidasi/dibuat.');

    // Buat tabel examinees (Calon Santri)
    await client.query(`
      CREATE TABLE IF NOT EXISTS examinees (
          id SERIAL PRIMARY KEY,
          registration_number VARCHAR(50) UNIQUE NOT NULL,
          name VARCHAR(100) NOT NULL,
          group_id INT REFERENCES groups(id) ON DELETE CASCADE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('Tabel "examinees" berhasil divalidasi/dibuat.');

    // Tabel exam_results (Ceklis penempatan)
    await client.query(`
      CREATE TABLE IF NOT EXISTS exam_results (
          id SERIAL PRIMARY KEY,
          examinee_id INT UNIQUE REFERENCES examinees(id) ON DELETE CASCADE,
          grade class_grade NOT NULL,
          examiner_id INT REFERENCES users(id) ON DELETE SET NULL,
          checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('Tabel "exam_results" berhasil divalidasi/dibuat.');

    const adminCheck = await client.query("SELECT * FROM users WHERE username = 'alhamidcintamulya'");
    if (adminCheck.rows.length === 0) {
      console.log('Tidak ditemukan akun super user alhamidcintamulya. Membuat akun...');
      const hashedPassword = await bcrypt.hash('alhamidku123', 10);
      await client.query(
        "INSERT INTO users (username, password, role) VALUES ($1, $2, $3)",
        ['alhamidcintamulya', hashedPassword, 'SUPER_USER']
      );
      console.log('Akun super user default berhasil dibuat:');
      console.log('Username: alhamidcintamulya');
      console.log('Password: alhamidku123');
    } else {
      console.log('Akun super user alhamidcintamulya sudah terdaftar.');
    }

    console.log('Inisialisasi skema database selesai dengan sukses!');
  } catch (err) {
    console.error('Error saat melakukan inisialisasi database:', err);
  } finally {
    client.release();
    db.pool.end();
  }
};

initSchema();
