# Rencana Migrasi Penuh: Database-Driven Query Catalog (sys_queries) & DCAF Query Object Pattern

Dokumen ini adalah **Rencana Eksekusi Final (Master Architecture & Switchover Plan)** yang menggabungkan:
1. **Tabel Database `sys_queries` di MariaDB**: Menjadi *Single Source of Truth* untuk mapping **Query ID**, **Query Code**, dan **Stored Procedure**.
2. **Pola OOP Query DCAF di Backend**: Pemanggilan terstandardisasi menggunakan:
   ```perl
   my $roq = Wahana::Query->new(
       q    => $ros->{q},
       name => 'CustInsert',
       data => $rhpar,
   );
   my $result = $roq->selectrow(); # atau $roq->selectall(), $roq->execute()
   ```
3. **Murni Stored Procedures + Prepared Statements**: Tanpa string SQL mentah di controller.

---

## 📋 Struktur Database: Tabel `sys_queries`

Tabel ini dibuat di dalam file [procedures.sql](file:///Documents/Scan-resi-magang/backend/db/procedures.sql) untuk mengelola katalog seluruh query sistem:

```sql
CREATE TABLE IF NOT EXISTS sys_queries (
    query_id        VARCHAR(32)   PRIMARY KEY,                         -- Contoh: 'QRY-001'
    query_code      VARCHAR(64)   UNIQUE NOT NULL,                     -- Contoh: 'CustInsert', 'AuthLogin'
    sp_name         VARCHAR(64)   NOT NULL,                            -- Contoh: 'sp_paket_save', 'sp_login'
    param_keys      TEXT          NULL,                                -- Urutan parameter JSON/CSV misal: '["resi","nama","pengirim"]'
    query_type      ENUM('SELECT_ROW', 'SELECT_ALL', 'EXECUTE') NOT NULL DEFAULT 'SELECT_ROW',
    required_role   ENUM('PUBLIC', 'PETUGAS_SCAN', 'ADMIN', 'DEVELOPER') NOT NULL DEFAULT 'PUBLIC',
    cache_ttl       INT           DEFAULT 0,                           -- 0 = realtime, >0 = cache detik
    timeout_sec     INT           DEFAULT 5,                           -- Timeout request
    deskripsi       VARCHAR(255)  NULL,
    status          ENUM('ACTIVE', 'MAINTENANCE', 'DEPRECATED') DEFAULT 'ACTIVE',
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seeder Awal Master Query
INSERT INTO sys_queries (query_id, query_code, sp_name, param_keys, query_type, required_role, deskripsi) VALUES
('QRY-001', 'UsersListAll',      'sp_getusers',           '[]', 'SELECT_ALL', 'ADMIN', 'Ambil seluruh daftar user'),
('QRY-002', 'UsersGetById',      'sp_getuserbyid',        '["id"]', 'SELECT_ROW', 'ADMIN', 'Ambil user by ID'),
('QRY-003', 'AuthLogin',         'sp_login',              '["username"]', 'SELECT_ROW', 'PUBLIC', 'Autentikasi login user'),
('QRY-004', 'AuthUpdateStatus',  'sp_auth_update_status', '["user_id", "status"]', 'EXECUTE', 'PUBLIC', 'Update status online/offline'),
('QRY-005', 'PaketCreateDraft',  'sp_paket_create_draft', '["resi", "created_by"]', 'SELECT_ROW', 'PETUGAS_SCAN', 'Generate nomor resi draft paket'),
('QRY-006', 'CustInsert',        'sp_paket_save',         '["resi","nama_barang","pengirim","alamat_pengirim","telepon_pengirim","penerima","alamat_tujuan","telepon_penerima","berat_kg","jenis_layanan"]', 'SELECT_ROW', 'PETUGAS_SCAN', 'Simpan data paket customer'),
('QRY-007', 'ScansProcess',      'sp_scans_process',      '["scan_id","nomor_resi","user_id","task_id","lokasi","device_id","jenis_scan"]', 'SELECT_ROW', 'PETUGAS_SCAN', 'Transaksi scan barcode atomik'),
('QRY-008', 'DevListQueries',    'sp_dev_list_queries',   '[]', 'SELECT_ALL', 'DEVELOPER', 'List seluruh registry query sistem')
ON DUPLICATE KEY UPDATE 
    query_code = VALUES(query_code),
    sp_name = VALUES(sp_name),
    param_keys = VALUES(param_keys),
    deskripsi = VALUES(deskripsi);
```

---

## 🏛️ Desain OOP Backend: `Wahana::Query` (DCAF Style)

Modul [Wahana/Query.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Query.pm) mengimplementasikan pola objek query:

```perl
package Wahana::Query;
use strict;
use warnings;
use JSON::PP qw(decode_json);
use Time::HiRes qw(time);
use Wahana::Db;

my %CATALOG_CACHE;
my $CATALOG_LOADED = 0;
my %RESULT_CACHE;

# ---------------------------------------------------------------------
# Inisialisasi Katalog dari Tabel sys_queries
# ---------------------------------------------------------------------
sub _load_catalog {
    return if $CATALOG_LOADED;
    my $dbh = Wahana::Db->connect();
    my $rows = eval {
        $dbh->selectall_arrayref(
            "SELECT query_id, query_code, sp_name, param_keys, query_type, required_role, cache_ttl, timeout_sec, deskripsi, status FROM sys_queries WHERE status = 'ACTIVE'",
            { Slice => {} }
        );
    } // [];

    for my $r (@$rows) {
        $CATALOG_CACHE{$r->{query_code}} = $r;
        $CATALOG_CACHE{$r->{query_id}}   = $r;
    }
    $CATALOG_LOADED = 1 if @$rows;
}

sub refresh_catalog {
    $CATALOG_LOADED = 0;
    %CATALOG_CACHE = ();
    _load_catalog();
}

# ---------------------------------------------------------------------
# Constructor: DCAF Query Object
# ---------------------------------------------------------------------
sub new {
    my ($class, %args) = @_;
    _load_catalog() unless $CATALOG_LOADED;

    my $name = $args{name} or die "[QUERY] Argument 'name' (Query Code) wajib diisi!";
    my $meta = $CATALOG_CACHE{$name} 
        or die "[QUERY] Query Code '$name' tidak terdaftar di tabel sys_queries!";

    my $self = {
        q       => $args{q} // Wahana::Db->connect(), # DB handle / session
        name    => $name,                             # Query Code
        data    => $args{data} // {},                 # Hashref parameter ($rhpar)
        meta    => $meta,                             # Metadata query
    };

    return bless $self, $class;
}

# ---------------------------------------------------------------------
# Eksekusi Prepared Statement Stored Procedure
# ---------------------------------------------------------------------
sub _execute_sp {
    my ($self) = @_;
    my $meta = $self->{meta};
    my $data = $self->{data};

    # Ekstrak urutan parameter sesuai param_keys di tabel sys_queries
    my @params = ();
    if ($meta->{param_keys}) {
        my $keys = eval { decode_json($meta->{param_keys}) } // [];
        for my $k (@$keys) {
            push @params, $data->{$k};
        }
    }

    # Cek Caching RAM
    my $cache_key = $meta->{query_code} . '_' . join(':', map { $_ // '' } @params);
    if ($meta->{cache_ttl} > 0 && exists $RESULT_CACHE{$cache_key}) {
        my ($cached_time, $cached_res) = @{ $RESULT_CACHE{$cache_key} };
        return $cached_res if (time() - $cached_time) < $meta->{cache_ttl};
    }

    my $dbh = $self->{q};
    my $placeholders = join(', ', ('?') x scalar(@params));
    my $sth = $dbh->prepare("CALL $meta->{sp_name}($placeholders)");
    $sth->execute(@params);

    my $result;
    if ($meta->{query_type} eq 'SELECT_ROW') {
        $result = $sth->fetchrow_hashref();
    } elsif ($meta->{query_type} eq 'SELECT_ALL') {
        $result = $sth->fetchall_arrayref({}) // [];
    } else {
        $result = 1; # Action success
    }

    if ($meta->{cache_ttl} > 0) {
        $RESULT_CACHE{$cache_key} = [ time(), $result ];
    }

    return $result;
}

# 1. Ambil 1 Baris
sub selectrow {
    my ($self) = @_;
    $self->{meta}->{query_type} = 'SELECT_ROW';
    return $self->_execute_sp();
}

# 2. Ambil Banyak Baris
sub selectall {
    my ($self) = @_;
    $self->{meta}->{query_type} = 'SELECT_ALL';
    return $self->_execute_sp();
}

# 3. Eksekusi Aksi (INSERT/UPDATE/DELETE)
sub execute {
    my ($self) = @_;
    $self->{meta}->{query_type} = 'EXECUTE';
    return $self->_execute_sp();
}

1;
```

---

## 💻 Pola Pemanggilan di Controller Backend

### 1. [PaketController.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Controller/PaketController.pm)
```perl
# Simpan Data Paket Customer (CustInsert)
my $rhpar = {
    resi             => $resi,
    nama_barang      => $body->{nama_barang},
    pengirim         => $body->{pengirim},
    alamat_pengirim  => $body->{alamat_pengirim},
    telepon_pengirim => $body->{telepon_pengirim},
    penerima         => $body->{penerima},
    alamat_tujuan    => $body->{alamat_tujuan},
    telepon_penerima => $body->{telepon_penerima},
    berat_kg         => $body->{berat_kg},
    jenis_layanan    => $body->{jenis_layanan},
};

my $roq = Wahana::Query->new(
    q    => $ros->{q},
    name => 'CustInsert',
    data => $rhpar,
);

my $paket = $roq->selectrow();
```

### 2. [AuthController.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Controller/AuthController.pm)
```perl
# Autentikasi Login
my $roq = Wahana::Query->new(
    q    => $ros->{q},
    name => 'AuthLogin',
    data => { username => $username },
);

my $user = $roq->selectrow();

if ($user) {
    Wahana::Query->new(
        q    => $ros->{q},
        name => 'AuthUpdateStatus',
        data => { user_id => $user->{id}, status => 'ONLINE' },
    )->execute();
}
```

### 3. [ScansController.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Controller/ScansController.pm)
```perl
# Transaksi Scan Barcode
my $roq = Wahana::Query->new(
    q    => $ros->{q},
    name => 'ScansProcess',
    data => {
        scan_id    => $scan_id,
        nomor_resi => $resi,
        user_id    => $user_id,
        task_id    => $task_id,
        lokasi     => $lokasi,
        device_id  => $device_id,
        jenis_scan => $jenis_scan,
    },
);

my $result = $roq->selectrow();
```

---

## 🛠️ Poin 4: Fitur Lengkap CRUD (Add, Edit, Delete, Inspect) di Dev Query Inspector

Halaman **Dev Query Inspector (`/dev/queries`)** dilengkapi dengan fitur manajemen katalog query penuh (Full CRUD) yang langsung terhubung ke database `sys_queries`:

### 1. Stored Procedures Pendukung CRUD di MariaDB
```sql
-- A. Ambil Seluruh Query
DROP PROCEDURE IF EXISTS sp_sys_get_queries //
CREATE PROCEDURE sp_sys_get_queries()
BEGIN
    SELECT query_id, query_code, sp_name, param_keys, query_type, required_role, cache_ttl, timeout_sec, deskripsi, status, created_at, updated_at
      FROM sys_queries
     ORDER BY query_id ASC;
END //

-- B. Tambah / Edit (Upsert) Query
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

-- C. Hapus Query
DROP PROCEDURE IF EXISTS sp_sys_delete_query //
CREATE PROCEDURE sp_sys_delete_query(IN p_id VARCHAR(32))
BEGIN
    DELETE FROM sys_queries WHERE query_id = p_id;
END //
```

### 2. Endpoints REST API CRUD Developer
- `GET /api/dev/queries` ➡️ Mengambil daftar semua query dari `sys_queries`.
- `POST /api/dev/queries` ➡️ **[ADD]** Menambahkan Query Code & Stored Procedure baru.
- `PUT /api/dev/queries/:id` ➡️ **[EDIT]** Memperbarui konfigurasi Query Code, cache TTL, timeout, atau param keys.
- `DELETE /api/dev/queries/:id` ➡️ **[DELETE]** Menghapus query dari katalog dengan notifikasi konfirmasi.

### 3. Aksi pada Antarmuka Web Dev Query Inspector (`/dev/queries`)
- ➕ **Tombol "Tambah Query / SP"**: Membuka dialog formulir pembuatan Query ID baru (`QRY-xxx`), Query Code, nama Stored Procedure MariaDB, parameter mapping, role RBAC, dan cache TTL.
- 👁️ **Aksi "Inspect / Pratinjau"**: Menampilkan detail definisi Stored Procedure, parameter binding, dan contoh sintaks pemanggilan `Wahana::Query->new(...)`.
- ✏️ **Aksi "Edit Query"**: Mengubah konfigurasi query secara langsung dan menyimpan perubahan ke tabel `sys_queries`.
- 🗑️ **Aksi "Hapus Query"**: Menghapus baris query dengan dialog konfirmasi Quasar `$q.dialog({ ... })` yang aman.

---

## 🚀 Langkah Eksekusi Migrasi

1. **Jalankan `procedures.sql` ke database**:
   ```bash
   mysql -u root -p wahana_scan < backend/db/procedures.sql
   ```
2. **Update `Wahana::Query`**: Menerapkan kelas OOP `Wahana::Query->new( q => ..., name => ..., data => $rhpar )`.
3. **Refaktor Controller Backend**: Menyesuaikan seluruh pemanggilan query ke pola `$roq->selectrow()`, `$roq->selectall()`, `$roq->execute()`.
4. **Deploy Fitur CRUD Dev Query Inspector**: Mengaktifkan tombol Add, Edit, Delete, dan Inspect di `/dev/queries` yang terhubung langsung ke API `/api/dev/queries`.

