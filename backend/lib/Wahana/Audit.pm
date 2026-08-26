package Wahana::Audit;
use strict;
use warnings;
use Wahana::Db;
use Exporter 'import';

our @EXPORT_OK = qw(record_audit);

# Catat satu event audit ke tabel AUDIT_LOGS.
# Tidak pernah menggagalkan alur utama — kesalahan hanya ditulis ke STDERR.
sub record_audit {
    my (%event) = @_;

    eval {
        my $dbh = Wahana::Db->connect();
        $dbh->do(
            'INSERT INTO audit_logs (user_id, action, details, ip_address) VALUES (?, ?, ?, ?)',
            undef,
            $event{user_id},
            $event{action},
            $event{details},
            $event{ip_address}
        );
        1;
    } or do {
        warn "[AUDIT] Gagal mencatat event: $@";
    };

    return 1;
}

1;
