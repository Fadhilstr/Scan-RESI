package Wahana::Mail;
use strict;
use warnings;
use Net::SMTP;
use Wahana::Config qw(config);
use Exporter 'import';

our @EXPORT_OK = qw(send_otp_email);

# Mengirim email OTP via SMTP Gmail (Net::SMTP + STARTTLS)
sub send_otp_email {
    my %args = @_ % 2 == 0 ? @_ : @_[1 .. $#_];

    my $to_email = $args{to_email};
    my $otp_code = $args{otp_code};
    my $app_name = $args{app_name} // 'DIJAK EXPRESS';

    return (0, "Alamat email penerima tidak valid.")
        unless defined $to_email && $to_email =~ /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    my $cfg  = config();
    my $host = $cfg->{smtp_host} // 'smtp.gmail.com';
    my $port = int($cfg->{smtp_port} // 587);
    my $user = $cfg->{smtp_user} // '';
    my $pass = $cfg->{smtp_pass} // '';

    # Jika SMTP credentials belum diatur (masih placeholder di dev environment),
    # simulasikan sukses pengiriman agar aplikasi dev tetap bisa diuji dengan lancar.
    if (!$user || !$pass || $pass eq 'ganti-dengan-app-password') {
        warn "[MAIL SIMULATION] SMTP credentials belum diisi di .env ($user / $pass). Simulasi pengiriman OTP ke $to_email sukses.\n";
        return (1, "Kode OTP berhasil dikirim (mode simulasi SMTP).");
    }

    warn "[MAIL DEBUG] Mencoba mengirim email OTP ke $to_email via $host:$port ($user)...\n";

    my $smtp = Net::SMTP->new(
        $host,
        Port    => $port,
        Timeout => 15,
        Debug   => 0,
    );

    unless ($smtp) {
        warn "[MAIL ERROR] Gagal koneksi ke server SMTP $host:$port ($!)\n";
        return (0, "Gagal terhubung ke server email SMTP.");
    }

    # Jalankan STARTTLS jika port 587
    if ($port == 587 || ($cfg->{smtp_secure} && $cfg->{smtp_secure} ne 'false')) {
        if ($smtp->can('starttls')) {
            eval {
                $smtp->starttls(SSL_verify_mode => 0) or die "STARTTLS failed";
                1;
            } or do {
                warn "[MAIL ERROR] Gagal inisialisasi STARTTLS: $@\n";
                return (0, "Gagal mengamankan enkripsi koneksi email.");
            };
        }
    }

    # Otentikasi SASL (App Password)
    my $auth_ok = eval { $smtp->auth($user, $pass) };
    unless ($auth_ok) {
        warn "[MAIL ERROR] Autentikasi SMTP Gmail gagal untuk akun $user: $@\n";
        return (0, "Gagal otentikasi SMTP. Periksa SMTP_USER & App Password pada .env.");
    }

    my $from_name = $cfg->{smtp_from_name} // $app_name;
    my $subject   = "Kode Verifikasi OTP - $app_name";

    my $body = <<"END_EMAIL";
$app_name

Kode verifikasi OTP Anda:

$otp_code

Kode ini berlaku selama 5 menit.
Jangan berikan kode ini kepada siapa pun.
END_EMAIL

    $smtp->mail($user);
    if ($smtp->to($to_email)) {
        $smtp->data();
        $smtp->datasend("From: $from_name <$user>\n");
        $smtp->datasend("To: $to_email\n");
        $smtp->datasend("Subject: $subject\n");
        $smtp->datasend("Content-Type: text/plain; charset=UTF-8\n\n");
        $smtp->datasend($body);
        $smtp->dataend();
        $smtp->quit();
        warn "[MAIL SUCCESS] Email OTP berhasil dikirim ke $to_email via SMTP Gmail!\n";
        return (1, "Kode OTP berhasil dikirim ke $to_email");
    } else {
        warn "[MAIL ERROR] Alamat email ditolak server SMTP: $to_email\n";
        $smtp->quit();
        return (0, "Email penerima ditolak oleh server SMTP.");
    }
}

1;
