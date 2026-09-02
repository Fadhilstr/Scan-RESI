package Wahana::Config;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(config);

# Konfigurasi terpusat — dapat dioverride lewat environment variable.
sub config {
    my $host = $ENV{DB_HOST} // $ENV{WAHANA_DB_HOST} // '127.0.0.1';
    my $port = $ENV{DB_PORT} // $ENV{WAHANA_DB_PORT} // 3306;
    my $name = $ENV{DB_NAME} // $ENV{WAHANA_DB_NAME} // 'wahana_scan';
    my $dsn  = $ENV{WAHANA_DB_DSN} // "DBI:mysql:database=$name;host=$host;port=$port";

    return {
        db_dsn       => $dsn,
        db_user      => $ENV{DB_USER}      // $ENV{WAHANA_DB_USER}      // 'wahana_app',
        db_pass      => $ENV{DB_PASS}      // $ENV{WAHANA_DB_PASS}      // 'wahana_pass',
        api_port     => $ENV{WAHANA_API_PORT}     // 5000,
        token_secret   => $ENV{WAHANA_TOKEN_SECRET} // 'wahana-dev-secret-2026-ganti-di-produksi',
        token_ttl      => $ENV{WAHANA_TOKEN_TTL}    // 86400,   # detik (24 jam)
        smtp_host      => $ENV{SMTP_HOST}           // 'smtp.gmail.com',
        smtp_port      => $ENV{SMTP_PORT}           // 587,
        smtp_user      => $ENV{SMTP_USER}           // '',
        smtp_pass      => $ENV{SMTP_PASSWORD}       // '',
        smtp_secure    => $ENV{SMTP_SECURE}         // 'false',
        smtp_from_name => $ENV{SMTP_FROM_NAME}      // 'DIJAK EXPRESS',
    };
}

1;
