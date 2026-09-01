package Wahana::Query;
# =====================================================================
# Wahana::Query — Object-Oriented Database-Driven Query Object (DCAF Style)
#
# Penggunaan:
#   my $roq = Wahana::Query->new(
#       q    => $ros->{q},        # Database handle (DBI $dbh)
#       name => 'CustInsert',     # Query Code di tabel sys_queries
#       data => $rhpar,           # Hashref parameter ($rhpar)
#   );
#   my $row  = $roq->selectrow(); # Ambil 1 baris (Hashref)
#   my $rows = $roq->selectall(); # Ambil banyak baris (Arrayref of Hash)
#   my $res  = $roq->execute();   # Eksekusi aksi (INSERT / UPDATE / DELETE)
# =====================================================================
use strict;
use warnings;
use JSON::PP qw(decode_json);
use Time::HiRes qw(time);
use File::Basename qw(dirname);
use File::Spec;
use Wahana::Db;
use Exporter 'import';

our @EXPORT_OK = qw(get_sql);

# Master Catalog 23 Query Lengkap Sistem
my %DEFAULT_CATALOG = (
    # AUTH & USERS (QRY-001 s/d QRY-008)
    'UsersListAll'      => { query_id => 'QRY-001', query_code => 'UsersListAll',      sp_name => 'sp_getusers',           param_keys => '[]', query_type => 'SELECT_ALL', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil seluruh daftar user' },
    'UsersGetById'      => { query_id => 'QRY-002', query_code => 'UsersGetById',      sp_name => 'sp_getuserbyid',        param_keys => '["id"]', query_type => 'SELECT_ROW', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil data user berdasarkan ID' },
    'AuthLogin'         => { query_id => 'QRY-003', query_code => 'AuthLogin',         sp_name => 'sp_login',              param_keys => '["username"]', query_type => 'SELECT_ROW', required_role => 'PUBLIC', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Autentikasi login user' },
    'AuthUpdateStatus'  => { query_id => 'QRY-004', query_code => 'AuthUpdateStatus',  sp_name => 'sp_auth_update_status', param_keys => '["user_id","status"]', query_type => 'EXECUTE', required_role => 'PUBLIC', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Update status online/offline user' },
    'UsersInsert'       => { query_id => 'QRY-005', query_code => 'UsersInsert',       sp_name => 'sp_users_insert',       param_keys => '["id","name","username","password_hash","role","status"]', query_type => 'EXECUTE', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Tambah user baru oleh admin' },
    'UsersUpdate'       => { query_id => 'QRY-006', query_code => 'UsersUpdate',       sp_name => 'sp_users_update',       param_keys => '["id","name","username","role","password_hash"]', query_type => 'EXECUTE', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Update profil & password user' },
    'UsersDelete'       => { query_id => 'QRY-007', query_code => 'UsersDelete',       sp_name => 'sp_users_delete',       param_keys => '["id"]', query_type => 'EXECUTE', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Hapus user dari database' },
    'UsersToggleStatus' => { query_id => 'QRY-008', query_code => 'UsersToggleStatus', sp_name => 'sp_users_toggle_status', param_keys => '["id","status"]', query_type => 'EXECUTE', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Aktifkan/Nonaktifkan status akun user' },

    # PAKET & RESI (QRY-009 s/d QRY-012)
    'PaketCreateDraft'  => { query_id => 'QRY-009', query_code => 'PaketCreateDraft',  sp_name => 'sp_paket_create_draft', param_keys => '["resi","created_by"]', query_type => 'SELECT_ROW', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Generate nomor resi draft paket' },
    'CustInsert'        => { query_id => 'QRY-010', query_code => 'CustInsert',        sp_name => 'sp_paket_save',         param_keys => '["resi","nama_barang","pengirim","alamat_pengirim","telepon_pengirim","penerima","alamat_tujuan","telepon_penerima","berat_kg","jenis_layanan"]', query_type => 'SELECT_ROW', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Simpan data paket customer' },
    'PaketListAll'      => { query_id => 'QRY-011', query_code => 'PaketListAll',      sp_name => 'sp_paket_list',         param_keys => '[]', query_type => 'SELECT_ALL', required_role => 'PUBLIC', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil seluruh daftar paket' },
    'PaketGetDetail'    => { query_id => 'QRY-012', query_code => 'PaketGetDetail',    sp_name => 'sp_paket_get_detail',   param_keys => '["resi"]', query_type => 'SELECT_ROW', required_role => 'PUBLIC', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil detail paket berdasarkan resi' },

    # TASKS (QRY-013 s/d QRY-017)
    'TasksListAll'      => { query_id => 'QRY-013', query_code => 'TasksListAll',      sp_name => 'sp_tasks_list',         param_keys => '[]', query_type => 'SELECT_ALL', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil seluruh daftar tugas scan' },
    'TasksGetById'      => { query_id => 'QRY-014', query_code => 'TasksGetById',      sp_name => 'sp_tasks_get_by_id',    param_keys => '["task_id"]', query_type => 'SELECT_ROW', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil detail tugas scan by ID' },
    'TasksInsert'       => { query_id => 'QRY-015', query_code => 'TasksInsert',       sp_name => 'sp_tasks_insert',       param_keys => '["task_id","user_id","shift","tanggal","target","lokasi"]', query_type => 'EXECUTE', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Buat penugasan scan baru' },
    'TasksProgress'     => { query_id => 'QRY-016', query_code => 'TasksProgress',     sp_name => 'sp_tasks_progress',     param_keys => '["task_id","increment"]', query_type => 'EXECUTE', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Tambah progress scan pada tugas' },
    'TasksComplete'     => { query_id => 'QRY-017', query_code => 'TasksComplete',     sp_name => 'sp_tasks_complete',     param_keys => '["task_id"]', query_type => 'EXECUTE', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Selesaikan tugas scan' },

    # SCAN EVENTS (QRY-018 s/d QRY-020)
    'ScansProcess'      => { query_id => 'QRY-018', query_code => 'ScansProcess',      sp_name => 'sp_scans_process',      param_keys => '["scan_id","nomor_resi","user_id","task_id","lokasi","device_id","jenis_scan"]', query_type => 'SELECT_ROW', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Transaksi scan barcode atomik' },
    'ScansListAll'      => { query_id => 'QRY-019', query_code => 'ScansListAll',      sp_name => 'sp_scans_list',         param_keys => '[]', query_type => 'SELECT_ALL', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil riwayat scan barcode' },
    'ScansStats'        => { query_id => 'QRY-020', query_code => 'ScansStats',        sp_name => 'sp_scans_stats',        param_keys => '["user_id"]', query_type => 'SELECT_ROW', required_role => 'PETUGAS_SCAN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil rekap statistik scan petugas' },

    # AUDIT LOGS & DEV (QRY-021 s/d QRY-023)
    'AuditInsert'       => { query_id => 'QRY-021', query_code => 'AuditInsert',       sp_name => 'sp_audit_insert',       param_keys => '["user_id","action","details","ip_address"]', query_type => 'EXECUTE', required_role => 'PUBLIC', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Catat aktivitas sistem ke audit logs' },
    'AuditListAll'      => { query_id => 'QRY-022', query_code => 'AuditListAll',      sp_name => 'sp_audit_list',         param_keys => '[]', query_type => 'SELECT_ALL', required_role => 'ADMIN', cache_ttl => 0, timeout_sec => 5, deskripsi => 'Ambil seluruh riwayat log audit' },
    'DevListQueries'    => { query_id => 'QRY-023', query_code => 'DevListQueries',    sp_name => 'sp_sys_get_queries',    param_keys => '[]', query_type => 'SELECT_ALL', required_role => 'DEVELOPER', cache_ttl => 0, timeout_sec => 5, deskripsi => 'List seluruh registry query sistem' },
);

my %CATALOG_CACHE;
my $CATALOG_LOADED = 0;
my %RESULT_CACHE;

# ---------------------------------------------------------------------
# Inisialisasi Katalog dari Tabel sys_queries
# ---------------------------------------------------------------------
sub load_catalog {
    my ($force) = @_;
    return if $CATALOG_LOADED && !$force;

    # Load defaults first
    for my $k (keys %DEFAULT_CATALOG) {
        $CATALOG_CACHE{$k} = $DEFAULT_CATALOG{$k};
        $CATALOG_CACHE{$DEFAULT_CATALOG{$k}->{query_id}} = $DEFAULT_CATALOG{$k};
    }

    eval {
        my $dbh = Wahana::Db->connect();
        my $rows = $dbh->selectall_arrayref(
            "SELECT query_id, query_code, sp_name, param_keys, query_type, required_role, cache_ttl, timeout_sec, deskripsi, status FROM sys_queries WHERE status = 'ACTIVE'",
            { Slice => {} }
        );
        if ($rows && @$rows) {
            for my $r (@$rows) {
                $CATALOG_CACHE{$r->{query_code}} = $r;
                $CATALOG_CACHE{$r->{query_id}}   = $r;
            }
        }
        1;
    };

    $CATALOG_LOADED = 1;
}

sub refresh_catalog {
    $CATALOG_LOADED = 0;
    %CATALOG_CACHE = ();
    load_catalog(1);
}

sub get_catalog_list {
    load_catalog() unless $CATALOG_LOADED;
    my %seen;
    my @list;
    for my $item (values %CATALOG_CACHE) {
        next if $seen{$item->{query_id}}++;
        push @list, $item;
    }
    return [ sort { $a->{query_id} cmp $b->{query_id} } @list ];
}

# ---------------------------------------------------------------------
# Constructor: DCAF Query Object
# ---------------------------------------------------------------------
sub new {
    my ($class, %args) = @_;
    load_catalog() unless $CATALOG_LOADED;

    my $name = $args{name} or die "[QUERY] Argument 'name' (Query Code) wajib diisi!";
    my $meta = $CATALOG_CACHE{$name} || $DEFAULT_CATALOG{$name}
        or die "[QUERY] Query Code '$name' tidak terdaftar di katalog query!";

    my $self = {
        q       => $args{q} // Wahana::Db->connect(), # DB handle / session
        name    => $name,                             # Query Code
        data    => $args{data} // {},                 # Hashref parameter ($rhpar)
        meta    => { %$meta },                        # Copy metadata query
    };

    return bless $self, $class;
}

# ---------------------------------------------------------------------
# Eksekusi Prepared Statement Stored Procedure
# ---------------------------------------------------------------------
sub _execute_sp {
    my ($self, $expected_type) = @_;
    my $meta = $self->{meta};
    my $data = $self->{data} // {};

    # Ekstrak urutan parameter sesuai param_keys
    my @params = ();
    if ($meta->{param_keys}) {
        my $keys = eval {
            ref $meta->{param_keys} eq 'ARRAY' 
                ? $meta->{param_keys} 
                : decode_json($meta->{param_keys})
        } // [];
        for my $k (@$keys) {
            push @params, $data->{$k};
        }
    }

    # Cek Caching RAM jika cache_ttl diaktifkan
    my $cache_key = $meta->{query_code} . '_' . join(':', map { $_ // '' } @params);
    if ($meta->{cache_ttl} && $meta->{cache_ttl} > 0 && exists $RESULT_CACHE{$cache_key}) {
        my ($cached_time, $cached_res) = @{ $RESULT_CACHE{$cache_key} };
        if ((time() - $cached_time) < $meta->{cache_ttl}) {
            return $cached_res;
        }
    }

    my $dbh = $self->{q} // Wahana::Db->connect();
    my $placeholders = join(', ', ('?') x scalar(@params));
    my $sth = $dbh->prepare("CALL $meta->{sp_name}($placeholders)");
    $sth->execute(@params);

    my $result;
    my $type = $expected_type // $meta->{query_type} // 'SELECT_ROW';

    if ($type eq 'SELECT_ROW' || $type eq 'ROW') {
        $result = $sth->fetchrow_hashref();
    } elsif ($type eq 'SELECT_ALL' || $type eq 'ALL') {
        $result = $sth->fetchall_arrayref({}) // [];
    } else {
        $result = 1; # Action success
    }

    if ($meta->{cache_ttl} && $meta->{cache_ttl} > 0) {
        $RESULT_CACHE{$cache_key} = [ time(), $result ];
    }

    return $result;
}

# 1. Ambil 1 Baris (Hashref)
sub selectrow {
    my ($self) = @_;
    return $self->_execute_sp('SELECT_ROW');
}

# 2. Ambil Banyak Baris (Arrayref of Hash)
sub selectall {
    my ($self) = @_;
    return $self->_execute_sp('SELECT_ALL');
}

# 3. Eksekusi Aksi (INSERT / UPDATE / DELETE)
sub execute {
    my ($self) = @_;
    return $self->_execute_sp('EXECUTE');
}

# ---------------------------------------------------------------------
# Backward Compatibility untuk file SQL lama jika dibutuhkan
# ---------------------------------------------------------------------
my %LEGACY_QUERIES;
my $LEGACY_INITIALIZED = 0;

sub _init_legacy {
    return if $LEGACY_INITIALIZED;
    my @candidates = (
        $ENV{WAHANA_QUERY_FILE},
        File::Spec->catfile(dirname(__FILE__), '..', '..', 'db', 'query.sql'),
        '/app/backend/db/query.sql',
        'backend/db/query.sql',
        'db/query.sql',
    );
    for my $path (@candidates) {
        next unless defined $path && -f $path;
        if (open my $fh, '<:encoding(UTF-8)', $path) {
            my $current_name = '';
            my @current_sql  = ();
            while (my $line = <$fh>) {
                if ($line =~ /^\s*--\s*name:\s*(\w+)\s*$/) {
                    if ($current_name && @current_sql) {
                        my $sql = join "\n", @current_sql;
                        $sql =~ s/;\s*$//;
                        $sql =~ s/^\s+|\s+$//g;
                        $LEGACY_QUERIES{$current_name} = $sql;
                    }
                    $current_name = $1;
                    @current_sql  = ();
                } elsif ($current_name) {
                    next if $line =~ /^\s*--/;
                    push @current_sql, $line;
                }
            }
            if ($current_name && @current_sql) {
                my $sql = join "\n", @current_sql;
                $sql =~ s/;\s*$//;
                $sql =~ s/^\s+|\s+$//g;
                $LEGACY_QUERIES{$current_name} = $sql;
            }
            close $fh;
            $LEGACY_INITIALIZED = 1;
            last;
        }
    }
}

sub get {
    my ($class_or_self, $name) = @_;
    _init_legacy() unless $LEGACY_INITIALIZED;
    return $LEGACY_QUERIES{$name} if exists $LEGACY_QUERIES{$name};
    die "[QUERY] Query dengan nama '$name' tidak ditemukan!";
}

sub get_sql {
    my ($name) = @_;
    return __PACKAGE__->get($name);
}

1;
