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
CREATE DATABASE IF NOT EXISTS wahana_scan CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'wahana_app' @'localhost' IDENTIFIED BY 'wahana_pass';

CREATE USER IF NOT EXISTS 'wahana_app' @'127.0.0.1' IDENTIFIED BY 'wahana_pass';

CREATE USER IF NOT EXISTS 'wahana_app' @'%' IDENTIFIED BY 'wahana_pass';

GRANT
SELECT,
INSERT
,
UPDATE ON wahana_scan.* TO 'wahana_app' @'localhost';

GRANT
SELECT,
INSERT
,
UPDATE ON wahana_scan.* TO 'wahana_app' @'127.0.0.1';

GRANT SELECT, INSERT , UPDATE ON wahana_scan.* TO 'wahana_app' @'%';

FLUSH PRIVILEGES;

USE wahana_scan;

-- ---------------------------------------------------------------------
-- Tabel USERS
-- Format password_hash: sha256$<salt>$<sha256_hex(salt + password)>
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(32) NOT NULL,
    name VARCHAR(100) NOT NULL,
    username VARCHAR(50) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM(
        'ADMIN',
        'PETUGAS_SCAN',
        'CUSTOMER'
    ) NOT NULL,
    status ENUM(
        'ONLINE',
        'OFFLINE',
        'DISABLED'
    ) NOT NULL DEFAULT 'OFFLINE',
    last_login DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_username (username)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Tabel TASKS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tasks (
    task_id VARCHAR(32) NOT NULL,
    user_id VARCHAR(32) NOT NULL,
    shift ENUM('Pagi', 'Sore') NOT NULL DEFAULT 'Pagi',
    tanggal DATE NOT NULL,
    target INT NOT NULL DEFAULT 100,
    progress INT NOT NULL DEFAULT 0,
    status ENUM(
        'DRAFT',
        'PROSES_SCAN',
        'SELESAI'
    ) NOT NULL DEFAULT 'DRAFT',
    lokasi VARCHAR(100) NOT NULL DEFAULT 'CIPUTAT',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (task_id),
    KEY idx_tasks_user (user_id),
    KEY idx_tasks_status (status),
    CONSTRAINT fk_tasks_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Tabel PAKET
-- Master data paket/barang. Nomor resi SELALU digenerate oleh backend
-- (8 karakter alfanumerik acak tanpa I/O/0/1) — klien tidak pernah
-- mengirim nomor resi buatannya sendiri.
-- Alur: CUSTOMER generate resi (DRAFT) → isi data barang → TERDAFTAR.
-- Hanya paket TERDAFTAR yang boleh discan petugas (validasi backend).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS paket (
    nomor_resi VARCHAR(16) NOT NULL,
    nama_barang VARCHAR(150) NULL,
    pengirim VARCHAR(100) NULL,
    alamat_pengirim VARCHAR(255) NULL,
    telepon_pengirim VARCHAR(20) NOT NULL DEFAULT '',
    pengirim_detail TEXT NULL,
    penerima VARCHAR(100) NULL,
    alamat_tujuan VARCHAR(255) NULL,
    telepon_penerima VARCHAR(20) NOT NULL DEFAULT '',
    penerima_detail TEXT NULL,
    berat_kg DECIMAL(6, 2) NOT NULL DEFAULT 0,
    jenis_layanan ENUM(
        'REGULER',
        'EXPRESS',
        'SAME_DAY'
    ) NOT NULL DEFAULT 'REGULER',
    status ENUM('DRAFT', 'TERDAFTAR') NOT NULL DEFAULT 'DRAFT',
    created_by VARCHAR(32) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (nomor_resi),
    KEY idx_paket_created_by (created_by),
    CONSTRAINT fk_paket_user FOREIGN KEY (created_by) REFERENCES users (id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Tabel SCAN_EVENTS
-- Satu nomor resi hanya boleh SUCCESS satu kali per task
-- (validasi dilakukan transaksional di backend).
-- FK ketat ke paket: hanya resi terdaftar yang bisa discan.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scan_events (
    scan_id VARCHAR(32) NOT NULL,
    nomor_resi VARCHAR(64) NOT NULL,
    user_id VARCHAR(32) NOT NULL,
    task_id VARCHAR(32) NOT NULL,
    waktu_scan DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    lokasi VARCHAR(100) NOT NULL DEFAULT 'CIPUTAT',
    status_scan ENUM('SUCCESS', 'DUPLICATE') NOT NULL DEFAULT 'SUCCESS',
    device_id VARCHAR(50) NOT NULL DEFAULT 'SCAN-DEVICE-01',
    jenis_scan ENUM('INBOUND', 'OUTBOUND') NOT NULL DEFAULT 'INBOUND',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (scan_id),
    KEY idx_scans_task (task_id),
    KEY idx_scans_user (user_id),
    KEY idx_scans_resi (nomor_resi),
    CONSTRAINT fk_scans_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_scans_task FOREIGN KEY (task_id) REFERENCES tasks (task_id),
    CONSTRAINT fk_scans_resi FOREIGN KEY (nomor_resi) REFERENCES paket (nomor_resi)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Tabel AUDIT_LOGS
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    log_id BIGINT NOT NULL AUTO_INCREMENT,
    user_id VARCHAR(32) NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT NULL,
    ip_address VARCHAR(45) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    KEY idx_audit_user (user_id),
    KEY idx_audit_action (action),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB;

-- =====================================================================
-- SEED DATA — Akun Demo (PRD bagian 3)
-- =====================================================================
INSERT IGNORE INTO users (id, name, username, password_hash, role, status, last_login) VALUES
('USR-ADMIN-001', 'Admin System',
 'admin',
 CONCAT('sha256$', '9f1c2a7e', '$', SHA2(CONCAT('9f1c2a7e', 'admin123'), 256)),
 'ADMIN', 'OFFLINE', '2026-08-24 08:00:00');