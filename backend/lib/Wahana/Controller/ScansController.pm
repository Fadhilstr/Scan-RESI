package Wahana::Controller::ScansController;
use strict;
use warnings;
use Wahana::Db;
use Wahana::Query;
use Wahana::Util qw(fmt_datetime trim);
use Wahana::Audit qw(record_audit);
use Exporter 'import';

our @EXPORT_OK = qw(map_scan);

sub map_scan {
    my ($r) = @_;
    return {
        scan_id     => $r->{scan_id},
        nomor_resi  => $r->{nomor_resi},
        user_id     => $r->{user_id},
        user_name   => $r->{user_name},
        task_id     => $r->{task_id},
        waktu_scan  => fmt_datetime($r->{waktu_scan}),
        lokasi      => $r->{lokasi},
        status_scan => $r->{status_scan},
        device_id   => $r->{device_id},
        jenis_scan  => $r->{jenis_scan},
    };
}

# GET /api/scans?user_id=&task_id=&status_scan=
sub list {
    my ($req) = @_;
    my $params = $req->{params} // {};

    my $uid         = trim($params->{user_id} // '');
    my $task_id     = trim($params->{task_id} // '');
    my $status_scan = trim($params->{status_scan} // '');

    my $roq = Wahana::Query->new(name => 'ScansListAll');
    my $rows = $roq->selectall();

    if ($uid) {
        @$rows = grep { $_->{user_id} && $_->{user_id} eq $uid } @$rows;
    }
    if ($task_id) {
        @$rows = grep { $_->{task_id} && $_->{task_id} eq $task_id } @$rows;
    }
    if ($status_scan) {
        @$rows = grep { $_->{status_scan} && $_->{status_scan} eq $status_scan } @$rows;
    }

    return { scans => [ map { map_scan($_) } @$rows ] };
}

# GET /api/scans/stats/:user_id
sub stats {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0];

    my $roq = Wahana::Query->new(
        name => 'ScansStats',
        data => { user_id => $user_id }
    );
    my $stats_row = $roq->selectrow() // {};

    return {
        stats => {
            total     => int(($stats_row->{total_success} // 0) + ($stats_row->{total_duplicate} // 0)),
            success   => int($stats_row->{total_success} // 0),
            duplicate => int($stats_row->{total_duplicate} // 0),
            lastScan  => $stats_row->{last_scan} ? fmt_datetime($stats_row->{last_scan}) : '-',
        }
    };
}

# POST /api/scans (Transaksi Atomik Stored Procedure: sp_scans_process)
sub create {
    my ($req) = @_;
    my $body = $req->{body} // {};

    my $user_id = $req->{auth_user}{uid} // trim($body->{user_id} // '');
    my $resi    = uc(trim($body->{nomor_resi} // ''));
    my $task_id = trim($body->{task_id} // '');

    return { success => \0, reason => 'EMPTY', message => 'Nomor resi tidak boleh kosong.' }
        unless length $resi;

    return { success => \0, reason => 'EMPTY', message => 'task_id wajib diisi.' }
        unless length $task_id;

    my $dbh = Wahana::Db->connect();
    my $max_num = $dbh->selectrow_array("SELECT COALESCE(MAX(CAST(SUBSTRING(scan_id, 5) AS UNSIGNED)), 0) FROM scan_events WHERE scan_id REGEXP '^SCN-[0-9]+$'") // 0;
    my $scan_id = sprintf 'SCN-%05d', $max_num + 1;

    my $lokasi  = trim($body->{lokasi}    // '') || 'CIPUTAT';
    my $device  = trim($body->{device_id} // '') || 'SCAN-DEVICE-01';
    my $jenis   = trim($body->{jenis_scan}// '') || 'INBOUND';

    my $res = Wahana::Query->new(
        name => 'ScansProcess',
        data => {
            scan_id    => $scan_id,
            nomor_resi => $resi,
            user_id    => $user_id,
            task_id    => $task_id,
            lokasi     => $lokasi,
            device_id  => $device,
            jenis_scan => $jenis,
        }
    )->selectrow();

    if (!$res) {
        return { success => \0, message => 'Terjadi kesalahan sistem saat memproses scan.' };
    }

    my $code = $res->{result_code} // '';

    if ($code eq 'UNKNOWN_RESI') {
        record_audit(
            user_id    => $user_id,
            action     => 'SCAN_REJECTED',
            details    => "Resi: $resi, Status: UNKNOWN_RESI",
            ip_address => $req->{ip},
        );
        return {
            success     => \0,
            reason      => 'UNKNOWN_RESI',
            status_scan => 'REJECTED',
            message     => "Nomor resi $resi tidak terdaftar. Pastikan customer sudah membuat resi.",
        };
    }

    if ($code eq 'DRAFT') {
        record_audit(
            user_id    => $user_id,
            action     => 'SCAN_REJECTED',
            details    => "Resi: $resi, Status: DRAFT",
            ip_address => $req->{ip},
        );
        return {
            success     => \0,
            reason      => 'DRAFT',
            status_scan => 'REJECTED',
            message     => "Nomor resi $resi masih DRAFT — data barang belum disimpan customer.",
        };
    }

    if ($code eq 'FINISHED') {
        return {
            success => \0,
            reason  => 'FINISHED',
            message => 'Task sudah selesai dan tidak dapat melakukan scan.',
        };
    }

    my $is_dup = ($code eq 'DUPLICATE');
    my $status = $is_dup ? 'DUPLICATE' : 'SUCCESS';

    my $scan_obj = {
        scan_id     => $scan_id,
        nomor_resi  => $resi,
        user_id     => $user_id,
        user_name   => $req->{auth_user}{name} // '(user)',
        task_id     => $task_id,
        waktu_scan  => 'Baru saja',
        lokasi      => $lokasi,
        status_scan => $status,
        device_id   => $device,
        jenis_scan  => $jenis,
    };

    record_audit(
        user_id    => $user_id,
        action     => $is_dup ? 'SCAN_DUPLICATE' : 'SCAN_EVENT_CREATED',
        details    => "Resi: $resi, Status: $status",
        ip_address => $req->{ip},
    );

    return $is_dup
        ? {
            success     => \0,
            reason      => 'DUPLICATE',
            status_scan => 'DUPLICATE',
            message     => "Nomor resi $resi sudah pernah discan.",
            scan        => $scan_obj,
        }
        : {
            success     => \1,
            resi        => $resi,
            status_scan => 'SUCCESS',
            message     => "Nomor resi $resi berhasil discan.",
            scan        => $scan_obj,
        };
}

1;
