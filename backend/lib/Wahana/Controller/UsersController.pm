package Wahana::Controller::UsersController;
use strict;
use warnings;
use Wahana::Db;
use Wahana::Query;
use Wahana::Util qw(fmt_datetime trim);
use Wahana::Auth ();
use Wahana::Audit qw(record_audit);
use Exporter 'import';

our @EXPORT_OK = qw(map_user get_user_role);

# Map baris tabel users ke bentuk JSON yang dikonsumsi frontend.
sub map_user {
    my ($r) = @_;
    return {
        id        => $r->{id},
        name      => $r->{name},
        username  => $r->{username},
        role      => $r->{role},
        status    => $r->{status},
        lastLogin => fmt_datetime($r->{last_login}),
    };
}

sub get_user_role {
    my ($user_id) = @_;
    my $roq = Wahana::Query->new(
        name => 'UsersGetById',
        data => { id => $user_id }
    );
    my $row = $roq->selectrow();
    return $row ? $row->{role} : undef;
}

# GET /api/users
sub list {
    my ($req) = @_;
    my $roq = Wahana::Query->new(name => 'UsersListAll');
    my $rows = $roq->selectall();
    return { users => [ map { map_user($_) } @$rows ] };
}

# POST /api/users  (ADMIN only)
sub create {
    my ($req) = @_;
    my $body = $req->{body} // {};

    my $name     = trim($body->{name}         // '');
    my $username = trim($body->{username}     // '');
    my $password = $body->{password}          // '123456';
    my $raw_role = $body->{role};
    if (ref $raw_role eq 'HASH') {
        $raw_role = $raw_role->{value} // $raw_role->{label};
    }
    my $role = uc(trim($raw_role // 'PETUGAS_SCAN'));
    $role = 'PETUGAS_SCAN' if $role eq 'PETUGAS' || $role eq 'PETUGAS SCAN';
    $role = 'CUSTOMER'     if $role eq 'CUST';
    $role = 'DEVELOPER'    if $role eq 'DEV';

    return { success => \0, message => 'Nama dan username wajib diisi.' }
        unless length $name && length $username;

    # Cek duplikasi username
    my $dbh = Wahana::Db->connect();
    my $existing = $dbh->selectrow_array("SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?)", undef, $username);
    return { success => \0, message => "Username '$username' sudah digunakan." }
        if $existing;

    # Generate format ID
    my $id;
    if ($role eq 'ADMIN') {
        my $max_num = $dbh->selectrow_array("SELECT COALESCE(MAX(CAST(SUBSTRING(id, 11) AS UNSIGNED)), 0) FROM users WHERE id REGEXP '^USR-ADMIN-[0-9]+$'") // 0;
        $id = sprintf('USR-ADMIN-%03d', $max_num + 1);
    } elsif ($role eq 'CUSTOMER') {
        my $max_num = $dbh->selectrow_array("SELECT COALESCE(MAX(CAST(SUBSTRING(id, 10) AS UNSIGNED)), 0) FROM users WHERE id REGEXP '^USR-CUST-[0-9]+$'") // 0;
        $id = sprintf('USR-CUST-%03d', $max_num + 1);
    } elsif ($role eq 'DEVELOPER') {
        my $max_num = $dbh->selectrow_array("SELECT COALESCE(MAX(CAST(SUBSTRING(id, 9) AS UNSIGNED)), 0) FROM users WHERE id REGEXP '^USR-DEV-[0-9]+$'") // 0;
        $id = sprintf('USR-DEV-%03d', $max_num + 1);
    } else {
        my $max_num = $dbh->selectrow_array("SELECT COALESCE(MAX(CAST(SUBSTRING(id, 5) AS UNSIGNED)), 0) FROM users WHERE id REGEXP '^USR-[0-9]+$'") // 0;
        $id = sprintf('USR-%03d', $max_num + 1);
    }

    my $pass_hash = Wahana::Auth->hash_password($password);

    Wahana::Query->new(
        name => 'UsersInsert',
        data => {
            id            => $id,
            name          => $name,
            username      => $username,
            password_hash => $pass_hash,
            role          => $role,
            status        => 'OFFLINE',
        }
    )->execute();

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_CREATED',
        details    => "Membuat user '$username' ($role) dengan ID $id.",
        ip_address => $req->{ip},
    );

    return {
        success => \1,
        user    => { id => $id, name => $name, username => $username, role => $role, status => 'OFFLINE' },
        message => 'User berhasil dibuat.',
    };
}

# PUT /api/users/:id  (ADMIN only)
sub update {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0] or return { success => \0, message => 'ID tidak valid.' };
    my $body    = $req->{body} // {};

    my $name     = trim($body->{name}     // '');
    my $username = trim($body->{username} // '');
    my $raw_role = $body->{role};
    if (ref $raw_role eq 'HASH') {
        $raw_role = $raw_role->{value} // $raw_role->{label};
    }
    my $role = uc(trim($raw_role // 'PETUGAS_SCAN'));
    $role = 'PETUGAS_SCAN' if $role eq 'PETUGAS' || $role eq 'PETUGAS SCAN';
    $role = 'CUSTOMER'     if $role eq 'CUST';
    $role = 'DEVELOPER'    if $role eq 'DEV';

    return { success => \0, message => 'Nama dan username wajib diisi.' }
        unless length $name && length $username;

    my $dbh = Wahana::Db->connect();
    my $existing = $dbh->selectrow_array("SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?) AND id != ?", undef, $username, $user_id);
    return { success => \0, message => "Username '$username' sudah digunakan user lain." }
        if $existing;

    my $pass_hash = '';
    if (defined $body->{password} && length trim($body->{password})) {
        $pass_hash = Wahana::Auth->hash_password(trim($body->{password}));
    }

    Wahana::Query->new(
        name => 'UsersUpdate',
        data => {
            id            => $user_id,
            name          => $name,
            username      => $username,
            role          => $role,
            password_hash => $pass_hash,
        }
    )->execute();

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_UPDATED',
        details    => "Update user '$username' ($user_id).",
        ip_address => $req->{ip},
    );

    return { success => \1, message => 'Data user berhasil diperbarui.' };
}

# DELETE /api/users/:id  (ADMIN only)
sub delete {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0] or return { success => \0, message => 'ID tidak valid.' };

    return { success => \0, message => 'Anda tidak dapat menghapus akun Anda sendiri.' }
        if $req->{auth_user}{uid} eq $user_id;

    Wahana::Query->new(
        name => 'UsersDelete',
        data => { id => $user_id }
    )->execute();

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_DELETED',
        details    => "Menghapus user ID $user_id.",
        ip_address => $req->{ip},
    );

    return { success => \1, message => 'User berhasil dihapus.' };
}

# PATCH /api/users/:id/status  (ADMIN only)
sub toggle_status {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0] or return { success => \0, message => 'ID tidak valid.' };
    my $body    = $req->{body} // {};

    my $new_status = uc(trim($body->{status} // ''));
    return { success => \0, message => 'Status harus ONLINE, OFFLINE, atau DISABLED.' }
        unless $new_status =~ /^(ONLINE|OFFLINE|DISABLED)$/;

    Wahana::Query->new(
        name => 'UsersToggleStatus',
        data => { id => $user_id, status => $new_status }
    )->execute();

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_STATUS_CHANGED',
        details    => "Status user ID $user_id diubah menjadi $new_status.",
        ip_address => $req->{ip},
    );

    return { success => \1, status => $new_status };
}

1;
