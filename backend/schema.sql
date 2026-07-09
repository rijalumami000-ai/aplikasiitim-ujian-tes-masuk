-- Buat ENUM Types jika belum ada
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('SUPER_USER', 'EXAMINER');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'class_grade') THEN
        CREATE TYPE class_grade AS ENUM ('SIFIR', 'SATU', 'SP');
    END IF;
END$$;

-- Buat tabel groups
CREATE TABLE IF NOT EXISTS groups (
    id SERIAL PRIMARY KEY,
    group_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Buat tabel users
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role user_role DEFAULT 'EXAMINER',
    group_id INT REFERENCES groups(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Buat tabel examinees (Calon Santri)
CREATE TABLE IF NOT EXISTS examinees (
    id SERIAL PRIMARY KEY,
    registration_number VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(10) NOT NULL, -- 'PUTRA' atau 'PUTRI'
    school VARCHAR(10) NOT NULL, -- 'MTS' atau 'ALIYAH'
    group_id INT REFERENCES groups(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabel exam_results (Ceklis penempatan)
CREATE TABLE IF NOT EXISTS exam_results (
    id SERIAL PRIMARY KEY,
    examinee_id INT UNIQUE REFERENCES examinees(id) ON DELETE CASCADE,
    grade class_grade NOT NULL,
    examiner_id INT REFERENCES users(id) ON DELETE SET NULL,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
