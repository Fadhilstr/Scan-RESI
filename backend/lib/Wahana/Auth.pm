package Wahana::Auth;
use strict;
use warnings;
use Digest::SHA qw(sha256_hex hmac_sha256_hex);
use MIME::Base64 qw(encode_base64url decode_base64url);
use JSON::PP ();
use Exporter 'import';
use Wahana::Config qw(config);

our @EXPORT_OK = qw(verify_password issue_token verify_token authenticate_request hash_password);

# Verifikasi password terhadap hash berformat: sha256$<salt>$<hex>
sub verify_password {
    my ($class, $password, $stored) = @_;

    return 0 unless defined $password && defined $stored;

    my ($scheme, $salt, $hex) = split /\$/, $stored;
    return 0 unless defined $scheme && $scheme eq 'sha256';
    return 0 unless defined $salt && defined $hex;

    return sha256_hex($salt . $password) eq lc($hex) ? 1 : 0;
}

# Token sederhana berformat: base64url(payload_json) . "." . hmac_sha256_hex
sub issue_token {
    my ($class, $user_id) = @_;
    my $cfg = config();

    my $payload = encode_base64url(
        JSON::PP::encode_json({ uid => $user_id, exp => time() + $cfg->{token_ttl} })
    );
    my $sig = hmac_sha256_hex($payload, $cfg->{token_secret});

    return "$payload.$sig";
}

sub verify_token {
    my ($class, $token) = @_;
    my $cfg = config();

    return undef unless defined $token && $token =~ /\./;

    my ($payload, $sig) = split /\./, $token, 2;
    return undef unless defined $payload && defined $sig;

    # Verifikasi tanda tangan HMAC
    return undef unless hmac_sha256_hex($payload, $cfg->{token_secret}) eq $sig;

    my $data = eval { JSON::PP::decode_json(decode_base64url($payload)) };
    return undef unless $data && $data->{uid} && $data->{exp};
    return undef unless $data->{exp} > time();

    return $data;
}

# Ekstrak & verifikasi header "Authorization: Bearer <token>".
# Mengembalikan payload hashref saat valid, undef saat tidak.
sub authenticate_request {
    my ($class, $req) = @_;

    my $auth_header = $req->{headers}{authorization} // '';
    return undef unless $auth_header =~ /^Bearer\s+(\S+)$/i;

    return __PACKAGE__->verify_token($1);
}

# Generate salt acak 8 karakter hex (untuk user baru)
sub generate_salt {
    my ($class) = @_;
    return join '', map { sprintf '%x', int rand(16) } 1 .. 8;
}

# Hash password dengan format identik seed SQL: sha256$<salt>$<hex>
sub hash_password {
    my ($class, $password, $salt) = @_;
    $salt //= __PACKAGE__->generate_salt();
    return "sha256\$$salt\$" . sha256_hex($salt . $password);
}

1;
