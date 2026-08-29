package Wahana::Controller::PaketController;
use strict;
use warnings;
use POSIX qw(strftime);
use Wahana::Db;
use Wahana::Util qw(fmt_datetime trim);
use Wahana::Audit qw(record_audit);
use Wahana::Controller::UsersController qw(get_user_role);
use Exporter 'import';

our @EXPORT_OK = qw(map_paket);

# Alfabet resi tanpa karakter ambigu (I, O, 0, 1) agar aman dibaca/disalin.
my $RESI_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
my $RESI_LEN   = 8;

sub map_paket {
    my ($r) = @_;
    return {
        nomor_resi        => $r->{nomor_resi},
        nama_barang       => $r->{nama_barang},
        pengirim          => $r->{pengirim},
        alamat_pengirim   => $r->{alamat_pengirim},
        telepon_pengirim  => $r->{telepon_pengirim} // '',
        penerima          => $r->{penerima},
        alamat_tujuan     => $r->{alamat_tujuan},
        telepon_penerima  => $r->{telepon_penerima} // '',
        berat_kg          => defined $r->{berat_kg} ? 0 + $r->{berat_kg} : 0,
        jenis_layanan     => $r->{jenis_layanan},
        status            => $r->{status},
        created_by        => $r->{created_by},
        creator_name      => $r->{creator_name},
        created_at        => fmt_datetime($r->{created_at}),
    };
}

# Generate nomor resi acak di SERVER (klien tidak pernah mengirim resi).
# Loop pengecekan menjamin unik terhadap tabel paket.
sub generate_resi {
    my ($dbh) = @_;

    for (1 .. 20) {
        my $resi = join '',
            map { substr $RESI_CHARS, int rand(length $RESI_CHARS), 1 }
            1 .. $RESI_LEN;

        my $exists = $dbh->selectrow_array(
            'SELECT COUNT(*) FROM paket WHERE nomor_resi = ?', undef, $resi
        );
        return $resi unless $exists;
    }

    die "__resi_exhausted__";
}

# Role user yang sedang request ('CUSTOMER', 'ADMIN', ...).
sub _requester_role {
    my ($req) = @_;
    my $uid = $req->{auth_user}{uid} or return undef;
    return get_user_role($uid);
}

# ---------------------------------------------------------------------
# POST /api/paket/resi
# Membuat baris paket DRAFT dengan nomor resi dari server.
# Hanya CUSTOMER & ADMIN yang boleh memicu generate.
# ---------------------------------------------------------------------
sub create_draft {
    my ($req) = @_;

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    return { success => \0, reason => 'FORBIDDEN',
             message => 'Hanya CUSTOMER atau ADMIN yang dapat membuat nomor resi.' }
        unless $role eq 'CUSTOMER' || $role eq 'ADMIN';

    my $dbh = Wahana::Db->connect();

    my $resi = eval { generate_resi($dbh) };
    if (!$resi) {
        warn "[PAKET] Generate resi gagal: $@";
        return { success => \0, reason => 'EXHAUSTED',
                 message => 'Gagal membuat nomor resi unik. Coba lagi.' };
    }

    $dbh->do(
        'INSERT INTO paket (nomor_resi, status, created_by, telepon_pengirim, telepon_penerima, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
        undef, $resi, 'DRAFT', $user_id, '', ''
    );

    record_audit(
        user_id    => $user_id,
        action     => 'PAKET_RESI_GENERATED',
        details    => "Nomor resi $resi digenerate (DRAFT).",
        ip_address => $req->{ip},
    );

    my $row = $dbh->selectrow_hashref(
        'SELECT p.*, u.name AS creator_name
           FROM paket p LEFT JOIN users u ON u.id = p.created_by
          WHERE p.nomor_resi = ?', undef, $resi
    );

    return { success => \1, paket => map_paket($row) };
}

# ---------------------------------------------------------------------
# PATCH /api/paket/:nomor_resi
# Melengkapi data barang pada paket DRAFT → status TERDAFTAR.
# Hanya pembuat paket (customer) atau ADMIN yang boleh menyimpan.
# ---------------------------------------------------------------------
sub update {
    my ($req, $captures) = @_;
    my $resi = uc(trim($captures->[0] // ''));
    my $body = $req->{body} // {};

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    my $dbh = Wahana::Db->connect();

    my $paket = $dbh->selectrow_hashref(
        'SELECT * FROM paket WHERE nomor_resi = ?', undef, $resi
    );
    return { success => \0, reason => 'NOT_FOUND', message => 'Paket tidak ditemukan.' }
        unless $paket;

    my $is_owner = defined $paket->{created_by} && $paket->{created_by} eq $user_id;
    return { success => \0, reason => 'FORBIDDEN',
             message => 'Hanya pembuat paket atau ADMIN yang dapat menyimpan data barang.' }
        unless $role eq 'ADMIN' || $is_owner;

    if ($paket->{status} eq 'TERDAFTAR') {
        return { success => \1, message => 'Data paket sudah tersimpan (TERDAFTAR).',
                 paket => map_paket($paket) };
    }

    # Field wajib untuk naik ke TERDAFTAR
    my %valid_layanan = map { $_ => 1 } qw(REGULER EXPRESS SAME_DAY);
    my $layanan = $valid_layanan{ trim($body->{jenis_layanan} // '') }
        ? $body->{jenis_layanan} : $paket->{jenis_layanan} || 'REGULER';

    my $nama             = trim($body->{nama_barang}      // '');
    my $pengirim         = trim($body->{pengirim}         // '');
    my $alamat_pengirim  = trim($body->{alamat_pengirim}  // '');
    my $telepon_pengirim = trim($body->{telepon_pengirim} // '');
    my $penerima         = trim($body->{penerima}         // '');
    my $alamat_tujuan    = trim($body->{alamat_tujuan}    // '');
    my $telepon_penerima = trim($body->{telepon_penerima} // '');
    my $berat            = $body->{berat_kg};
    $berat = 0 unless defined $berat && $berat =~ /^\d+(\.\d+)?$/;

    # Validasi field wajib (termasuk telepon)
    for my $field (['nama_barang', $nama], ['pengirim', $pengirim], ['penerima', $penerima],
                   ['telepon_pengirim', $telepon_pengirim], ['telepon_penerima', $telepon_penerima]) {
        return { success => \0, reason => 'VALIDATION',
                 message => $field->[0] . ' wajib diisi.' }
            unless length $field->[1];
    }

    # Validasi format telepon: minimal 8 digit angka, maksimal 15 digit
    for my $field (['telepon_pengirim', $telepon_pengirim], ['telepon_penerima', $telepon_penerima]) {
        return { success => \0, reason => 'VALIDATION',
                 message => $field->[0] . ' harus berupa angka 8-15 digit.' }
            unless $field->[1] =~ /^\d{8,15}$/;
    }

    $dbh->do(
        'UPDATE paket
            SET nama_barang = ?, pengirim = ?, alamat_pengirim = ?, telepon_pengirim = ?,
                penerima = ?, alamat_tujuan = ?, telepon_penerima = ?,
                berat_kg = ?, jenis_layanan = ?, status = ?,
                created_at = NOW()
          WHERE nomor_resi = ?',
        undef, $nama, $pengirim, $alamat_pengirim, $telepon_pengirim,
            $penerima, $alamat_tujuan, $telepon_penerima,
            $berat, $layanan,
        'TERDAFTAR', $resi
    );

    record_audit(
        user_id    => $user_id,
        action     => 'PAKET_UPDATED',
        details    => "Paket $resi disimpan dan TERDAFTAR ($nama).",
        ip_address => $req->{ip},
    );

    my $row = $dbh->selectrow_hashref(
        'SELECT p.*, u.name AS creator_name
           FROM paket p LEFT JOIN users u ON u.id = p.created_by
          WHERE p.nomor_resi = ?', undef, $resi
    );

    return { success => \1, message => "Paket $resi berhasil disimpan.",
             paket => map_paket($row) };
}

# ---------------------------------------------------------------------
# GET /api/paket?q=&status=&mine=1
# CUSTOMER hanya melihat paket miliknya; role lain melihat semua.
# ---------------------------------------------------------------------
sub list {
    my ($req) = @_;
    my $params = $req->{params} // {};

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    my @where;
    my @bind;

    # CUSTOMER selalu di-scope ke miliknya sendiri
    if ($role eq 'CUSTOMER') {
        push @where, 'p.created_by = ?';
        push @bind,  $user_id;
    }
    elsif (trim($params->{created_by} // '')) {
        push @where, 'p.created_by = ?';
        push @bind,  trim($params->{created_by});
    }

    if (my $status = trim($params->{status} // '')) {
        push @where, 'p.status = ?';
        push @bind,  $status;
    }

    if (my $q = trim($params->{q} // '')) {
        push @where, '(UPPER(p.nomor_resi) LIKE ? OR LOWER(p.nama_barang) LIKE ?)';
        push @bind,  '%' . uc($q) . '%', '%' . lc($q) . '%';
    }

    my $dbh = Wahana::Db->connect();
    my $sql = 'SELECT p.*, u.name AS creator_name
                 FROM paket p LEFT JOIN users u ON u.id = p.created_by'
        . (@where ? ' WHERE ' . join(' AND ', @where) : '')
        . ' ORDER BY p.created_at DESC, p.nomor_resi DESC';

    my $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind);

    return { pakets => [ map { map_paket($_) } @$rows ] };
}

# ---------------------------------------------------------------------
# GET /api/paket/:nomor_resi — lookup detail (tahap "Cari Data Paket")
# ---------------------------------------------------------------------
sub detail {
    my ($req, $captures) = @_;
    my $resi = uc(trim($captures->[0] // ''));

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    my $dbh = Wahana::Db->connect();
    my $row = $dbh->selectrow_hashref(
        'SELECT p.*, u.name AS creator_name
           FROM paket p LEFT JOIN users u ON u.id = p.created_by
          WHERE p.nomor_resi = ?', undef, $resi
    );

    return { success => \0, reason => 'NOT_FOUND', message => 'Paket tidak ditemukan.' }
        unless $row;

    if ($role eq 'CUSTOMER'
        && (!defined $row->{created_by} || $row->{created_by} ne $user_id)) {
        return { success => \0, reason => 'FORBIDDEN',
                 message => 'Anda tidak memiliki akses ke paket ini.' };
    }

    return { success => \1, paket => map_paket($row) };
}

1;
