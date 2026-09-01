package Wahana::Router;
use strict;
use warnings;
use Exporter 'import';
use Wahana::Config qw(config);
use Wahana::Auth ();
use Wahana::Response qw(json_response);
use Wahana::Controller::AuthController   ();
use Wahana::Controller::UsersController  qw(get_user_role);
use Wahana::Controller::TasksController  ();
use Wahana::Controller::ScansController  ();
use Wahana::Controller::PaketController  ();
use Wahana::Controller::AuditController  ();
use Wahana::Controller::DocsController   ();

our @EXPORT_OK = qw(handle_request);

# =====================================================================
# TABEL ROUTE — kontrak REST yang dikonsumsi frontend (src/services/)
# meta: { auth => butuh token Bearer, admin => khusus role ADMIN }
# =====================================================================
my @ROUTES = (
    # Dokumentasi API & OpenAPI Specification
    [ 'GET',    qr{^/api/openapi\.ya?ml$},             \&Wahana::Controller::DocsController::get_openapi_yaml,{} ],
    [ 'GET',    qr{^/api/docs/?$},                     \&Wahana::Controller::DocsController::get_swagger_ui,  {} ],

    [ 'POST',   qr{^/api/auth/login$},                 \&Wahana::Controller::AuthController::login,          {} ],
    [ 'POST',   qr{^/api/auth/quick-login$},           \&Wahana::Controller::AuthController::quick_login,    {} ],
    [ 'POST',   qr{^/api/auth/logout$},                \&Wahana::Controller::AuthController::logout,         {} ],
    [ 'GET',    qr{^/api/users$},                      \&Wahana::Controller::UsersController::list,          { auth => 1 } ],
    [ 'POST',   qr{^/api/users$},                      \&Wahana::Controller::UsersController::create,        { auth => 1, admin => 1 } ],
    [ 'PUT',    qr{^/api/users/([^/]+)$},              \&Wahana::Controller::UsersController::update,        { auth => 1, admin => 1 } ],
    [ 'DELETE', qr{^/api/users/([^/]+)$},              \&Wahana::Controller::UsersController::delete,        { auth => 1, admin => 1 } ],
    [ 'PATCH',  qr{^/api/users/([^/]+)/status$},       \&Wahana::Controller::UsersController::toggle_status, { auth => 1, admin => 1 } ],
    [ 'GET',    qr{^/api/tasks$},                      \&Wahana::Controller::TasksController::list,          { auth => 1 } ],
    [ 'POST',   qr{^/api/tasks$},                      \&Wahana::Controller::TasksController::create,        { auth => 1, admin => 1 } ],
    [ 'PATCH',  qr{^/api/tasks/([^/]+)/progress$},     \&Wahana::Controller::TasksController::progress,      { auth => 1 } ],
    [ 'PATCH',  qr{^/api/tasks/([^/]+)/complete$},     \&Wahana::Controller::TasksController::complete,      { auth => 1 } ],
    [ 'GET',    qr{^/api/scans$},                      \&Wahana::Controller::ScansController::list,          { auth => 1 } ],
    [ 'POST',   qr{^/api/scans$},                      \&Wahana::Controller::ScansController::create,        { auth => 1 } ],
    [ 'GET',    qr{^/api/scans/stats/([^/]+)$},        \&Wahana::Controller::ScansController::stats,         { auth => 1 } ],
    # Paket: resi digenerate SERVER (CUSTOMER/ADMIN); petugas hanya scan & lookup
    [ 'POST',   qr{^(?:/api)?/paket/resi$},            \&Wahana::Controller::PaketController::create_draft,  { auth => 1 } ],
    [ 'GET',    qr{^(?:/api)?/paket$},                 \&Wahana::Controller::PaketController::list,          { auth => 1 } ],
    [ 'PATCH',  qr{^(?:/api)?/paket/([^/]+)$},         \&Wahana::Controller::PaketController::update,        { auth => 1 } ],
    [ 'GET',    qr{^(?:/api)?/paket/([^/]+)$},         \&Wahana::Controller::PaketController::detail,        { auth => 1 } ],
    # Alias 3PL Customer Endpoints (/3pl/Customer & /api/3pl/Customer)
    [ 'POST',   qr{^(?:/api)?/3pl/Customer/resi$},     \&Wahana::Controller::PaketController::create_draft,  { auth => 1 } ],
    [ 'GET',    qr{^(?:/api)?/3pl/Customer$},          \&Wahana::Controller::PaketController::list,          { auth => 1 } ],
    [ 'PATCH',  qr{^(?:/api)?/3pl/Customer/([^/]+)$},  \&Wahana::Controller::PaketController::update,        { auth => 1 } ],
    [ 'POST',   qr{^(?:/api)?/3pl/Customer/([^/]+)$},  \&Wahana::Controller::PaketController::update,        { auth => 1 } ],
    [ 'GET',    qr{^(?:/api)?/3pl/Customer/([^/]+)$},  \&Wahana::Controller::PaketController::detail,        { auth => 1 } ],
    [ 'GET',    qr{^/api/audit-logs$},                 \&Wahana::Controller::AuditController::list,          { auth => 1, admin => 1 } ],
    [ 'GET',    qr{^/api/dev/procedures$},             \&Wahana::Controller::DocsController::get_procedures, { auth => 1, dev => 1 } ],
    [ 'GET',    qr{^/api/dev/queries$},                \&Wahana::Controller::DocsController::list_queries,    { auth => 1, dev => 1 } ],
    [ 'POST',   qr{^/api/dev/queries$},                \&Wahana::Controller::DocsController::create_query,   { auth => 1, dev => 1 } ],
    [ 'PUT',    qr{^/api/dev/queries/([^/]+)$},        \&Wahana::Controller::DocsController::update_query,   { auth => 1, dev => 1 } ],
    [ 'DELETE', qr{^/api/dev/queries/([^/]+)$},        \&Wahana::Controller::DocsController::delete_query,   { auth => 1, dev => 1 } ],
);

# Titik masuk utama semua adapter (dev server HTTP & CGI produksi).
# %req: method, path, params, body(hashref|undef), headers(lowercase keys), ip
sub handle_request {
    my (%req) = @_;

    my $method = uc($req{method} // 'GET');
    my $path   = $req{path} // '/';
    $path =~ s{/+$}{/};

    # Preflight CORS
    if ($method eq 'OPTIONS') {
        return json_response(status => 204, body => '');
    }

    for my $route (@ROUTES) {
        my ($r_method, $r_regex, $handler, $meta) = @$route;
        next unless $method eq $r_method;
        my @captures = $path =~ $r_regex or next;

        # --- Middleware Auth ---
        if ($meta->{auth} || $meta->{admin} || $meta->{dev}) {
            my $payload = Wahana::Auth->authenticate_request(\%req);
            return json_response(
                status => 401,
                data   => { success => \0, message => 'Sesi tidak valid atau sudah kedaluwarsa.' }
            ) unless $payload;

            if ($meta->{admin}) {
                my $role = get_user_role($payload->{uid});
                return json_response(
                    status => 403,
                    data   => { success => \0, message => 'Akses ditolak. Hanya ADMIN.' }
                ) unless defined $role && $role eq 'ADMIN';
            }

            if ($meta->{dev}) {
                my $role = get_user_role($payload->{uid});
                return json_response(
                    status => 403,
                    data   => { success => \0, message => 'Akses ditolak. Hanya DEVELOPER atau ADMIN.' }
                ) unless defined $role && ($role eq 'DEVELOPER' || $role eq 'ADMIN');
            }

            $req{auth_user} = $payload;
        }

        # --- Eksekusi handler ---
        my $data = eval { $handler->(\%req, \@captures) };
        if ($@) {
            warn "[ROUTER] Handler error pada $method $path: $@";
            return json_response(
                status => 500,
                data   => { success => \0, message => 'Terjadi kesalahan internal pada server.' }
            );
        }

        # Raw responses (misal YAML / Swagger UI HTML)
        if (ref $data eq 'HASH' && $data->{_is_raw}) {
            return {
                status  => $data->{status} // 200,
                headers => $data->{headers} // {},
                body    => $data->{body} // '',
            };
        }

        return json_response(data => $data // {});
    }

    return json_response(
        status => 404,
        data   => { success => \0, message => "Endpoint tidak ditemukan: $method $path" }
    );
}

1;
