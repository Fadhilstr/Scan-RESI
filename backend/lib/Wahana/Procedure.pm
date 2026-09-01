package Wahana::Procedure;
# =====================================================================
# Wahana::Procedure — Wrapper Eksekusi Stored Procedure
# Terintegrasi dengan Wahana::Query & Master Table sys_queries
# =====================================================================
use strict;
use warnings;
use Wahana::Query;
use Exporter 'import';

our @EXPORT_OK = qw(get_all get_row execute_action list_registry);

sub get_all {
    my ($class, $name, $rhpar) = @_;
    # Support jika dikirim parameter array legacy atau hashref
    my $data = ref $rhpar eq 'HASH' ? $rhpar : {};
    my $roq = Wahana::Query->new(name => $name, data => $data);
    return $roq->selectall();
}

sub get_row {
    my ($class, $name, $rhpar) = @_;
    my $data = ref $rhpar eq 'HASH' ? $rhpar : {};
    my $roq = Wahana::Query->new(name => $name, data => $data);
    return $roq->selectrow();
}

sub execute_action {
    my ($class, $name, $rhpar) = @_;
    my $data = ref $rhpar eq 'HASH' ? $rhpar : {};
    my $roq = Wahana::Query->new(name => $name, data => $data);
    return $roq->execute();
}

sub list_registry {
    return Wahana::Query::get_catalog_list();
}

1;
