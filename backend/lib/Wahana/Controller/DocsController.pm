package Wahana::Controller::DocsController;
use strict;
use warnings;
use FindBin;
use JSON::PP qw(encode_json decode_json);
use Wahana::Response qw(cors_headers);
use Wahana::Db;
use Wahana::Query;

sub get_openapi_yaml {
    my ($req) = @_;

    my @candidates = (
        "$FindBin::Bin/etc/api/scanresi.yaml",
        "$FindBin::Bin/../etc/api/scanresi.yaml",
        "/app/etc/api/scanresi.yaml",
        "/Documents/Scan-resi-magang/etc/api/scanresi.yaml"
    );

    my $content = '';
    for my $file (@candidates) {
        if (-f $file) {
            if (open my $fh, '<', $file) {
                local $/;
                $content = <$fh>;
                close $fh;
                last;
            }
        }
    }

    return {
        _is_raw => 1,
        status  => 200,
        headers => {
            'Content-Type' => 'text/yaml; charset=utf-8',
            cors_headers(),
        },
        body => $content || "# OpenAPI spec not found\n",
    };
}

sub get_procedures {
    my ($req) = @_;
    Wahana::Query::refresh_catalog();

    my $registry = Wahana::Query::get_catalog_list();
    my $db_routines = [];
    my $db_online = 0;

    eval {
        my $dbh = Wahana::Db->connect();
        $db_online = 1;
        $db_routines = $dbh->selectall_arrayref(
            "SELECT ROUTINE_NAME AS name, ROUTINE_TYPE AS type, CREATED AS created_at, LAST_ALTERED AS last_altered
               FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = 'wahana_scan' ORDER BY ROUTINE_NAME ASC",
            { Slice => {} }
        );
        1;
    };

    my $active_mode = scalar(@$db_routines) > 0 ? 'STORED_PROCEDURE_ACTIVE' : 'PREPARED_STATEMENT_FALLSAFE';

    return {
        success     => \1,
        mode        => $active_mode,
        db_online   => $db_online ? \1 : \0,
        database    => 'wahana_scan',
        registry    => $registry,
        db_routines => $db_routines,
        total_sp    => scalar(@$db_routines),
    };
}

# GET /api/dev/queries
sub list_queries {
    my ($req) = @_;
    Wahana::Query::refresh_catalog();
    my $list = Wahana::Query::get_catalog_list();
    return {
        success => \1,
        data    => $list,
        total   => scalar(@$list),
    };
}

# POST /api/dev/queries
sub create_query {
    my ($req) = @_;
    my $body = $req->{body} // {};

    my $id       = $body->{query_id}    // '';
    my $code     = $body->{query_code}  // '';
    my $sp       = $body->{sp_name}     // '';
    my $params   = ref $body->{param_keys} ? encode_json($body->{param_keys}) : ($body->{param_keys} // '[]');
    my $type     = $body->{query_type}  // 'SELECT_ROW';
    my $role     = $body->{required_role} // 'PUBLIC';
    my $ttl      = int($body->{cache_ttl} // 0);
    my $timeout  = int($body->{timeout_sec} // 5);
    my $desc     = $body->{deskripsi}   // '';

    return { success => \0, message => 'query_id, query_code, dan sp_name wajib diisi.' }
        unless length $id && length $code && length $sp;

    eval {
        my $dbh = Wahana::Db->connect();
        my $sth = $dbh->prepare("CALL sp_sys_upsert_query(?, ?, ?, ?, ?, ?, ?, ?, ?)");
        $sth->execute($id, $code, $sp, $params, $type, $role, $ttl, $timeout, $desc);
        1;
    } or do {
        return { success => \0, message => "Gagal menyimpan query: $@" };
    };

    Wahana::Query::refresh_catalog();

    return {
        success => \1,
        message => "Query $code ($id) berhasil didaftarkan.",
        query_id => $id,
    };
}

# PUT /api/dev/queries/:id
sub update_query {
    my ($req, $captures) = @_;
    my $id = $captures->[0] or return { success => \0, message => 'Query ID tidak valid.' };
    my $body = $req->{body} // {};

    my $code     = $body->{query_code}  // '';
    my $sp       = $body->{sp_name}     // '';
    my $params   = ref $body->{param_keys} ? encode_json($body->{param_keys}) : ($body->{param_keys} // '[]');
    my $type     = $body->{query_type}  // 'SELECT_ROW';
    my $role     = $body->{required_role} // 'PUBLIC';
    my $ttl      = int($body->{cache_ttl} // 0);
    my $timeout  = int($body->{timeout_sec} // 5);
    my $desc     = $body->{deskripsi}   // '';

    return { success => \0, message => 'query_code dan sp_name wajib diisi.' }
        unless length $code && length $sp;

    eval {
        my $dbh = Wahana::Db->connect();
        my $sth = $dbh->prepare("CALL sp_sys_upsert_query(?, ?, ?, ?, ?, ?, ?, ?, ?)");
        $sth->execute($id, $code, $sp, $params, $type, $role, $ttl, $timeout, $desc);
        1;
    } or do {
        return { success => \0, message => "Gagal memperbarui query: $@" };
    };

    Wahana::Query::refresh_catalog();

    return {
        success => \1,
        message => "Query $code ($id) berhasil diperbarui.",
    };
}

# DELETE /api/dev/queries/:id
sub delete_query {
    my ($req, $captures) = @_;
    my $id = $captures->[0] or return { success => \0, message => 'Query ID tidak valid.' };

    eval {
        my $dbh = Wahana::Db->connect();
        my $sth = $dbh->prepare("CALL sp_sys_delete_query(?)");
        $sth->execute($id);
        1;
    } or do {
        return { success => \0, message => "Gagal menghapus query: $@" };
    };

    Wahana::Query::refresh_catalog();

    return {
        success => \1,
        message => "Query ID $id berhasil dihapus dari sys_queries.",
    };
}

sub get_swagger_ui {
    my ($req) = @_;

    my $html = <<'HTML';
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>Wahana Express - REST API Documentation</title>
  <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
  <link rel="icon" type="image/png" href="https://unpkg.com/swagger-ui-dist@5/favicon-32x32.png" sizes="32x32" />
  <style>
    html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
    *, *:before, *:after { box-sizing: inherit; }
    body { margin:0; background: #fafafa; font-family: sans-serif; }
    .topbar { background-color: #0d233a !important; }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: "/api/openapi.yaml",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIBundle.SwaggerUIStandalonePreset
        ],
        layout: "BaseLayout"
      });
    };
  </script>
</body>
</html>
HTML

    return {
        _is_raw => 1,
        status  => 200,
        headers => {
            'Content-Type' => 'text/html; charset=utf-8',
            cors_headers(),
        },
        body => $html,
    };
}

1;
