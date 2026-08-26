package Wahana::Controller::AuditController;
use strict;
use warnings;
use Wahana::Db;
use Wahana::Util qw(fmt_datetime);
use Exporter 'import';

our @EXPORT_OK = qw();

# GET /api/audit-logs  (ADMIN only)
# Query opsional: ?user_id=&action=&limit=
sub list {
    my ($req) = @_;
    my $params = $req->{params} // {};

    my @where;
    my @bind;
    if (my $uid = $params->{user_id}) {
        push @where, 'a.user_id = ?';
        push @bind,  $uid;
    }
    if (my $action = $params->{action}) {
        push @where, 'a.action = ?';
        push @bind,  $action;
    }

    my $limit = int($params->{limit} || 200);
    $limit = 500 if $limit > 500;

    my $dbh = Wahana::Db->connect();
    my $sql = 'SELECT a.*, u.name AS user_name
                 FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id'
        . (@where ? ' WHERE ' . join(' AND ', @where) : '')
        . " ORDER BY a.log_id DESC LIMIT $limit";

    my $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @bind);

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
