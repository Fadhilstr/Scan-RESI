/**
 * paket.service.js — Service Layer Paket (Master Data Barang)
 *
 * Nomor resi SELALU dibuat oleh BACKEND (prinsip inti sistem):
 *   CUSTOMER klik generate → POST /api/paket/resi → server susun
 *   8 karakter acak → barcode dirender frontend DARI resi tersebut.
 *
 * MODE LOCAL (VITE_USE_LOCAL_DATA=true):
 *   Array dummy lokal + generator resi sisi-klien yang meniru aturan server.
 *
 * MODE API (VITE_USE_LOCAL_DATA=false):
 *   Endpoint:
 *     POST  /api/paket/resi       — Generate resi + buat baris DRAFT (CUSTOMER/ADMIN)
 *     GET   /api/paket            — Daftar paket (customer otomatis di-scope miliknya)
 *     PATCH /api/paket/:resi      — Simpan data barang → TERDAFTAR
 *     GET   /api/paket/:resi      — Detail / cari data paket by nomor resi
 */

import api, { USE_LOCAL_DATA } from './api'
import { addAuditLog } from './audit.service'

// =====================================================================
// ALFABET RESI — sama dengan backend (tanpa I, O, 0, 1)
// =====================================================================
const RESI_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const RESI_LEN = 8

// Helper: format datetime string Waktu Indonesia Barat (WIB - Asia/Jakarta)
export const getWIBTimeString = (dateObj = new Date()) => {
  const options = {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }
  const formatter = new Intl.DateTimeFormat('en-GB', options)
  const parts = formatter.formatToParts(dateObj)
  const map = {}
  parts.forEach((p) => {
    if (p.type !== 'literal') map[p.type] = p.value
  })
  return `${map.day}-${map.month}-${map.year} ${map.hour}:${map.minute}:${map.second}`
}

export const getRelativeWIBTime = (minutesAgo = 0) => {
  return getWIBTimeString(new Date(Date.now() - minutesAgo * 60 * 1000))
}

const nowString = () => getWIBTimeString()

// =====================================================================
// LOCAL DUMMY DATA — paritas dengan seed backend/db/schema.sql
// =====================================================================
export const LOCAL_PAKETS = [
  {
    nomor_resi: 'GJXL8FLB',
    nama_barang: 'Dokumen Kontrak',
    pengirim: 'PT Sinar Jaya',
    pengirim_detail: {
      nama: 'PT Sinar Jaya',
      telepon: '081234567890',
      alamat: 'Jl. Merpati',
      no_rumah: '25',
      kelurahan: 'Rempoa',
      kecamatan: 'Ciputat Timur',
      kota: 'Tangerang Selatan',
      provinsi: 'Banten',
      kode_pos: '15412'
    },
    penerima: 'Rina Wulandari',
    penerima_detail: {
      nama: 'Rina Wulandari',
      telepon: '085712345678',
      alamat: 'Jl. Margonda Raya',
      no_rumah: '12',
      kelurahan: 'Kemiri Muka',
      kecamatan: 'Beji',
      kota: 'Depok',
      provinsi: 'Jawa Barat',
      kode_pos: '16423'
    },
    alamat_tujuan: 'Jl. Margonda Raya No. 12, Depok',
    berat_kg: 1.2,
    jenis_layanan: 'EXPRESS',
    hub_asal: 'Tangerang Selatan',
    hub_tujuan: 'Depok',
    cod_amount: 0,
    status: 'TERDAFTAR',
    created_by: 'USR-CUST-001',
    creator_name: 'Customer Demo',
    get created_at() { return getRelativeWIBTime(45) }
  },
  {
    nomor_resi: 'AB123456',
    nama_barang: 'Sepatu Olahraga',
    pengirim: 'Toko Amanah',
    pengirim_detail: {
      nama: 'Toko Amanah',
      telepon: '081122334455',
      alamat: 'Jl. Raya Ciputat',
      no_rumah: '45',
      kelurahan: 'Ciputat',
      kecamatan: 'Ciputat',
      kota: 'Tangerang Selatan',
      provinsi: 'Banten',
      kode_pos: '15411'
    },
    penerima: 'Dedi Kurniawan',
    penerima_detail: {
      nama: 'Dedi Kurniawan',
      telepon: '081399887766',
      alamat: 'Jl. Raya Ciputat',
      no_rumah: '45',
      kelurahan: 'Sukasari',
      kecamatan: 'Tangerang',
      kota: 'Tangerang',
      provinsi: 'Banten',
      kode_pos: '15118'
    },
    alamat_tujuan: 'Jl. Raya Ciputat No. 45, Tangerang',
    berat_kg: 2.5,
    jenis_layanan: 'REGULER',
    hub_asal: 'Tangerang Selatan',
    hub_tujuan: 'Tangerang',
    cod_amount: 0,
    status: 'TERDAFTAR',
    created_by: 'USR-CUST-001',
    creator_name: 'Customer Demo',
    get created_at() { return getRelativeWIBTime(30) }
  },
  {
    nomor_resi: 'WHN555555',
    nama_barang: 'Laptop Kerja',
    pengirim: 'CV Techindo',
    penerima: 'Sari Melati',
    alamat_tujuan: 'Jl. Sudirman Kav. 21, Jakarta',
    berat_kg: 3.8,
    jenis_layanan: 'SAME_DAY',
    hub_asal: 'Jakarta',
    hub_tujuan: 'Jakarta',
    status: 'TERDAFTAR',
    created_by: 'USR-CUST-001',
    creator_name: 'Customer Demo',
    get created_at() { return getRelativeWIBTime(20) }
  },
  {
    nomor_resi: 'XYZ123456',
    nama_barang: 'Buku Tulis (12 pcs)',
    pengirim: 'Toko Buku Ilmu',
    penerima: 'Ahmad Fauzi',
    alamat_tujuan: 'Jl. Kampus Barat No. 8, Ciputat',
    berat_kg: 4.0,
    jenis_layanan: 'REGULER',
    hub_asal: 'Jakarta',
    hub_tujuan: 'Ciputat',
    status: 'TERDAFTAR',
    created_by: 'USR-CUST-001',
    creator_name: 'Customer Demo',
    get created_at() { return getRelativeWIBTime(15) }
  },
  {
    nomor_resi: 'WHN777777',
    nama_barang: 'Kamera Mirrorless',
    pengirim: 'PhotoMart',
    penerima: 'Bagas Pratama',
    alamat_tujuan: 'Jl. Cempaka Putih No. 3, Jakarta',
    berat_kg: 2.1,
    jenis_layanan: 'EXPRESS',
    hub_asal: 'Jakarta',
    hub_tujuan: 'Jakarta',
    status: 'TERDAFTAR',
    created_by: 'USR-CUST-001',
    creator_name: 'Customer Demo',
    get created_at() { return getRelativeWIBTime(10) }
  },
  {
    nomor_resi: 'ABC111111',
    nama_barang: 'Serum Skincare',
    pengirim: 'GlowStore',
    penerima: 'Nadia Putri',
    alamat_tujuan: 'Jl. Kartini No. 19, South Tangerang',
    berat_kg: 0.6,
    jenis_layanan: 'SAME_DAY',
    hub_asal: 'Jakarta',
    hub_tujuan: 'South Tangerang',
    status: 'TERDAFTAR',
    created_by: 'USR-CUST-001',
    creator_name: 'Customer Demo',
    get created_at() { return getRelativeWIBTime(5) }
  },
  {
    nomor_resi: 'ABC222222',
    nama_barang: 'Helm Motor',
    pengirim: 'RideSafe Shop',
    penerima: 'Yoga Saputra',
    alamat_tujuan: 'Jl. Ir. Juanda No. 77, Depok',
    berat_kg: 1.9,
    jenis_layanan: 'REGULER',
    hub_asal: 'Jakarta',
    hub_tujuan: 'Depok',
    status: 'TERDAFTAR',
    created_by: 'USR-CUST-001',
    creator_name: 'Customer Demo',
    get created_at() { return getRelativeWIBTime(1) }
  }
]

// Generator lokal — HANYA untuk mode demo; produksi selalu via backend.
const makeLocalResi = () => {
  let resi = ''
  do {
    resi = Array.from({ length: RESI_LEN }, () =>
      RESI_CHARS[Math.floor(Math.random() * RESI_CHARS.length)]
    ).join('')
  } while (LOCAL_PAKETS.some((p) => p.nomor_resi === resi))
  return resi
}

// =====================================================================
// SERVICE FUNCTIONS
// =====================================================================

/**
 * Minta backend membuat nomor resi baru + baris paket DRAFT.
 * @param {Object} currentUser - user pembuat (harus CUSTOMER/ADMIN)
 * @returns {Promise<{success, paket?, reason?, message?}>}
 */
export async function generateResi(currentUser) {
  if (!currentUser) {
    return { success: false, message: 'Sesi tidak valid.' }
  }

  if (USE_LOCAL_DATA) {
    // --- LOCAL MODE: tiru perilaku server ---
    if (currentUser.role !== 'CUSTOMER' && currentUser.role !== 'ADMIN') {
      return { success: false, reason: 'FORBIDDEN', message: 'Hanya CUSTOMER atau ADMIN yang dapat membuat nomor resi.' }
    }

    const resi = makeLocalResi()
    const paket = {
      nomor_resi: resi,
      nama_barang: null,
      pengirim: null,
      penerima: null,
      alamat_tujuan: null,
      berat_kg: 0,
      jenis_layanan: 'REG',
      status: 'DRAFT',
      created_by: currentUser.id,
      creator_name: currentUser.name,
      created_at: nowString()
    }
    LOCAL_PAKETS.unshift(paket)

    await addAuditLog({
      user_id: currentUser.id,
      user_name: currentUser.name,
      action: 'PAKET_RESI_GENERATED',
      details: `Nomor resi ${resi} digenerate (DRAFT).`
    })

    return { success: true, paket: { ...paket } }
  }

  // --- API MODE: resi dibuat server-side ---
  try {
    const data = await api.post('/api/paket/resi')
    return { success: !!data.success, paket: data.paket, message: data.message }
  } catch (err) {
    return { success: false, reason: 'ERROR', message: err.message || 'Gagal membuat nomor resi.' }
  }
}

/**
 * Simpan data barang pada paket DRAFT → status TERDAFTAR.
 * @param {string} nomorResi
 * @param {Object} data - { nama_barang, pengirim, penerima, alamat_tujuan?, berat_kg?, jenis_layanan?, pengirim_detail?, penerima_detail?, hub_asal?, hub_tujuan?, cod_amount? }
 * @param {Object} currentUser
 */
export async function savePaketData(nomorResi, data, currentUser) {
  const resi = (nomorResi || '').trim().toUpperCase()

  // Validasi field wajib (mirror backend)
  for (const field of ['nama_barang', 'pengirim', 'penerima']) {
    if (!(data[field] || '').trim()) {
      return { success: false, reason: 'VALIDATION', message: `${field.replace('_', ' ')} wajib diisi.` }
    }
  }

  if (USE_LOCAL_DATA) {
    // --- LOCAL MODE ---
    const paket = LOCAL_PAKETS.find((p) => p.nomor_resi === resi)
    if (!paket) {
      return { success: false, reason: 'NOT_FOUND', message: 'Paket tidak ditemukan.' }
    }
    if (currentUser.role !== 'ADMIN' && paket.created_by !== currentUser.id) {
      return { success: false, reason: 'FORBIDDEN', message: 'Hanya pembuat paket atau ADMIN yang dapat menyimpan data barang.' }
    }

    Object.assign(paket, {
      nama_barang: data.nama_barang.trim(),
      pengirim: data.pengirim.trim(),
      alamat_pengirim: (data.alamat_pengirim || '').trim(),
      penerima: data.penerima.trim(),
      alamat_tujuan: (data.alamat_tujuan || '').trim(),
      berat_kg: Number(data.berat_kg) || 0,
      jenis_layanan: data.jenis_layanan || 'REG',
      pengirim_detail: data.pengirim_detail || null,
      penerima_detail: data.penerima_detail || null,
      hub_asal: data.hub_asal || 'Jakarta',
      hub_tujuan: data.hub_tujuan || 'Bandung',
      cod_amount: Number(data.cod_amount) || 0,
      status: 'TERDAFTAR'
    })

    await addAuditLog({
      user_id: currentUser.id,
      user_name: currentUser.name,
      action: 'PAKET_UPDATED',
      details: `Paket ${resi} disimpan dan TERDAFTAR (${paket.nama_barang}).`
    })

    return { success: true, message: `Paket ${resi} berhasil disimpan.`, paket: { ...paket } }
  }

  // --- API MODE ---
  try {
    const res = await api.patch(`/api/paket/${encodeURIComponent(resi)}`, {
      nama_barang: data.nama_barang,
      pengirim: data.pengirim,
      alamat_pengirim: data.alamat_pengirim,
      penerima: data.penerima,
      alamat_tujuan: data.alamat_tujuan,
      berat_kg: data.berat_kg,
      jenis_layanan: data.jenis_layanan
    })
    return {
      success: !!res.success,
      reason: res.reason,
      message: res.message,
      paket: res.paket
    }
  } catch (err) {
    return { success: false, reason: 'ERROR', message: err.message || 'Gagal menyimpan data paket.' }
  }
}

export function parseDateToTime(dateStr) {
  if (!dateStr) return 0
  const str = String(dateStr).trim()
  if (/^\d{2}-\d{2}-\d{4}/.test(str)) {
    const [dPart, tPart = '00:00:00'] = str.split(' ')
    const [d, m, y] = dPart.split('-')
    const t = tPart.replace(/\./g, ':')
    const timeNum = new Date(`${y}-${m}-${d}T${t}`).getTime()
    return isNaN(timeNum) ? 0 : timeNum
  }
  if (/^\d{4}-\d{2}-\d{2}/.test(str)) {
    const formattedStr = str.replace(' ', 'T').replace(/\./g, ':')
    const timeNum = new Date(formattedStr).getTime()
    return isNaN(timeNum) ? 0 : timeNum
  }
  const parsed = Date.parse(str)
  return isNaN(parsed) ? 0 : parsed
}

/**
 * Ambil daftar paket (CUSTOMER otomatis hanya miliknya via backend).
 * @param {Object} filters - optional: { q, status, created_by }
 */
export async function getPakets(filters = {}) {
  let result = []
  if (USE_LOCAL_DATA) {
    // --- LOCAL MODE: scope customer dilakukan pemanggil (store) ---
    result = [...LOCAL_PAKETS]
    if (filters.created_by) result = result.filter((p) => p.created_by === filters.created_by)
    if (filters.status) result = result.filter((p) => p.status === filters.status)
    if (filters.q) {
      const q = filters.q.toLowerCase()
      result = result.filter(
        (p) =>
          p.nomor_resi.toLowerCase().includes(q) ||
          (p.nama_barang || '').toLowerCase().includes(q)
      )
    }
  } else {
    // --- API MODE ---
    const data = await api.get('/api/paket', { params: filters })
    result = data.pakets || []
  }

  // Urutkan paket secara descending berdasarkan timestamp pembuatan (created_at)
  return result.sort((a, b) => parseDateToTime(b.created_at) - parseDateToTime(a.created_at))
}

/**
 * Cari satu paket berdasarkan nomor resi (tahap "Cari Data Paket").
 * @param {string} nomorResi
 * @returns {Promise<{success, paket?, reason?, message?}>}
 */
export async function getPaketByResi(nomorResi) {
  const resi = (nomorResi || '').trim().toUpperCase()
  if (!resi) {
    return { success: false, reason: 'EMPTY', message: 'Nomor resi tidak boleh kosong.' }
  }

  if (USE_LOCAL_DATA) {
    // --- LOCAL MODE ---
    const paket = LOCAL_PAKETS.find((p) => p.nomor_resi === resi)
    if (!paket) {
      return { success: false, reason: 'NOT_FOUND', message: `Paket dengan resi ${resi} tidak ditemukan.` }
    }
    return { success: true, paket: { ...paket } }
  }

  // --- API MODE ---
  try {
    const data = await api.get(`/api/paket/${encodeURIComponent(resi)}`)
    return { success: !!data.success, reason: data.reason, paket: data.paket, message: data.message }
  } catch (err) {
    return { success: false, reason: 'ERROR', message: err.message || 'Gagal mencari data paket.' }
  }
}
