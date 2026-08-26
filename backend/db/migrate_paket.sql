-- =====================================================================
-- Wahana Express — Migrasi: Fitur Paket + Role CUSTOMER
-- Untuk database wahana_scan yang SUDAH ADA (dari skema versi lama).
--
-- Cara jalankan:
--   mysql -u root -p < backend/db/migrate_paket.sql
--
-- CATATAN PENTING:
--   FK scan_events.nomor_resi → paket.nomor_resi bersifat ketat.
--   Baris scan_events dengan resi yang tidak terdaftar di tabel paket
--   HARUS dibersihkan/dipetakan dulu, jika tidak FK akan gagal dibuat.
-- =====================================================================
USE wahana_scan;

-- 1. Tambah role CUSTOMER ke enum users.role
ALTER TABLE users
  MODIFY role ENUM('ADMIN','SUPERVISOR','PETUGAS_SCAN','CUSTOMER') NOT NULL;

-- 2. Tabel paket (master data; resi digenerate backend)
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

-- 3. Daftarkan resi lama yang sudah pernah discan sebagai paket TERDAFTAR
--    (agar FK bisa dibuat tanpa menghapus riwayat scan).
INSERT IGNORE INTO paket
  (nomor_resi, nama_barang, pengirim, penerima, status, created_at)
SELECT DISTINCT se.nomor_resi, '(migrasi) resi legacy', 'Migrasi Sistem', '-', 'TERDAFTAR', NOW()
  FROM scan_events se
 WHERE NOT EXISTS (SELECT 1 FROM paket p WHERE p.nomor_resi = se.nomor_resi);

-- 4. FK ketat: hanya resi terdaftar boleh masuk scan_events
ALTER TABLE scan_events
  ADD CONSTRAINT fk_scans_resi
  FOREIGN KEY (nomor_resi) REFERENCES paket (nomor_resi);

-- 5. Akun customer demo (password: cust123)
INSERT INTO users (id, name, username, password_hash, role, supervisor_id, status)
VALUES ('USR-CUST-001', 'Customer Demo', 'customer',
        CONCAT('sha256$', 'a1b2c3d4', '$', SHA2(CONCAT('a1b2c3d4', 'cust123'), 256)),
        'CUSTOMER', NULL, 'OFFLINE');
