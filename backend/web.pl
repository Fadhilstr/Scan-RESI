#!/usr/bin/env perl
# =====================================================================
# web.pl — PSGI Entrypoint untuk uWSGI & Plack Server (Wahana Express)
#
# Mengadaptasikan Wahana::Router ke spesifikasi standar PSGI
# Dijalankan dengan uWSGI:
#   uwsgi --ini backend/uwsgi.ini
#   uwsgi --http-socket 0.0.0.0:5000 --plugin psgi --psgi backend/web.pl
# =====================================================================
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";

use Wahana::Router   qw(handle_request);
use Wahana::Response qw(decode_json_body);

my $app = sub {
    my ($env) = @_;

    my $method = uc($env->{REQUEST_METHOD} // 'GET');
    my $path   = $env->{PATH_INFO} // '/';
    $path ||= '/';

    # --- Query Params ---
    my %params;
    if (defined $env->{QUERY_STRING} && length $env->{QUERY_STRING}) {
        for my $pair (split /[&;]/, $env->{QUERY_STRING}) {
            my ($k, $v) = map {
                my $s = $_ // '';
                $s =~ s/\+/ /g;
                $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
                $s;
            } split /=/, $pair, 2;
            $params{$k} = $v // '' if length $k;
        }
    }

    # --- Read Request Body ---
    my $body_raw = '';
    if (my $len = int($env->{CONTENT_LENGTH} // 0)) {
        if (my $input = $env->{'psgi.input'}) {
            $input->read($body_raw, $len);
        }
    }

    # --- Extract Headers ---
    my %headers;
    for my $key (keys %$env) {
        if ($key =~ /^HTTP_(.+)$/) {
            my $h = lc $1;
            $h =~ tr/_/-/;
            $headers{$h} = $env->{$key};
        } elsif ($key eq 'CONTENT_TYPE') {
            $headers{'content-type'} = $env->{$key};
        } elsif ($key eq 'CONTENT_LENGTH') {
            $headers{'content-length'} = $env->{$key};
        }
    }

    # --- Decode Body (JSON / Form) ---
    my $body;
    my $content_type = $headers{'content-type'} // '';
    if ($content_type =~ m{application/x-www-form-urlencoded}i) {
        my %form;
        for my $pair (split /[&;]/, $body_raw) {
            my ($k, $v) = map {
                my $s = $_ // '';
                $s =~ s/\+/ /g;
                $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
                $s;
            } split /=/, $pair, 2;
            $form{$k} = $v // '' if length $k;
        }
        $body = \%form;
    } else {
        $body = decode_json_body($body_raw);
    }

    my %req = (
        method  => $method,
        path    => $path,
        params  => \%params,
        headers => \%headers,
        body    => $body // {},
        ip      => $env->{REMOTE_ADDR} // $env->{HTTP_X_FORWARDED_FOR} // '-',
    );

    # Dispatch ke Wahana::Router
    my $res = handle_request(%req);

    my $status = int($res->{status} || 200);
    my @psgi_headers;
    while (my ($k, $v) = each %{ $res->{headers} || {} }) {
        push @psgi_headers, $k => $v;
    }

    my $res_body = ($status == 204) ? '' : ($res->{body} // '');
    return [ $status, \@psgi_headers, [ $res_body ] ];
};

return $app;
