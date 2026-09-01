-- =====================================================================
-- Wahana Express / Dijak Express — Master Stored Procedures Catalog
-- File: backend/db/procedures.sql
--
-- Seluruh 23 Query & Stored Procedures Lengkap Sistem (100% Cakupan)
-- =====================================================================

USE wahana_scan;

-- ---------------------------------------------------------------------
-- 0. ROLE DEVELOPER MIGRATION & SYSTEM QUERY CATALOG TABLE
-- ---------------------------------------------------------------------
ALTER TABLE users 
  MODIFY role ENUM('ADMIN', 'PETUGAS_SCAN', 'CUSTOMER', 'DEVELOPER') NOT NULL DEFAULT 'PETUGAS_SCAN';

-- Seeder Akun Developer Default: dev / dev123
INSERT INTO users (id, name, username, password_hash, role, status)
VALUES ('USR-DEV-001', 'Lead Developer', 'dev',
        CONCAT('sha256$', 'd3v12345', '$', SHA2(CONCAT('d3v12345', 'dev123'), 256)),
        'DEVELOPER', 'OFFLINE')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ---------------------------------------------------------------------
-- Master System Query Table: sys_queries
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_queries (
    query_id        VARCHAR(32)   PRIMARY KEY,
    query_code      VARCHAR(64)   UNIQUE NOT NULL,
    sp_name         VARCHAR(64)   NOT NULL,
    param_keys      TEXT          NULL,
    query_type      ENUM('SELECT_ROW', 'SELECT_ALL', 'EXECUTE') NOT NULL DEFAULT 'SELECT_ROW',
    required_role   ENUM('PUBLIC', 'PETUGAS_SCAN', 'ADMIN', 'DEVELOPER') NOT NULL DEFAULT 'PUBLIC',
    cache_ttl       INT           DEFAULT 0,
    timeout_sec     INT           DEFAULT 5,
    deskripsi       VARCHAR(255)  NULL,
    status          ENUM('ACTIVE', 'MAINTENANCE', 'DEPRECATED') DEFAULT 'ACTIVE',
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Master Seeder: Seluruh 23 Query Sistem
-- ---------------------------------------------------------------------
INSERT INTO sys_queries (query_id, query_code, sp_name, param_keys, query_type, required_role, cache_ttl, timeout_sec, deskripsi) VALUES
-- AUTH & USERS (QRY-001 s/d QRY-008)
('QRY-001', 'UsersListAll',      'sp_getusers',           '[]', 'SELECT_ALL', 'ADMIN', 0, 5, 'Ambil seluruh daftar user'),
('QRY-002', 'UsersGetById',      'sp_getuserbyid',        '["id"]', 'SELECT_ROW', 'ADMIN', 0, 5, 'Ambil data user berdasarkan ID'),
('QRY-003', 'AuthLogin',         'sp_login',              '["username"]', 'SELECT_ROW', 'PUBLIC', 0, 5, 'Autentikasi login user'),
('QRY-004', 'AuthUpdateStatus',  'sp_auth_update_status', '["user_id", "status"]', 'EXECUTE', 'PUBLIC', 0, 5, 'Update status online/offline user'),
('QRY-005', 'UsersInsert',       'sp_users_insert',       '["id","name","username","password_hash","role","status"]', 'EXECUTE', 'ADMIN', 0, 5, 'Tambah user baru oleh admin'),
('QRY-006', 'UsersUpdate',       'sp_users_update',       '["id","name","username","role","password_hash"]', 'EXECUTE', 'ADMIN', 0, 5, 'Update profil & password user'),
('QRY-007', 'UsersDelete',       'sp_users_delete',       '["id"]', 'EXECUTE', 'ADMIN', 0, 5, 'Hapus user dari database'),
('QRY-008', 'UsersToggleStatus', 'sp_users_toggle_status', '["id","status"]', 'EXECUTE', 'ADMIN', 0, 5, 'Aktifkan/Nonaktifkan status akun user'),

-- PAKET & RESI (QRY-009 s/d QRY-012)
('QRY-009', 'PaketCreateDraft',  'sp_paket_create_draft', '["resi", "created_by"]', 'SELECT_ROW', 'PETUGAS_SCAN', 0, 5, 'Generate nomor resi draft paket'),
('QRY-010', 'CustInsert',        'sp_paket_save',         '["resi","nama_barang","pengirim","alamat_pengirim","telepon_pengirim","penerima","alamat_tujuan","telepon_penerima","berat_kg","jenis_layanan"]', 'SELECT_ROW', 'PETUGAS_SCAN', 0, 5, 'Simpan data paket customer menjadi TERDAFTAR'),
('QRY-011', 'PaketListAll',      'sp_paket_list',         '[]', 'SELECT_ALL', 'PUBLIC', 0, 5, 'Ambil seluruh daftar paket'),
('QRY-012', 'PaketGetDetail',    'sp_paket_get_detail',   '["resi"]', 'SELECT_ROW', 'PUBLIC', 0, 5, 'Ambil detail paket berdasarkan nomor resi'),

-- TASKS / TUGAS SCAN (QRY-013 s/d QRY-017)
('QRY-013', 'TasksListAll',      'sp_tasks_list',         '[]', 'SELECT_ALL', 'PETUGAS_SCAN', 0, 5, 'Ambil seluruh daftar tugas scan'),
('QRY-014', 'TasksGetById',      'sp_tasks_get_by_id',    '["task_id"]', 'SELECT_ROW', 'PETUGAS_SCAN', 0, 5, 'Ambil detail tugas scan by ID'),
('QRY-015', 'TasksInsert',       'sp_tasks_insert',       '["task_id","user_id","shift","tanggal","target","lokasi"]', 'EXECUTE', 'ADMIN', 0, 5, 'Buat penugasan scan baru'),
('QRY-016', 'TasksProgress',     'sp_tasks_progress',     '["task_id","increment"]', 'EXECUTE', 'PETUGAS_SCAN', 0, 5, 'Tambah progress scan pada tugas'),
('QRY-017', 'TasksComplete',     'sp_tasks_complete',     '["task_id"]', 'EXECUTE', 'PETUGAS_SCAN', 0, 5, 'Selesaikan tugas scan'),

-- SCAN EVENTS & STATISTIK (QRY-018 s/d QRY-020)
('QRY-018', 'ScansProcess',      'sp_scans_process',      '["scan_id","nomor_resi","user_id","task_id","lokasi","device_id","jenis_scan"]', 'SELECT_ROW', 'PETUGAS_SCAN', 0, 5, 'Transaksi scan barcode atomik & anti duplikasi'),
('QRY-019', 'ScansListAll',      'sp_scans_list',         '[]', 'SELECT_ALL', 'PETUGAS_SCAN', 0, 5, 'Ambil riwayat scan barcode'),
('QRY-020', 'ScansStats',        'sp_scans_stats',        '["user_id"]', 'SELECT_ROW', 'PETUGAS_SCAN', 0, 5, 'Ambil rekap statistik scan petugas'),

-- AUDIT LOGS & DEV (QRY-021 s/d QRY-023)
('QRY-021', 'AuditInsert',       'sp_audit_insert',       '["user_id","action","details","ip_address"]', 'EXECUTE', 'PUBLIC', 0, 5, 'Catat aktivitas sistem ke audit logs'),
('QRY-022', 'AuditListAll',      'sp_audit_list',         '[]', 'SELECT_ALL', 'ADMIN', 0, 5, 'Ambil seluruh riwayat log audit'),
('QRY-023', 'DevListQueries',    'sp_sys_get_queries',    '[]', 'SELECT_ALL', 'DEVELOPER', 0, 5, 'List seluruh registry query sistem')
ON DUPLICATE KEY UPDATE 
    query_code   = VALUES(query_code),
    sp_name      = VALUES(sp_name),
    param_keys   = VALUES(param_keys),
    query_type   = VALUES(query_type),
    required_role= VALUES(required_role),
    cache_ttl    = VALUES(cache_ttl),
    timeout_sec  = VALUES(timeout_sec),
    deskripsi    = VALUES(deskripsi);

DELIMITER //

-- =====================================================================
-- 1. USERS & AUTENTIKASI
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_getusers //
CREATE PROCEDURE sp_getusers()
BEGIN
    SELECT id, name, username, role, status, last_login FROM users ORDER BY id ASC;
END //

DROP PROCEDURE IF EXISTS sp_getuserbyid //
CREATE PROCEDURE sp_getuserbyid(IN p_id VARCHAR(32))
BEGIN
    SELECT * FROM users WHERE id = p_id;
END //

DROP PROCEDURE IF EXISTS sp_login //
CREATE PROCEDURE sp_login(IN p_username VARCHAR(50))
BEGIN
    SELECT * FROM users WHERE LOWER(username) = LOWER(p_username) LIMIT 1;
END //

DROP PROCEDURE IF EXISTS sp_auth_update_status //
CREATE PROCEDURE sp_auth_update_status(IN p_user_id VARCHAR(32), IN p_status VARCHAR(20))
BEGIN
    IF p_status = 'ONLINE' THEN
        UPDATE users SET status = 'ONLINE', last_login = NOW() WHERE id = p_user_id;
    ELSE
        UPDATE users SET status = 'OFFLINE' WHERE id = p_user_id;
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_users_insert //
CREATE PROCEDURE sp_users_insert(
    IN p_id VARCHAR(32),
    IN p_name VARCHAR(100),
    IN p_username VARCHAR(50),
    IN p_pass VARCHAR(255),
    IN p_role VARCHAR(20),
    IN p_status VARCHAR(20)
)
BEGIN
    INSERT INTO users (id, name, username, password_hash, role, status)
    VALUES (p_id, p_name, p_username, p_pass, p_role, p_status);
END //

DROP PROCEDURE IF EXISTS sp_users_update //
CREATE PROCEDURE sp_users_update(
    IN p_id VARCHAR(32),
    IN p_name VARCHAR(100),
    IN p_username VARCHAR(50),
    IN p_role VARCHAR(20),
    IN p_pass VARCHAR(255)
)
BEGIN
    IF p_pass IS NOT NULL AND p_pass != '' THEN
        UPDATE users SET name = p_name, username = p_username, role = p_role, password_hash = p_pass WHERE id = p_id;
    ELSE
        UPDATE users SET name = p_name, username = p_username, role = p_role WHERE id = p_id;
    END IF;
END //

DROP PROCEDURE IF EXISTS sp_users_delete //
CREATE PROCEDURE sp_users_delete(IN p_id VARCHAR(32))
BEGIN
    DELETE FROM users WHERE id = p_id;
END //

DROP PROCEDURE IF EXISTS sp_users_toggle_status //
CREATE PROCEDURE sp_users_toggle_status(IN p_id VARCHAR(32), IN p_status VARCHAR(20))
BEGIN
    UPDATE users SET status = p_status WHERE id = p_id;
END //

-- =====================================================================
-- 2. PAKET & RESI
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_paket_create_draft //
CREATE PROCEDURE sp_paket_create_draft(IN p_resi VARCHAR(16), IN p_created_by VARCHAR(32))
BEGIN
    INSERT INTO paket (nomor_resi, status, created_by, telepon_pengirim, telepon_penerima, created_at)
    VALUES (p_resi, 'DRAFT', p_created_by, '', '', NOW());
    
    SELECT p.*, u.name AS creator_name 
      FROM paket p LEFT JOIN users u ON u.id = p.created_by 
     WHERE p.nomor_resi = p_resi;
END //

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

DROP PROCEDURE IF EXISTS sp_paket_list //
CREATE PROCEDURE sp_paket_list()
BEGIN
    SELECT p.*, u.name AS creator_name 
      FROM paket p LEFT JOIN users u ON u.id = p.created_by
     ORDER BY p.created_at DESC;
END //

DROP PROCEDURE IF EXISTS sp_paket_get_detail //
CREATE PROCEDURE sp_paket_get_detail(IN p_resi VARCHAR(16))
BEGIN
    SELECT p.*, u.name AS creator_name 
      FROM paket p LEFT JOIN users u ON u.id = p.created_by 
     WHERE p.nomor_resi = p_resi;
END //

-- =====================================================================
-- 3. TASKS / TUGAS SCAN
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_tasks_list //
CREATE PROCEDURE sp_tasks_list()
BEGIN
    SELECT t.*, u.name AS user_name 
      FROM tasks t JOIN users u ON u.id = t.user_id
     ORDER BY t.tanggal DESC, t.task_id DESC;
END //

DROP PROCEDURE IF EXISTS sp_tasks_get_by_id //
CREATE PROCEDURE sp_tasks_get_by_id(IN p_task_id VARCHAR(32))
BEGIN
    SELECT t.*, u.name AS user_name 
      FROM tasks t JOIN users u ON u.id = t.user_id 
     WHERE t.task_id = p_task_id;
END //

DROP PROCEDURE IF EXISTS sp_tasks_insert //
CREATE PROCEDURE sp_tasks_insert(
    IN p_id VARCHAR(32),
    IN p_user_id VARCHAR(32),
    IN p_shift VARCHAR(10),
    IN p_tanggal DATE,
    IN p_target INT,
    IN p_lokasi VARCHAR(100)
)
BEGIN
    INSERT INTO tasks (task_id, user_id, shift, tanggal, target, progress, status, lokasi)
    VALUES (p_id, p_user_id, p_shift, p_tanggal, p_target, 0, 'PROSES_SCAN', p_lokasi);
END //

DROP PROCEDURE IF EXISTS sp_tasks_progress //
CREATE PROCEDURE sp_tasks_progress(IN p_task_id VARCHAR(32), IN p_increment INT)
BEGIN
    UPDATE tasks SET progress = progress + p_increment WHERE task_id = p_task_id;
END //

DROP PROCEDURE IF EXISTS sp_tasks_complete //
CREATE PROCEDURE sp_tasks_complete(IN p_task_id VARCHAR(32))
BEGIN
    UPDATE tasks SET status = 'SELESAI' WHERE task_id = p_task_id;
END //

-- =====================================================================
-- 4. TRANSAKSI SCAN PAKET ATOMIK & RIWAYAT
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

DROP PROCEDURE IF EXISTS sp_scans_list //
CREATE PROCEDURE sp_scans_list()
BEGIN
    SELECT s.*, u.name AS user_name 
      FROM scan_events s JOIN users u ON u.id = s.user_id 
     ORDER BY s.waktu_scan DESC;
END //

DROP PROCEDURE IF EXISTS sp_scans_stats //
CREATE PROCEDURE sp_scans_stats(IN p_user_id VARCHAR(32))
BEGIN
    SELECT 
        COALESCE(SUM(CASE WHEN status_scan = 'SUCCESS' THEN 1 ELSE 0 END), 0) AS total_success,
        COALESCE(SUM(CASE WHEN status_scan = 'DUPLICATE' THEN 1 ELSE 0 END), 0) AS total_duplicate,
        MAX(waktu_scan) AS last_scan
      FROM scan_events 
     WHERE user_id = p_user_id;
END //

-- =====================================================================
-- 5. AUDIT LOGS
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_audit_insert //
CREATE PROCEDURE sp_audit_insert(
    IN p_user_id VARCHAR(32),
    IN p_action VARCHAR(50),
    IN p_details TEXT,
    IN p_ip VARCHAR(50)
)
BEGIN
    INSERT INTO audit_logs (user_id, action, details, ip_address, created_at)
    VALUES (p_user_id, p_action, p_details, p_ip, NOW());
END //

DROP PROCEDURE IF EXISTS sp_audit_list //
CREATE PROCEDURE sp_audit_list()
BEGIN
    SELECT a.*, u.name AS user_name 
      FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id 
     ORDER BY a.created_at DESC;
END //

-- =====================================================================
-- 6. SYSTEM & PROCEDURE INSPECTOR (CRUD sys_queries)
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

DROP PROCEDURE IF EXISTS sp_sys_get_queries //
CREATE PROCEDURE sp_sys_get_queries()
BEGIN
    SELECT query_id, query_code, sp_name, param_keys, query_type, required_role, cache_ttl, timeout_sec, deskripsi, status, created_at, updated_at
      FROM sys_queries
     ORDER BY query_id ASC;
END //

DROP PROCEDURE IF EXISTS sp_sys_upsert_query //
CREATE PROCEDURE sp_sys_upsert_query(
    IN p_id VARCHAR(32),
    IN p_code VARCHAR(64),
    IN p_sp VARCHAR(64),
    IN p_params TEXT,
    IN p_type VARCHAR(20),
    IN p_role VARCHAR(20),
    IN p_ttl INT,
    IN p_timeout INT,
    IN p_desc VARCHAR(255)
)
BEGIN
    INSERT INTO sys_queries (query_id, query_code, sp_name, param_keys, query_type, required_role, cache_ttl, timeout_sec, deskripsi)
    VALUES (p_id, p_code, p_sp, p_params, p_type, p_role, p_ttl, p_timeout, p_desc)
    ON DUPLICATE KEY UPDATE
        query_code   = VALUES(query_code),
        sp_name      = VALUES(sp_name),
        param_keys   = VALUES(param_keys),
        query_type   = VALUES(query_type),
        required_role= VALUES(required_role),
        cache_ttl    = VALUES(cache_ttl),
        timeout_sec  = VALUES(timeout_sec),
        deskripsi    = VALUES(deskripsi);
END //

DROP PROCEDURE IF EXISTS sp_sys_delete_query //
CREATE PROCEDURE sp_sys_delete_query(IN p_id VARCHAR(32))
BEGIN
    DELETE FROM sys_queries WHERE query_id = p_id;
END //

DELIMITER ;
