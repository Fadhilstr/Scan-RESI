package Wahana::Controller::ScansController;
use strict;
use warnings;
use Wahana::Db;
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

    my @where;
    my @bind;
    for my $f (qw(user_id task_id status_scan)) {
        if (my $v = trim($params->{$f} // '')) {
            push @where, "s.$f = ?";
            push @bind,  $v;
        }
    }

    my $dbh = Wahana::Db->connect();
    my $sql = 'SELECT s.*, u.name AS user_name
                 FROM scan_events s JOIN users u ON u.id = s.user_id'
        . (@where ? ' WHERE ' . join(' AND ', @where) : '')
        . ' ORDER BY s.scan_id DESC';

    my $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind);

    return { scans => [ map { map_scan($_) } @$rows ] };
}

# GET /api/scans/stats/:user_id
sub stats {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0];

    my $dbh = Wahana::Db->connect();

    my ($success) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM scan_events WHERE user_id = ? AND status_scan = 'SUCCESS'",
        undef, $user_id
    );
    my ($duplicate) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM scan_events WHERE user_id = ? AND status_scan = 'DUPLICATE'",
        undef, $user_id
    );
    my ($last) = $dbh->selectrow_array(
        'SELECT MAX(waktu_scan) FROM scan_events WHERE user_id = ?',
        undef, $user_id
    );

    return {
        stats => {
            total    => int($success // 0),
            success  => int($success // 0),
            duplicate => int($duplicate // 0),
            lastScan => $last ? fmt_datetime($last) : '-',
        }
    };
}

# POST /api/scans
# Body: { nomor_resi, user_id?, task_id, lokasi?, device_id?, jenis_scan? }
#
# Validasi duplikasi + increment progress dilakukan TRANSAKSIONAL di server:
#   BEGIN → LOCK task → cek duplikat → INSERT scan → UPDATE progress → COMMIT
sub create {
    my ($req) = @_;
    my $body = $req->{body} // {};

    # Prioritaskan user_id dari token auth; fallback ke body.
    my $user_id = $req->{auth_user}{uid} // trim($body->{user_id} // '');
    my $resi    = uc(trim($body->{nomor_resi} // ''));
    my $task_id = trim($body->{task_id} // '');

    return { success => \0, reason => 'EMPTY', message => 'Nomor resi tidak boleh kosong.' }
        unless length $resi;

    return { success => \0, reason => 'EMPTY', message => 'task_id wajib diisi.' }
        unless length $task_id;

    my $dbh = Wahana::Db->connect();

    $dbh->begin_work();
    my $failed = 0;
    my $result;

    eval {
        # Kunci baris task untuk mencegah race condition antar petugas.
        my $task = $dbh->selectrow_hashref(
            'SELECT * FROM tasks WHERE task_id = ? FOR UPDATE', undef, $task_id
        );
        die "__notfound__" unless $task;
        die "__finished__" if $task->{status} eq 'SELESAI';

        my $dup = $dbh->selectrow_array(
            "SELECT COUNT(*) FROM scan_events
              WHERE task_id = ? AND UPPER(nomor_resi) = ? AND status_scan = 'SUCCESS'",
            undef, $task_id, $resi
        );

        # Generate scan_id berurutan: SCN-00008, SCN-00009, ...
        my $max_num = $dbh->selectrow_array(
            "SELECT COALESCE(MAX(CAST(SUBSTRING(scan_id, 5) AS UNSIGNED)), 0)
               FROM scan_events WHERE scan_id REGEXP '^SCN-[0-9]+\$'"
        );
        my $scan_id = sprintf 'SCN-%05d', $max_num + 1;

        my $status = $dup ? 'DUPLICATE' : 'SUCCESS';

        $dbh->do(
            'INSERT INTO scan_events
                (scan_id, nomor_resi, user_id, task_id, waktu_scan,
                 lokasi, status_scan, device_id, jenis_scan)
             VALUES (?, ?, ?, ?, NOW(), ?, ?, ?, ?)',
            undef,
            $scan_id, $resi, $user_id, $task_id,
            trim($body->{lokasi}      // '') || $task->{lokasi} || 'CIPUTAT',
            $status,
            trim($body->{device_id}   // '') || 'SCAN-DEVICE-01',
            trim($body->{jenis_scan}  // '') || 'INBOUND',
        ) or die "insert gagal: " . ($dbh->errstr // '');

        # Progress hanya bertambah untuk scan SUCCESS (FR-4.2)
        $dbh->do('UPDATE tasks SET progress = progress + 1 WHERE task_id = ?', undef, $task_id)
            unless $dup;

        $dbh->commit();

        my $row = $dbh->selectrow_hashref(
            'SELECT s.*, u.name AS user_name
               FROM scan_events s JOIN users u ON u.id = s.user_id
              WHERE s.scan_id = ?', undef, $scan_id
        );
        my $scan_obj = map_scan($row);

        record_audit(
            user_id    => $user_id,
            action     => $dup ? 'SCAN_DUPLICATE' : 'SCAN_EVENT_CREATED',
            details    => "Resi: $resi, Status: $status",
            ip_address => $req->{ip},
        );

        $result = $dup
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

        1;
    } or do {
        my $err = $@;
        eval { $dbh->rollback() };
        $failed = 1;

        if ($err =~ /__notfound__/) {
            $result = { success => \0, reason => 'NOT_FOUND', message => 'Task tidak ditemukan.' };
        }
        elsif ($err =~ /__finished__/) {
            $result = {
                success => \0, reason => 'FINISHED',
                message => 'Task sudah selesai dan tidak dapat melakukan scan.',
            };
        }
        else {
            warn "[SCANS] Transaksi gagal: $err";
            die $err;   # ditangkap Router → HTTP 500
        }
    };

    return $result;
}

1;
