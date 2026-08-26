package Wahana::Controller::UsersController;
use strict;
use warnings;
use Wahana::Db;
use Wahana::Util qw(fmt_datetime trim);
use Wahana::Auth ();
use Wahana::Audit qw(record_audit);
use Exporter 'import';

our @EXPORT_OK = qw(map_user get_user_role);

# Map baris tabel users ke bentuk JSON yang dikonsumsi frontend.
# CATATAN: password_hash TIDAK PERNAH dikirim ke klien.
sub map_user {
    my ($r) = @_;
    return {
        id            => $r->{id},
        name          => $r->{name},
        username      => $r->{username},
        role          => $r->{role},
        supervisor_id => $r->{supervisor_id},
        status        => $r->{status},
        lastLogin     => fmt_datetime($r->{last_login}),
    };
}

sub get_user_role {
    my ($user_id) = @_;
    my $dbh  = Wahana::Db->connect();
    my $role = $dbh->selectrow_array(
        'SELECT role FROM users WHERE id = ?', undef, $user_id
    );
    return $role;
}

# GET /api/users
sub list {
    my ($req) = @_;

    my $dbh  = Wahana::Db->connect();
    my $rows = $dbh->selectall_arrayref(
        'SELECT * FROM users ORDER BY id ASC', { Slice => {} }
    );

    return { users => [ map { map_user($_) } @$rows ] };
}

# POST /api/users  (ADMIN only)
sub create {
    my ($req) = @_;
    my $body = $req->{body} // {};

    my $name     = trim($body->{name}         // '');
    my $username = trim($body->{username}     // '');
    my $password = $body->{password}          // '123456';
    my $role     = $body->{role}              // 'PETUGAS_SCAN';
    my $spv_id   = $body->{supervisor_id};

    return { success => \0, message => 'Nama dan username wajib diisi.' }
        unless length $name && length $username;

    my %valid_roles = map { $_ => 1 } qw(ADMIN SUPERVISOR PETUGAS_SCAN CUSTOMER);
    return { success => \0, message => 'Role tidak valid.' }
        unless $valid_roles{$role};

    my $dbh = Wahana::Db->connect();

    # Username harus unik
    my $exists = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?)',
        undef, $username
    );
    return { success => \0, message => "Username '$username' sudah digunakan." }
        if $exists;

    # Generate ID berurutan: USR-004, USR-005, ...
    my $max_num = $dbh->selectrow_array(
        "SELECT COALESCE(MAX(CAST(SUBSTRING(id, 5) AS UNSIGNED)), 0)
           FROM users WHERE id REGEXP '^USR-[0-9]+\$'"
    );
    my $new_id = sprintf 'USR-%03d', $max_num + 1;

    $dbh->do(
        'INSERT INTO users (id, name, username, password_hash, role, supervisor_id, status)
         VALUES (?, ?, ?, ?, ?, ?, ?)',
        undef,
        $new_id, $name, $username,
        Wahana::Auth->hash_password($password),
        $role, $spv_id, 'OFFLINE'
    );

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_CREATED',
        details    => "User baru $name ($new_id) dengan role $role.",
        ip_address => $req->{ip},
    );

    my $row = $dbh->selectrow_hashref('SELECT * FROM users WHERE id = ?', undef, $new_id);
    return { success => \1, user => map_user($row) };
}

# PATCH /api/users/:id/status  (ADMIN only)
sub toggle_status {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0];

    my $dbh = Wahana::Db->connect();
    my $row = $dbh->selectrow_hashref('SELECT * FROM users WHERE id = ?', undef, $user_id);

    return { success => \0, message => 'User tidak ditemukan.' }
        unless $row;

    my $new_status = $row->{status} eq 'DISABLED' ? 'OFFLINE' : 'DISABLED';
    $dbh->do('UPDATE users SET status = ? WHERE id = ?', undef, $new_status, $user_id);

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_STATUS_CHANGED',
        details    => "Status $user_id diubah dari $row->{status} menjadi $new_status.",
        ip_address => $req->{ip},
    );

    return { success => \1, newStatus => $new_status };
}

1;
