-- =====================================================================
-- Wahana Express / Dijak Express — Master Stored Procedures Catalog
-- File: backend/db/procedures.sql
--
-- CATATAN:
--   File ini berisi seluruh definisi Stored Procedures resmi MariaDB.
--   Jalankan file ini ke database saat siap beralih ke Stored Procedures:
--     mysql -u root -p wahana_scan < backend/db/procedures.sql
-- =====================================================================

USE wahana_scan;

-- ---------------------------------------------------------------------
-- 0. ROLE DEVELOPER MIGRATION
-- ---------------------------------------------------------------------
ALTER TABLE users 
  MODIFY role ENUM('ADMIN', 'PETUGAS_SCAN', 'CUSTOMER', 'DEVELOPER') NOT NULL DEFAULT 'PETUGAS_SCAN';

-- Seeder Akun Developer Default: dev / dev123
INSERT INTO users (id, name, username, password_hash, role, status)
VALUES ('USR-DEV-001', 'Lead Developer', 'dev',
        CONCAT('sha256$', 'd3v12345', '$', SHA2(CONCAT('d3v12345', 'dev123'), 256)),
        'DEVELOPER', 'OFFLINE')
ON DUPLICATE KEY UPDATE name = VALUES(name);

DELIMITER //

-- =====================================================================
-- 1. USERS & AUTENTIKASI
-- =====================================================================

-- Ambil seluruh user
DROP PROCEDURE IF EXISTS sp_getusers //
CREATE PROCEDURE sp_getusers()
BEGIN
    SELECT id, name, username, role, status, last_login FROM users ORDER BY id ASC;
END //

-- Ambil user berdasarkan ID
DROP PROCEDURE IF EXISTS sp_getuserbyid //
CREATE PROCEDURE sp_getuserbyid(IN p_id VARCHAR(32))
BEGIN
    SELECT * FROM users WHERE id = p_id;
END //

-- Ambil user berdasarkan username untuk login
DROP PROCEDURE IF EXISTS sp_login //
CREATE PROCEDURE sp_login(IN p_username VARCHAR(50))
BEGIN
    SELECT * FROM users WHERE LOWER(username) = LOWER(p_username) LIMIT 1;
END //

-- Update status user online/offline
DROP PROCEDURE IF EXISTS sp_auth_update_status //
CREATE PROCEDURE sp_auth_update_status(IN p_user_id VARCHAR(32), IN p_status VARCHAR(20))
BEGIN
    IF p_status = 'ONLINE' THEN
        UPDATE users SET status = 'ONLINE', last_login = NOW() WHERE id = p_user_id;
    ELSE
        UPDATE users SET status = 'OFFLINE' WHERE id = p_user_id;
    END IF;
END //

-- =====================================================================
-- 2. RESI PAKET
-- =====================================================================

-- Buat Draft Resi Paket
DROP PROCEDURE IF EXISTS sp_paket_create_draft //
CREATE PROCEDURE sp_paket_create_draft(IN p_resi VARCHAR(16), IN p_created_by VARCHAR(32))
BEGIN
    INSERT INTO paket (nomor_resi, status, created_by, telepon_pengirim, telepon_penerima, created_at)
    VALUES (p_resi, 'DRAFT', p_created_by, '', '', NOW());
    
    SELECT p.*, u.name AS creator_name 
      FROM paket p LEFT JOIN users u ON u.id = p.created_by 
     WHERE p.nomor_resi = p_resi;
END //

-- Simpan Data Paket Menjadi TERDAFTAR
DROP PROCEDURE IF EXISTS sp_paket_save //
CREATE PROCEDURE sp_paket_save(
    IN p_resi VARCHAR(16), 
    IN p_nama VARCHAR(150), 
    IN p_pengirim VARCHAR(100),
    IN p_alamat_p VARCHAR(255), 
    IN p_telp_p VARCHAR(20), 
    IN p_penerima VARCHAR(100),
    IN p_alamat_t VARCHAR(255), 
    IN p_telp_t VARCHAR(20), 
    IN p_berat DECIMAL(6,2), 
    IN p_layanan VARCHAR(20)
)
BEGIN
    UPDATE paket
       SET nama_barang = p_nama, 
           pengirim = p_pengirim, 
           alamat_pengirim = p_alamat_p, 
           telepon_pengirim = p_telp_p,
           penerima = p_penerima, 
           alamat_tujuan = p_alamat_t, 
           telepon_penerima = p_telp_t,
           berat_kg = p_berat, 
           jenis_layanan = p_layanan, 
           status = 'TERDAFTAR', 
           created_at = NOW()
     WHERE nomor_resi = p_resi;
     
    SELECT p.*, u.name AS creator_name 
      FROM paket p LEFT JOIN users u ON u.id = p.created_by 
     WHERE p.nomor_resi = p_resi;
END //

-- =====================================================================
-- 3. TRANSAKSI SCAN PAKET ATOMIK
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_scans_process //
CREATE PROCEDURE sp_scans_process(
    IN p_scan_id VARCHAR(32), 
    IN p_resi VARCHAR(16), 
    IN p_user_id VARCHAR(32),
    IN p_task_id VARCHAR(32), 
    IN p_lokasi VARCHAR(100), 
    IN p_device VARCHAR(50), 
    IN p_jenis VARCHAR(20)
)
proc: BEGIN
    DECLARE v_paket_status VARCHAR(20);
    DECLARE v_task_status VARCHAR(20);
    DECLARE v_dup_count INT DEFAULT 0;
    
    -- 1. Validasi Paket
    SELECT status INTO v_paket_status FROM paket WHERE nomor_resi = p_resi;
    IF v_paket_status IS NULL THEN
        SELECT 'UNKNOWN_RESI' AS result_code, 'Nomor resi tidak terdaftar.' AS message;
        LEAVE proc;
    END IF;
    IF v_paket_status = 'DRAFT' THEN
        SELECT 'DRAFT' AS result_code, 'Nomor resi masih DRAFT.' AS message;
        LEAVE proc;
    END IF;
    
    -- 2. Kunci Task
    SELECT status INTO v_task_status FROM tasks WHERE task_id = p_task_id FOR UPDATE;
    IF v_task_status IS NULL OR v_task_status = 'SELESAI' THEN
        SELECT 'FINISHED' AS result_code, 'Task sudah selesai atau tidak ditemukan.' AS message;
        LEAVE proc;
    END IF;
    
    -- 3. Cek Duplikasi
    SELECT COUNT(*) INTO v_dup_count FROM scan_events 
     WHERE task_id = p_task_id AND UPPER(nomor_resi) = UPPER(p_resi) AND status_scan = 'SUCCESS';
     
    IF v_dup_count > 0 THEN
        INSERT INTO scan_events (scan_id, nomor_resi, user_id, task_id, waktu_scan, lokasi, status_scan, device_id, jenis_scan)
        VALUES (p_scan_id, p_resi, p_user_id, p_task_id, NOW(), p_lokasi, 'DUPLICATE', p_device, p_jenis);
        SELECT 'DUPLICATE' AS result_code, 'Nomor resi sudah pernah discan.' AS message, p_scan_id AS scan_id;
    ELSE
        INSERT INTO scan_events (scan_id, nomor_resi, user_id, task_id, waktu_scan, lokasi, status_scan, device_id, jenis_scan)
        VALUES (p_scan_id, p_resi, p_user_id, p_task_id, NOW(), p_lokasi, 'SUCCESS', p_device, p_jenis);
        UPDATE tasks SET progress = progress + 1 WHERE task_id = p_task_id;
        SELECT 'SUCCESS' AS result_code, 'Nomor resi berhasil discan.' AS message, p_scan_id AS scan_id;
    END IF;
END //

-- =====================================================================
-- 4. SYSTEM & PROCEDURE INSPECTOR (Untuk Halaman Developer)
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_dev_list_procedures //
CREATE PROCEDURE sp_dev_list_procedures()
BEGIN
    SELECT ROUTINE_NAME AS procedure_name,
           ROUTINE_SCHEMA AS database_name,
           ROUTINE_DEFINITION AS routine_definition,
           CREATED AS created_at,
           LAST_ALTERED AS last_altered
      FROM information_schema.ROUTINES
     WHERE ROUTINE_SCHEMA = 'wahana_scan'
     ORDER BY ROUTINE_NAME ASC;
END //

DELIMITER ;
