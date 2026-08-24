import { defineStore } from 'pinia'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    // Initial login state defaults to Fadhil for quick testing, but can be changed anytime
    currentUser: {
      id: 'USR-001',
      name: 'Fadhil',
      username: 'fadhil',
      role: 'PETUGAS_SCAN',
      supervisor_id: 'USR-SPV-001',
      status: 'ONLINE',
      lastLogin: '24-08-2026 10:20:00'
    },
    isLoggedIn: true,

    // Dummy user list (Requirement AA & I)
    users: [
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
      }
    ]
  }),

  getters: {
    role: (state) => state.currentUser?.role || null,
    isAdmin: (state) => state.currentUser?.role === 'ADMIN',
    isSupervisor: (state) => state.currentUser?.role === 'SUPERVISOR',
    isPetugas: (state) => state.currentUser?.role === 'PETUGAS_SCAN',

    // Get list of petugas supervised by a supervisor ID (Requirement F)
    supervisedPetugas: (state) => (supervisorId) => {
      return state.users.filter(u => u.supervisor_id === supervisorId && u.role === 'PETUGAS_SCAN')
    },

    allPetugas: (state) => state.users.filter(u => u.role === 'PETUGAS_SCAN'),
    allSupervisors: (state) => state.users.filter(u => u.role === 'SUPERVISOR')
  },

  actions: {
    login(usernameInput, passwordInput) {
      const user = this.users.find(
        (u) => u.username.toLowerCase() === (usernameInput || '').trim().toLowerCase() && u.password === passwordInput
      )

      if (user) {
        if (user.status === 'DISABLED') {
          return { success: false, message: 'Akun Anda telah dinonaktifkan.' }
        }

        const now = new Date()
        user.status = 'ONLINE'
        user.lastLogin = `${String(now.getDate()).padStart(2, '0')}-${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()} ${now.toTimeString().split(' ')[0]}`

        this.currentUser = { ...user }
        this.isLoggedIn = true

        return {
          success: true,
          role: user.role,
          message: `Selamat datang, ${user.name}!`
        }
      }

      return {
        success: false,
        message: 'Username atau password salah.'
      }
    },

    quickLogin(userId) {
      const user = this.users.find((u) => u.id === userId)
      if (user) {
        const now = new Date()
        user.status = 'ONLINE'
        user.lastLogin = `${String(now.getDate()).padStart(2, '0')}-${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()} ${now.toTimeString().split(' ')[0]}`

        this.currentUser = { ...user }
        this.isLoggedIn = true

        return {
          success: true,
          role: user.role,
          message: `Login instan sebagai ${user.name} (${user.role})`
        }
      }
      return { success: false, message: 'User tidak ditemukan.' }
    },

    logout() {
      if (this.currentUser) {
        const target = this.users.find((u) => u.id === this.currentUser.id)
        if (target) target.status = 'OFFLINE'
      }
      this.currentUser = null
      this.isLoggedIn = false
    },

    toggleUserStatus(userId) {
      const target = this.users.find((u) => u.id === userId)
      if (target) {
        target.status = target.status === 'DISABLED' ? 'OFFLINE' : 'DISABLED'
        return { success: true, newStatus: target.status }
      }
      return { success: false }
    },

    addUser(newUser) {
      const newId = `USR-${String(this.users.length + 1).padStart(3, '0')}`
      const created = {
        id: newId,
        name: newUser.name,
        username: newUser.username,
        password: newUser.password || '123456',
        role: newUser.role || 'PETUGAS_SCAN',
        supervisor_id: newUser.supervisor_id || 'USR-SPV-001',
        status: 'OFFLINE',
        lastLogin: '-'
      }
      this.users.push(created)
      return { success: true, user: created }
    }
  }
})
