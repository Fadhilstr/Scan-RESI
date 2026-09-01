package Wahana::Controller::PaketController;
use strict;
use warnings;
use POSIX qw(strftime);
use Wahana::Db;
use Wahana::Query;
use Wahana::Util qw(fmt_datetime trim);
use Wahana::Audit qw(record_audit);
use Wahana::Controller::UsersController qw(get_user_role);
use Exporter 'import';

our @EXPORT_OK = qw(map_paket);

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

sub generate_resi {
    my ($dbh) = @_;
    for (1 .. 20) {
        my $resi = join '',
            map { substr $RESI_CHARS, int rand(length $RESI_CHARS), 1 }
            1 .. $RESI_LEN;

        my $exists = $dbh->selectrow_array("SELECT COUNT(*) FROM paket WHERE nomor_resi = ?", undef, $resi);
        return $resi unless $exists;
    }
    die "__resi_exhausted__";
}

sub _requester_role {
    my ($req) = @_;
    my $uid = $req->{auth_user}{uid} or return undef;
    return get_user_role($uid);
}

# POST /api/paket/resi (Generate Draft)
sub create_draft {
    my ($req) = @_;

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    return { success => \0, reason => 'FORBIDDEN',
             message => 'Hanya CUSTOMER, ADMIN, atau DEVELOPER yang dapat membuat nomor resi.' }
        unless $role eq 'CUSTOMER' || $role eq 'ADMIN' || $role eq 'DEVELOPER';

    my $dbh = Wahana::Db->connect();
    my $resi = eval { generate_resi($dbh) };
    if (!$resi) {
        warn "[PAKET] Generate resi gagal: $@";
        return { success => \0, reason => 'EXHAUSTED',
                 message => 'Gagal membuat nomor resi unik. Coba lagi.' };
    }

    my $row = Wahana::Query->new(
        name => 'PaketCreateDraft',
        data => { resi => $resi, created_by => $user_id }
    )->selectrow();

    record_audit(
        user_id    => $user_id,
        action     => 'PAKET_RESI_GENERATED',
        details    => "Nomor resi $resi digenerate (DRAFT).",
        ip_address => $req->{ip},
    );

    return { success => \0, message => 'Gagal menyimpan draft paket ke database.' }
        unless $row;

    return { success => \1, paket => map_paket($row) };
}

# PATCH /api/paket/:nomor_resi (Simpan Paket TERDAFTAR)
sub update {
    my ($req, $captures) = @_;
    my $resi = uc(trim($captures->[0] // ''));
    my $body = $req->{body} // {};

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    my $paket = Wahana::Query->new(
        name => 'PaketGetDetail',
        data => { resi => $resi }
    )->selectrow();

    return { success => \0, reason => 'NOT_FOUND', message => 'Paket tidak ditemukan.' }
        unless $paket;

    my $is_owner = defined $paket->{created_by} && $paket->{created_by} eq $user_id;
    return { success => \0, reason => 'FORBIDDEN',
             message => 'Hanya pembuat paket, ADMIN, atau DEVELOPER yang dapat menyimpan data barang.' }
        unless $role eq 'ADMIN' || $role eq 'DEVELOPER' || $is_owner;

    if ($paket->{status} eq 'TERDAFTAR') {
        return { success => \1, message => 'Data paket sudah tersimpan (TERDAFTAR).',
                 paket => map_paket($paket) };
    }

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

    for my $field (['nama_barang', $nama], ['pengirim', $pengirim], ['penerima', $penerima],
                   ['telepon_pengirim', $telepon_pengirim], ['telepon_penerima', $telepon_penerima]) {
        return { success => \0, reason => 'VALIDATION',
                 message => $field->[0] . ' wajib diisi.' }
            unless length $field->[1];
    }

    for my $field (['telepon_pengirim', $telepon_pengirim], ['telepon_penerima', $telepon_penerima]) {
        return { success => \0, reason => 'VALIDATION',
                 message => $field->[0] . ' harus berupa angka 8-15 digit.' }
            unless $field->[1] =~ /^\d{8,15}$/;
    }

    my $row = Wahana::Query->new(
        name => 'CustInsert',
        data => {
            resi             => $resi,
            nama_barang      => $nama,
            pengirim         => $pengirim,
            alamat_pengirim  => $alamat_pengirim,
            telepon_pengirim => $telepon_pengirim,
            penerima         => $penerima,
            alamat_tujuan    => $alamat_tujuan,
            telepon_penerima => $telepon_penerima,
            berat_kg         => $berat,
            jenis_layanan    => $layanan,
        }
    )->selectrow();

    record_audit(
        user_id    => $user_id,
        action     => 'PAKET_UPDATED',
        details    => "Paket $resi disimpan dan TERDAFTAR ($nama).",
        ip_address => $req->{ip},
    );

    return { success => \1, message => "Paket $resi berhasil disimpan.",
             paket => map_paket($row // $paket) };
}

# GET /api/paket?q=&status=&mine=1
sub list {
    my ($req) = @_;
    my $params = $req->{params} // {};

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    my $roq = Wahana::Query->new(name => 'PaketListAll');
    my $rows = $roq->selectall();

    if ($role eq 'CUSTOMER') {
        @$rows = grep { $_->{created_by} && $_->{created_by} eq $user_id } @$rows;
    } elsif (trim($params->{created_by} // '')) {
        my $cb = trim($params->{created_by});
        @$rows = grep { $_->{created_by} && $_->{created_by} eq $cb } @$rows;
    }

    if (my $status = trim($params->{status} // '')) {
        @$rows = grep { $_->{status} && $_->{status} eq $status } @$rows;
    }

    if (my $q = trim($params->{q} // '')) {
        my $uq = uc($q);
        my $lq = lc($q);
        @$rows = grep {
            (index(uc($_->{nomor_resi} // ''), $uq) != -1) ||
            (index(lc($_->{nama_barang} // ''), $lq) != -1)
        } @$rows;
    }

    return { pakets => [ map { map_paket($_) } @$rows ] };
}

# GET /api/paket/:nomor_resi
sub detail {
    my ($req, $captures) = @_;
    my $resi = uc(trim($captures->[0] // ''));

    my $user_id = $req->{auth_user}{uid};
    my $role    = _requester_role($req) // '';

    my $row = Wahana::Query->new(
        name => 'PaketGetDetail',
        data => { resi => $resi }
    )->selectrow();

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
