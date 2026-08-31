package Wahana::Controller::DocsController;
use strict;
use warnings;
use FindBin;
use Wahana::Response qw(cors_headers);

sub get_openapi_yaml {
    my ($req) = @_;

    # Cari file openapi yaml di beberapa kemungkinan lokasi
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
    require Wahana::Procedure;
    require Wahana::Db;

    my $registry = Wahana::Procedure::list_registry();
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
