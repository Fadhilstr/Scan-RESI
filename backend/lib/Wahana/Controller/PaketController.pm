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
        barcode_format    => $r->{barcode_format} // 'CODE_128',
        status            => $r->{status},
        created_by        => $r->{created_by},
        creator_name      => $r->{creator_name},
        created_at        => fmt_datetime($r->{created_at}),
    };
}

# Hitung Check Digit Modulo 10 standar internasional (GS1 / EAN / UPC / ITF)
sub calc_mod10 {
    my ($digits) = @_;
    my @d = split //, $digits;
    my $sum = 0;
    my $len = scalar @d;
    for my $i (0 .. $len - 1) {
        my $weight = (($len - 1 - $i) % 2 == 0) ? 3 : 1;
        $sum += $d[$i] * $weight;
    }
    my $rem = $sum % 10;
    return $rem == 0 ? 0 : 10 - $rem;
}

# Hitung Check Digit UPC-E via ekspansi UPC-A standar
sub calc_upce_check_digit {
    my ($d6) = @_;
    my @d = split //, $d6;
    my @upca;
    my $last = $d[5];
    if ($last == 0 || $last == 1 || $last == 2) {
        @upca = (0, $d[0], $d[1], $last, 0, 0, 0, 0, $d[2], $d[3], $d[4]);
    } elsif ($last == 3) {
        @upca = (0, $d[0], $d[1], $d[2], 0, 0, 0, 0, 0, $d[3], $d[4]);
    } elsif ($last == 4) {
        @upca = (0, $d[0], $d[1], $d[2], $d[3], 0, 0, 0, 0, 0, $d[4]);
    } else {
        @upca = (0, $d[0], $d[1], $d[2], $d[3], $d[4], 0, 0, 0, 0, $last);
    }
    my $sum = 0;
    for my $i (0 .. 10) {
        $sum += $upca[$i] * ($i % 2 == 0 ? 3 : 1);
    }
    my $rem = $sum % 10;
    return $rem == 0 ? 0 : 10 - $rem;
}

# Generate nomor resi acak di SERVER (klien tidak pernah mengirim resi).
# Format nomor resi langsung sesuai dengan format barcode yang dipilih,
# sehingga nomor resi dan barcode 100% identik tanpa perlu nilai encoded terpisah.
sub generate_resi {
    my ($dbh, $format) = @_;
    $format //= 'CODE_128';

    for (1 .. 30) {
        my $resi;
        if ($format eq 'EAN_13') {
            # 12 digit data (prefiks 899 standar logistik) + 1 digit mod10 check digit = 13 digit
            my $data = '899' . join('', map { int rand(10) } 1 .. 9);
            my $chk = calc_mod10($data);
            $resi = $data . $chk;
        } elsif ($format eq 'EAN_8') {
            # 7 digit data + 1 digit mod10 check digit = 8 digit
            my $data = join('', map { int rand(10) } 1 .. 7);
            my $chk = calc_mod10($data);
            $resi = $data . $chk;
        } elsif ($format eq 'UPC_A') {
            # 11 digit data (prefiks 0) + 1 digit mod10 check digit = 12 digit
            my $data = '0' . join('', map { int rand(10) } 1 .. 10);
            my $chk = calc_mod10($data);
            $resi = $data . $chk;
        } elsif ($format eq 'UPC_E') {
            # 8 digit UPC-E standard (0 + 6 digit payload + 1 digit valid check digit)
            my $payload6 = join('', map { int rand(10) } 1 .. 6);
            my $chk = calc_upce_check_digit($payload6);
            $resi = '0' . $payload6 . $chk;
        } elsif ($format eq 'UPC_EAN_EXTENSION') {
            # 5 digit numerik
            $resi = join('', map { int rand(10) } 1 .. 5);
        } elsif ($format eq 'ITF') {
            # 12 digit numerik genap untuk Interleaved 2 of 5
            $resi = join('', map { int rand(10) } 1 .. 12);
        } elsif ($format eq 'CODABAR') {
            # 10 digit angka
            $resi = join('', map { int rand(10) } 1 .. 10);
        } elsif ($format eq 'RSS_14') {
            # 13 digit data + 1 digit check digit = 14 digit
            my $data = '1' . join('', map { int rand(10) } 1 .. 12);
            my $chk = calc_mod10($data);
            $resi = $data . $chk;
        } else {
            # Alfanumerik standar (CODE_128, QR_CODE, AZTEC, CODE_39, CODE_93, DATA_MATRIX, PDF_417, MAXICODE, RSS_EXPANDED)
            $resi = join '',
                map { substr $RESI_CHARS, int rand(length $RESI_CHARS), 1 }
                1 .. $RESI_LEN;
        }

        my $exists = $dbh->selectrow_array(
            Wahana::Query->get('paket_check_resi_exists'), undef, $resi
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

    my $body   = $req->{body} // {};
    my $format = uc(trim($body->{format} // $req->{query}{format} // 'CODE_128'));

    my $dbh = Wahana::Db->connect();

    my $resi = eval { generate_resi($dbh, $format) };
    if (!$resi) {
        warn "[PAKET] Generate resi gagal: $@";
        return { success => \0, reason => 'EXHAUSTED',
                 message => 'Gagal membuat nomor resi unik. Coba lagi.' };
    }

    $dbh->do(
        Wahana::Query->get('paket_insert_draft'),
        undef, $resi, $user_id, $format
    );

    record_audit(
        user_id    => $user_id,
        action     => 'PAKET_RESI_GENERATED',
        details    => "Nomor resi $resi digenerate (DRAFT).",
        ip_address => $req->{ip},
    );

    my $row = $dbh->selectrow_hashref(
        Wahana::Query->get('paket_get_detail'), undef, $resi
    );

    return { success => \0, message => 'Gagal menyimpan draft paket ke database.' }
        unless $row;

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
        Wahana::Query->get('paket_get_by_resi'), undef, $resi
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
    my $barcode_format = $body->{barcode_format} || $paket->{barcode_format} || 'CODE_128';
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
        Wahana::Query->get('paket_update_data'),
        undef, $nama, $pengirim, $alamat_pengirim, $telepon_pengirim,
            $penerima, $alamat_tujuan, $telepon_penerima,
            $berat, $layanan, $barcode_format,
            $resi
    );

    record_audit(
        user_id    => $user_id,
        action     => 'PAKET_UPDATED',
        details    => "Paket $resi disimpan dan TERDAFTAR ($nama).",
        ip_address => $req->{ip},
    );

    my $row = $dbh->selectrow_hashref(
        Wahana::Query->get('paket_get_detail'), undef, $resi
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
        $q =~ s/([%_\\])/\\$1/g; # Escape karakter SQL wildcard
        push @where, '(UPPER(p.nomor_resi) LIKE ? OR LOWER(p.nama_barang) LIKE ?)';
        push @bind,  '%' . uc($q) . '%', '%' . lc($q) . '%';
    }

    # Hitung pagination: default 100 data per halaman
    my $limit = int($params->{limit} // 100);
    $limit = 100 if $limit <= 0;
    $limit = 500 if $limit > 500;

    my $page = int($params->{page} // 1);
    $page = 1 if $page <= 0;
    my $offset = int($params->{offset} // (($page - 1) * $limit));
    $offset = 0 if $offset < 0;
    
    my $dbh = Wahana::Db->connect();
    my $base_sql = Wahana::Query->get('paket_list_base');
    my $sql = $base_sql
        . (@where ? ' WHERE ' . join(' AND ', @where) : '')
        . " ORDER BY p.created_at DESC, p.nomor_resi DESC LIMIT $limit OFFSET $offset";

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
        Wahana::Query->get('paket_get_detail'), undef, $resi
    );

    # Normalisasi otomatis jika barcode mengandung prefiks GS1, AI (10), atau Codabar
    if (!$row) {
        my $alt_resi = $resi;
        $alt_resi =~ s/[\x00-\x1F\x7F-\x9F]//g;
        $alt_resi =~ s/^\][A-Z0-9]{2}//i;
        if ($alt_resi =~ /\(10\)\s*([A-Z0-9]+)/i || $alt_resi =~ /^(?:\(01\)|01)?\s*\d{13,14}\s*(?:\(10\)|10)\s*([A-Z0-9]+)/i || $alt_resi =~ /\d{14}10([A-Z0-9]{4,16})/i) {
            $alt_resi = $1;
        } elsif ($alt_resi =~ /^[ABCD]([0-9]+)[ABCD]$/i) {
            $alt_resi = $1;
        } elsif ($alt_resi =~ /^\(01\)\s*(\d{13,14})$/i || $alt_resi =~ /^01(\d{14})$/i) {
            $alt_resi = $1;
        } elsif ($alt_resi =~ /^0(\d{12})$/) {
            $alt_resi = $1;
        }
        if ($alt_resi ne $resi) {
            $row = $dbh->selectrow_hashref(
                Wahana::Query->get('paket_get_detail'), undef, $alt_resi
            );
        }

        # Toleransi pembacaan optik kamera pada UPC-E (misal digit 2/8 tertukar akibat noise sensor)
        if (!$row && $resi =~ /^0\d{7}$/) {
            my $upce_rows = $dbh->selectall_arrayref(
                "SELECT nomor_resi FROM paket WHERE barcode_format = 'UPC_E' AND status = 'TERDAFTAR'",
                { Slice => {} }
            );
            for my $item (@$upce_rows) {
                my $target = $item->{nomor_resi};
                if (length($target) == 8) {
                    my $diff = 0;
                    for my $i (0 .. 7) {
                        $diff++ if substr($resi, $i, 1) ne substr($target, $i, 1);
                    }
                    if ($diff == 1) {
                        $row = $dbh->selectrow_hashref(
                            Wahana::Query->get('paket_get_detail'), undef, $target
                        );
                        last if $row;
                    }
                }
            }
        }
    }

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
