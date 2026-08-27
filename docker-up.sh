#!/bin/bash
# ============================================================
# docker-up.sh — Menjalankan Full Stack Wahana Scan App
# ============================================================

set -e

echo "=========================================================="
echo "  Membangun & Menjalankan Container (DB + BE + FE + NGINX)"
echo "=========================================================="

docker compose up --build -d

echo ""
echo "Menunggu database & backend siap..."
sleep 5

echo ""
echo "=========================================================="
echo "  ✓ Seluruh container berhasil dijalankan!"
echo "  🌐 Nginx Gateway : http://localhost:8080 (Akses Utama)"
echo "  💻 Frontend Dev  : http://localhost:9000 (Quasar Dev Server)"
echo "  ⚙️  Backend API   : http://localhost:5000 (Perl uWSGI)"
echo "  🗄️  Database     : localhost:3307 (MariaDB wahana_scan)"
echo "=========================================================="
echo "  Lihat status : docker compose ps"
echo "  Lihat log    : docker compose logs -f"
echo "  Matikan      : ./docker-down.sh"
echo "=========================================================="
