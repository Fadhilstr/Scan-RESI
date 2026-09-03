# Panduan Rinci: Arsitektur Query Catalog, Hash Mapping, dan Prepared Statement di Dijak Express

Dokumen ini menjelaskan secara teknis dan komprehensif bagaimana query SQL diatur, dibaca (*parsed*), disimpan ke dalam struktur data **Perl Hash (`%QUERIES`)**, hingga dieksekusi menggunakan *prepared statement* dan diolah sebagai *hash reference* oleh Perl DBI.

---

## 1. Arsitektur Keseluruhan

Sistem backend Dijak Express menggunakan pola **Query Catalog Pattern**. Pola ini memisahkan secara tegas antara logika bisnis (Perl controller) dan logika basis data (SQL).

### Alur Kerja Sistem Langkah demi Langkah (Step-by-Step)

#### 🔹 FASE 1: Inisialisasi & Caching (Saat Server Start / Pertama Kali Diakses)
* **Step 1: Pembacaan File Sumber**  
  Modul `Wahana::Query` mencari dan membuka file katalog `backend/db/query.sql` melalui fungsi `_find_query_file()`.
* **Step 2: Parsing Baris & Regex**  
  File dibaca baris demi baris. Sistem mendeteksi header penanda `-- name: <nama_query>` menggunakan Regex, mengumpulkan baris SQL, serta membersihkan titik koma (`;`) dan spasi.
* **Step 3: Pemetaan ke Perl Hash di RAM**  
  Setiap pasangan nama dan query disimpan ke variabel global `%QUERIES` berbentuk `{ 'nama_query' => 'teks SQL' }`. Flag `$INITIALIZED` diset menjadi `1` agar parsing hanya berjalan **1 kali** selama server hidup.

```
[backend/db/query.sql] ──(Step 1-3)──> [RAM: Perl Hash %QUERIES]
```

#### 🔹 FASE 2: Pemrosesan Request & Eksekusi Query (Runtime)
* **Step 4: Controller Meminta Query**  
  Controller Perl (misalnya `AuthController.pm`) memanggil `Wahana::Query->get('nama_query')`.
* **Step 5: Lookup Instan dari Hash Memori**  
  Fungsi `get` mengambil teks SQL berparameter `?` dari memori `%QUERIES` secara instan dengan kecepatan $O(1)$.
* **Step 6: Prepared Statement & Bind Value**  
  Controller menyerahkan SQL dan parameter pengguna ke DBI via `$dbh->selectrow_hashref($sql, undef, @bind)`. DBI mengikat data secara aman ke placeholder `?`.
* **Step 7: Eksekusi Aman di MariaDB**  
  Database mengeksekusi perintah SQL secara terpisah dari data parameter, menjamin keamanan dari serangan SQL Injection.
* **Step 8: Konversi Hasil ke Hash Reference & Response JSON**  
  Hasil baris database otomatis dibungkus oleh DBI menjadi *Hash Reference* (`$row`), diolah oleh controller, lalu dikirim ke klien/frontend dalam format JSON.

```
Controller ──(Step 4-5)──> %QUERIES ──(Step 6-7)──> MariaDB ──(Step 8)──> JSON Response
```


---

## 2. Bedah File Sumber: `backend/db/query.sql`

File [backend/db/query.sql](file:///Documents/Scan-resi-magang/backend/db/query.sql) adalah satu-satunya tempat seluruh perintah SQL ditulis.

### Aturan Format Penulisan:
1. **Anotasi Nama Query**: Diawali dengan baris komentar `-- name: <nama_unik>`. Nama ini akan menjadi **Key** pada Perl Hash.
2. **Perintah SQL**: Tepat di bawah anotasi `-- name:`, ditulis query SQL lengkap. Query bisa terdiri dari satu baris atau beberapa baris (*multiline*).
3. **Placeholder Parameter (`?`)**: Setiap nilai dinamis wajib memakai tanda tanya (`?`) untuk mendukung *prepared statement*.
4. **Titik Koma (`;`)**: Ditulis di akhir query sebagai penutup standar SQL (akan dibersihkan otomatis saat parsing).

### Contoh dari Baris 32–56 `query.sql`:
```sql
-- name: otp_increment_attempt
UPDATE user_otps SET attempt_count = attempt_count + 1 WHERE id = ?;

-- name: otp_mark_used
UPDATE user_otps SET used = 1 WHERE id = ?;

-- name: auth_update_user_password
UPDATE users SET password_hash = ? WHERE id = ?;

-- name: users_get_role
SELECT role FROM users WHERE id = ?;

-- name: users_list_all
SELECT * FROM users ORDER BY id ASC;

-- name: users_check_username_exists
SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?);

-- name: users_check_username_exists_except_self
SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?) AND id != ?;

-- name: users_check_email_exists
SELECT COUNT(*) FROM users WHERE email IS NOT NULL AND email != '' AND LOWER(email) = LOWER(?);
```

---

## 3. Bedah Mesin Parser: `backend/lib/Wahana/Query.pm`

Modul [backend/lib/Wahana/Query.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Query.pm) bertanggung jawab membaca file fisik `query.sql`, menguraikan isinya, dan menyimpannya ke dalam struktur data Perl Hash di memori (*RAM*).

### A. Deklarasi Hash dan State Cache (Baris 10–11)
```perl
my %QUERIES;       # Variabel hash global modul (Key => SQL)
my $INITIALIZED = 0; # Penanda state agar proses parsing hanya berjalan 1 kali
```
- `%QUERIES` adalah struktur data *associative array* bawaan Perl. Waktu pencarian (*lookup*) nilai berdasarkan key adalah **$O(1)$** (sangat cepat).
- `$INITIALIZED` memastikan file `query.sql` tidak dibaca ulang setiap kali ada request HTTP, melainkan di-*cache* selama proses Perl hidup.

### B. Pencarian File Otomatis (`_find_query_file`, Baris 13–29)
Untuk memastikan backend dapat berjalan fleksibel di berbagai lingkungan (Docker container, Linux development, atau subdirektori CGI), fungsi ini memeriksa daftar kandidat path:
```perl
my @candidates = (
    $ENV{WAHANA_QUERY_FILE},                                                      # Dari environment variable
    File::Spec->catfile(dirname(__FILE__), '..', '..', 'db', 'query.sql'),        # Relatif dari lib/Wahana/
    File::Spec->catfile(dirname(__FILE__), '..', '..', '..', 'backend', 'db', 'query.sql'),
    '/app/backend/db/query.sql',                                                 # Path standar Docker
    'backend/db/query.sql',                                                      # Dari root repo
    'db/query.sql',
);
```

### C. Algoritma Parsing Baris demi Baris (`_init`, Baris 31–66)

Berikut adalah logika parsing dengan anotasi penjelasan detail:

```perl
sub _init {
    return if $INITIALIZED; # Jika sudah pernah diparse, lewati langsung

    my $file = _find_query_file();
    open my $fh, '<:encoding(UTF-8)', $file or die "[QUERY] Gagal membuka $file: $!";

    my $current_name = ''; # Menyimpan nama query (Key) yang sedang aktif
    my @current_sql  = (); # Menyimpan baris-baris SQL dari query yang sedang aktif

    while (my $line = <$fh>) {
        # 1. CEK APAKAH BARIS MERUPAKAN HEADER NAMA: "-- name: <nama>"
        # Regex: ^\s*--\s*name:\s*(\w+)\s*$
        # ^\s*   : spasi opsional di awal baris
        # --\s*  : komentar dua strip dan spasi
        # name:\s*: kata kunci 'name:' diikuti spasi
        # (\w+)  : group capture untuk nama query (hanya huruf, angka, underscore)
        if ($line =~ /^\s*--\s*name:\s*(\w+)\s*$/) {
            # Jika sebelumnya sudah ada query yang sedang dikumpulkan, simpan dulu ke %QUERIES
            if ($current_name && @current_sql) {
                my $sql = join "\n", @current_sql;
                $sql =~ s/;\s*$//;       # Bersihkan titik koma (;) di akhir query
                $sql =~ s/^\s+|\s+$//g;   # Trim spasi kosong di awal & akhir teks
                $QUERIES{$current_name} = $sql; # <-- MASUKKAN KE HASH
            }
            $current_name = $1;  # Set nama query baru (contoh: 'otp_increment_attempt')
            @current_sql  = ();  # Reset penampung baris SQL
        } 
        elsif ($current_name) {
            # 2. ABAIKAN JIKA MERUPAKAN BARIS KOMENTAR BIASA (bukan nama query)
            next if $line =~ /^\s*--/;
            
            # 3. MASUKKAN BARIS INI SEBAGAI BAGIAN DARI QUERY SQL
            push @current_sql, $line;
        }
    }

    # 4. SIMPAN QUERY TERAKHIR DI DALAM FILE (karena loop while sudah selesai)
    if ($current_name && @current_sql) {
        my $sql = join "\n", @current_sql;
        $sql =~ s/;\s*$//;
        $sql =~ s/^\s+|\s+$//g;
        $QUERIES{$current_name} = $sql;
    }

    close $fh;
    $INITIALIZED = 1; # Tandai bahwa inisialisasi hash sudah selesai
}
```

---

## 4. Hasil Pemetaan Struktur Data di Memori (`%QUERIES`)

Setelah fungsi `_init()` selesai berjalan, isi dari variabel `%QUERIES` di memori Perl akan berbentuk tabel asosiatif seperti berikut:

| Key (Nama Query) | Value (Isi String SQL) |
| :--- | :--- |
| `'otp_increment_attempt'` | `UPDATE user_otps SET attempt_count = attempt_count + 1 WHERE id = ?` |
| `'otp_mark_used'` | `UPDATE user_otps SET used = 1 WHERE id = ?` |
| `'auth_update_user_password'` | `UPDATE users SET password_hash = ? WHERE id = ?` |
| `'users_get_role'` | `SELECT role FROM users WHERE id = ?` |
| `'users_list_all'` | `SELECT * FROM users ORDER BY id ASC` |
| `'users_check_username_exists'`| `SELECT COUNT(*) FROM users WHERE LOWER(username) = LOWER(?)` |

Ketika controller memanggil:
```perl
my $sql = Wahana::Query->get('users_get_role');
```
Fungsi `get` mengecek apakah `%QUERIES` sudah ada. Jika sudah, langsung mengambil nilai `$QUERIES{'users_get_role'}` secara instan.

### Cara Praktis Melihat / Dump Isi Hash Mapping di Terminal

Untuk melihat seluruh pemetaan query yang tersimpan di dalam RAM, modul `Wahana::Query` telah dilengkapi method `Wahana::Query->all()`. Anda bisa menjalankan perintah-perintah one-liner berikut langsung dari terminal:

#### 1. Menghitung Total Query yang Sudah Masuk ke Hash:
```bash
perl -I backend/lib -e 'use Wahana::Query; print "Total Query: " . scalar(keys %{Wahana::Query->all}) . "\n";'
```
*(Output: Total Query: 53)*

#### 2. Menampilkan Seluruh Key (Nama Query) dan Cuplikan SQL-nya:
```bash
perl -I backend/lib -e '
use Wahana::Query;
my $q = Wahana::Query->all;
for my $k (sort keys %$q) {
    printf "%-35s => %s\n", $k, substr($q->{$k}, 0, 50) . "...";
}
'
```

#### 3. Melakukan Dump Lengkap (Key & Full SQL) Menggunakan `Data::Dumper`:
```bash
perl -I backend/lib -MData::Dumper -e 'use Wahana::Query; print Dumper(Wahana::Query->all);'
```

#### 4. Jika Dijalankan dari Dalam Container Docker yang Sedang Hidup:
```bash
docker compose exec backend perl -I /app/lib -e '
use Wahana::Query;
my $q = Wahana::Query->all;
print "$_\n" for sort keys %$q;
'
```


---

## 5. Hubungan dengan Prepared Statement & Hash Reference (DBI)

Setelah string SQL berparameter diambil dari hash `%QUERIES`, bagaimana ia dieksekusi secara aman?

### Langkah 1: Eksekusi dengan Bind Values
Perhatikan contoh di [backend/lib/Wahana/Controller/UsersController.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Controller/UsersController.pm#L31-L32):
```perl
my $sql  = Wahana::Query->get('users_get_role'); # Mengambil "SELECT role FROM users WHERE id = ?"
my $role = $dbh->selectrow_array($sql, undef, $user_id);
```

Di balik layar, DBI melakukan mekanisme *prepared statement*:
1. Database mengompilasi struktur query: `SELECT role FROM users WHERE id = ?`.
2. Nilai variabel `$user_id` dikirim secara terpisah ke placeholder `?`.
3. Database tidak akan mengevaluasi karakter apa pun di dalam `$user_id` sebagai perintah SQL, melainkan murni sebagai teks/data biasa. Ini mencegah serangan SQL Injection.

### Langkah 2: Mengembalikan Baris sebagai Hash Reference (`selectrow_hashref`)
Ketika query mengambil banyak kolom sekaligus, controller menggunakan:
```perl
my $sql = Wahana::Query->get('auth_get_user_by_id'); # "SELECT * FROM users WHERE id = ? LIMIT 1"
my $row = $dbh->selectrow_hashref($sql, undef, $user_id);
```

DBI membaca metadata kolom tabel MySQL dan secara otomatis membungkusnya ke dalam struktur data **Perl Hash Reference (`$row`)**:
```perl
$row = {
    'id'            => 'USR-0001',
    'username'      => 'admin',
    'email'         => 'admin@dijakexpress.com',
    'role'          => 'ADMIN',
    'password_hash' => '$2a$12$e0...',
    'status'        => 'ONLINE',
    'last_login'    => '2026-09-03 09:30:00'
};
```
Sehingga pada kode Perl, pengembang dapat mengakses nilai kolom dengan sintaks panah hash:
```perl
my $nama = $row->{username};
my $peran = $row->{role};
```

---

## 6. Bedah Fitur SQL `REGEXP` (Auto-Numbering ID Generator)

Di dalam [backend/db/query.sql](file:///Documents/Scan-resi-magang/backend/db/query.sql) terdapat beberapa query yang memanfaatkan operator **`REGEXP`** (Regular Expression di MySQL/MariaDB), misalnya pada baris 61–70, 112–113, dan 157–158:

```sql
-- name: users_get_max_admin_id
SELECT COALESCE(MAX(CAST(SUBSTRING(id, 11) AS UNSIGNED)), 0)
  FROM users WHERE id REGEXP '^USR-ADMIN-[0-9]+$';

-- name: users_get_max_cust_id
SELECT COALESCE(MAX(CAST(SUBSTRING(id, 10) AS UNSIGNED)), 0)
  FROM users WHERE id REGEXP '^USR-CUST-[0-9]+$';

-- name: tasks_get_max_id
SELECT COALESCE(MAX(CAST(SUBSTRING(task_id, 6) AS UNSIGNED)), 0)
  FROM tasks WHERE task_id REGEXP '^TASK-[0-9]+$';

-- name: scans_get_max_id
SELECT COALESCE(MAX(CAST(SUBSTRING(scan_id, 5) AS UNSIGNED)), 0)
  FROM scan_events WHERE scan_id REGEXP '^SCN-[0-9]+$';
```

### Mengapa Digunakan `REGEXP` di Database?
Sistem Dijak Express tidak memakai ID angka otomatis bawaan (seperti `1, 2, 3`), melainkan **ID berformat kode prefix** seperti:
- Admin: `USR-ADMIN-0001`
- Customer: `USR-CUST-0005`
- Kurir/Petugas: `USR-0012`
- Tugas: `TASK-0020`
- Scan Event: `SCN-0100`

Untuk membuat nomor urut berikutnya secara otomatis, sistem harus mencari **angka tertinggi yang sudah terpakai**. 

Jika di dalam tabel terdapat ID kustom acak (seperti user default `'admin'`, `'guest'`, atau ID aneh lainnya), parsing string ke angka akan menyebabkan error atau hasil keliru. Di sinilah **`REGEXP`** bertindak sebagai filter keamanan data.

---

### Cara Kerja Komponen Query Langkah demi Langkah

Ambil contoh query:
```sql
SELECT COALESCE(MAX(CAST(SUBSTRING(id, 11) AS UNSIGNED)), 0)
  FROM users WHERE id REGEXP '^USR-ADMIN-[0-9]+$';
```

#### 1. Filter dengan `REGEXP '^USR-ADMIN-[0-9]+$'`
- `^` : Awal string.
- `USR-ADMIN-` : Wajib diawali tepat dengan teks ini (panjangnya 10 karakter).
- `[0-9]+` : Diikuti oleh satu atau lebih digit angka `0` sampai `9`.
- `$` : Akhir string (tidak boleh ada karakter aneh lain di belakangnya).
- **Fungsi**: Memastikan hanya baris berformat valid seperti `USR-ADMIN-0001` atau `USR-ADMIN-0015` yang diproses. Data lama atau tidak standar akan otomatis diabaikan.

#### 2. `SUBSTRING(id, 11)`
- Memotong string mulai dari karakter ke-11 sampai habis.
- Contoh: `USR-ADMIN-0015` $\to$ dipotong dari posisi 11 menghasilkan string `'0015'`.

#### 3. `CAST(... AS UNSIGNED)`
- Mengubah tipe data teks `'0015'` menjadi integer angka asli `15`.
- **Penting**: Dalam pengurutan teks (string), `'100'` dianggap lebih kecil daripada `'2'`. Dengan mengubahnya menjadi angka (`UNSIGNED`), perbandingan nilai angka menjadi benar: $15 > 2$.

#### 4. `MAX(...)`
- Mengambil angka integer tertinggi dari seluruh baris yang lolos filter (misal ditemukan angka maksimum adalah `15`).

#### 5. `COALESCE(..., 0)`
- Jika tabel masih kosong atau belum ada user admin sama sekali, fungsi `MAX()` akan bernilai `NULL`.
- `COALESCE(NULL, 0)` secara otomatis mengubah `NULL` menjadi angka `0`.

---

### Bagaimana Controller Perl Menggunakannya?
Setelah database mengembalikan angka tertinggi (misal `15`), controller Perl (contoh di [UsersController.pm](file:///Documents/Scan-resi-magang/backend/lib/Wahana/Controller/UsersController.pm#L93-L108)) tinggal menambah 1 dan memformatnya kembali dengan `sprintf`:

```perl
my $max_admin = $dbh->selectrow_array(Wahana::Query->get('users_get_max_admin_id')); # Bernilai 15
my $next_num  = ($max_admin // 0) + 1;                                                # 15 + 1 = 16
my $new_id    = sprintf("USR-ADMIN-%04d", $next_num);                                 # Menjadi "USR-ADMIN-0016"
```

---

## 7. Ringkasan Keuntungan Desain Ini

1. **Clean Code**: Tidak ada query SQL yang berceceran atau ditulis berulang-ulang di dalam file Perl Controller.
2. **Kinerja Tinggi ($O(1)$)**: File `query.sql` hanya dibaca satu kali saat aplikasi start, selanjutnya query diambil langsung dari memori RAM lewat Perl Hash.
3. **Keamanan Maksimal**: Format katalog query mewajibkan penggunaan placeholder `?`, menjamin seluruh transaksi database menggunakan *prepared statements* anti-SQL Injection.
4. **Auto-Numbering yang Kuat**: Penggunaan `REGEXP` + `SUBSTRING` + `CAST` menjamin pembuatan ID unik custom selalu urut tanpa khawatir error karena data anomali.
5. **Kemudahan Maintenance**: Jika struktur tabel atau query SQL berubah, developer cukup memperbarui file [backend/db/query.sql](file:///Documents/Scan-resi-magang/backend/db/query.sql) tanpa perlu mengedit file-file controller Perl.

