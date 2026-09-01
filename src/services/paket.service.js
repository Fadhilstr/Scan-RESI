/**
 * paket.service.js — Service Layer Paket & Customer (Request Object Style)
 *
 * Menggunakan gaya pemanggilan:
 *   api({
 *     url: `/3pl/Customer/${resi}`,
 *     method: 'PATCH',
 *     data: { ... }
 *   })
 */
import api, { USE_LOCAL_DATA } from './api'
import { addAuditLog } from './audit.service'

const RESI_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const RESI_LEN = 8

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

export const LOCAL_PAKETS = []

const makeLocalResi = () => {
  let resi = ''
  do {
    resi = Array.from({ length: RESI_LEN }, () =>
      RESI_CHARS[Math.floor(Math.random() * RESI_CHARS.length)]
    ).join('')
  } while (LOCAL_PAKETS.some((p) => p.nomor_resi === resi))
  return resi
}

export async function generateResi(currentUser) {
  if (!currentUser) {
    return { success: false, message: 'Sesi tidak valid.' }
  }

  if (USE_LOCAL_DATA) {
    if (currentUser.role !== 'CUSTOMER' && currentUser.role !== 'ADMIN' && currentUser.role !== 'DEVELOPER') {
      return { success: false, reason: 'FORBIDDEN', message: 'Hanya CUSTOMER atau ADMIN yang dapat membuat nomor resi.' }
    }

    const resi = makeLocalResi()
    const paket = {
      nomor_resi: resi,
      nama_barang: null,
      pengirim: null,
      alamat_pengirim: null,
      telepon_pengirim: '',
      penerima: null,
      alamat_tujuan: null,
      telepon_penerima: '',
      berat_kg: 0,
      jenis_layanan: 'REGULER',
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

  // --- API MODE (Object Style with url) ---
  try {
    const data = await api({
      url: '/3pl/Customer/resi',
      method: 'POST'
    })
    return { success: !!data.success, paket: data.paket, message: data.message }
  } catch (err) {
    return { success: false, reason: 'ERROR', message: err.message || 'Gagal membuat nomor resi.' }
  }
}

export async function savePaketData(nomorResi, data, currentUser) {
  const resi = (nomorResi || '').trim().toUpperCase()

  for (const field of ['nama_barang', 'pengirim', 'penerima', 'telepon_pengirim', 'telepon_penerima']) {
    if (!(data[field] || '').trim()) {
      return { success: false, reason: 'VALIDATION', message: `${field.replace('_', ' ')} wajib diisi.` }
    }
  }

  for (const field of ['telepon_pengirim', 'telepon_penerima']) {
    const val = (data[field] || '').trim()
    if (!/^\d{8,15}$/.test(val)) {
      return { success: false, reason: 'VALIDATION', message: `${field.replace('_', ' ')} harus berupa angka 8-15 digit.` }
    }
  }

  if (USE_LOCAL_DATA) {
    const paket = LOCAL_PAKETS.find((p) => p.nomor_resi === resi)
    if (!paket) {
      return { success: false, reason: 'NOT_FOUND', message: 'Paket tidak ditemukan.' }
    }
    if (currentUser.role !== 'ADMIN' && currentUser.role !== 'DEVELOPER' && paket.created_by !== currentUser.id) {
      return { success: false, reason: 'FORBIDDEN', message: 'Hanya pembuat paket atau ADMIN yang dapat menyimpan data barang.' }
    }

    Object.assign(paket, {
      nama_barang: data.nama_barang.trim(),
      pengirim: data.pengirim.trim(),
      alamat_pengirim: (data.alamat_pengirim || '').trim(),
      telepon_pengirim: data.telepon_pengirim.trim(),
      penerima: data.penerima.trim(),
      alamat_tujuan: (data.alamat_tujuan || '').trim(),
      telepon_penerima: data.telepon_penerima.trim(),
      berat_kg: Number(data.berat_kg) || 0,
      jenis_layanan: data.jenis_layanan || 'REGULER',
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

  // --- API MODE (Object Style with url: /3pl/Customer/...) ---
  try {
    const res = await api({
      url: `/3pl/Customer/${encodeURIComponent(resi)}`,
      method: 'PATCH',
      data: {
        nama_barang: data.nama_barang,
        pengirim: data.pengirim,
        alamat_pengirim: data.alamat_pengirim,
        telepon_pengirim: data.telepon_pengirim,
        penerima: data.penerima,
        alamat_tujuan: data.alamat_tujuan,
        telepon_penerima: data.telepon_penerima,
        berat_kg: data.berat_kg,
        jenis_layanan: data.jenis_layanan
      }
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

export async function getPakets(filters = {}) {
  let result = []
  if (USE_LOCAL_DATA) {
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
    // --- API MODE (Object Style with url: /3pl/Customer) ---
    const data = await api({
      url: '/3pl/Customer',
      method: 'GET',
      params: filters
    })
    result = data.pakets || []
  }

  return result.sort((a, b) => parseDateToTime(b.created_at) - parseDateToTime(a.created_at))
}

export async function getPaketByResi(nomorResi) {
  const resi = (nomorResi || '').trim().toUpperCase()
  if (!resi) {
    return { success: false, reason: 'EMPTY', message: 'Nomor resi tidak boleh kosong.' }
  }

  if (USE_LOCAL_DATA) {
    const paket = LOCAL_PAKETS.find((p) => p.nomor_resi === resi)
    if (!paket) {
      return { success: false, reason: 'NOT_FOUND', message: `Paket dengan resi ${resi} tidak ditemukan.` }
    }
    return { success: true, paket: { ...paket } }
  }

  // --- API MODE (Object Style with url: /3pl/Customer/:id) ---
  try {
    const data = await api({
      url: `/3pl/Customer/${encodeURIComponent(resi)}`,
      method: 'GET'
    })
    return { success: !!data.success, reason: data.reason, paket: data.paket, message: data.message }
  } catch (err) {
    return { success: false, reason: 'ERROR', message: err.message || 'Gagal mencari data paket.' }
  }
}