# PRODUCT REQUIREMENT DOCUMENT (PRD)
## Dijak Express (Scan-RESI) — Platform Manajemen Paket & Pemindaian Resi Barcode Logistik Terintegrasi

* **Versi Dokumen**: v1.2.0
* **Status**: Approved & Fully Implemented
* **Kategori**: Logistik, Operasional Ekspedisi, & Management Resi Paket
* **Platform**: Web SPA (Desktop & Mobile PWA Ready)
* **Teknologi**: Quasar Framework (Vue 3 + Pinia + IndexedDB) + Perl uWSGI Backend + MariaDB 11 + Nginx + Docker

---

## 1. Ringkasan Eksekutif (Executive Summary)

Aplikasi **Dijak Express (Scan-RESI)** adalah platform digital terintegrasi skala enterprise untuk mengotomasi dan meningkatkan efisiensi operasional pengiriman paket logistik. Sistem ini menghubungkan tiga pilar pengguna utama:
1. **Pelanggan (Customer)**: Pendaftaran paket mandiri, pembuatan resi acak server-side 8-karakter unik, serta pencetak label pengiriman standar industri (Barcode Code 128 & QR Code).
2. **Petugas Operasional (Petugas Scan Hub)**: Pemindaian cepat via kamera smartphone/laptop atau scanner fisik, berkapabilitas **Offline Scanning PWA** (antrean IndexedDB), proteksi duplikasi transaksional, serta umpan balik audio visual (*audio beep/buzzer*).
3. **Manajemen (Admin)**: Pemantauan KPI rayon harian, alokasi penugasan task shift, manajemen pengguna & RBAC, pelaporan analitik, dan penelusuran jejak audit (*audit logs*).

---

## 2. Target Pengguna & Manajemen Role (RBAC)

Aplikasi menerapkan sistem *Role-Based Access Control* (RBAC) dua lapis: Client Guard (Vue Router) dan Server Guard (Perl API Middleware).

| Role | Deskripsi & Tanggung Jawab | Akses Utama |
| :--- | :--- | :--- |
| **`ADMIN`** | Administrator sistem pusat. Mengelola data pengguna, alokasi task/shift, memantau audit log, dan laporan performa harian. | `/admin/*` (Dashboard, Monitoring, Petugas, Users, Tasks, Reports, Audit Logs) |
| **`PETUGAS_SCAN`** | Petugas lapangan hub/rayon logistik. Bertanggung jawab memindai paket *Inbound/Outbound* secara online maupun offline. | `/petugas/*` (Dashboard, Tasks, Scan Kamera, Hasil Scan) |
| **`CUSTOMER`** | Pengirim / Pelanggan. Menginput paket baru, mencetak label resi 10x15cm, dan memantau status riwayat paket. | `/customer/*` (Dashboard, Buat Paket, Riwayat Paket & Print Label) |

---

## 3. Kredensial Pengujian & Quick Login Environment

Sistem menyediakan akun master bawaan untuk inisialisasi awal (*bootstrap master account*):

| Role | Nama | Username | Password Default | Keterangan |
| :--- | :--- | :--- | :--- | :--- |
| **`ADMIN`** | Admin System | `admin` | `admin123` | Master Superadmin untuk mengelola master data sistem |

> **Dynamic Account Management**: Pengguna dengan peran `PETUGAS_SCAN` dan `CUSTOMER` dibuat secara dinamis melalui fitur **User Management** oleh Admin atau registrasi mandiri Customer.

---

## 4. Kebutuhan Fungsional (Functional Requirements)

### 4.1 Modul Autentikasi & Verifikasi Gmail OTP (FR-1)
* **FR-1.1 - Login Credentials**: Autentikasi standar menggunakan `username` dan `password` terenkripsi SHA-256 salted hash.
* **FR-1.2 - Gmail OTP Verification**: Pengiriman kode OTP 6-digit dengan batas waktu 5 menit melalui SMTP Gmail (`Wahana::Mail`) untuk verifikasi akun & reset password.
* **FR-1.3 - Quick Login Simulator**: Tombol 1-Click Quick Login pada lingkungan pengujian untuk simulasi pergantian antar role (`ADMIN`, `PETUGAS_SCAN`, `CUSTOMER`).
* **FR-1.4 - Session Management**: Token autentikasi berbasis HMAC-SHA256 berbatas waktu 24 jam dengan tracking status pengguna (`ONLINE`/`OFFLINE`).

### 4.2 Modul Customer Portal & Printing (FR-2)
* **FR-2.1 - Form Pendaftaran Paket**: Input terstruktur mencakup barang (nama, berat, layanan), detail pengirim (nama, WhatsApp, alamat lengkap), dan detail penerima.
* **FR-2.2 - Generator Nomor Resi Server-Side**: Menghasilkan nomor resi acak 8-karakter alfanumerik unik tanpa ambigu (misal: `GJXL8FLB`, `D99X5MV2`).
* **FR-2.3 - Label Resi Standard Logistik (10x15cm)**:
  * Visual Barcode Code 128 & QR Code resi.
  * Parsing otomatis rute asal-tujuan, kode pos, dan format thermal print dialog.
* **FR-2.4 - Riwayat & Pelacakan Resi**: Menampilkan daftar paket pelanggan dengan indikator status (`DRAFT`, `TERDAFTAR`, `DIPROSES`).

### 4.3 Modul Pemindaian Barcode & Offline Sync PWA (FR-3)
* **FR-3.1 - Inisialisasi Shift Scan**: Petugas memilih task aktif sebelum memulai sesi scan.
* **FR-3.2 - Live Camera Scanner & Torch**: Pemindaian kamera realtime (HTML5 Barcode Reader) dengan kontrol ganti kamera (Depan/Belakang) dan Senter (*Flash/Torch*).
* **FR-3.3 - Offline PWA Scanning Engine**:
  * Ketika jaringan terputus (`OFFLINE`), hasil scan disimpan ke database lokal browser (**IndexedDB** tabel `pending_scans`).
  * Saat jaringan kembali terhubung (`ONLINE`), sistem secara otomatis menyinkronkan antrean scan ke database MariaDB server.
* **FR-3.4 - Validasi Transaksional & Anti-Duplikasi**:
  * Memastikan resi terdaftar di MariaDB.
  * Mencegah duplikasi pemindaian pada task yang sama (`DUPLICATE`).
* **FR-3.5 - Audio-Visual Feedback**: Sound Effect nada tinggi untuk `SUCCESS` dan buzzer nada ganda untuk `DUPLICATE`/Error, disertai animasi border hijau/merah.

### 4.4 Modul Admin & Analitik Operasional (FR-4)
* **FR-4.1 - Monitoring Dashboard**: Visualisasi ringkasan paket terdaftar, total scan sukses, scan duplikat, dan ketercapaian kuota shift.
* **FR-4.2 - User Management**: Fitur CRUD user, riset status (`ONLINE`/`OFFLINE`/`DISABLED`), dan proteksi password.
* **FR-4.3 - Task & Shift Allocation**: Pembuatan tugas harian petugas berdasar tanggal, shift (Pagi/Sore), target kuota scan, dan lokasi hub.
* **FR-4.4 - Audit Logs**: Pencatatan otomatis aktivitas sensitif sistem (Login, Scan, Tambah Resi, Edit User) mencakup User ID, jenis aksi, IP Address, dan timestamp.

### 4.5 Modul API Security & Routing Engine (FR-5)
* **FR-5.1 - Rate Limiting Protection**: Middleware `Wahana::RateLimit` membatasi request berlebihan (max 100 req/menit per IP) untuk mencegah DoS/Brute-force.
* **FR-5.2 - SQL Query Catalog**: Seluruh query SQL dipisahkan secara aman ke file catalog `database/query.sql` dan dieksekusi via `Wahana::Query` dengan prepared statement (`?`).
* **FR-5.3 - Active OpenAPI DCAF Router**: Routing backend dikendalikan secara dinamis oleh `backend/etc/api/scanresi.yaml` dengan pola DCAF SWB (`operationId: <method>/<Controller>`) dan fitur hot-reloading file mtime.

---

## 5. Kebutuhan Non-Fungsional (Non-Functional Requirements)

* **NFR-1 Latensi & Throughput API**: Respon API pemindaian scan < 150 ms pada kondisi normal.
* **NFR-2 High Availability & Offline Resiliency**: Aplikasi PWA tetap berfungsi memindai resi meskipun koneksi internet terputus total.
* **NFR-3 Keamanan Data & Transaksi**: Hash password SHA-256 salted, token HMAC-SHA256, dan transaksi `FOR UPDATE` MariaDB untuk integritas data scan.
* **NFR-4 Kompatibilitas Browser & Mobile**: Support Chrome, Safari, Edge, Android PWA, dan iOS WebRTC Kamera.
* **NFR-5 Containerized Deployment**: Siap dideploy menggunakan Docker Compose (Container Nginx, Perl uWSGI, MariaDB).

---

## 6. Arsitektur Sistem & Flow Data

```text
+-----------------------------------------------------------------------------------+
|                                   CLIENT LAYER                                    |
|                                                                                   |
|  +-----------------------+   +-----------------------+   +---------------------+  |
|  |    Customer Portal    |   |   Petugas Scanner     |   |    Admin Portal     |  |
|  | (Form Paket & Label)  |   | (PWA + Camera Scanner)|   | (Monitoring & Users)|  |
|  +-----------+-----------+   +-----------+-----------+   +----------+----------+  |
|              |                           |                          |             |
|              |               +-----------v-----------+              |             |
|              |               |  IndexedDB Local Queue|              |             |
|              |               |  (Offline Fallback)   |              |             |
|              |               +-----------+-----------+              |             |
|              +---------------------------+--------------------------+             |
|                                          | (HTTPS / JSON REST API)                |
+------------------------------------------v----------------------------------------+
|                                WEB GATEWAY (Nginx)                                |
|   - Reverse Proxy: /api/* -> Backend uWSGI                                        |
|   - Static SPA Serving: Quasar PWA (/dist/spa)                                    |
+------------------------------------------+----------------------------------------+
|                                          |                                        |
+------------------------------------------v----------------------------------------+
|                             PERL BACKEND ENGINE (uWSGI)                           |
|   - OpenAPI DCAF Router (scanresi.yaml) | Rate Limiter Middleware                     |
|   - Wahana Modules: Auth, Mail (Gmail OTP), Query Catalog, Controllers            |
+------------------------------------------+----------------------------------------+
|                                          | (DBI / SQL Prepared Statements)        |
+------------------------------------------v----------------------------------------+
|                             DATABASE LAYER (MariaDB 11)                           |
|   - Tabel: users, tasks, paket, scan_events, audit_logs                           |
+-----------------------------------------------------------------------------------+
```

---

## 7. Skema Basis Data (Database Schema)

### 7.1 Tabel `users`
```sql
CREATE TABLE users (
    id            VARCHAR(32)  NOT NULL,
    name          VARCHAR(100) NOT NULL,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('ADMIN','PETUGAS_SCAN','CUSTOMER') NOT NULL,
    status        ENUM('ONLINE','OFFLINE','DISABLED') NOT NULL DEFAULT 'OFFLINE',
    last_login    DATETIME     NULL,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);
```

### 7.2 Tabel `tasks`
```sql
CREATE TABLE tasks (
    task_id    VARCHAR(32)  NOT NULL,
    user_id    VARCHAR(32)  NOT NULL,
    shift      ENUM('Pagi','Sore') NOT NULL DEFAULT 'Pagi',
    tanggal    DATE         NOT NULL,
    target     INT          NOT NULL DEFAULT 100,
    progress   INT          NOT NULL DEFAULT 0,
    status     ENUM('DRAFT','PROSES_SCAN','SELESAI') NOT NULL DEFAULT 'DRAFT',
    lokasi     VARCHAR(100) NOT NULL DEFAULT 'CIPUTAT',
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (task_id),
    CONSTRAINT fk_tasks_user FOREIGN KEY (user_id) REFERENCES users (id)
);
```

### 7.3 Tabel `paket`
```sql
CREATE TABLE paket (
    nomor_resi       VARCHAR(16)   NOT NULL,
    nama_barang      VARCHAR(150)  NULL,
    pengirim         VARCHAR(100)  NULL,
    alamat_pengirim  VARCHAR(255)  NULL,
    pengirim_detail  TEXT          NULL,
    telepon_pengirim VARCHAR(30)   NULL,
    penerima         VARCHAR(100)  NULL,
    alamat_tujuan    VARCHAR(255)  NULL,
    penerima_detail  TEXT          NULL,
    telepon_penerima VARCHAR(30)   NULL,
    berat_kg         DECIMAL(6,2)  NOT NULL DEFAULT 0,
    jenis_layanan    ENUM('REGULER','EXPRESS','SAME_DAY') NOT NULL DEFAULT 'REGULER',
    status           ENUM('DRAFT','TERDAFTAR') NOT NULL DEFAULT 'DRAFT',
    created_by       VARCHAR(32)   NULL,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (nomor_resi),
    CONSTRAINT fk_paket_user FOREIGN KEY (created_by) REFERENCES users (id)
);
```

### 7.4 Tabel `scan_events`
```sql
CREATE TABLE scan_events (
    scan_id     VARCHAR(32)  NOT NULL,
    nomor_resi  VARCHAR(64)  NOT NULL,
    user_id     VARCHAR(32)  NOT NULL,
    task_id     VARCHAR(32)  NOT NULL,
    waktu_scan  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    lokasi      VARCHAR(100) NOT NULL DEFAULT 'CIPUTAT',
    status_scan ENUM('SUCCESS','DUPLICATE') NOT NULL DEFAULT 'SUCCESS',
    device_id   VARCHAR(50)  NOT NULL DEFAULT 'SCAN-DEVICE-01',
    jenis_scan  ENUM('INBOUND','OUTBOUND') NOT NULL DEFAULT 'INBOUND',
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (scan_id),
    CONSTRAINT fk_scans_user FOREIGN KEY (user_id) REFERENCES users (id),
    CONSTRAINT fk_scans_task FOREIGN KEY (task_id) REFERENCES tasks (task_id),
    CONSTRAINT fk_scans_resi FOREIGN KEY (nomor_resi) REFERENCES paket (nomor_resi)
);
```

### 7.5 Tabel `audit_logs`
```sql
CREATE TABLE audit_logs (
    log_id     BIGINT       NOT NULL AUTO_INCREMENT,
    user_id    VARCHAR(32)  NULL,
    action     VARCHAR(100) NOT NULL,
    details    TEXT         NULL,
    ip_address VARCHAR(45)  NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users (id)
);
```

---

## 8. Kontrak Spesifikasi REST API

Seluruh request dan response API menggunakan JSON. Endpoint terproteksi memerlukan `Authorization: Bearer <token>`.

| Method | Endpoint | Role Guard | Fungsi |
| :--- | :--- | :--- | :--- |
| **GET** | `/api/docs` | Public | Interactive Swagger UI Documentation |
| **GET** | `/api/openapi.yaml` | Public | OpenAPI 3.0 YAML Specification |
| **POST** | `/api/auth/login` | Public | Login standar username & password |
| **POST** | `/api/auth/quick-login` | Public (Demo) | 1-Click login cepat simulasi per role |
| **POST** | `/api/auth/otp/send` | Public | Mengirimkan kode OTP verifikasi ke Gmail |
| **POST** | `/api/auth/otp/verify` | Public | Verifikasi kode 6-digit OTP |
| **POST** | `/api/auth/logout` | Authenticated | Mengakhiri sesi pengguna |
| **GET** | `/api/users` | Authenticated | Mendapatkan daftar seluruh pengguna |
| **POST** | `/api/users` | `ADMIN` | Membuat pengguna baru |
| **PUT** | `/api/users/:id` | `ADMIN` | Update data pengguna |
| **DELETE** | `/api/users/:id` | `ADMIN` | Hapus akun pengguna |
| **GET** | `/api/tasks` | Authenticated | Mendapatkan daftar task & shift |
| **POST** | `/api/tasks` | `ADMIN` | Alokasi task shift baru |
| **PATCH**| `/api/tasks/:id/complete` | Authenticated | Selesaikan task shift |
| **POST** | `/api/paket/resi` | `CUSTOMER`, `ADMIN` | Generate resi acak & simpan paket |
| **GET** | `/api/paket` | Authenticated | Ambil daftar paket |
| **GET** | `/api/paket/:resi` | Authenticated | Ambil detail satu resi paket |
| **POST** | `/api/scans` | `PETUGAS_SCAN`, `ADMIN` | Eksekusi scan resi (Validasi & Duplikasi) |
| **GET** | `/api/scans/stats/:user_id` | Authenticated | Rekapitulasi performa scan petugas |
| **GET** | `/api/audit-logs` | `ADMIN` | Ambil data jejak audit aktivitas sistem |

---

## 9. Penjaminan Kualitas (QA) & Pengujian Otomatis

Sistem dilengkapi skrip pengujian **E2E QA Full Matrix** (`tests/e2e_full_qa_matrix.py`) yang menguji seluruh skenario fungsionalitas, keamanan, dan fitur offline:
- Verification of 18 QA Matrix Test Cases.
- Generation of Interactive HTML Report (`tests/laporan_qa.html`) & PDF Report (`LAPORAN_QA_DAN_PENGUJIAN_SYSTEM_DIJAK_EXPRESS.pdf`).
- 100% Pass Rate pada pengujian Online & Offline Mode.

---

## 10. Panduan Deployment Singkat

```bash
# Menjalankan seluruh sistem via Docker Compose (Port 8080)
./docker-up.sh

# Menghentikan container
./docker-down.sh
```

Dokumen ini menjadi acuan utama pengembangan dan pemeliharaan platform **Dijak Express v1.2.0**.
