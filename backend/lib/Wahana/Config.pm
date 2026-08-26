package Wahana::Config;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(config);

# Konfigurasi terpusat — dapat dioverride lewat environment variable.
sub config {
    return {
        db_dsn       => $ENV{WAHANA_DB_DSN}       // 'DBI:mysql:database=wahana_scan;host=127.0.0.1;port=3306',
        db_user      => $ENV{WAHANA_DB_USER}      // 'wahana_app',
        db_pass      => $ENV{WAHANA_DB_PASS}      // 'wahana_pass',
        api_port     => $ENV{WAHANA_API_PORT}     // 8080,
        token_secret => $ENV{WAHANA_TOKEN_SECRET} // 'wahana-dev-secret-2026-ganti-di-produksi',
        token_ttl    => $ENV{WAHANA_TOKEN_TTL}    // 86400,   # detik (24 jam)
    };
}

1;
