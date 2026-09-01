package Wahana::Controller::AuditController;
use strict;
use warnings;
use Wahana::Db;
use Wahana::Query;
use Wahana::Util qw(fmt_datetime);
use Exporter 'import';

our @EXPORT_OK = qw();

# GET /api/audit-logs  (ADMIN only)
# Query opsional: ?user_id=&action=&limit=
sub list {
    my ($req) = @_;
    my $params = $req->{params} // {};

    my $uid    = $params->{user_id};
    my $action = $params->{action};
    my $limit  = int($params->{limit} || 200);
    $limit = 500 if $limit > 500;

    my $roq = Wahana::Query->new(name => 'AuditListAll');
    my $rows = $roq->selectall();

    # In-memory filter jika ada query params
    if ($uid) {
        @$rows = grep { $_->{user_id} && $_->{user_id} eq $uid } @$rows;
    }
    if ($action) {
        @$rows = grep { $_->{action} && $_->{action} eq $action } @$rows;
    }
    if (scalar(@$rows) > $limit) {
        @$rows = @$rows[0 .. $limit - 1];
    }

    my $logs = [ map {
        {
            log_id     => int($_->{log_id}),
            user_id    => $_->{user_id},
            user_name  => $_->{user_name} // '(system)',
            action     => $_->{action},
            details    => $_->{details},
            ip_address => $_->{ip_address},
            created_at => fmt_datetime($_->{created_at}),
        }
    } @$rows ];

    return { logs => $logs };
}

1;
