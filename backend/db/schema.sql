-- =====================================================================
-- Wahana Express — Scan Paket Logistik Berbasis Barcode
-- Skema Database (sesuai ERD PRD v1.0.0 bagian 6)
-- Target: MariaDB / MySQL
--
-- Cara load:
--   mysql -u root -p < backend/db/schema.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- Database & User Aplikasi
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS wahana_scan
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'wahana_app'@'localhost' IDENTIFIED BY 'wahana_pass';
CREATE USER IF NOT EXISTS 'wahana_app'@'127.0.0.1' IDENTIFIED BY 'wahana_pass';
CREATE USER IF NOT EXISTS 'wahana_app'@'%'         IDENTIFIED BY 'wahana_pass';

GRANT SELECT, INSERT, UPDATE ON wahana_scan.* TO 'wahana_app'@'localhost';
GRANT SELECT, INSERT, UPDATE ON wahana_scan.* TO 'wahana_app'@'127.0.0.1';
GRANT SELECT, INSERT, UPDATE ON wahana_scan.* TO 'wahana_app'@'%';
FLUSH PRIVILEGES;

USE wahana_scan;

-- ---------------------------------------------------------------------
-- Tabel USERS
-- Format password_hash: sha256$<salt>$<sha256_hex(salt + password)>
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            VARCHAR(32)  NOT NULL,
  name          VARCHAR(100) NOT NULL,
  username      VARCHAR(50)  NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('ADMIN','SUPERVISOR','PETUGAS_SCAN','CUSTOMER') NOT NULL,
  supervisor_id VARCHAR(32)  NULL,
  status        ENUM('ONLINE','OFFLINE','DISABLED') NOT NULL DEFAULT 'OFFLINE',
  last_login    DATETIME     NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  KEY idx_users_supervisor (supervisor_id),
  CONSTRAINT fk_users_supervisor
    FOREIGN KEY (supervisor_id) REFERENCES users (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabel TASKS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tasks (
  task_id    VARCHAR(32)  NOT NULL,
  user_id    VARCHAR(32)  NOT NULL,
  shift      ENUM('Pagi','Sore') NOT NULL DEFAULT 'Pagi',
  tanggal    DATE         NOT NULL,
  target     INT          NOT NULL DEFAULT 100,
  progress   INT          NOT NULL DEFAULT 0,
  status     ENUM('DRAFT','PROSES_SCAN','SELESAI') NOT NULL DEFAULT 'DRAFT',
  lokasi     VARCHAR(100) NOT NULL DEFAULT 'CIPUTAT',
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (task_id),
  KEY idx_tasks_user (user_id),
  KEY idx_tasks_status (status),
  CONSTRAINT fk_tasks_user
    FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabel PAKET
-- Master data paket/barang. Nomor resi SELALU digenerate oleh backend
-- (8 karakter alfanumerik acak tanpa I/O/0/1) — klien tidak pernah
-- mengirim nomor resi buatannya sendiri.
-- Alur: CUSTOMER generate resi (DRAFT) → isi data barang → TERDAFTAR.
-- Hanya paket TERDAFTAR yang boleh discan petugas (validasi backend).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS paket (
  nomor_resi    VARCHAR(16)  NOT NULL,
  nama_barang   VARCHAR(150) NULL,
  pengirim      VARCHAR(100) NULL,
  penerima      VARCHAR(100) NULL,
  alamat_tujuan VARCHAR(255) NULL,
  berat_kg      DECIMAL(6,2) NOT NULL DEFAULT 0,
  jenis_layanan ENUM('REGULER','EXPRESS','SAME_DAY') NOT NULL DEFAULT 'REGULER',
  status        ENUM('DRAFT','TERDAFTAR') NOT NULL DEFAULT 'DRAFT',
  created_by    VARCHAR(32)  NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (nomor_resi),
  KEY idx_paket_created_by (created_by),
  CONSTRAINT fk_paket_user
    FOREIGN KEY (created_by) REFERENCES users (id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabel SCAN_EVENTS
-- Satu nomor resi hanya boleh SUCCESS satu kali per task
-- (validasi dilakukan transaksional di backend).
-- FK ketat ke paket: hanya resi terdaftar yang bisa discan.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scan_events (
  scan_id     VARCHAR(32) NOT NULL,
  nomor_resi  VARCHAR(64) NOT NULL,
  user_id     VARCHAR(32) NOT NULL,
  task_id     VARCHAR(32) NOT NULL,
  waktu_scan  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  lokasi      VARCHAR(100) NOT NULL DEFAULT 'CIPUTAT',
  status_scan ENUM('SUCCESS','DUPLICATE') NOT NULL DEFAULT 'SUCCESS',
  device_id   VARCHAR(50) NOT NULL DEFAULT 'SCAN-DEVICE-01',
  jenis_scan  ENUM('INBOUND','OUTBOUND') NOT NULL DEFAULT 'INBOUND',
  created_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (scan_id),
  KEY idx_scans_task (task_id),
  KEY idx_scans_user (user_id),
  KEY idx_scans_resi (nomor_resi),
  CONSTRAINT fk_scans_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_scans_task FOREIGN KEY (task_id) REFERENCES tasks (task_id),
  CONSTRAINT fk_scans_resi FOREIGN KEY (nomor_resi) REFERENCES paket (nomor_resi)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tabel AUDIT_LOGS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  log_id     BIGINT       NOT NULL AUTO_INCREMENT,
  user_id    VARCHAR(32)  NULL,
  action     VARCHAR(100) NOT NULL,
  details    TEXT         NULL,
  ip_address VARCHAR(45)  NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id),
  KEY idx_audit_user (user_id),
  KEY idx_audit_action (action),
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB;

-- =====================================================================
-- SEED DATA — Akun Demo (PRD bagian 3)
-- =====================================================================
INSERT INTO users (id, name, username, password_hash, role, supervisor_id, status, last_login) VALUES
('USR-ADMIN-001', 'Admin System',
 'admin',
 CONCAT('sha256$', '9f1c2a7e', '$', SHA2(CONCAT('9f1c2a7e', 'admin123'), 256)),
 'ADMIN', NULL, 'OFFLINE', '2026-08-24 08:00:00'),
('USR-SPV-001', 'Supervisor A',
 'supervisor',
 CONCAT('sha256$', '4b8d11c9', '$', SHA2(CONCAT('4b8d11c9', 'supervisor123'), 256)),
 'SUPERVISOR', NULL, 'OFFLINE', '2026-08-24 08:15:00'),
('USR-001', 'Fadhil',
 'fadhil',
 CONCAT('sha256$', '77aa01fe', '$', SHA2(CONCAT('77aa01fe', 'fadhil123'), 256)),
 'PETUGAS_SCAN', 'USR-SPV-001', 'OFFLINE', '2026-08-24 10:20:00'),
('USR-002', 'Budi',
 'budi',
 CONCAT('sha256$', 'c3e90b21', '$', SHA2(CONCAT('c3e90b21', 'budi123'), 256)),
 'PETUGAS_SCAN', 'USR-SPV-001', 'OFFLINE', '2026-08-24 09:45:00'),
('USR-003', 'Andi',
 'andi',
 CONCAT('sha256$', '5d40fa88', '$', SHA2(CONCAT('5d40fa88', 'andi123'), 256)),
 'PETUGAS_SCAN', 'USR-SPV-001', 'OFFLINE', '2026-08-23 17:30:00'),
('USR-CUST-001', 'Customer Demo',
 'customer',
 CONCAT('sha256$', 'a1b2c3d4', '$', SHA2(CONCAT('a1b2c3d4', 'cust123'), 256)),
 'CUSTOMER', NULL, 'OFFLINE', '2026-08-24 09:00:00');

-- =====================================================================
-- SEED DATA — Task / Batch
-- =====================================================================
INSERT INTO tasks (task_id, user_id, shift, tanggal, target, progress, status, lokasi) VALUES
('TASK-001', 'USR-001', 'Pagi', '2026-08-24', 100, 3, 'PROSES_SCAN', 'CIPUTAT'),
('TASK-002', 'USR-002', 'Pagi', '2026-08-24', 80,  2, 'PROSES_SCAN', 'CIPUTAT'),
('TASK-003', 'USR-003', 'Pagi', '2026-08-24', 120, 2, 'PROSES_SCAN', 'CIPUTAT');

-- =====================================================================
-- SEED DATA — Paket (wajib ada sebelum scan_events karena FK resi)
-- =====================================================================
INSERT INTO paket (nomor_resi, nama_barang, pengirim, penerima, alamat_tujuan, berat_kg, jenis_layanan, status, created_by, created_at) VALUES
('GJXL8FLB',  'Dokumen Kontrak',   'PT Sinar Jaya', 'Rina Wulandari', 'Jl. Margonda Raya No. 12, Depok',    1.20, 'EXPRESS',   'TERDAFTAR', 'USR-CUST-001', '2026-08-24 09:10:00'),
('AB123456',  'Sepatu Olahraga',   'Toko Amanah',   'Dedi Kurniawan', 'Jl. Raya Ciputat No. 45, Tangerang', 2.50, 'REGULER',   'TERDAFTAR', 'USR-CUST-001', '2026-08-24 09:12:00'),
('WHN555555', 'Laptop Kerja',      'CV Techindo',   'Sari Melati',    'Jl. Sudirman Kav. 21, Jakarta',      3.80, 'SAME_DAY',  'TERDAFTAR', 'USR-CUST-001', '2026-08-24 09:15:00'),
('XYZ123456', 'Buku Tulis (12 pcs)', 'Toko Buku Ilmu', 'Ahmad Fauzi',  'Jl. Kampus Barat No. 8, Ciputat',    4.00, 'REGULER',   'TERDAFTAR', 'USR-CUST-001', '2026-08-24 09:18:00'),
('WHN777777', 'Kamera Mirrorless', 'PhotoMart',     'Bagas Pratama',  'Jl. Cempaka Putih No. 3, Jakarta',   2.10, 'EXPRESS',   'TERDAFTAR', 'USR-CUST-001', '2026-08-24 09:20:00'),
('ABC111111', 'Serum Skincare',    'GlowStore',     'Nadia Putri',    'Jl. Kartini No. 19, South Tangerang',0.60, 'SAME_DAY',  'TERDAFTAR', 'USR-CUST-001', '2026-08-24 09:22:00'),
('ABC222222', 'Helm Motor',        'RideSafe Shop', 'Yoga Saputra',   'Jl. Ir. Juanda No. 77, Depok',       1.90, 'REGULER',   'TERDAFTAR', 'USR-CUST-001', '2026-08-24 09:25:00');

-- =====================================================================
-- SEED DATA — Scan Events
-- =====================================================================
INSERT INTO scan_events (scan_id, nomor_resi, user_id, task_id, waktu_scan, lokasi, status_scan, device_id, jenis_scan) VALUES
('SCN-00001', 'GJXL8FLB',  'USR-001', 'TASK-001', '2026-08-24 10:21:32', 'CIPUTAT', 'SUCCESS',   'SCAN-DEVICE-01', 'INBOUND'),
('SCN-00002', 'AB123456',  'USR-001', 'TASK-001', '2026-08-24 10:22:10', 'CIPUTAT', 'SUCCESS',   'SCAN-DEVICE-01', 'INBOUND'),
('SCN-00003', 'WHN555555', 'USR-001', 'TASK-001', '2026-08-24 10:23:45', 'CIPUTAT', 'SUCCESS',   'SCAN-DEVICE-01', 'INBOUND'),
('SCN-00004', 'XYZ123456', 'USR-002', 'TASK-002', '2026-08-24 10:22:10', 'CIPUTAT', 'SUCCESS',   'SCAN-DEVICE-02', 'INBOUND'),
('SCN-00005', 'WHN777777', 'USR-002', 'TASK-002', '2026-08-24 10:24:12', 'CIPUTAT', 'SUCCESS',   'SCAN-DEVICE-02', 'INBOUND'),
('SCN-00006', 'ABC111111', 'USR-003', 'TASK-003', '2026-08-24 10:15:00', 'CIPUTAT', 'SUCCESS',   'SCAN-DEVICE-03', 'INBOUND'),
('SCN-00007', 'ABC222222', 'USR-003', 'TASK-003', '2026-08-24 10:18:30', 'CIPUTAT', 'SUCCESS',   'SCAN-DEVICE-03', 'INBOUND');

-- =====================================================================
-- SEED DATA — Audit Logs
-- =====================================================================
INSERT INTO audit_logs (log_id, user_id, action, details, ip_address, created_at) VALUES
(1, 'USR-001',     'LOGIN_SUCCESS',       'Login berhasil.',                    '192.168.3.189', '2026-08-24 10:20:00'),
(2, 'USR-001',     'SCAN_EVENT_CREATED',  'Resi: GJXL8FLB, Status: SUCCESS',    '192.168.3.189', '2026-08-24 10:21:32'),
(3, 'USR-002',     'LOGIN_SUCCESS',       'Login berhasil.',                    '192.168.3.102', '2026-08-24 09:45:00'),
(4, 'USR-SPV-001', 'LOGIN_SUCCESS',       'Monitoring rayon active',            '192.168.3.10',  '2026-08-24 08:15:00');
