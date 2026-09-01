# Rencana Final Arsitektur: Stored Procedures Mapping, Konfigurasi Cache Time & Request Timeout, UI Query Inspector & Role Developer

Dokumen ini memuat spesifikasi arsitektur final lengkap yang mencakup:
1. **Arsitektur Stored Procedures + Prepared Statements dengan Mapping Alias (`query/getusers` ➔ `sp_getusers`)**.
2. **Konfigurasi Fleksibel Per-Query: Cache Time (TTL) dan Request Timeout** yang dapat diatur saat Tambah & Edit Query di web.
3. **Pengelolaan Siklus Hidup Stored Procedure (Tambah, Edit/Update via DROP & RECREATE, dan Hapus/DROP)**.
4. **Penambahan Role `DEVELOPER`** ke dalam sistem RBAC.
5. **Halaman Baru: "Database & Query Inspector" (`/dev/queries`)** yang menampilkan seluruh Stored Procedure, parameter, status database, serta form interaktif Tambah/Edit Query.

---

## 1. Konsep Arsitektur Final

```
┌────────────────────────────────────────────────────────┐
│                   Frontend (Quasar)                    │
│   • Customer Portal (/customer/*)                      │
│   • Petugas Scan Portal (/petugas/*)                   │
│   • Admin Portal (/admin/*)                            │
│   • Developer Portal (/dev/*) [Query Inspector Page]   │
└───────────────────────────┬────────────────────────────┘
                            │ HTTP REST (JSON)
┌───────────────────────────▼────────────────────────────┐
│                  Backend (Perl uWSGI)                  │
│   • Wahana::Router (Route Guard & Role Check)          │
│   • Wahana::Procedure (Mapping 'query/...' -> 'sp_...')│
│   • In-Memory Cache Manager (TTL Cache Time)           │
│   • Statement Timeout Handler (Request Timeout)        │
│   • Prepared Statements ($dbh->prepare("CALL sp_...")) │
└───────────────────────────┬────────────────────────────┘
                            │ MySQL Protocol (Pre-compiled)
┌───────────────────────────▼────────────────────────────┐
│                    Database (MariaDB)                  │
│   • Tabel Master (users, tasks, paket, scan_events)   │
│   • Stored Procedures (sp_getusers, sp_login, ...)     │
│   • Role ENUM('ADMIN', 'PETUGAS_SCAN',                 │
│               'CUSTOMER', 'DEVELOPER')                 │
└────────────────────────────────────────────────────────┘
```

---

## 2. Pengaturan Per-Query: Cache Time & Request Timeout

Setiap Stored Procedure memiliki konfigurasi performa yang dapat disesuaikan pada form web:

| Field Konfigurasi | Tipe Data | Nilai Default | Penjelasan |
| :--- | :--- | :--- | :--- |
| **`cache_ttl`** | Integer (Detik) | `0` (No Cache / Real-time) | Durasi penyimpanan hasil query di memori RAM. `0` untuk transaksi real-time (scan/paket), `300` (5 menit) untuk data statis. |
| **`timeout_sec`** | Integer (Detik) | `5` (Detik) | Batas waktu maksimal eksekusi query sebelum dibatalkan otomatis agar server tidak macet (*hang*). |

---

## 3. Penambahan Role `DEVELOPER`

### A. Di Database (`schema.sql`)
```sql
ALTER TABLE users 
  MODIFY role ENUM('ADMIN', 'PETUGAS_SCAN', 'CUSTOMER', 'DEVELOPER') NOT NULL DEFAULT 'PETUGAS_SCAN';

-- Seeder Akun Developer Default:
-- Username: dev | Password: dev123
INSERT INTO users (id, name, username, password_hash, role, status)
VALUES ('USR-DEV-001', 'Lead Developer', 'dev',
        CONCAT('sha256$', 'd3v12345', '$', SHA2(CONCAT('d3v12345', 'dev123'), 256)),
        'DEVELOPER', 'OFFLINE')
ON DUPLICATE KEY UPDATE name = VALUES(name);
```

### B. Hak Akses Portal Role `DEVELOPER`
* Mengakses **Developer Portal (`/dev/queries`)** untuk memonitor, menambah, mengedit, dan mengatur cache/timeout query.
* Mengakses **Swagger / OpenAPI Documentation**.
* Mengakses **Audit Logs** dan **Database Performance Metrics**.

---

## 4. Kumpulan Lengkap Stored Procedures (`procedures.sql`)

```sql
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

-- =====================================================================
-- 2. RESI PAKET
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_paket_create_draft //
CREATE PROCEDURE sp_paket_create_draft(IN p_resi VARCHAR(16), IN p_created_by VARCHAR(32))
BEGIN
    INSERT INTO paket (nomor_resi, status, created_by, telepon_pengirim, telepon_penerima, created_at)
    VALUES (p_resi, 'DRAFT', p_created_by, '', '', NOW());
    
    SELECT p.*, u.name AS creator_name FROM paket p LEFT JOIN users u ON u.id = p.created_by WHERE p.nomor_resi = p_resi;
END //

DROP PROCEDURE IF EXISTS sp_paket_save //
CREATE PROCEDURE sp_paket_save(
    IN p_resi VARCHAR(16), IN p_nama VARCHAR(150), IN p_pengirim VARCHAR(100),
    IN p_alamat_p VARCHAR(255), IN p_telp_p VARCHAR(20), IN p_penerima VARCHAR(100),
    IN p_alamat_t VARCHAR(255), IN p_telp_t VARCHAR(20), IN p_berat DECIMAL(6,2), IN p_layanan VARCHAR(20)
)
BEGIN
    UPDATE paket
       SET nama_barang = p_nama, pengirim = p_pengirim, alamat_pengirim = p_alamat_p, telepon_pengirim = p_telp_p,
           penerima = p_penerima, alamat_tujuan = p_alamat_t, telepon_penerima = p_telp_t,
           berat_kg = p_berat, jenis_layanan = p_layanan, status = 'TERDAFTAR', created_at = NOW()
     WHERE nomor_resi = p_resi;
     
    SELECT p.*, u.name AS creator_name FROM paket p LEFT JOIN users u ON u.id = p.created_by WHERE p.nomor_resi = p_resi;
END //

-- =====================================================================
-- 3. TRANSAKSI SCAN PAKET ATOMIK
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_scans_process //
CREATE PROCEDURE sp_scans_process(
    IN p_scan_id VARCHAR(32), IN p_resi VARCHAR(16), IN p_user_id VARCHAR(32),
    IN p_task_id VARCHAR(32), IN p_lokasi VARCHAR(100), IN p_device VARCHAR(50), IN p_jenis VARCHAR(20)
)
proc: BEGIN
    DECLARE v_paket_status VARCHAR(20);
    DECLARE v_task_status VARCHAR(20);
    DECLARE v_dup_count INT DEFAULT 0;
    
    SELECT status INTO v_paket_status FROM paket WHERE nomor_resi = p_resi;
    IF v_paket_status IS NULL THEN
        SELECT 'UNKNOWN_RESI' AS result_code, 'Nomor resi tidak terdaftar.' AS message;
        LEAVE proc;
    END IF;
    IF v_paket_status = 'DRAFT' THEN
        SELECT 'DRAFT' AS result_code, 'Nomor resi masih DRAFT.' AS message;
        LEAVE proc;
    END IF;
    
    SELECT status INTO v_task_status FROM tasks WHERE task_id = p_task_id FOR UPDATE;
    IF v_task_status IS NULL OR v_task_status = 'SELESAI' THEN
        SELECT 'FINISHED' AS result_code, 'Task sudah selesai atau tidak ditemukan.' AS message;
        LEAVE proc;
    END IF;
    
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
```

---

## 5. Halaman Baru: "Database & Query Inspector" (`/dev/queries`)

### Fitur Halaman:
1. **Daftar Seluruh Stored Procedure & Parameter**:
   * Tabel yang memuat ID Prosedur (`SP-001`), Alias (`query/getusers`), Nama Prosedur (`sp_getusers`), Nilai Cache Time, dan Nilai Timeout.
2. **Modal Form Tambah & Edit Query Terpadu**:
   * Input Alias & Nama Prosedur.
   * Input **Cache Time (Detik)** (0 = no cache, 300 = 5 menit).
   * Input **Request Timeout (Detik)** (Batas waktu eksekusi).
   * Editor Kode SQL dengan *syntax highlighting*.
3. **Database Health & Metrics**:
   * Nama Database: `wahana_scan` (MariaDB).
   * Status Koneksi: `ONLINE` (Port 3307 / 3306).
   * Total Prosedur Terpasang: Dinamis dihitung dari database.
4. **Simulator Uji Coba Query**:
   * Developer dapat mengetes eksekusi prosedur dengan menginput parameter langsung di web.

---

## 6. Modul Mapper Backend (`Wahana/Procedure.pm`) dengan Cache & Timeout

```perl
package Wahana::Procedure;
use strict;
use warnings;
use Time::HiRes qw(time);
use Wahana::Db;

# Registry: ID -> Alias -> SP -> Cache TTL -> Timeout
my %REGISTRY = (
    'SP-001' => { id => 'SP-001', alias => 'query/getusers',      sp => 'sp_getusers',          cache_ttl => 0,   timeout => 5, desc => 'Ambil semua user' },
    'SP-002' => { id => 'SP-002', alias => 'query/getuserbyid',   sp => 'sp_getuserbyid',       cache_ttl => 0,   timeout => 5, desc => 'Ambil user by ID' },
    'SP-003' => { id => 'SP-003', alias => 'query/login',         sp => 'sp_login',             cache_ttl => 0,   timeout => 5, desc => 'Autentikasi login' },
    'SP-004' => { id => 'SP-004', alias => 'query/update_online', sp => 'sp_auth_update_status',cache_ttl => 0,   timeout => 5, desc => 'Update online/offline' },
    'SP-005' => { id => 'SP-005', alias => 'query/create_draft',  sp => 'sp_paket_create_draft', cache_ttl => 0,   timeout => 5, desc => 'Generate nomor resi' },
    'SP-006' => { id => 'SP-006', alias => 'query/save_paket',    sp => 'sp_paket_save',         cache_ttl => 0,   timeout => 5, desc => 'Simpan data paket' },
    'SP-007' => { id => 'SP-007', alias => 'query/process_scan',  sp => 'sp_scans_process',     cache_ttl => 0,   timeout => 5, desc => 'Transaksi scan barcode' },
    'SP-008' => { id => 'SP-008', alias => 'dev/list_procedures', sp => 'sp_dev_list_procedures',cache_ttl => 60,  timeout => 5, desc => 'List semua prosedur' },
);

my %CACHE;
my %ALIAS_MAP = map { $_->{alias} => $_ } values %REGISTRY;
my %ID_MAP    = map { $_->{id}    => $_ } values %REGISTRY;

sub _resolve_item {
    my ($key) = @_;
    return $ALIAS_MAP{$key} || $ID_MAP{$key};
}

sub get_all {
    my ($class, $key, @params) = @_;
    my $item = _resolve_item($key) or die "[PROC] Prosedur '$key' tidak ditemukan!";
    
    my $cache_key = $key . '_' . join(':', @params);
    if ($item->{cache_ttl} > 0 && exists $CACHE{$cache_key}) {
        my ($cached_time, $data) = @{ $CACHE{$cache_key} };
        return $data if (time() - $cached_time) < $item->{cache_ttl};
    }
    
    my $dbh = Wahana::Db->connect();
    my $placeholders = join(', ', ('?') x scalar(@params));
    my $sth = $dbh->prepare("CALL $item->{sp}($placeholders)");
    $sth->execute(@params);
    my $data = $sth->fetchall_arrayref({});
    
    if ($item->{cache_ttl} > 0) {
        $CACHE{$cache_key} = [ time(), $data ];
    }
    
    return $data;
}

sub list_registry {
    return [ sort { $a->{id} cmp $b->{id} } values %REGISTRY ];
}

1;
```

---

## 7. Panduan Eksekusi Saat Ingin Dijalankan

1. **Jalankan Database Procedures**:
   ```bash
   mysql -u root -p wahana_scan < backend/db/procedures.sql
   ```
2. **Aktifkan `Wahana::Procedure`** di seluruh backend controller.
3. **Daftarkan Rute `/dev/queries`** di frontend Quasar dengan meta `{ role: 'DEVELOPER' }`.
4. **Login sebagai Developer**: Username `dev` (password: `dev123`) untuk menginspeksi dan mengelola seluruh Stored Procedure beserta Cache & Timeout-nya.
