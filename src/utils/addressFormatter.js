/**
 * addressFormatter.js — Utility helper untuk format alamat terstruktur & string
 */

/**
 * Format detail alamat (objek terstruktur atau string) menjadi baris alamat yang rapi.
 * Menurut Aturan PRD:
 * - Baris 1: Jalan + (No. X jika no_rumah ada) + (, Kelurahan jika ada)
 * - Baris 2: Kecamatan + (, Kota/Kabupaten jika ada)
 * - Baris 3: Provinsi + ( Kode Pos jika ada)
 * - Jika Nomor Rumah kosong, JANGAN tampilkan "No.".
 * - Jika nomor telepon kosong, sembunyikan nomor telepon.
 * - Tanpa undefined, null, string kosong, koma berlebihan, spasi kosong ganda.
 *
 * @param {Object|string} detail - Objek terstruktur alamat atau string
 * @param {string} fallbackName - Nama default jika detail adalah string
 * @param {string} fallbackAddress - Alamat default jika detail adalah string
 * @returns {{ name: string, phone: string, addressLines: string[] }}
 */
export function formatAddressInfo(detail, fallbackName = '', fallbackAddress = '') {
  if (!detail || typeof detail === 'string') {
    const rawAddress = typeof detail === 'string' && detail.trim() ? detail.trim() : fallbackAddress.trim()
    return {
      name: fallbackName.trim(),
      phone: '',
      addressLines: rawAddress ? [rawAddress] : []
    }
  }

  const d = detail || {}
  const name = (d.nama || d.nama_lengkap || fallbackName || '').trim()
  const phone = (d.telepon || d.no_tlp || d.phone || '').trim()

  // Baris 1: Jalan, No. Rumah, Kelurahan
  const jalan = (d.alamat || d.jalan || '').trim()
  const noRumah = (d.no_rumah || d.nomor_rumah || '').trim()
  const kelurahan = (d.kelurahan || d.desa || '').trim()

  let line1 = jalan
  if (noRumah) {
    line1 += (line1 ? ' No. ' : 'No. ') + noRumah
  }
  if (kelurahan) {
    line1 += (line1 ? ', ' : '') + kelurahan
  }

  // Baris 2: Kecamatan, Kota/Kabupaten
  const kecamatan = (d.kecamatan || '').trim()
  const kota = (d.kota || d.kabupaten || d.kota_kabupaten || '').trim()

  let line2 = kecamatan
  if (kota) {
    line2 += (line2 ? ', ' : '') + kota
  }

  // Baris 3: Provinsi Kode Pos
  const provinsi = (d.provinsi || '').trim()
  const kodePos = (d.kode_pos || '').trim()

  let line3 = provinsi
  if (kodePos) {
    line3 += (line3 ? ' ' : '') + kodePos
  }

  // Filter baris kosong
  const addressLines = [line1, line2, line3].filter((line) => line && line.trim().length > 0)

  // Jika tidak ada baris terstruktur yang terbentuk, gunakan fallbackAddress
  if (addressLines.length === 0 && fallbackAddress.trim()) {
    addressLines.push(fallbackAddress.trim())
  }

  return {
    name,
    phone,
    addressLines
  }
}

/**
 * Gabungkan detail alamat terstruktur menjadi string single line (untuk alamat_tujuan)
 */
export function buildSingleLineAddress(d = {}) {
  const { addressLines } = formatAddressInfo(d)
  return addressLines.join(', ')
}
