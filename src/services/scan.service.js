/**
 * scan.service.js — Service Layer Scan Event (Request Object Style)
 *
 * Menggunakan gaya pemanggilan:
 *   api({
 *     url: '/api/scans',
 *     method: 'POST',
 *     data: { ... }
 *   })
 */
import api, { USE_LOCAL_DATA } from './api'
import { incrementTaskProgress } from './task.service'
import { addAuditLog } from './audit.service'
import { LOCAL_PAKETS, getWIBTimeString } from './paket.service'

const nowString = () => getWIBTimeString()

export const LOCAL_SCANS = [
  {
    scan_id: 'SCN-00001',
    nomor_resi: 'GJXL8FLB',
    user_id: 'USR-001',
    user_name: 'Fadhil',
    task_id: 'TASK-001',
    waktu_scan: '28-08-2026 10:21:32',
    lokasi: 'CIPUTAT',
    status_scan: 'SUCCESS',
    device_id: 'SCAN-DEVICE-01',
    jenis_scan: 'INBOUND'
  }
]

export async function getScans(filters = {}) {
  if (USE_LOCAL_DATA) {
    let result = [...LOCAL_SCANS]
    if (filters.user_id) result = result.filter((s) => s.user_id === filters.user_id)
    if (filters.task_id) result = result.filter((s) => s.task_id === filters.task_id)
    if (filters.status_scan) result = result.filter((s) => s.status_scan === filters.status_scan)
    return result
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: '/api/scans',
    method: 'GET',
    params: filters
  })
  return data.scans || []
}

export async function addScan({ resi, currentUser, activeTask, lokasi = 'CIPUTAT', device_id = 'SCAN-DEVICE-01', jenis_scan = 'INBOUND' }) {
  const sanitizedResi = (resi || '').trim().toUpperCase()

  if (!sanitizedResi) {
    return { success: false, reason: 'EMPTY', message: 'Nomor resi tidak boleh kosong.' }
  }

  if (!activeTask || activeTask.status === 'SELESAI') {
    return { success: false, reason: 'FINISHED', message: 'Task sudah selesai dan tidak dapat melakukan scan.' }
  }

  if (USE_LOCAL_DATA) {
    const paketTerdaftar = LOCAL_PAKETS.find((p) => p.nomor_resi.toUpperCase() === sanitizedResi)
    if (!paketTerdaftar) {
      await addAuditLog({
        user_id: currentUser.id,
        user_name: currentUser.name,
        action: 'SCAN_REJECTED',
        details: `Resi: ${sanitizedResi}, Status: UNKNOWN_RESI`
      })
      return {
        success: false,
        reason: 'UNKNOWN_RESI',
        message: `Nomor resi ${sanitizedResi} tidak terdaftar. Pastikan customer sudah membuat resi.`
      }
    }
    if (paketTerdaftar.status !== 'TERDAFTAR') {
      await addAuditLog({
        user_id: currentUser.id,
        user_name: currentUser.name,
        action: 'SCAN_REJECTED',
        details: `Resi: ${sanitizedResi}, Status: DRAFT`
      })
      return {
        success: false,
        reason: 'DRAFT',
        message: `Nomor resi ${sanitizedResi} masih DRAFT — data barang belum disimpan customer.`
      }
    }

    const isDuplicate = LOCAL_SCANS.some(
      (evt) =>
        evt.task_id === activeTask.task_id &&
        evt.nomor_resi.toUpperCase() === sanitizedResi &&
        evt.status_scan === 'SUCCESS'
    )

    const newScan = {
      scan_id: `SCN-${String(LOCAL_SCANS.length + 1).padStart(5, '0')}`,
      nomor_resi: sanitizedResi,
      user_id: currentUser.id,
      user_name: currentUser.name,
      task_id: activeTask.task_id,
      waktu_scan: nowString(),
      lokasi,
      status_scan: isDuplicate ? 'DUPLICATE' : 'SUCCESS',
      device_id,
      jenis_scan
    }

    LOCAL_SCANS.unshift(newScan)

    await addAuditLog({
      user_id: currentUser.id,
      user_name: currentUser.name,
      action: isDuplicate ? 'SCAN_DUPLICATE' : 'SCAN_EVENT_CREATED',
      details: `Resi: ${sanitizedResi}, Status: ${isDuplicate ? 'DUPLICATE' : 'SUCCESS'}`
    })

    if (isDuplicate) {
      return {
        success: false,
        reason: 'DUPLICATE',
        message: `Nomor resi ${sanitizedResi} sudah pernah discan.`,
        scan: { ...newScan }
      }
    }

    await incrementTaskProgress(activeTask.task_id)

    return {
      success: true,
      resi: sanitizedResi,
      message: `Nomor resi ${sanitizedResi} berhasil discan.`,
      scan: { ...newScan }
    }
  }

  // --- API MODE (Object Style with url) ---
  try {
    const data = await api({
      url: '/api/scans',
      method: 'POST',
      data: {
        nomor_resi: sanitizedResi,
        user_id: currentUser.id,
        user_name: currentUser.name,
        task_id: activeTask.task_id,
        lokasi,
        device_id,
        jenis_scan
      }
    })

    if (data.reason === 'UNKNOWN_RESI' || data.reason === 'DRAFT') {
      return {
        success: false,
        reason: data.reason,
        message: data.message || `Nomor resi ${sanitizedResi} tidak dapat discan.`
      }
    }

    if (data.status_scan === 'DUPLICATE') {
      return {
        success: false,
        reason: 'DUPLICATE',
        message: data.message || `Nomor resi ${sanitizedResi} sudah pernah discan.`,
        scan: data.scan
      }
    }

    return {
      success: true,
      resi: sanitizedResi,
      message: data.message || `Nomor resi ${sanitizedResi} berhasil discan.`,
      scan: data.scan
    }
  } catch (err) {
    return { success: false, reason: 'ERROR', message: err.message || 'Gagal mengirim scan event.' }
  }
}

export async function getUserScanStats(userId) {
  if (USE_LOCAL_DATA) {
    const userScans = LOCAL_SCANS.filter((s) => s.user_id === userId)
    const success = userScans.filter((s) => s.status_scan === 'SUCCESS').length
    const duplicate = userScans.filter((s) => s.status_scan === 'DUPLICATE').length
    const lastScan = userScans.length > 0 ? userScans[0].waktu_scan : '-'
    return { total: success, success, duplicate, lastScan }
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: `/api/scans/stats/${encodeURIComponent(userId)}`,
    method: 'GET'
  })
  return data.stats || { total: 0, success: 0, duplicate: 0, lastScan: '-' }
}
