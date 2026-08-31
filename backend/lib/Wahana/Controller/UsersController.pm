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
    my $raw_role = $body->{role};
    if (ref $raw_role eq 'HASH') {
        $raw_role = $raw_role->{value} // $raw_role->{label};
    }
    my $role = uc(trim($raw_role // 'PETUGAS_SCAN'));
    $role = 'PETUGAS_SCAN' if $role eq 'PETUGAS' || $role eq 'PETUGAS SCAN';
    $role = 'CUSTOMER'     if $role eq 'CUST';

    return { success => \0, message => 'Nama dan username wajib diisi.' }
        unless length $name && length $username;

    my %valid_roles = map { $_ => 1 } qw(ADMIN PETUGAS_SCAN CUSTOMER);
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

    # Generate ID berurutan sesuai role:
    my $new_id;
    if ($role eq 'CUSTOMER') {
        my $max_cust = $dbh->selectrow_array(
            "SELECT COALESCE(MAX(CAST(SUBSTRING(id, 10) AS UNSIGNED)), 0)
               FROM users WHERE id REGEXP '^USR-CUST-[0-9]+\$'"
        );
        $new_id = sprintf 'USR-CUST-%03d', ($max_cust // 0) + 1;
    } else {
        my $max_num = $dbh->selectrow_array(
            "SELECT COALESCE(MAX(CAST(SUBSTRING(id, 5) AS UNSIGNED)), 0)
               FROM users WHERE id REGEXP '^USR-[0-9]+\$'"
        );
        $new_id = sprintf 'USR-%03d', ($max_num // 0) + 1;
    }

    $dbh->do(
        'INSERT INTO users (id, name, username, password_hash, role, status)
         VALUES (?, ?, ?, ?, ?, ?)',
        undef,
        $new_id, $name, $username,
        Wahana::Auth->hash_password($password),
        $role, 'OFFLINE'
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

# PUT /api/users/:id  (ADMIN only)
sub update {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0];
    my $body = $req->{body} // {};

    my $dbh = Wahana::Db->connect();
    my $row = $dbh->selectrow_hashref('SELECT * FROM users WHERE id = ?', undef, $user_id);
    return { success => \0, message => 'User tidak ditemukan.' } unless $row;

    my $name     = trim($body->{name} // $row->{name});
    my $username = trim($body->{username} // $row->{username});
    my $password = $body->{password};

    my $raw_role = $body->{role} // $row->{role};
    if (ref $raw_role eq 'HASH') {
        $raw_role = $raw_role->{value} // $raw_role->{label};
    }
    my $role = uc(trim($raw_role // $row->{role}));
    $role = 'PETUGAS_SCAN' if $role eq 'PETUGAS' || $role eq 'PETUGAS SCAN';
    $role = 'CUSTOMER'     if $role eq 'CUST';

    return { success => \0, message => 'Nama dan username wajib diisi.' }
        unless length $name && length $username;

    my %valid_roles = map { $_ => 1 } qw(ADMIN PETUGAS_SCAN CUSTOMER);
    return { success => \0, message => 'Role tidak valid.' }
        unless $valid_roles{$role};

    # Username harus unik kecuali untuk user itu sendiri
    my $exists = $dbh->selectrow_array(
        'SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?) AND id != ?',
        undef, $username, $user_id
    );
    return { success => \0, message => "Username '$username' sudah digunakan oleh user lain." }
        if $exists;

    if (defined $password && length trim($password)) {
        $dbh->do(
            'UPDATE users SET name = ?, username = ?, role = ?, password_hash = ? WHERE id = ?',
            undef, $name, $username, $role, Wahana::Auth->hash_password(trim($password)), $user_id
        );
    } else {
        $dbh->do(
            'UPDATE users SET name = ?, username = ?, role = ? WHERE id = ?',
            undef, $name, $username, $role, $user_id
        );
    }

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_UPDATED',
        details    => "Data user $name ($user_id) diperbarui. Role: $role.",
        ip_address => $req->{ip},
    );

    my $updated = $dbh->selectrow_hashref('SELECT * FROM users WHERE id = ?', undef, $user_id);
    return { success => \1, user => map_user($updated), message => 'Data user berhasil diperbarui.' };
}

# DELETE /api/users/:id  (ADMIN only)
sub delete {
    my ($req, $captures) = @_;
    my $user_id = $captures->[0];

    my $dbh = Wahana::Db->connect();
    my $row = $dbh->selectrow_hashref('SELECT * FROM users WHERE id = ?', undef, $user_id);
    return { success => \0, message => 'User tidak ditemukan.' } unless $row;

    # Cegah admin menghapus dirinya sendiri
    if ($req->{auth_user}{uid} eq $user_id) {
        return { success => \0, message => 'Anda tidak dapat menghapus akun Anda sendiri yang sedang aktif.' };
    }

    # Cek relasi data (tasks, paket, scan_events)
    my $has_tasks = $dbh->selectrow_array('SELECT COUNT(*) FROM tasks WHERE user_id = ?', undef, $user_id);
    my $has_scans = $dbh->selectrow_array('SELECT COUNT(*) FROM scan_events WHERE user_id = ?', undef, $user_id);
    my $has_paket = $dbh->selectrow_array('SELECT COUNT(*) FROM paket WHERE created_by = ?', undef, $user_id);

    if ($has_tasks || $has_scans || $has_paket) {
        return {
            success => \0,
            message => "User $row->{name} tidak dapat dihapus karena memiliki riwayat operasional (Tasks/Scans/Paket). Silakan nonaktifkan (Disable) user."
        };
    }

    $dbh->do('DELETE FROM users WHERE id = ?', undef, $user_id);

    record_audit(
        user_id    => $req->{auth_user}{uid},
        action     => 'USER_DELETED',
        details    => "User $row->{name} ($user_id) telah dihapus dari sistem.",
        ip_address => $req->{ip},
    );

    return { success => \1, message => "User $row->{name} berhasil dihapus." };
}

1;
