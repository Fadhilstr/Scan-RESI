# Rencana Arsitektur & Spesifikasi Seluruh Flow Sistem (Dijak Express / Scan-Resi)

Dokumen ini memuat spesifikasi terstruktur untuk **13 Flow Proses Fungsional** yang ada di dalam platform Dijak Express (Wahana Scan Resi Magang), terbagi ke dalam **4 Kategori Utama**, lengkap dengan diagram alir Mermaid mandiri dan alur integrasi *End-to-End*.

---

## 1. Integrasi Makro: End-to-End Core Lifecycle

Diagram berikut menggambarkan interaksi lintas peran antara **Customer**, **Petugas Scan**, dan **Admin** beserta siklus hidup paket logistik:

```mermaid
flowchart TD
    %% Global Nodes
    subgraph S1["👤 Aktor: Pelanggan (Customer)"]
        C1["Input Form Paket<br/>(Barang, Pengirim, Penerima)"]
        C2["Dapatkan No. Resi Unik<br/>(Status: TERDAFTAR)"]
        C3["Cetak Label Resi<br/>(Barcode Code 128 / QR)"]
        C4["Tempel Label pada Paket & Serahkan ke Hub"]
    end

    subgraph S2["👷 Aktor: Petugas Scan (Hub Operasional)"]
        P1["Pilih Task Shift Aktif<br/>(Pagi / Sore)"]
        P2["Pindai Barcode via Kamera / Scanner"]
        P3{"Validasi Server"}
        P4["Beep Sukses & +1 Kuota Target"]
        P5["Buzzer Peringatan (Duplikat / Invalid)"]
        P6["Selesaikan Task Shift (Status: SELESAI)"]
    end

    subgraph S3["👔 Aktor: Administrator"]
        A1["Buat Jadwal Task & Target Kuota Petugas"]
        A2["Pantau Real-Time Dashboard Rayon"]
        A3["Audit Log & Rekap Laporan Harian"]
    end

    %% Lifecycle Transitions
    A1 -.->|Tugaskan Shift| P1
    C1 --> C2 --> C3 --> C4
    C4 -->|Paket Fisik di Hub| P2
    P1 --> P2
    P2 --> P3
    P3 -- "Resi Valid & Belum Discan" --> P4
    P3 -- "Sudah Discan / Tak Dikenal" --> P5
    P5 --> P2
    P4 --> P2
    P2 --> P6
    P4 -.->|Update Metrik| A2
    P6 -.->|Rekap Final| A3
```

---

## 2. Kategori 1: Flow Autentikasi & Keamanan (Auth)

### Flow 1.1: Login Kredensial + OTP 2FA (Email)
* **Tujuan**: Memastikan keamanan akun dengan verifikasi dua langkah (Kata Sandi + Token OTP 6-Digit via Email).

```mermaid
flowchart TD
    startNode([● Mulai]) --> inputCred[User Input Username & Password]
    inputCred --> checkCred{Sistem Cek Kredensial di Database}
    
    checkCred -- Salah --> errCred[Kembalikan Error Kredensial Salah]
    errCred --> inputCred
    
    checkCred -- Benar --> checkStatus{Status User Aktif/Enabled?}
    checkStatus -- Disabled --> errDisabled[Tampilkan Alert Akun Dinonaktifkan]
    errDisabled --> inputCred
    
    checkStatus -- Aktif --> genOtp[Generate Kode OTP 6 Digit & Token Preauth]
    genOtp --> sendEmail[Kirim Kode OTP ke Email User]
    sendEmail --> inputOtp[User Memasukkan 6 Digit OTP]
    
    inputOtp --> verifyOtp{Validasi Kode OTP & Waktu Berlaku}
    verifyOtp -- Salah / Expired --> alertOtp[Tampilkan Pesan OTP Tidak Valid]
    alertOtp --> inputOtp
    
    verifyOtp -- Benar --> grantAccess[Terbitkan JWT Bearer Token]
    grantAccess --> updateStatus[Update Status User: ONLINE & Catat Audit Log]
    updateStatus --> redirectDash[Arahkan ke Dashboard sesuai Role]
    redirectDash --> endNode([◉ Selesai])
```

---

### Flow 1.2: Resend OTP (Kirim Ulang Kode OTP)
* **Tujuan**: Memberikan kesempatan kepada user meminta kode baru jika OTP sebelumnya tidak kunjung sampai atau sudah kadaluarsa.

```mermaid
flowchart TD
    A([● Request Resend OTP]) --> B{Cek Token Preauth & Rate Limit}
    B -- Cooldown Belum Lewat --> C[Tampilkan Peringatan Cooldown 60 Detik]
    C --> G([◉ Kembali ke Input OTP])
    
    B -- Valid --> D[Generate Kode OTP Baru & Hash Ulang]
    D --> E[Kirim Email Berisi Kode OTP Baru]
    E --> F[Reset Timer Masa Berlaku 5 Menit]
    F --> G
```

---

### Flow 1.3: Lupa & Reset Password via OTP
* **Tujuan**: Memulihkan akun pengguna yang lupa kata sandi dengan verifikasi kepemilikan email.

```mermaid
flowchart TD
    A([● Halaman Lupa Password]) --> B[User Input Username / Email Terdaftar]
    B --> C{Email Ditemukan & Status Aktif?}
    C -- Tidak --> D[Tampilkan Pesan Akun Tidak Ditemukan]
    D --> B
    
    C -- Ya --> E[Generate OTP Pemulihan Akun & Kirim ke Email]
    E --> F[User Input Kode OTP Pemulihan]
    F --> G{Validasi OTP Benar?}
    G -- Salah --> H[Tampilkan Alert OTP Salah]
    H --> F
    
    G -- Benar --> I[User Input Password Baru & Konfirmasi]
    I --> J{Validasi Kompleksitas Password}
    J -- Tidak Memenuhi --> K[Tampilkan Error Kriteria Password]
    K --> I
    
    J -- Memenuhi --> L[Simpan Hash Password Baru di Database]
    L --> M[Catat Aktivitas di Audit Log]
    M --> N([◉ Kembali ke Form Login])
```

---

### Flow 1.4: Quick Login Simulator (Demo & Testing)
* **Tujuan**: Mengizinkan penguji beralih peran (`ADMIN`, `PETUGAS_SCAN`, `CUSTOMER`) secara instan untuk pengujian fungsional tanpa login berulang.

```mermaid
flowchart TD
    A([● Klik Tombol Quick Role]) --> B[Frontend Kirim User ID ke /api/auth/quick-login]
    B --> C{Server Cek Eksistensi Akun Seed}
    C -- Gagal --> D[Kembalikan Error Akun Demo Tidak Ada]
    C -- Sukses --> E[Generate Token Sesi Langsung Tanpa OTP]
    E --> F[Set State Pinia Store & Role Antarmuka]
    F --> G([◉ Langsung Masuk ke Workspace Role Terpilih])
```

---

### Flow 1.5: Logout & Audit Status
* **Tujuan**: Mengakhiri sesi pengguna secara aman dan memperbarui status kehadiran sistem.

```mermaid
flowchart TD
    A([● Klik Tombol Logout]) --> B[Kirim Request POST /api/auth/logout]
    B --> C[Server Update Kolom status = 'OFFLINE' di DB]
    C --> D[Simpan Record 'LOGOUT' di Tabel audit_logs]
    D --> E[Hapus Token dari LocalStorage / Pinia]
    E --> F[Redirect Browser ke /login]
    F --> G([◉ Selesai])
```

---

## 3. Kategori 2: Flow Pelanggan / Customer Portal

### Flow 2.1: Pembuatan Paket & Auto-Generate Nomor Resi
* **Tujuan**: Pelanggan mendaftarkan pengiriman barang baru secara mandiri.

```mermaid
flowchart TD
    A([● Buka Menu Buat Paket]) --> B[Input Data Barang: Nama, Bobot kg, Layanan]
    B --> C[Input Data Pengirim: Nama, No HP, Alamat Detail]
    C --> D[Input Data Penerima: Nama, No HP, Alamat Tujuan]
    D --> E[Klik Submit / Buat Paket]
    
    E --> F{Validasi Kelengkapan Field}
    F -- Ada Field Kosong --> G[Tampilkan Validasi Form Error]
    G --> B
    
    F -- Valid --> H[Server Generate Nomor Resi Unik 8 Karakter]
    H --> I[Insert Baris Baru ke Tabel paket dengan Status TERDAFTAR]
    I --> J[Catat Event 'CREATE_PAKET' di Audit Logs]
    J --> K[Tampilkan Dialog Sukses & Opsi Cetak Resi]
    K --> L([◉ Selesai])
```

---

### Flow 2.2: Cetak Label Pengiriman Ber-Barcode (Code 128 / QR)
* **Tujuan**: Mencetak label pengiriman standar fisik dengan barcode yang dapat dibaca scanner.

```mermaid
flowchart TD
    A([● Pilih Resi di Riwayat]) --> B[Buka Modal Preview Label Paket]
    B --> C[Render Visual Barcode Code 128 & QR Code Nomor Resi]
    C --> D[Pilih Format Cetak: Standar Kertas A4 / Thermal 100x150]
    D --> E[Trigger window.print Dialog Browser]
    E --> F[Proses Pencetakan Selesai]
    F --> G([◉ Tempelkan Label ke Paket Fisik])
```

---

### Flow 2.3: Riwayat & Status Pelacakan Paket
* **Tujuan**: Pelanggan memantau status seluruh paket yang pernah didaftarkan.

```mermaid
flowchart TD
    A([● Buka Halaman Riwayat Paket]) --> B[Request GET /api/paket?created_by=USER_ID]
    B --> C[Tampilkan Daftar Paket dalam Tabel Dinamis]
    C --> D{User Menggunakan Pencarian / Filter Status}
    D -- Cari Nomor Resi --> E[Filter Tabel Real-Time]
    D -- Klik Detail Resi --> F[Tampilkan Modal Riwayat & Timestamp Scan]
    F --> G([◉ Selesai])
```

---

## 4. Kategori 3: Flow Petugas Operasional (Scan Engine)

### Flow 3.1: Inisialisasi & Pemilihan Tugas Shift
* **Tujuan**: Petugas mengikat sesi kerja harian dengan kuota target sebelum memindai.

```mermaid
flowchart TD
    A([● Buka Menu Tasks]) --> B[Fetch Data Penugasan Aktif Petugas Hari Ini]
    B --> C{Apakah Ada Task Berstatus DRAFT / PROSES_SCAN?}
    C -- Tidak Ada --> D[Tampilkan Pesan: Hubungi Admin untuk Alokasi Shift]
    D --> E([◉ Selesai / Menunggu])
    
    C -- Ada --> F[Pilih Task: Menampilkan Shift Pagi/Sore, Lokasi & Target Kuota]
    F --> G[Klik Mulai Sesi Pemindaian]
    G --> H[Update Status Task Menjadi PROSES_SCAN]
    H --> I[Beralih ke Halaman Live Scanner]
    I --> J([◉ Siap Scan])
```

---

### Flow 3.2: Live Barcode Scanning Engine (Validasi Server & Feedback Audio)
* **Tujuan**: Inti operasional pemindaian cepat, validasi anti-duplikasi, dan pencatatan kuota.

```mermaid
flowchart TD
    A([● Petugas Arahkan Kamera ke Barcode Paket]) --> B[HTML5 Barcode Scanner Mendeteksi Kode Resi]
    B --> C[Kirim POST /api/scans dengan nomor_resi, task_id, user_id]
    
    C --> D{Query Database: Apakah Nomor Resi Terdaftar di Tabel paket?}
    D -- Tidak Terdaftar --> E[Tolak: Status UNKNOWN RESI]
    E --> F[Audio Buzzer Nada Rendah + Visual Flash Merah]
    F --> M[Lanjut Scan Paket Berikutnya]
    
    D -- Terdaftar --> G{Cek Tabel scan_events: Sudah Pernah Discan di Task Ini?}
    G -- Sudah Pernah --> H[Catat scan_id Baru dengan Status DUPLICATE]
    H --> I[Tolak Penambahan Kuota + Audio Buzzer Peringatan]
    I --> M
    
    G -- Belum Pernah --> J[Transaksi DB: Insert scan_event SUCCESS & +1 Progress Task]
    J --> K[Audio Beep Nada Tinggi + Visual Flash Hijau]
    K --> L[Update Progress Bar Target Shift di Layar]
    L --> M
    M --> A
```

---

### Flow 3.3: Penyelesaian Shift (Complete Task)
* **Tujuan**: Mengakhiri shift dan mengunci hasil pemindaian agar tidak terjadi modifikasi kuota lanjutan.

```mermaid
flowchart TD
    A([● Petugas Buka Halaman Hasil Scan]) --> B[Tinjau Rekapitulasi: Total Sukses vs Duplikat]
    B --> C[Klik Tombol Selesaikan Task]
    C --> D[Konfirmasi Dialog Penyelesaian]
    D --> E[Kirim PATCH /api/tasks/:id/complete]
    E --> F[Server Set status = 'SELESAI' & Kunci Transaksi Scan]
    F --> G[Catat Selesai Shift di Audit Log]
    G --> H[Tampilkan Rangkuman Akhir Pencapaian Kuota]
    H --> I([◉ Shift Berakhir])
```

---

## 5. Kategori 4: Flow Administrator (Supervisi & Master Data)

### Flow 4.1: Rayon Real-Time Monitoring Dashboard
* **Tujuan**: Memantau kesehatan operasional rayon secara makro dan performa petugas secara langsung.

```mermaid
flowchart TD
    A([● Admin Masuk ke Dashboard]) --> B[Request Ringkasan Metrik Operasional]
    B --> C[Tampilkan Kartu KPI: Total Paket, Total Scan, Duplikat, % Kuota]
    C --> D[Tampilkan Grafik Tren Scan Per Jam / Shift]
    D --> E[Tampilkan Tabel Aktivitas Terkini Semua Petugas]
    E --> F([◉ Monitoring Berjalan])
```

---

### Flow 4.2: Manajemen Pengguna (User Management RBAC)
* **Tujuan**: Mengatur hak akses, membuat pengguna baru, dan mengaktifkan/menonaktifkan akun.

```mermaid
flowchart TD
    A([● Buka Halaman User Management]) --> B[Load Tabel Pengguna & Role]
    B --> C{Pilih Tindakan}
    
    C -- Tambah Pengguna Baru --> D[Form Input Nama, Username, Password, Role]
    D --> E[Server Hash Password sha256$salt$hash & Insert User Baru]
    E --> J[Refresh Tabel & Catat Audit Log]
    
    C -- Toggle Status --> F[Klik Status Switch: ENABLED / DISABLED]
    F --> G[Kirim PATCH /api/users/:id/status]
    G --> J
    
    C -- Edit / Hapus --> H[Update Informasi User atau Soft Delete]
    H --> J
    
    J --> K([◉ Selesai])
```

---

### Flow 4.3: Alokasi & Manajemen Task Shift Petugas
* **Tujuan**: Membagi beban target kuota scan harian kepada petugas operasional.

```mermaid
flowchart TD
    A([● Buka Halaman Task Management]) --> B[Klik Buat Task Baru]
    B --> C[Pilih Petugas Scan dari Dropdown User Aktif]
    C --> D[Tentukan Tanggal, Shift Pagi/Sore, Lokasi Hub, dan Target Kuota]
    D --> E[Submit Form POST /api/tasks]
    E --> F[Simpan Task Baru berstatus DRAFT di Database]
    F --> G[Task Otomatis Muncul di Akun Petugas Terkait]
    G --> H([◉ Selesai])
```

---

### Flow 4.4: Rekapitulasi Laporan & Ekspor Analitik
* **Tujuan**: Mengkaji data historis pengiriman dan kinerja petugas dalam periode tertentu.

```mermaid
flowchart TD
    A([● Buka Halaman Reports]) --> B[Pilih Rentang Tanggal Mulai & Akhir]
    B --> C[Pilih Filter Tambahan: Shift, Petugas Tertentu, Status Scan]
    C --> D[Klik Tampilkan Data]
    D --> E[Server Agregasi Data Scan & Performa Task]
    E --> F[Tampilkan Tabel Rekap & Metrik Rasio Keberhasilan]
    F --> G[Klik Ekspor CSV / Excel / PDF]
    G --> H[Browser Mengunduh File Laporan]
    H --> I([◉ Selesai])
```

---

### Flow 4.5: Audit Trail & Jejak Aktivitas (Audit Logs)
* **Tujuan**: Merekam dan menginspeksi segala aktivitas penting di sistem untuk kepatuhan dan pelacakan insiden.

```mermaid
flowchart TD
    A([● Sistem Mendeteksi Aksi Kritis]) --> B[Interceptor Logging Menangkap: user_id, action, details, ip_address]
    B --> C[Insert Record Baru ke Tabel audit_logs Tanpa Mengganggu Transaksi Utama]
    
    subgraph AdminViewer["Inspeksi Admin"]
        D([● Admin Buka Menu Audit Logs]) --> E[Request GET /api/audit-logs]
        E --> F[Tampilkan Riwayat Kronologis Lengkap]
        F --> G[Filter Berdasarkan Aktor, Kata Kunci Aksi, atau Tanggal]
    end
    
    C -.->|Tersimpan di DB| E
```

---

## 6. Rangkuman Pemetaan Modul & Kode Sumber

| No | Nama Flow | Komponen Frontend | Endpoint Backend | Tabel DB Terkait |
| :--- | :--- | :--- | :--- | :--- |
| **1.1** | Login Kredensial + OTP | `LoginPage.vue` | `POST /api/auth/login`<br/>`POST /api/auth/verify-otp` | `users`, `audit_logs` |
| **1.2** | Resend OTP | `LoginPage.vue` | `POST /api/auth/resend-otp` | `users` |
| **1.3** | Reset Password OTP | `LoginPage.vue` | `POST /api/auth/forgot-password`<br/>`POST /api/auth/reset-password` | `users`, `audit_logs` |
| **1.4** | Quick Login Demo | `LoginPage.vue` | `POST /api/auth/quick-login` | `users` |
| **1.5** | Logout Presensi | `MainLayout.vue` | `POST /api/auth/logout` | `users`, `audit_logs` |
| **2.1** | Buat Paket & Resi | `CustomerBuatPaketPage.vue` | `POST /api/paket/resi` | `paket`, `audit_logs` |
| **2.2** | Cetak Label Resi | `CustomerPaketPage.vue` | - | `paket` |
| **2.3** | Riwayat Paket Customer | `CustomerPaketPage.vue` | `GET /api/paket` | `paket` |
| **3.1** | Inisialisasi Shift | `PetugasTasksPage.vue` | `GET /api/tasks` | `tasks` |
| **3.2** | Live Scan Engine | `PetugasScanPage.vue` | `POST /api/scans` | `scan_events`, `tasks`, `paket` |
| **3.3** | Selesai Shift | `PetugasHasilPage.vue` | `PATCH /api/tasks/:id/complete` | `tasks`, `audit_logs` |
| **4.1** | Monitoring Rayon | `AdminDashboard.vue` | `GET /api/scans`, `GET /api/tasks` | `scan_events`, `tasks` |
| **4.2** | User Management | `AdminUserManagementPage.vue` | `GET/POST/PUT/DELETE /api/users` | `users`, `audit_logs` |
| **4.3** | Alokasi Task Shift | `AdminTasksPage.vue` | `POST /api/tasks` | `tasks`, `users` |
| **4.4** | Rekap Laporan | `AdminReportsPage.vue` | `GET /api/scans/stats/:user_id` | `scan_events`, `tasks` |
| **4.5** | Audit Logs | `AdminAuditLogsPage.vue` | `GET /api/audit-logs` | `audit_logs` |
