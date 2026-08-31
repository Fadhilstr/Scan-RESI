# Rencana Migrasi Penuh (Switchover): Murni Stored Procedures + Prepared Statements

Dokumen ini adalah **Rencana Eksekusi Final (Switchover Plan)** yang akan dijalankan ketika Anda memutuskan untuk:
1. **Mengeksekusi `procedures.sql` ke database MariaDB**.
2. **Menghapus seluruh logika `if` failsafe** pada modul backend.
3. **Mengalihkan 100% sistem ke arsitektur Murni Stored Procedures + Prepared Statements**.

---

## 📋 Langkah Demi Langkah Eksekusi Migrasi

### Langkah 1: Eksekusi `procedures.sql` ke Database MariaDB
Jalankan file katalog Stored Procedure ke database aktif:
```bash
mysql -u root -p wahana_scan < backend/db/procedures.sql
```
*(Atau di dalam container Docker: `docker compose exec -T db mysql -uroot -proot wahana_scan < backend/db/procedures.sql`)*.

---

### Langkah 2: Refaktor `Wahana/Procedure.pm` Menjadi Murni Stored Procedure (Tanpa `if` Fallback)

Modul [Wahana/Procedure.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Procedure.pm) disederhanakan total sehingga hanya mengeksekusi Stored Procedure via Prepared Statement:

```perl
package Wahana::Procedure;
use strict;
use warnings;
use Time::HiRes qw(time);
use Wahana::Db;
use Exporter 'import';

our @EXPORT_OK = qw(get_all get_row execute_action list_registry);

# Master Registry: Alias -> Stored Procedure MariaDB
my %REGISTRY = (
    'SP-001' => { id => 'SP-001', alias => 'query/getusers',      sp => 'sp_getusers',          cache_ttl => 0,  timeout => 5, desc => 'Ambil semua user' },
    'SP-002' => { id => 'SP-002', alias => 'query/getuserbyid',   sp => 'sp_getuserbyid',       cache_ttl => 0,  timeout => 5, desc => 'Ambil user by ID' },
    'SP-003' => { id => 'SP-003', alias => 'query/login',         sp => 'sp_login',             cache_ttl => 0,  timeout => 5, desc => 'Autentikasi login' },
    'SP-004' => { id => 'SP-004', alias => 'query/update_online', sp => 'sp_auth_update_status',cache_ttl => 0,  timeout => 5, desc => 'Update online/offline' },
    'SP-005' => { id => 'SP-005', alias => 'query/create_draft',  sp => 'sp_paket_create_draft', cache_ttl => 0,  timeout => 5, desc => 'Generate nomor resi' },
    'SP-006' => { id => 'SP-006', alias => 'query/save_paket',    sp => 'sp_paket_save',         cache_ttl => 0,  timeout => 5, desc => 'Simpan data paket' },
    'SP-007' => { id => 'SP-007', alias => 'query/process_scan',  sp => 'sp_scans_process',     cache_ttl => 0,  timeout => 5, desc => 'Transaksi scan barcode' },
    'SP-008' => { id => 'SP-008', alias => 'dev/list_procedures', sp => 'sp_dev_list_procedures',cache_ttl => 30, timeout => 5, desc => 'List semua prosedur' },
);

my %ALIAS_MAP = map { $_->{alias} => $_ } values %REGISTRY;
my %ID_MAP    = map { $_->{id}    => $_ } values %REGISTRY;
my %CACHE;

sub _resolve_item {
    my ($key) = @_;
    return $ALIAS_MAP{$key} || $ID_MAP{$key} or die "[PROC] Stored Procedure key '$key' tidak terdaftar!";
}

# 1. GET_ALL: Murni Prepared Statement -> CALL sp_nama(?, ...)
sub get_all {
    my ($class, $key, @params) = @_;
    my $item = _resolve_item($key);
    
    # Cek Cache
    my $cache_key = $item->{alias} . '_' . join(':', map { $_ // '' } @params);
    if ($item->{cache_ttl} > 0 && exists $CACHE{$cache_key}) {
        my ($cached_time, $data) = @{ $CACHE{$cache_key} };
        return $data if (time() - $cached_time) < $item->{cache_ttl};
    }
    
    my $dbh = Wahana::Db->connect();
    my $placeholders = join(', ', ('?') x scalar(@params));
    
    # Eksekusi Stored Procedure via Prepared Statement
    my $sth = $dbh->prepare("CALL $item->{sp}($placeholders)");
    $sth->execute(@params);
    my $data = $sth->fetchall_arrayref({}) // [];
    
    if ($item->{cache_ttl} > 0) {
        $CACHE{$cache_key} = [ time(), $data ];
    }
    return $data;
}

# 2. GET_ROW: Murni Prepared Statement -> CALL sp_nama(?, ...)
sub get_row {
    my ($class, $key, @params) = @_;
    my $item = _resolve_item($key);
    
    my $dbh = Wahana::Db->connect();
    my $placeholders = join(', ', ('?') x scalar(@params));
    
    my $sth = $dbh->prepare("CALL $item->{sp}($placeholders)");
    $sth->execute(@params);
    return $sth->fetchrow_hashref();
}

# 3. EXECUTE_ACTION: Murni Prepared Statement -> CALL sp_nama(?, ...)
sub execute_action {
    my ($class, $key, @params) = @_;
    my $item = _resolve_item($key);
    
    my $dbh = Wahana::Db->connect();
    my $placeholders = join(', ', ('?') x scalar(@params));
    
    my $sth = $dbh->prepare("CALL $item->{sp}($placeholders)");
    return $sth->execute(@params);
}

sub list_registry {
    return [ sort { $a->{id} cmp $b->{id} } values %REGISTRY ];
}

1;
```

---

### Langkah 3: Gabungkan Stored Procedures ke Master `schema.sql`
Gabungkan isi `procedures.sql` ke file [backend/db/schema.sql](file:///Documents/Scan-resi-magang/backend/db/schema.sql).
* **Tujuannya**: Agar saat menjalankan `./docker-up.sh` atau `docker compose down -v` di masa depan, seluruh Stored Procedure langsung terpasang otomatis dari awal tanpa perlu migrasi manual lagi.

---

### Langkah 4: Verifikasi & Pengujian Pasca Migrasi
1. **Restart Backend**: `docker compose restart backend`.
2. **Buka Web Developer Portal**: Masuk ke menu **Query Inspector (`/dev/queries`)**.
3. **Verifikasi Badge Status**: Badge di header akan otomatis berubah menjadi:
   🟢 **`STORED PROCEDURES ACTIVE`**
4. **Uji Fitur Utama**:
   * Login Admin & Developer (`admin` / `dev`)
   * Pembuatan Resi Paket (`/customer/buat-paket`)
   * Pemindaian Barcode (`/petugas/scan`)
   * Kueri dan filter data real-time.

---

## 🚀 Cara Memicu Eksekusi Ini di Masa Depan
Cukup berikan instruksi:
> *"Tolong jalankan rencana migrasi penuh sesuai file `MIGRATION_PURE_STORED_PROCEDURES_PLAN.md`"*

Maka seluruh 4 langkah di atas akan langsung dieksekusi secara otomatis dan tuntas!
