# Dijak Express — Aplikasi Scan Paket Logistik Berbasis Barcode

Implementasi full-stack sesuai **PRD v1.0.0**: frontend Quasar (Vue 3 + Pinia) dan backend REST Perl + MariaDB, disajikan lewat Nginx.

```text
Browser → Nginx ─┬─ /        → Static SPA (dist/spa)
                 └─ /api/    → Perl Backend (server.pl / CGI)  →  MariaDB
```

## Struktur Project

```
src/                    Frontend Quasar SPA
  services/             Service layer (dual-mode: local dummy ↔ HTTP API)
    api.js              → Axios instance + token interceptor
    auth.service.js     → Login, quick-login, users
    task.service.js     → Task/batch
    scan.service.js     → Scan event (validasi duplikat)
    audit.service.js    → Audit log
  stores/               Pinia: authStore, taskStore, scanStore, auditStore
  router/routes.js      Route per role + guard
backend/
  server.pl             Dev HTTP server (port 8080, modul core Perl saja)
  cgi-bin/api.cgi       Adapter CGI untuk produksi (fcgiwrap)
  lib/Wahana/           Config, Db, Auth, Router, Controller/*
  db/schema.sql         Skema MariaDB sesuai ERD PRD + seed akun demo
  start-db.sh / stop-db.sh   Helper MariaDB via Docker (port 3307)
deploy/nginx.conf       Konfigurasi Nginx (static + reverse proxy /api)
```

## Cara Menjalankan (Mode Full-Stack)

### 1. Database

Jika MariaDB native dapat diakses:

```bash
mysql -u root -p < backend/db/schema.sql
```

Jika tidak, gunakan Docker (port 3307, data persisten di volume):

```bash
./backend/start-db.sh
```

### 2. Backend API (port 8080)

```bash
# Jika pakai start-db.sh (Docker port 3307):
export WAHANA_DB_DSN='DBI:mysql:database=wahana_scan;host=127.0.0.1;port=3307'
export WAHANA_DB_USER='wahana_app'
export WAHANA_DB_PASS='wahana_pass'

perl backend/server.pl
```

### 3. Frontend

`.env` diset `VITE_API_BASE_URL=` (kosong) sehingga semua request API **same-origin** `/api/...` dan diproxy ke backend:

- **Laptop (localhost):**
  ```bash
  npx quasar dev          # http://localhost:9000 — kamera aktif
  ```
- **Device lain (HP via WiFi):**
  ```bash
  npm run dev:lan         # = WAHANA_DEV_HTTPS=1 quasar dev (HTTPS + bind 0.0.0.0)
  ```
  Buka dari HP: `https://<IP-laptop>:9000` contoh `https://192.168.3.189:9000`
  → terima peringatan sertifikat self-signed (*Advanced → Proceed*).
  Kamera HP otomatis dipakai karena halaman HTTPS (syarat `getUserMedia`).

- **Produksi:** `npx quasar build` lalu sajikan `dist/spa` lewat Nginx (bagian 4) yang sudah memproxy `/api`.

> Catatan: server statis polos (mis. `python3 -m http.server`) tidak lagi memadai
> untuk mode API karena tidak memiliki proxy `/api`.

### 4. Produksi via Nginx (opsional)

```bash
sudo cp deploy/nginx.conf /etc/nginx/sites-available/wahana
sudo ln -s /etc/nginx/sites-available/wahana /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Akun Bawaan (Admin Master)

| User | Username | Password | Role |
|------|----------|----------|------|
| Admin System | `admin` | `admin123` | ADMIN |

Akun peran lain (`PETUGAS_SCAN`, `CUSTOMER`) dibuat secara dinamis melalui antarmuka **User Management** oleh Admin atau registrasi Customer.

## Kontrak API (dikonsumsi src/services)

| Method | Endpoint | Keterangan |
|--------|----------|------------|
| POST | `/api/auth/login` | Login form → `{ success, user, token }` |
| POST | `/api/auth/quick-login` | Demo FR-1.2 → `{ success, user, token }` |
| POST | `/api/auth/logout` | Tutup sesi |
| GET/POST | `/api/users` | List / create user (create = ADMIN) |
| PUT | `/api/users/:id` | Update nama, username, password, role (ADMIN) |
| DELETE | `/api/users/:id` | Hapus user tanpa riwayat transaksi (ADMIN) |
| PATCH | `/api/users/:id/status` | Toggle ENABLED/DISABLED (ADMIN) |
| GET/POST | `/api/tasks` | List (+filter `user_id`,`status`) / create |
| PATCH | `/api/tasks/:id/progress` | Increment progress |
| PATCH | `/api/tasks/:id/complete` | Selesaikan & kunci task |
| GET | `/api/scans` | List scan event (+filter) |
| POST | `/api/scans` | Scan barcode; duplikat + increment progress transaksional di server |
| GET | `/api/scans/stats/:user_id` | Statistik per petugas |
| GET | `/api/audit-logs` | Jejak aktivitas (ADMIN) |

Semua endpoint bisnis merespons HTTP 200 dengan flag `success`; kegagalan auth = 401, akses lintas role = 403.

## Keamanan

- Password di-hash `sha256$<salt>$<hex>` (`Digest::SHA`, modul core).
- Token HMAC-SHA256 berbatas waktu 24 jam (`Authorization: Bearer`), secret via env `WAHANA_TOKEN_SECRET`.
- Role guard server-side: user management & audit log hanya ADMIN.
- Catatan capstone: quick-login adalah fitur demo PRD — hapus route-nya di produksi.
