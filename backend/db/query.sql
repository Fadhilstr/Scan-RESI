-- =====================================================================
-- Dijak Express — Master Query Catalog (query.sql)
-- Seluruh query SQL backend dikelola secara terpusat di file ini.
-- Dipanggil oleh Perl controllers melalui Wahana::Query->get('query_name')
-- =====================================================================

-- =====================================================================
-- AUTH & USERS
-- =====================================================================

-- name: auth_get_user_by_username
SELECT * FROM users WHERE LOWER(username) = LOWER(?) LIMIT 1;

-- name: auth_get_user_by_id
SELECT * FROM users WHERE id = ? LIMIT 1;

-- name: auth_update_user_online
UPDATE users SET status = 'ONLINE', last_login = NOW() WHERE id = ?;

-- name: auth_update_user_offline
UPDATE users SET status = 'OFFLINE' WHERE id = ?;

-- name: users_get_role
SELECT role FROM users WHERE id = ?;

-- name: users_list_all
SELECT * FROM users ORDER BY id ASC;

-- name: users_check_username_exists
SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?);

-- name: users_check_username_exists_except_self
SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?) AND id != ?;

-- name: users_get_max_admin_id
SELECT COALESCE(MAX(CAST(SUBSTRING(id, 11) AS UNSIGNED)), 0)
  FROM users WHERE id REGEXP '^USR-ADMIN-[0-9]+$';

-- name: users_get_max_cust_id
SELECT COALESCE(MAX(CAST(SUBSTRING(id, 10) AS UNSIGNED)), 0)
  FROM users WHERE id REGEXP '^USR-CUST-[0-9]+$';

-- name: users_get_max_petugas_id
SELECT COALESCE(MAX(CAST(SUBSTRING(id, 5) AS UNSIGNED)), 0)
  FROM users WHERE id REGEXP '^USR-[0-9]+$';

-- name: users_insert
INSERT INTO users (id, name, username, password_hash, role, status)
VALUES (?, ?, ?, ?, ?, ?);

-- name: users_get_by_id
SELECT * FROM users WHERE id = ?;

-- name: users_toggle_status
UPDATE users SET status = ? WHERE id = ?;

-- name: users_update_with_password
UPDATE users SET name = ?, username = ?, role = ?, password_hash = ? WHERE id = ?;

-- name: users_update_without_password
UPDATE users SET name = ?, username = ?, role = ? WHERE id = ?;

-- name: users_count_tasks
SELECT COUNT(*) FROM tasks WHERE user_id = ?;

-- name: users_count_scans
SELECT COUNT(*) FROM scan_events WHERE user_id = ?;

-- name: users_count_paket
SELECT COUNT(*) FROM paket WHERE created_by = ?;

-- name: users_delete
DELETE FROM users WHERE id = ?;

-- =====================================================================
-- TASKS
-- =====================================================================

-- name: tasks_list_base
SELECT t.*, u.name AS user_name
  FROM tasks t JOIN users u ON u.id = t.user_id;

-- name: tasks_check_user_exists
SELECT COUNT(*) FROM users WHERE id = ?;

-- name: tasks_get_max_id
SELECT COALESCE(MAX(CAST(SUBSTRING(task_id, 6) AS UNSIGNED)), 0)
  FROM tasks WHERE task_id REGEXP '^TASK-[0-9]+$';

-- name: tasks_insert
INSERT INTO tasks (task_id, user_id, shift, tanggal, target, progress, status, lokasi)
VALUES (?, ?, ?, ?, ?, 0, 'PROSES_SCAN', ?);

-- name: tasks_get_by_id
SELECT t.*, u.name AS user_name
  FROM tasks t JOIN users u ON u.id = t.user_id
 WHERE t.task_id = ?;

-- name: tasks_increment_progress
UPDATE tasks SET progress = progress + ? WHERE task_id = ?;

-- name: tasks_complete
UPDATE tasks SET status = 'SELESAI' WHERE task_id = ?;

-- =====================================================================
-- SCANS
-- =====================================================================

-- name: scans_list_base
SELECT s.*, u.name AS user_name
  FROM scan_events s JOIN users u ON u.id = s.user_id;

-- name: scans_stats_success
SELECT COUNT(*) FROM scan_events WHERE user_id = ? AND status_scan = 'SUCCESS';

-- name: scans_stats_duplicate
SELECT COUNT(*) FROM scan_events WHERE user_id = ? AND status_scan = 'DUPLICATE';

-- name: scans_stats_last_scan
SELECT MAX(waktu_scan) FROM scan_events WHERE user_id = ?;

-- name: scans_lock_task
SELECT * FROM tasks WHERE task_id = ? FOR UPDATE;

-- name: scans_check_duplicate
SELECT COUNT(*) FROM scan_events WHERE nomor_resi = ? AND task_id = ? AND status_scan = 'SUCCESS';

-- name: scans_check_paket_registered
SELECT * FROM paket WHERE nomor_resi = ?;

-- name: scans_get_max_id
SELECT COALESCE(MAX(CAST(SUBSTRING(scan_id, 5) AS UNSIGNED)), 0)
  FROM scan_events WHERE scan_id REGEXP '^SCN-[0-9]+$';

-- name: scans_insert
INSERT INTO scan_events (scan_id, nomor_resi, user_id, task_id, lokasi, status_scan, device_id, jenis_scan)
VALUES (?, ?, ?, ?, ?, ?, ?, ?);

-- name: scans_get_by_id
SELECT s.*, u.name AS user_name
  FROM scan_events s JOIN users u ON u.id = s.user_id
 WHERE s.scan_id = ?;

-- =====================================================================
-- PAKET
-- =====================================================================

-- name: paket_check_resi_exists
SELECT COUNT(*) FROM paket WHERE nomor_resi = ?;

-- name: paket_insert_draft
INSERT INTO paket (nomor_resi, status, created_by, telepon_pengirim, telepon_penerima, created_at)
VALUES (?, 'DRAFT', ?, '', '', NOW());

-- name: paket_get_detail
SELECT p.*, u.name AS creator_name
  FROM paket p LEFT JOIN users u ON u.id = p.created_by
 WHERE p.nomor_resi = ?;

-- name: paket_get_by_resi
SELECT * FROM paket WHERE nomor_resi = ?;

-- name: paket_list_base
SELECT p.*, u.name AS creator_name
  FROM paket p LEFT JOIN users u ON u.id = p.created_by;

-- name: paket_update_data
UPDATE paket
   SET nama_barang = ?, pengirim = ?, alamat_pengirim = ?, telepon_pengirim = ?,
       penerima = ?, alamat_tujuan = ?, telepon_penerima = ?,
       berat_kg = ?, jenis_layanan = ?, status = 'TERDAFTAR',
       created_at = NOW()
 WHERE nomor_resi = ?;

-- =====================================================================
-- AUDIT LOGS
-- =====================================================================

-- name: audit_insert
INSERT INTO audit_logs (user_id, action, details, ip_address)
VALUES (?, ?, ?, ?);

-- name: audit_list_base
SELECT a.*, u.name AS user_name
  FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id;
