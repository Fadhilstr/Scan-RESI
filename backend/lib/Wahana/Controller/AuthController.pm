package Wahana::Controller::AuthController;
use strict;
use warnings;
use Wahana::Db;
use Wahana::Query;
use Wahana::Auth ();
use Wahana::Util qw(trim);
use Wahana::Audit qw(record_audit);
use Wahana::Controller::UsersController qw(map_user);

# POST /api/auth/login
# Body: { username, password }
sub login {
    my ($req) = @_;
    my $body = $req->{body} // {};

    my $username = trim($body->{username} // '');
    my $password = $body->{password} // '';

    return { success => \0, message => 'Username dan password wajib diisi.' }
        unless length $username && length $password;

    my $roq = Wahana::Query->new(
        name => 'AuthLogin',
        data => { username => $username }
    );
    my $row = $roq->selectrow();

    if (!$row || !Wahana::Auth->verify_password($password, $row->{password_hash})) {
        record_audit(
            user_id    => $row ? $row->{id} : undef,
            action     => 'LOGIN_FAILED',
            details    => "Percobaan login gagal untuk username '$username'.",
            ip_address => $req->{ip},
        );
        return { success => \0, message => 'Username atau password salah.' };
    }

    return { success => \0, message => 'Akun Anda telah dinonaktifkan.' }
        if $row->{status} eq 'DISABLED';

    Wahana::Query->new(
        name => 'AuthUpdateStatus',
        data => { user_id => $row->{id}, status => 'ONLINE' }
    )->execute();

    my $token = Wahana::Auth->issue_token($row->{id});

    record_audit(
        user_id    => $row->{id},
        action     => 'LOGIN_SUCCESS',
        details    => 'Login berhasil.',
        ip_address => $req->{ip},
    );

    my $mapped = map_user({ %$row, status => 'ONLINE' });

    return {
        success => \1,
        user    => $mapped,
        role    => $row->{role},
        token   => $token,
        message => "Selamat datang, $row->{name}!",
    };
}

# POST /api/auth/quick-login
sub quick_login {
    my ($req) = @_;
    my $body = $req->{body} // {};

    my $user_id = trim($body->{user_id} // '');
    return { success => \0, message => 'user_id wajib diisi.' }
        unless length $user_id;

    my $roq = Wahana::Query->new(
        name => 'UsersGetById',
        data => { id => $user_id }
    );
    my $row = $roq->selectrow();

    return { success => \0, message => 'User tidak ditemukan.' }
        unless $row;

    return { success => \0, message => 'Akun Anda telah dinonaktifkan.' }
        if $row->{status} eq 'DISABLED';

    Wahana::Query->new(
        name => 'AuthUpdateStatus',
        data => { user_id => $row->{id}, status => 'ONLINE' }
    )->execute();

    my $token = Wahana::Auth->issue_token($row->{id});

    record_audit(
        user_id    => $row->{id},
        action     => 'LOGIN_SUCCESS',
        details    => '1-Click Quick Login Demo.',
        ip_address => $req->{ip},
    );

    my $mapped = map_user({ %$row, status => 'ONLINE' });

    return {
        success => \1,
        user    => $mapped,
        role    => $row->{role},
        token   => $token,
        message => "Login instan sebagai $row->{name} ($row->{role})",
    };
}

# POST /api/auth/logout
sub logout {
    my ($req) = @_;

    my $payload = $req->{auth_user};
    my $uid     = $payload ? $payload->{uid} : ($req->{body}{user_id} // undef);

    if ($uid) {
        Wahana::Query->new(
            name => 'AuthUpdateStatus',
            data => { user_id => $uid, status => 'OFFLINE' }
        )->execute();

        record_audit(
            user_id    => $uid,
            action     => 'LOGOUT',
            details    => 'User keluar dari sistem.',
            ip_address => $req->{ip},
        );
    }

    return { success => \1 };
}

1;
