# Rencana & Analisis Perbaikan: Scanner Kamera Format RSS Expanded (GS1 DataBar Expanded)

Dokumen ini mendokumentasikan analisis teknis mendalam mengenai penyebab kegagalan pemindaian kamera pada format barcode **RSS Expanded (GS1 DataBar Expanded)**, perbandingan status format lainnya, serta rencana arsitektur perbaikannya di sistem Wahana Express.

---

## 1. Status Pemindaian Kamera Terkini

Berdasarkan pengujian langsung di sistem:
* **Codabar:** **BERHASIL** (Perlindungan minimum digit `length >= 6` berhasil menghilangkan glitch single-digit `1` atau `-`).
* **RSS-14 (GS1 DataBar Omni):** **BERHASIL** (Sinkronisasi payload `(01)GTIN-14` dan perbaikan prioritas filter berhasil membaca resi dengan akurat).
* **MaxiCode:** Ditandai khusus untuk scanner 2D hardware/laser (tidak didukung pustaka kamera web browser).
* **RSS Expanded:** **BELUM TERDETEKSI** oleh scanner kamera.

---

## 2. Investigasi & Akar Masalah (Root Cause)

Pustaka scanner web browser yang digunakan pada aplikasi adalah `@zxing/library` dan `html5-qrcode` (yang juga membungkus `zxing-js`). 

Implementasi modul `RSSExpandedReader` pada pustaka tersebut di-porting dari Java ZXing, namun statusnya secara resmi **belum selesai (unfinished / experimental)**. Bahkan pada kode sumber bawaan `@zxing/library` terdapat peringatan:
> `console.warn('RSS Expanded reader IS NOT ready for production yet! use at your own risk.');`

Melalui pelacakan langkah-demi-langkah (*execution tracing*) terhadap proses decoding citra bilah barcode, ditemukan **5 cacat struktural bawaan pustaka**:

### Cacat 1: In-place Array Overwrite pada `System.arraycopy`
* **Lokasi:** `core/util/System.js` & `RSSExpandedReader.prototype.parseFoundFinderPattern`
* **Masalah:**
  ```javascript
  System.arraycopy = function (src, srcPos, dest, destPos, length) {
      while (length--) {
          dest[destPos++] = src[srcPos++];
      }
  };
  ```
  Ketika fungsi `parseFoundFinderPattern` menggeser array counter finder pattern secara in-place (`counters, 0, counters, 1, counters.length - 1`), loop maju menimpa seluruh elemen array menjadi sama dengan nilai `counters[0]` (`[c0, c0, c0, c0]`).
* **Dampak:** Pola awal (*finder pattern*) selalu gagal dicocokkan (`parseFinderValue` selalu melempar `NotFoundException`).

### Cacat 2: Indeks Pecahan Float (`i / 2`)
* **Lokasi:** `RSSExpandedReader.prototype.decodeDataCharacter` (baris 625)
* **Masalah:**
  Pada Java: `int offset = i / 2;` menghasilkan integer (`0, 0, 1, 1, ...`).
  Pada JavaScript: `var offset = i / 2;` menghasilkan float (`0, 0.5, 1, 1.5, ...`).
* **Dampak:** Slot array integer `evenCounts[0]`, `evenCounts[1]`, dll. tidak pernah terisi, melainkan menjadi properti desimal objek JS (`evenCounts["0.5"]`). Akibatnya, saat pembacaan checksum, `evenCounts[i]` bernilai `undefined`, memicu perhitungan `NaN`.

### Cacat 3: Pembulatan Bilangan Desimal (`value + 0.5`)
* **Lokasi:** `RSSExpandedReader.prototype.decodeDataCharacter` (baris 612)
* **Masalah:**
  Pada Java: `int count = (int) (value + 0.5f);` memotong angka ke integer terdekat.
  Pada JavaScript: `var count = value_1 + 0.5;` tanpa `Math.floor()` membiarkan nilai tetap desimal (`2.5`, `3.5`).
* **Dampak:** Perhitungan checksum menghasilkan angka pecahan desimal (misalnya `checksum: 57.5, checkCharacterValue: 479.5`), sehingga validasi checksum modul data selalu tidak cocok (*mismatch*).

### Cacat 4: State Decoder Tidak Terinisialisasi di `GeneralAppIdDecoder`
* **Lokasi:** `GeneralAppIdDecoder.js` (baris 12–15 & 82)
* **Masalah:**
  Konstruktor `GeneralAppIdDecoder` tidak menginstansiasi `this.current = new CurrentParsingState()`.
* **Dampak:** Saat rekonstruksi payload string GS1 dimulai, terjadi runtime crash:
  `TypeError: Cannot read properties of undefined (reading 'setPosition')`.

### Cacat 5: Metode Java vs JavaScript Array
* **Lokasi:** `RSSExpandedReader.prototype.checkChecksum` & `storeRow`
* **Masalah:**
  Kode memanggil `this.pairs.get(0)`, `this.pairs.size()`, dan `this.rows.push(insertPos, element)`. Di JavaScript, `Array.push(insertPos, element)` mendorong angka `insertPos` ke dalam array, sehingga `rows[0]` bernilai angka `0` dan memicu error `erow.getRowNumber is not a function`.

---

## 3. Rencana Solusi & Arsitektur Implementasi

Untuk mengatasi masalah ini secara permanen tanpa perlu memodifikasi `node_modules` secara manual atau mengganggu build CI/CD, dibuat modul runtime patcher transparan.

### A. Modul Baru: `src/utils/zxingRssExpandedPatcher.js`
Modul ini bertugas melakukan *monkey-patching* pada prototipe ZXing saat scanner kamera diinisialisasi di browser:
1. **Patch `System.arraycopy`**: Menambahkan deteksi pergeseran maju in-place (`destPos > srcPos && src === dest`) dan mengeksekusinya secara mundur (*backward copy*).
2. **Patch `decodeDataCharacter`**:
   * Menambahkan `Math.floor(value + 0.5)` agar jumlah modul selalu bilangan bulat positif.
   * Menambahkan pembulatan indeks integer: `var offset = (i / 2) | 0`.
3. **Patch `checkChecksum`**:
   * Mengganti `.get(0)` dan `.size()` menjadi array native JavaScript `this.pairs[0]` dan `this.pairs.length`.
4. **Patch `decodeGeneralPurposeField`**:
   * Memastikan `this.current` selalu memiliki instance `CurrentParsingState` sebelum parsing blok GS1.
5. **Patch `storeRow`**:
   * Mengganti `this.rows.push(insertPos, item)` menjadi `this.rows.splice(insertPos, 0, item)`.

### B. Integrasi ke `src/components/CameraScannerDialog.vue`
* Memanggil `applyZxingRssExpandedPatch()` satu kali saat dialog kamera pertama kali dimuat.
* Memastikan format `BarcodeFormat.RSS_EXPANDED` aktif di pipeline `zxingReader`.

### C. Normalisasi String di `src/utils/barcodeGenerator.js`
* Memastikan fungsi `normalizeScannedResi()` dapat mengekstrak nomor resi murni dari format payload standar GS1:
  `(01)GTIN-14(10)NomorResi` $\rightarrow$ `NomorResi`.

---

## 4. Rencana Pengujian & Verifikasi

1. **Pengujian Otomatis (Node.js Test):**
   * Barcode RSS Expanded digenerate secara sintetis menggunakan `bwip-js`.
   * Decoder ZXing yang telah dipatch diuji untuk membaca citra tersebut.
   * Verifikasi teks hasil decode sama persis dengan nomor resi input.
2. **Pengujian Kamera Browser (E2E):**
   * Buka menu pemindai kamera (Customer atau Petugas).
   * Sorot barcode RSS Expanded dari layar monitor / label cetak.
   * Pastikan sistem mengenali format `RSS_EXPANDED` dan mencocokkan nomor resi dalam waktu $< 1$ detik.
