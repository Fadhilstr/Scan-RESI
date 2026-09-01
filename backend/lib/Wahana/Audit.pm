package Wahana::Audit;
use strict;
use warnings;
use Wahana::Db;
use Wahana::Query;
use Exporter 'import';

our @EXPORT_OK = qw(record_audit);

# Catat satu event audit ke tabel AUDIT_LOGS via Stored Procedure sp_audit_insert
sub record_audit {
    my (%event) = @_;

    eval {
        Wahana::Query->new(
            name => 'AuditInsert',
            data => {
                user_id    => $event{user_id},
                action     => $event{action},
                details    => $event{details},
                ip_address => $event{ip_address},
            }
        )->execute();
        1;
    } or do {
        warn "[AUDIT] Gagal mencatat event: $@";
    };

    return 1;
}

1;
