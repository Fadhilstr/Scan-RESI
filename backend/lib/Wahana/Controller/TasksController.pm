package Wahana::Controller::TasksController;
use strict;
use warnings;
use POSIX qw(strftime);
use Wahana::Db;
use Wahana::Query;
use Wahana::Util qw(fmt_date iso_date trim);
use Wahana::Audit qw(record_audit);
use Exporter 'import';

our @EXPORT_OK = qw(map_task);

sub map_task {
    my ($r) = @_;
    return {
        task_id   => $r->{task_id},
        user_id   => $r->{user_id},
        user_name => $r->{user_name},
        shift     => $r->{shift},
        tanggal   => fmt_date($r->{tanggal}),
        target    => int($r->{target} // 0),
        progress  => int($r->{progress} // 0),
        status    => $r->{status},
        lokasi    => $r->{lokasi},
    };
}

# GET /api/tasks?user_id=&status=
sub list {
    my ($req) = @_;
    my $params = $req->{params} // {};

    my $uid    = trim($params->{user_id} // '');
    my $status = trim($params->{status} // '');

    my $roq = Wahana::Query->new(name => 'TasksListAll');
    my $rows = $roq->selectall();

    if ($uid) {
        @$rows = grep { $_->{user_id} && $_->{user_id} eq $uid } @$rows;
    }
    if ($status) {
        @$rows = grep { $_->{status} && $_->{status} eq $status } @$rows;
    }

    return { tasks => [ map { map_task($_) } @$rows ] };
}

# POST /api/tasks  (ADMIN only)
sub create {
    my ($req) = @_;
    my $body = $req->{body} // {};

    my $user_id = trim($body->{user_id} // '');
    return { success => \0, message => 'user_id wajib diisi.' }
        unless length $user_id;

    my %valid_shifts = map { $_ => 1 } qw(Pagi Sore);
    my $shift = $valid_shifts{ $body->{shift} // '' } ? $body->{shift} : 'Pagi';

    my $tanggal = iso_date($body->{tanggal}) // strftime('%Y-%m-%d', localtime);
    my $target  = int($body->{target} || 100);
    my $lokasi  = trim($body->{lokasi} // '') || 'CIPUTAT';

    my $dbh = Wahana::Db->connect();

    # Cek user
    my $user = Wahana::Query->new(name => 'UsersGetById', data => { id => $user_id })->selectrow();
    return { success => \0, message => "User '$user_id' tidak ditemukan." }
        unless $user;

    my $max_num = $dbh->selectrow_array("SELECT COALESCE(MAX(CAST(SUBSTRING(task_id, 6) AS UNSIGNED)), 0) FROM tasks WHERE task_id REGEXP '^TASK-[0-9]+$'") // 0;
    my $new_id = sprintf 'TASK-%03d', $max_num + 1;

    Wahana::Query->new(
        name => 'TasksInsert',
        data => {
            task_id => $new_id,
            user_id => $user_id,
            shift   => $shift,
            tanggal => $tanggal,
            target  => $target,
            lokasi  => $lokasi,
        }
    )->execute();

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'TASK_CREATED',
        details    => "Task $new_id dibuat untuk $user_id (target: $target).",
        ip_address => $req->{ip},
    );

    my $row = Wahana::Query->new(name => 'TasksGetById', data => { task_id => $new_id })->selectrow();

    return { success => \1, task => map_task($row) };
}

# PATCH /api/tasks/:id/progress — increment progress +1
sub progress {
    my ($req, $captures) = @_;
    my $task_id = $captures->[0];

    Wahana::Query->new(
        name => 'TasksProgress',
        data => { task_id => $task_id, increment => 1 }
    )->execute();

    return { success => \1 };
}

# PATCH /api/tasks/:id/complete — selesaikan task (kunci scan)
sub complete {
    my ($req, $captures) = @_;
    my $task_id = $captures->[0];

    my $task = Wahana::Query->new(name => 'TasksGetById', data => { task_id => $task_id })->selectrow();
    return { success => \0, message => 'Task tidak ditemukan.' }
        unless $task;

    if ($task->{status} eq 'SELESAI') {
        return { success => \1, message => "Task $task_id sudah berstatus SELESAI." };
    }

    Wahana::Query->new(
        name => 'TasksComplete',
        data => { task_id => $task_id }
    )->execute();

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'TASK_COMPLETED',
        details    => "Task $task_id diselesaikan ($task->{progress}/$task->{target}).",
        ip_address => $req->{ip},
    );

    return { success => \1, message => "Task $task_id berhasil diselesaikan." };
}

1;
