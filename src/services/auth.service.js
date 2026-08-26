/**
 * auth.service.js — Service Layer Autentikasi
 *
 * Semua operasi autentikasi dan manajemen user ada di sini.
 *
 * MODE LOCAL (VITE_USE_LOCAL_DATA=true):
 *   Menggunakan data dummy array lokal.
 *
 * MODE API (VITE_USE_LOCAL_DATA=false):
 *   Menggunakan HTTP calls ke backend Perl via axios.
 *   Endpoint yang dituju:
 *     POST   /api/auth/login
 *     POST   /api/auth/logout
 *     GET    /api/users
 *     POST   /api/users
 *     PATCH  /api/users/:id/status
 */

import api, { USE_LOCAL_DATA } from './api'
import { addAuditLog } from './audit.service'

// =====================================================================
// LOCAL DUMMY DATA — Digunakan saat USE_LOCAL_DATA=true
// =====================================================================
const LOCAL_USERS = [
  {
    id: 'USR-ADMIN-001',
    name: 'Admin System',
    username: 'admin',
    password: 'admin123',
    role: 'ADMIN',
    supervisor_id: null,
    status: 'ONLINE',
    lastLogin: '24-08-2026 08:00:00'
  },
  {
    id: 'USR-SPV-001',
    name: 'Supervisor A',
    username: 'supervisor',
    password: 'supervisor123',
    role: 'SUPERVISOR',
    supervisor_id: null,
    status: 'ONLINE',
    lastLogin: '24-08-2026 08:15:00'
  },
  {
    id: 'USR-001',
    name: 'Fadhil',
    username: 'fadhil',
    password: 'fadhil123',
    role: 'PETUGAS_SCAN',
    supervisor_id: 'USR-SPV-001',
    status: 'ONLINE',
    lastLogin: '24-08-2026 10:20:00'
  },
  {
    id: 'USR-002',
    name: 'Budi',
    username: 'budi',
    password: 'budi123',
    role: 'PETUGAS_SCAN',
    supervisor_id: 'USR-SPV-001',
    status: 'ONLINE',
    lastLogin: '24-08-2026 09:45:00'
  },
  {
    id: 'USR-003',
    name: 'Andi',
    username: 'andi',
    password: 'andi123',
    role: 'PETUGAS_SCAN',
    supervisor_id: 'USR-SPV-001',
    status: 'OFFLINE',
    lastLogin: '23-08-2026 17:30:00'
  },
  {
    id: 'USR-CUST-001',
    name: 'Customer Demo',
    username: 'customer',
    password: 'cust123',
    role: 'CUSTOMER',
    supervisor_id: null,
    status: 'OFFLINE',
    lastLogin: '24-08-2026 09:00:00'
  }
]

// Helper: format datetime string
const nowString = () => {
  const now = new Date()
  const d = String(now.getDate()).padStart(2, '0')
  const m = String(now.getMonth() + 1).padStart(2, '0')
  const y = now.getFullYear()
  return `${d}-${m}-${y} ${now.toTimeString().split(' ')[0]}`
}

// =====================================================================
// SERVICE FUNCTIONS
// =====================================================================

/**
 * Login user dengan username & password.
 * @returns {Promise<{success, user, role, message}>}
 */
export async function login(username, password) {
  if (USE_LOCAL_DATA) {
    // --- LOCAL MODE ---
    const user = LOCAL_USERS.find(
      (u) =>
        u.username.toLowerCase() === (username || '').trim().toLowerCase() &&
        u.password === password
    )

    if (!user) {
      return { success: false, message: 'Username atau password salah.' }
    }

    if (user.status === 'DISABLED') {
      return { success: false, message: 'Akun Anda telah dinonaktifkan.' }
    }

    user.status = 'ONLINE'
    user.lastLogin = nowString()

    await addAuditLog({
      user_id: user.id,
      user_name: user.name,
      action: 'LOGIN_SUCCESS',
      details: 'Login berhasil via form.'
    })

    return {
      success: true,
      user: { ...user },
      role: user.role,
      message: `Selamat datang, ${user.name}!`
    }
  }

  // --- API MODE ---
  // POST /api/auth/login
  // Response JSON dari Perl: { success, user, token, message }
  // (Server mencatat LOGIN_SUCCESS ke tabel AUDIT_LOGS secara otomatis.)
  try {
    const data = await api.post('/api/auth/login', { username, password })
    // Simpan JWT token jika ada
    if (data.token) localStorage.setItem('wahana_token', data.token)
    return { success: true, user: data.user, role: data.user?.role, message: data.message }
  } catch (err) {
    return { success: false, message: err.message || 'Login gagal.' }
  }
}

/**
 * Quick login 1-click untuk demo (PRD FR-1.2).
 * MODE LOCAL : bypass password dari data dummy.
 * MODE API   : POST /api/auth/quick-login (endpoint demo backend).
 * @returns {Promise<{success, user, role, message}>}
 */
export async function quickLogin(userId) {
  if (USE_LOCAL_DATA) {
    const user = LOCAL_USERS.find((u) => u.id === userId)
    if (!user) return { success: false, message: 'User tidak ditemukan.' }
    user.status = 'ONLINE'
    user.lastLogin = nowString()

    await addAuditLog({
      user_id: user.id,
      user_name: user.name,
      action: 'LOGIN_SUCCESS',
      details: '1-Click Quick Login Demo.'
    })

    return {
      success: true,
      user: { ...user },
      role: user.role,
      message: `Login instan sebagai ${user.name} (${user.role})`
    }
  }

  // --- API MODE ---
  // POST /api/auth/quick-login (endpoint demo sesuai PRD FR-1.2)
  try {
    const data = await api.post('/api/auth/quick-login', { user_id: userId })
    if (data.token) localStorage.setItem('wahana_token', data.token)
    return {
      success: true,
      user: data.user,
      role: data.user?.role,
      message: data.message
    }
  } catch (err) {
    return { success: false, message: err.message || 'Quick login gagal.' }
  }
}

/**
 * Logout user.
 */
export async function logout(userId) {
  if (USE_LOCAL_DATA) {
    const user = LOCAL_USERS.find((u) => u.id === userId)
    if (user) {
      user.status = 'OFFLINE'
      await addAuditLog({
        user_id: user.id,
        user_name: user.name,
        action: 'LOGOUT',
        details: 'User keluar dari sistem.'
      })
    }
    return { success: true }
  }

  // --- API MODE ---
  // POST /api/auth/logout
  try {
    await api.post('/api/auth/logout', { user_id: userId })
    localStorage.removeItem('wahana_token')
    return { success: true }
  } catch {
    return { success: true } // logout local tetap berhasil
  }
}

/**
 * Ambil seluruh daftar user dari sistem.
 * @returns {Promise<User[]>}
 */
export async function getUsers() {
  if (USE_LOCAL_DATA) {
    return [...LOCAL_USERS]
  }

  // --- API MODE ---
  // GET /api/users
  // Response: { users: [...] }
  const data = await api.get('/api/users')
  return data.users || []
}

/**
 * Tambah user baru.
 * @returns {Promise<{success, user}>}
 */
export async function addUser(newUserData) {
  if (USE_LOCAL_DATA) {
    const newId = `USR-${String(LOCAL_USERS.length + 1).padStart(3, '0')}`
    const created = {
      id: newId,
      name: newUserData.name,
      username: newUserData.username,
      password: newUserData.password || '123456',
      role: newUserData.role || 'PETUGAS_SCAN',
      supervisor_id: newUserData.supervisor_id || 'USR-SPV-001',
      status: 'OFFLINE',
      lastLogin: '-'
    }
    LOCAL_USERS.push(created)
    return { success: true, user: { ...created } }
  }

  // --- API MODE ---
  // POST /api/users
  const data = await api.post('/api/users', newUserData)
  return { success: true, user: data.user }
}

/**
 * Toggle status user (ACTIVE <-> DISABLED).
 * @returns {Promise<{success, newStatus}>}
 */
export async function toggleUserStatus(userId) {
  if (USE_LOCAL_DATA) {
    const target = LOCAL_USERS.find((u) => u.id === userId)
    if (!target) return { success: false }
    target.status = target.status === 'DISABLED' ? 'OFFLINE' : 'DISABLED'
    return { success: true, newStatus: target.status }
  }

  // --- API MODE ---
  // PATCH /api/users/:id/status
  const data = await api.patch(`/api/users/${userId}/status`)
  return { success: true, newStatus: data.status }
}
