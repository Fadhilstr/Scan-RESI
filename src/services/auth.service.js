/**
 * auth.service.js — Service Layer Autentikasi (Request Object Style)
 *
 * Menggunakan gaya pemanggilan:
 *   api({
 *     url: '/api/auth/login',
 *     method: 'POST',
 *     data: { ... }
 *   })
 */
import api, { USE_LOCAL_DATA } from './api'
import { addAuditLog } from './audit.service'

const LOCAL_USERS = [
  {
    id: 'USR-ADMIN-001',
    name: 'Admin System',
    username: 'admin',
    password: 'admin123',
    role: 'ADMIN',
    status: 'ONLINE',
    lastLogin: '28-08-2026 08:00:00'
  },
  {
    id: 'USR-001',
    name: 'Fadhil',
    username: 'fadhil',
    password: 'fadhil123',
    role: 'PETUGAS_SCAN',
    status: 'ONLINE',
    lastLogin: '28-08-2026 10:20:00'
  },
  {
    id: 'USR-002',
    name: 'Budi',
    username: 'budi',
    password: 'budi123',
    role: 'PETUGAS_SCAN',
    status: 'ONLINE',
    lastLogin: '28-08-2026 09:45:00'
  },
  {
    id: 'USR-003',
    name: 'Andi',
    username: 'andi',
    password: 'andi123',
    role: 'PETUGAS_SCAN',
    status: 'OFFLINE',
    lastLogin: '23-08-2026 17:30:00'
  },
  {
    id: 'USR-CUST-001',
    name: 'Customer Demo',
    username: 'customer',
    password: 'cust123',
    role: 'CUSTOMER',
    status: 'OFFLINE',
    lastLogin: '28-08-2026 09:00:00'
  }
]

const nowString = () => {
  const now = new Date()
  const d = String(now.getDate()).padStart(2, '0')
  const m = String(now.getMonth() + 1).padStart(2, '0')
  const y = now.getFullYear()
  return `${d}-${m}-${y} ${now.toTimeString().split(' ')[0]}`
}

export async function login(username, password) {
  if (USE_LOCAL_DATA) {
    const user = LOCAL_USERS.find(
      (u) =>
        u.username.toLowerCase() === (username || '').trim().toLowerCase() &&
        u.password === password
    )

    if (!user) return { success: false, message: 'Username atau password salah.' }
    if (user.status === 'DISABLED') return { success: false, message: 'Akun Anda telah dinonaktifkan.' }

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

  // --- API MODE (Object Style with url) ---
  try {
    const data = await api({
      url: '/api/auth/login',
      method: 'POST',
      data: { username, password }
    })
    if (data.token) localStorage.setItem('wahana_token', data.token)
    return { success: true, user: data.user, role: data.user?.role, message: data.message }
  } catch (err) {
    return { success: false, message: err.message || 'Login gagal.' }
  }
}

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

  // --- API MODE (Object Style with url) ---
  try {
    const data = await api({
      url: '/api/auth/quick-login',
      method: 'POST',
      data: { user_id: userId }
    })
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

  // --- API MODE (Object Style with url) ---
  try {
    await api({
      url: '/api/auth/logout',
      method: 'POST',
      data: { user_id: userId }
    })
    localStorage.removeItem('wahana_token')
    return { success: true }
  } catch {
    return { success: true }
  }
}

export async function getUsers() {
  if (USE_LOCAL_DATA) {
    return [...LOCAL_USERS]
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: '/api/users',
    method: 'GET'
  })
  return data.users || []
}

export async function addUser(newUserData) {
  const role = typeof newUserData.role === 'object' && newUserData.role !== null
    ? (newUserData.role.value || newUserData.role.label || 'PETUGAS_SCAN')
    : (newUserData.role || 'PETUGAS_SCAN')

  if (USE_LOCAL_DATA) {
    const isCustomer = role === 'CUSTOMER'
    const newId = isCustomer
      ? `USR-CUST-${String(LOCAL_USERS.filter((u) => u.role === 'CUSTOMER').length + 1).padStart(3, '0')}`
      : `USR-${String(LOCAL_USERS.filter((u) => u.role !== 'CUSTOMER').length + 1).padStart(3, '0')}`

    const created = {
      id: newId,
      name: newUserData.name,
      username: newUserData.username,
      password: newUserData.password || '123456',
      role,
      status: 'OFFLINE',
      lastLogin: '-'
    }
    LOCAL_USERS.push(created)
    return { success: true, user: { ...created } }
  }

  // --- API MODE (Object Style with url) ---
  const payload = {
    ...newUserData,
    role
  }
  const data = await api({
    url: '/api/users',
    method: 'POST',
    data: payload
  })
  return { success: true, user: data.user }
}

export async function toggleUserStatus(userId) {
  if (USE_LOCAL_DATA) {
    const target = LOCAL_USERS.find((u) => u.id === userId)
    if (!target) return { success: false }
    target.status = target.status === 'DISABLED' ? 'OFFLINE' : 'DISABLED'
    return { success: true, newStatus: target.status }
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: `/api/users/${encodeURIComponent(userId)}/status`,
    method: 'PATCH'
  })
  return { success: true, newStatus: data.newStatus }
}

export async function updateUser(userId, userData) {
  const role = typeof userData.role === 'object' && userData.role !== null
    ? (userData.role.value || userData.role.label || 'PETUGAS_SCAN')
    : (userData.role || 'PETUGAS_SCAN')

  if (USE_LOCAL_DATA) {
    const idx = LOCAL_USERS.findIndex((u) => u.id === userId)
    if (idx === -1) return { success: false, message: 'User tidak ditemukan.' }
    LOCAL_USERS[idx] = {
      ...LOCAL_USERS[idx],
      name: userData.name || LOCAL_USERS[idx].name,
      username: userData.username || LOCAL_USERS[idx].username,
      role
    }
    if (userData.password) LOCAL_USERS[idx].password = userData.password
    return { success: true, user: { ...LOCAL_USERS[idx] } }
  }

  // --- API MODE (Object Style with url) ---
  const payload = {
    ...userData,
    role
  }
  const data = await api({
    url: `/api/users/${encodeURIComponent(userId)}`,
    method: 'PUT',
    data: payload
  })
  return data
}

export async function deleteUser(userId) {
  if (USE_LOCAL_DATA) {
    const idx = LOCAL_USERS.findIndex((u) => u.id === userId)
    if (idx === -1) return { success: false, message: 'User tidak ditemukan.' }
    LOCAL_USERS.splice(idx, 1)
    return { success: true, message: 'User berhasil dihapus.' }
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: `/api/users/${encodeURIComponent(userId)}`,
    method: 'DELETE'
  })
  return data
}
