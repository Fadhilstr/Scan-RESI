/**
 * audit.service.js — Service Layer Audit Log (Request Object Style)
 *
 * Menggunakan gaya pemanggilan:
 *   api({
 *     url: '/api/audit-logs',
 *     method: 'GET',
 *     params: { ... }
 *   })
 */
import api, { USE_LOCAL_DATA } from './api'

let LOCAL_AUDIT_LOGS = [
  {
    log_id: 3,
    user_id: 'USR-002',
    user_name: 'Budi',
    action: 'LOGIN_SUCCESS',
    details: 'Login berhasil.',
    ip_address: '192.168.3.102 (demo)',
    created_at: '28-08-2026 09:45:00'
  }
]

const nowString = () => {
  const now = new Date()
  const d = String(now.getDate()).padStart(2, '0')
  const m = String(now.getMonth() + 1).padStart(2, '0')
  const y = now.getFullYear()
  return `${d}-${m}-${y} ${now.toTimeString().split(' ')[0]}`
}

export async function getAuditLogs(filters = {}) {
  if (USE_LOCAL_DATA) {
    let result = [...LOCAL_AUDIT_LOGS]
    if (filters.user_id) result = result.filter((l) => l.user_id === filters.user_id)
    if (filters.action) result = result.filter((l) => l.action === filters.action)
    return result.sort((a, b) => b.log_id - a.log_id)
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: '/api/audit-logs',
    method: 'GET',
    params: filters
  })
  return data.logs || []
}

export async function addAuditLog(event) {
  if (!USE_LOCAL_DATA) {
    return { success: true, log: null }
  }

  const entry = {
    log_id: Math.max(0, ...LOCAL_AUDIT_LOGS.map((l) => l.log_id)) + 1,
    user_id: event.user_id || '-',
    user_name: event.user_name || '-',
    action: event.action,
    details: event.details || '',
    ip_address: '127.0.0.1 (local)',
    created_at: nowString()
  }

  LOCAL_AUDIT_LOGS.unshift(entry)
  return { success: true, log: { ...entry } }
}
