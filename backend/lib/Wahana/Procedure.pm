package Wahana::Procedure;
use strict;
use warnings;
use Time::HiRes qw(time);
use Wahana::Db;
use Wahana::Query;
use Exporter 'import';

our @EXPORT_OK = qw(get_all get_row execute_action list_registry);

# =====================================================================
# MASTER REGISTRY: Stored Procedure + Failsafe Fallback SQL Mapping
# =====================================================================
my %REGISTRY = (
    'SP-001' => {
        id             => 'SP-001',
        alias          => 'query/getusers',
        sp             => 'sp_getusers',
        fallback_query => 'users_list_all',
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Ambil seluruh daftar user',
    },
    'SP-002' => {
        id             => 'SP-002',
        alias          => 'query/getuserbyid',
        sp             => 'sp_getuserbyid',
        fallback_query => 'users_get_by_id',
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Ambil data user berdasarkan ID',
    },
    'SP-003' => {
        id             => 'SP-003',
        alias          => 'query/login',
        sp             => 'sp_login',
        fallback_query => 'auth_get_user_by_username',
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Autentikasi login user',
    },
    'SP-004' => {
        id             => 'SP-004',
        alias          => 'query/update_online',
        sp             => 'sp_auth_update_status',
        fallback_query => 'auth_update_user_online',
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Update status online/offline user',
    },
    'SP-005' => {
        id             => 'SP-005',
        alias          => 'query/create_draft',
        sp             => 'sp_paket_create_draft',
        fallback_query => 'paket_insert_draft',
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Generate nomor resi draft paket',
    },
    'SP-006' => {
        id             => 'SP-006',
        alias          => 'query/save_paket',
        sp             => 'sp_paket_save',
        fallback_query => 'paket_update_data',
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Simpan data paket menjadi TERDAFTAR',
    },
    'SP-007' => {
        id             => 'SP-007',
        alias          => 'query/process_scan',
        sp             => 'sp_scans_process',
        fallback_query => 'scans_insert',
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Transaksi pencatatan scan barcode atomik',
    },
    'SP-008' => {
        id             => 'SP-008',
        alias          => 'dev/list_procedures',
        sp             => 'sp_dev_list_procedures',
        fallback_query => '',
        cache_ttl      => 30,
        timeout        => 5,
        desc           => 'List seluruh stored procedures di database',
    },
);

my %ALIAS_MAP = map { $_->{alias} => $_ } values %REGISTRY;
my %ID_MAP    = map { $_->{id}    => $_ } values %REGISTRY;
my %CACHE;

sub _resolve_item {
    my ($key) = @_;
    return $ALIAS_MAP{$key} || $ID_MAP{$key} || {
        id             => 'SP-CUSTOM',
        alias          => $key,
        sp             => $key,
        fallback_query => $key,
        cache_ttl      => 0,
        timeout        => 5,
        desc           => 'Dynamic query',
    };
}

# =====================================================================
# GET_ALL (Ambil Banyak Baris / List) dengan Failsafe Fallback
# =====================================================================
sub get_all {
    my ($class, $key, @params) = @_;
    my $item = _resolve_item($key);
    
    # 1. Cek In-Memory Cache jika cache_ttl diaktifkan
    my $cache_key = $item->{alias} . '_' . join(':', map { $_ // '' } @params);
    if ($item->{cache_ttl} > 0 && exists $CACHE{$cache_key}) {
        my ($cached_time, $cached_data) = @{ $CACHE{$cache_key} };
        if ((time() - $cached_time) < $item->{cache_ttl}) {
            return $cached_data;
        }
    }

    my $dbh = Wahana::Db->connect();
    my $data;
    my $used_sp = 0;

    # 2. Percobaan Eksekusi Stored Procedure (Prepared Statement)
    if ($item->{sp}) {
        eval {
            my $placeholders = join(', ', ('?') x scalar(@params));
            my $sth = $dbh->prepare("CALL $item->{sp}($placeholders)");
            $sth->execute(@params);
            $data = $sth->fetchall_arrayref({});
            $used_sp = 1;
            1;
        };
    }

    # 3. FAILSAFE IF: Jika Stored Procedure belum dipasang di database,
    #    otomatis beralih (fallback) ke Prepared Statement SQL biasa
    if (!$used_sp && $item->{fallback_query}) {
        eval {
            my $sql = Wahana::Query->get($item->{fallback_query});
            $data = $dbh->selectall_arrayref($sql, { Slice => {} }, @params);
            1;
        } or do {
            warn "[PROCEDURE/FALLSAFE ERROR] Gagal mengeksekusi fallback query: $@";
            $data = [];
        };
    }

    $data //= [];

    # Simpan ke Cache RAM jika ada TTL
    if ($item->{cache_ttl} > 0) {
        $CACHE{$cache_key} = [ time(), $data ];
    }

    return $data;
}

# =====================================================================
# GET_ROW (Ambil 1 Baris / Hash) dengan Failsafe Fallback
# =====================================================================
sub get_row {
    my ($class, $key, @params) = @_;
    my $item = _resolve_item($key);

    my $dbh = Wahana::Db->connect();
    my $row;
    my $used_sp = 0;

    # 1. Coba panggil Stored Procedure
    if ($item->{sp}) {
        eval {
            my $placeholders = join(', ', ('?') x scalar(@params));
            my $sth = $dbh->prepare("CALL $item->{sp}($placeholders)");
            $sth->execute(@params);
            $row = $sth->fetchrow_hashref();
            $used_sp = 1;
            1;
        };
    }

    # 2. FAILSAFE IF: Fallback ke Prepared Statement SQL standar
    if (!$used_sp && $item->{fallback_query}) {
        eval {
            my $sql = Wahana::Query->get($item->{fallback_query});
            $row = $dbh->selectrow_hashref($sql, undef, @params);
            1;
        } or do {
            warn "[PROCEDURE/FALLSAFE ERROR] Gagal mengeksekusi fallback row query: $@";
        };
    }

    return $row;
}

# =====================================================================
# EXECUTE_ACTION (INSERT / UPDATE / DELETE / CALL Action)
# =====================================================================
sub execute_action {
    my ($class, $key, @params) = @_;
    my $item = _resolve_item($key);

    my $dbh = Wahana::Db->connect();
    my $success = 0;

    # 1. Coba panggil Stored Procedure
    if ($item->{sp}) {
        eval {
            my $placeholders = join(', ', ('?') x scalar(@params));
            my $sth = $dbh->prepare("CALL $item->{sp}($placeholders)");
            $sth->execute(@params);
            $success = 1;
            1;
        };
    }

    # 2. FAILSAFE IF: Fallback ke Prepared Statement SQL standar
    if (!$success && $item->{fallback_query}) {
        eval {
            my $sql = Wahana::Query->get($item->{fallback_query});
            $dbh->do($sql, undef, @params);
            $success = 1;
            1;
        } or do {
            warn "[PROCEDURE/FALLSAFE ERROR] Gagal mengeksekusi fallback action: $@";
        };
    }

    return $success;
}

# Daftar registry untuk Halaman Inspector
sub list_registry {
    return [ sort { $a->{id} cmp $b->{id} } values %REGISTRY ];
}

1;
