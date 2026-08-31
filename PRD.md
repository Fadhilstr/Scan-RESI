# PRODUCT REQUIREMENT DOCUMENT (PRD)
## Dijak Express / Wahana Express — Platform Manajemen Paket & Pemindaian Resi Barcode Logistik

* **Versi Dokumen**: v1.1.0
* **Status**: Approved & Implemented
* **Kategori**: Logistik & Operasional Ekspedisi
* **Platform**: Web SPA (Desktop & Mobile PWA Ready)
* **Teknologi**: Quasar Framework (Vue 3 + Pinia) + Perl REST API + MariaDB + Nginx

---

## 1. Ringkasan Eksekutif (Executive Summary)

Aplikasi **Dijak Express (Scan Resi Logistik)** adalah platform digital terintegrasi untuk mempercepat dan mengotomasi proses operasional logistik pengiriman paket. Sistem ini menghubungkan tiga pilar utama:
1. **Pelanggan (Customer)**: Membuat draft resi secara mandiri, melengkapi data pengirim & penerima, serta mencetak label pengiriman ber-barcode standar (Code 128 / QR Code).
2. **Petugas Operasional (Petugas Scan)**: Melakukan pemindaian barcode resi paket secara cepat dan akurat menggunakan kamera perangkat (smartphone/laptop) atau scanner barcode fisik, didukung validasi anti-duplikasi serta umpan balik suara (*audio beep*).
3. **Manajemen (Admin)**: Memantau ketercapaian target shift harian, mengelola penugasan tugas scan (*task/batch allocation*), mengelola data pengguna, melihat laporan performa, dan mengaudit jejak aktivitas (*audit logs*).

---

## 2. Target Pengguna & Manajemen Role (RBAC)

Aplikasi menerapkan sistem *Role-Based Access Control* (RBAC) ketat pada tingkat antarmuka (Vue Router Guard) dan tingkat server (Perl API Middleware).

| Role | Deskripsi & Tanggung Jawab | Akses Utama |
| :--- | :--- | :--- |
| **`ADMIN`** | Administrator sistem pusat. Mengelola data master pengguna, penugasan target task harian, memantau seluruh aktivitas rayon, rekap laporan, dan audit logs. | `/admin/*` (Dashboard, Monitoring, Petugas, Users, Tasks, Reports, Audit Logs) |
| **`PETUGAS_SCAN`** | Petugas lapangan di hub/rayon. Bertanggung jawab memindai paket masuk (*Inbound*) atau keluar (*Outbound*) sesuai target task harian. | `/petugas/*` (Dashboard, Tasks, Scan Kamera, Hasil Scan) |
| **`CUSTOMER`** | Pengirim / Pemilik barang. Membuat pesanan pengiriman baru, mengunduh/mencetak label resi, dan melihat riwayat status paket. | `/customer/*` (Dashboard, Buat Paket, Riwayat & Label Paket) |

---

## 3. Akun Demo & Fitur Quick Login (Testing Environment)

Untuk inisialisasi awal sistem (*bootstrap master account*), sistem menyediakan kredensial bawaan (*default master admin seed*):

| Role | Nama | Username | Password Default | Keterangan |
| :--- | :--- | :--- | :--- | :--- |
| **`ADMIN`** | Admin System | `admin` | `admin123` | Akun Superadmin bawaan untuk mengelola seluruh data master sistem |

> **Catatan Manajemen Pengguna Dinamis**: Akun peran lain (`PETUGAS_SCAN`, `CUSTOMER`) serta data operasional (Tasks, Paket, dan Scan Events) dibuat dan dikelola secara dinamis melalui menu **User Management** oleh Admin atau registrasi mandiri oleh Customer.

---

## 4. Kebutuhan Fungsional (Functional Requirements)

### 4.1 Modul Autentikasi & Pengguna (FR-1)
* **FR-1.1**: Form login standar menggunakan kredensial `username` dan `password`.
* **FR-1.2**: 1-Click Quick Login simulator untuk berpindah peran (*role*) demo secara instan.
* **FR-1.3**: Manajemen status login pengguna (`ONLINE` saat aktif, `OFFLINE` saat logout).
* **FR-1.4**: Token autentikasi berbasis HMAC-SHA256 berbatas waktu 24 jam.
* **FR-1.5**: Role Guards pada sisi client (Vue Router) dan sisi server (Perl API Handler) untuk mencegah eskalasi hak akses (*unauthorized privilege access*).

### 4.2 Modul Customer Portal (FR-2)
* **FR-2.1 - Pembuatan Paket**: Form pendaftaran paket dengan input komprehensif:
  * Informasi Barang: Nama barang, berat (kg), jenis layanan (`REGULER`, `EXPRESS`, `SAME_DAY`).
  * Informasi Pengirim: Nama, Nomor Telepon/WhatsApp, Alamat lengkap (Provinsi, Kota/Kabupaten, Kecamatan, Kode Pos, Detail Jalan).
  * Informasi Penerima: Nama, Nomor Telepon/WhatsApp, Alamat tujuan pengiriman lengkap.
* **FR-2.2 - Nomor Resi Otomatis**: Server men-generate nomor resi acak 8-karakter alfanumerik unik (contoh: `GJXL8FLB`, `WHN555555`) yang diawali huruf alfabet.
* **FR-2.3 - Label Resi Siap Cetak**: Komponen cetak label resi standar ekspedisi logistik:
  * Visual Barcode Code 128 & QR Code nomor resi.
  * Ringkasan rute pengiriman, alamat pengirim & penerima, bobot, dan badge tipe layanan.
  * Mode cetak thermal (layout kompak) dan print dialog browser langsung.
* **FR-2.4 - Daftar Riwayat Paket**: Menampilkan tabel paket yang dibuat pelanggan beserta statusnya (`DRAFT` / `TERDAFTAR`).

### 4.3 Modul Petugas Operasional & Pemindaian Barcode (FR-3)
* **FR-3.1 - Inisialisasi Tugas (Task/Batch)**: Petugas memilih task aktif sebelum memulai sesi pemindaian (mencakup data shift, tanggal, lokasi hub, dan target kuota scan).
* **FR-3.2 - Live Camera Barcode Scanner**:
  * Pemindaian barcode resi langsung melalui kamera browser (HTML5 Barcode Scanner).
  * Dukungan ganti kamera (Depan / Belakang / Kamera Eksternal).
  * Dukungan kontrol Flash / Senter (*Torch control*) pada perangkat yang mendukung.
  * Fitur *Continuous Scan Mode* (scan berkelanjutan tanpa jeda) dan mode *Manual Input* nomor resi jika barcode rusak.
* **FR-3.3 - Validasi Ketat Sisi Server**:
  * Paket harus berstatus `TERDAFTAR` di database agar dapat dipindai.
  * Validasi duplikasi: Jika nomor resi yang sama dipindai lebih dari satu kali dalam task yang sama, sistem mencatat status `DUPLICATE` dan menolak penambahan progres kuota.
  * Resi tidak dikenal / belum terdaftar akan ditolak dengan notifikasi error jelas.
* **FR-3.4 - Audio & Visual Feedback**:
  * Audio Beep Nada Tinggi (Web Audio API) saat scan sukses (`SUCCESS`).
  * Audio Buzzer Nada Ganda Rendah saat terjadi scan duplikat (`DUPLICATE`) atau error.
  * Animasi flash visual pada antarmuka (Border Hijau = Sukses, Border Merah = Gagal/Duplikat).
* **FR-3.5 - Progres Target Real-time**: Indikator *progress bar* dan persentase ketercapaian target scan shift secara langsung yang otomatis bertambah secara transaksional di database.
* **FR-3.6 - Ringkasan Hasil Scan**: Petugas dapat melihat daftar riwayat resi yang berhasil discan pada shift aktif dan menyelesaikan (*complete task*).

### 4.4 Modul Admin Portal (FR-4)
* **FR-4.1 - Rayon Monitoring Dashboard**: Ringkasan metrik statistik operasional (Total Paket Terdaftar, Total Scan Berhasil, Total Duplikat, Persentase Ketercapaian Target).
* **FR-4.2 - Manajemen Pengguna (User Management)**:
  * Melihat daftar semua pengguna dan role-nya.
  * Menambah pengguna baru (Admin, Petugas Scan, Customer).
  * Mengaktifkan atau menonaktifkan akun pengguna (`ENABLED` / `DISABLED`).
* **FR-4.3 - Manajemen Task & Shift (Task Management)**:
  * Membuat alokasi tugas harian baru berdasarkan tanggal, shift (Pagi/Sore), target kuota, dan petugas yang ditugaskan.
  * Memantau progres masing-masing task per petugas.
* **FR-4.4 - Laporan & Analitik (Reports)**:
  * Rekapitulasi scan harian, mingguan, dan bulanan.
  * Filter data berdasarkan rentang tanggal, shift, status scan, dan petugas.
  * Ekspor data rekapitulasi operasional.
* **FR-4.5 - Audit Logs (Jejak Aktivitas)**:
  * Pencatatan otomatis setiap aksi penting di sistem (Login, Pembuatan Resi Paket, Eksekusi Scan, Update Status User, Penyelesaian Task).
  * Menyimpan metadata lengkap: User ID, Jenis Aksi, Rincian Payload/Keterangan, Alamat IP Pengguna, dan Timestamp.

### 4.5 Modul Dokumentasi OpenAPI / Swagger (FR-5)
* **FR-5.1**: Endpoint `/api/openapi.yaml` menyajikan spesifikasi REST API OpenAPI 3.0.3 lengkap.
* **FR-5.2**: Endpoint `/api/docs` menyajikan Swagger UI interaktif untuk pengujian endpoint secara langsung.

---

## 5. Kebutuhan Non-Fungsional (Non-Functional Requirements)

* **NFR-1 Performa & Latensi**: Waktu respon pemrosesan scan pada API < 200 ms untuk menjaga kelancaran alur kerja pemindaian cepat di lapangan (*high-throughput scanning*).
* **NFR-2 Integritas Data & Transaksional**: Operasi insert scan event dan increment progress task dibungkus dalam transaksi database untuk mencegah inkonsistensi data / *race condition*.
* **NFR-3 Keamanan & Kriptografi**:
  * Password disimpan dengan algoritma `sha256$<salt>$<hash>` menggunakan salt acak per pengguna.
  * Token autentikasi menggunakan enkripsi `HMAC-SHA256` dengan rahasia lingkungan (*environment secret*).
  * Sanitasi parameter input query database menggunakan prepared statements (`DBI` placeholders `?`) untuk mencegah SQL Injection.
* **NFR-4 Kompatibilitas Perangkat & Kamera**:
  * Dukungan HTTPS lokal (`npm run dev:lan`) untuk mengaktifkan izin WebRTC / `getUserMedia` saat pengujian menggunakan smartphone via jaringan WiFi lokal.
  * Desain antarmuka responsif (Mobile First untuk Petugas dan Customer, Desktop View untuk Admin).
* **NFR-5 Reliabilitas**: Kemudahan deployment dengan arsitektur container Docker (Nginx, Perl Backend, MariaDB Database).

---

## 6. Arsitektur Sistem & Diagram Alur

```text
+-------------------------------------------------------------------------------+
|                                  CLIENT LAYER                                 |
|                                                                               |
|  +---------------------+   +---------------------+   +---------------------+  |
|  |   Customer Portal   |   |   Petugas Scanner   |   |    Admin Portal     |  |
|  |  (Input & Cetak)    |   |  (Kamera & Beep)    |   | (Monitoring & User) |  |
|  +----------+----------+   +----------+----------+   +----------+----------+  |
|             |                         |                         |             |
|             +-------------------------+-------------------------+             |
|                                       | (HTTPS / JSON REST)                   |
+---------------------------------------v---------------------------------------+
|                              WEB GATEWAY (Nginx)                              |
|   - Port 80 / 443 / 8080                                                      |
|   - Static SPA Routing (Quasar /dist/spa)                                     |
|   - Reverse Proxy: /api/* -> Perl Backend Service                             |
+---------------------------------------+---------------------------------------+
|                                       |                                       |
+---------------------------------------v---------------------------------------+
|                              BACKEND API (Perl)                               |
|   - Server Core: HTTP::Daemon / uWSGI CGI Adapter                             |
|   - Middleware: Auth HMAC-SHA256, RBAC Role Guard, Audit Logger               |
|   - Controllers: Auth, Users, Tasks, Scans, Paket, Audit, Docs                |
+---------------------------------------+---------------------------------------+
|                                       | (DBI / SQL Transactions)              |
+---------------------------------------v---------------------------------------+
|                           DATABASE LAYER (MariaDB 11)                         |
|   - Tabel: users, tasks, paket, scan_events, audit_logs                       |
|   - Relasi Foreign Key & Indexing Integritas Resi                             |
+-------------------------------------------------------------------------------+
```

---

## 7. Skema Basis Data & ERD

### 7.1 Tabel `users`
Menyimpan data akun pengguna dan role sistem.
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
Menyimpan penugasan shift dan kuota target scan petugas.
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
Menyimpan data pendaftaran paket dan nomor resi pengiriman.
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
Menyimpan riwayat pemindaian resi barcode oleh petugas.
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
Menyimpan jejak audit aktivitas pengguna di seluruh sistem.
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

## 8. Spesifikasi Kontrak REST API

Semua request dan response menggunakan format `application/json`. Endpoint terproteksi memerlukan header `Authorization: Bearer <token>`.

| HTTP Method | Path Endpoint | Role Diizinkan | Deskripsi Fungsi |
| :--- | :--- | :--- | :--- |
| **GET** | `/api/docs` | Public | Dokumentasi Interaktif Swagger UI |
| **GET** | `/api/openapi.yaml` | Public | OpenAPI 3.0 Specification YAML File |
| **POST** | `/api/auth/login` | Public | Login akun dengan username dan password |
| **POST** | `/api/auth/quick-login` | Public (Demo) | 1-Click login otomatis dengan `user_id` |
| **POST** | `/api/auth/logout` | Authenticated | Mengakhiri sesi dan mengubah status jadi OFFLINE |
| **GET** | `/api/users` | Authenticated | Mendapatkan daftar pengguna sistem |
| **POST** | `/api/users` | `ADMIN` | Mendaftarkan pengguna baru ke database |
| **PUT** | `/api/users/:id` | `ADMIN` | Memperbarui data pengguna (nama, username, password, role) |
| **DELETE** | `/api/users/:id` | `ADMIN` | Menghapus akun pengguna dari sistem |
| **PATCH** | `/api/users/:id/status` | `ADMIN` | Mengubah status pengguna (ONLINE/OFFLINE/DISABLED) |
| **GET** | `/api/tasks` | Authenticated | Mengambil daftar task (+ filter `user_id`, `status`) |
| **POST** | `/api/tasks` | `ADMIN` | Membuat penugasan task/shift baru |
| **PATCH** | `/api/tasks/:id/progress` | Authenticated | Menambah progress task secara manual |
| **PATCH** | `/api/tasks/:id/complete` | Authenticated | Menyelesaikan dan mengunci status task |
| **POST** | `/api/paket/resi` | `CUSTOMER`, `ADMIN` | Generate nomor resi dan buat draft paket baru |
| **GET** | `/api/paket` | Authenticated | Mengambil daftar data paket |
| **GET** | `/api/paket/:resi` | Authenticated | Mengambil detail spesifik satu paket |
| **PATCH** | `/api/paket/:resi` | Authenticated | Memperbarui informasi data paket |
| **POST** | `/api/scans` | `PETUGAS_SCAN`, `ADMIN` | Memproses pemindaian barcode resi (validasi & progress) |
| **GET** | `/api/scans` | Authenticated | Riwayat log event scan (+ filter `task_id`, `resi`) |
| **GET** | `/api/scans/stats/:user_id` | Authenticated | Rekapitulasi statistik performa scan petugas |
| **GET** | `/api/audit-logs` | `ADMIN` | Mengambil seluruh jejak aktivitas audit sistem |

---

## 9. Panduan Menjalankan & Pengujian

### 9.1 Database MariaDB
```bash
# Jalankan container MariaDB (Port 3307)
./backend/start-db.sh
```

### 9.2 Backend Perl API Server
```bash
export WAHANA_DB_DSN='DBI:mysql:database=wahana_scan;host=127.0.0.1;port=3307'
export WAHANA_DB_USER='wahana_app'
export WAHANA_DB_PASS='wahana_pass'

perl backend/server.pl
```

### 9.3 Frontend Quasar Development
```bash
# Mode Desktop Localhost:
npx quasar dev

# Mode Mobile HP via WiFi (HTTPS Self-Signed):
npm run dev:lan
```
Buka browser HP ke `https://<IP-Laptop>:9000` untuk menguji scan langsung dengan kamera smartphone.

---

## 10. Kesimpulan & Roadmap Pengembangan Selanjutnya

Implementasi platform saat ini telah memenuhi seluruh spesifikasi PRD v1.1.0 untuk kebutuhan *core logistics scanning & parcel handling*. Rencana peningkatan di versi berikutnya meliputi:
1. Dukungan mode pemindaian *Offline PWA* dengan sinkronisasi otomatis menggunakan IndexedDB saat jaringan pulih.
2. Integrasi printer Bluetooth Thermal portabel langsung dari aplikasi mobile (*Web Bluetooth API*).
3. Notifikasi webhook / WhatsApp otomatis kepada penerima saat paket berhasil dipindai di hub tujuan.
