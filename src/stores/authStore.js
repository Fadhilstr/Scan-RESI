/**
 * authStore.js — Pinia Store Autentikasi
 *
 * Store ini hanya mengelola STATE (data reaktif).
 * Semua logika I/O (local data / HTTP API) didelegasikan ke auth.service.js.
 *
 * Untuk switch ke backend Perl:
 *   → Ubah VITE_USE_LOCAL_DATA=false di file .env
 *   → Tidak ada perubahan di file ini maupun di komponen UI.
 */

import { defineStore } from 'pinia'
import {
  login as svcLogin,
  quickLogin as svcQuickLogin,
  logout as svcLogout,
  getUsers as svcGetUsers,
  addUser as svcAddUser,
  updateUser as svcUpdateUser,
  deleteUser as svcDeleteUser,
  toggleUserStatus as svcToggleUserStatus
} from '../services/auth.service'
import { useTaskStore } from './taskStore'
import { useScanStore } from './scanStore'
import { usePaketStore } from './paketStore'

const getSavedUser = () => {
  try {
    const raw = localStorage.getItem('wahana_user')
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

const savedUser = getSavedUser()

export const useAuthStore = defineStore('auth', {
  state: () => ({
    currentUser: savedUser,
    isLoggedIn: !!savedUser && (import.meta.env.VITE_USE_LOCAL_DATA === 'true' || !!localStorage.getItem('wahana_token')),

    // Daftar user (diisi via fetchUsers)
    users: [],

    // Loading & error state — digunakan UI untuk menampilkan spinner / pesan
    isLoading: false,
    error: null
  }),

  getters: {
    role: (state) => state.currentUser?.role || null,
    isAdmin: (state) => state.currentUser?.role === 'ADMIN',
    isDeveloper: (state) => state.currentUser?.role === 'DEVELOPER',
    isPetugas: (state) => state.currentUser?.role === 'PETUGAS_SCAN',
    isCustomer: (state) => state.currentUser?.role === 'CUSTOMER',

    allPetugas: (state) => state.users.filter((u) => u.role === 'PETUGAS_SCAN')
  },

  actions: {
    /**
     * Prefetch semua data operasional SETELAH sesi aktif.
     * Wajib di MODE API karena boot tidak melakukan fetch saat belum login.
     */
    async prefetchOperationalData() {
      const taskStore = useTaskStore()
      const scanStore = useScanStore()
      const paketStore = usePaketStore()
      await Promise.all([
        this.fetchUsers(),
        taskStore.fetchTasks(),
        scanStore.fetchScans(),
        paketStore.fetchPakets()
      ])
    },

    /**
     * Login dengan username & password.
     * Memanggil auth.service.js → local dummy atau POST /api/auth/login
     */
    async login(username, password) {
      this.isLoading = true
      this.error = null
      try {
        const result = await svcLogin(username, password)
        if (result.success) {
          this.currentUser = result.user
          this.isLoggedIn = true
          localStorage.setItem('wahana_user', JSON.stringify(result.user))
          await this.prefetchOperationalData()
        }
        return result
      } catch (err) {
        this.error = err.message
        return { success: false, message: err.message }
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Quick login bypass password (hanya untuk prototype/demo).
     */
    async quickLogin(userId) {
      this.isLoading = true
      this.error = null
      try {
        const result = await svcQuickLogin(userId)
        if (result.success) {
          this.currentUser = result.user
          this.isLoggedIn = true
          localStorage.setItem('wahana_user', JSON.stringify(result.user))
          await this.prefetchOperationalData()
        }
        return result
      } catch (err) {
        this.error = err.message
        return { success: false, message: err.message }
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Logout user aktif.
     */
    async logout() {
      if (this.currentUser) {
        await svcLogout(this.currentUser.id)
      }
      this.currentUser = null
      this.isLoggedIn = false
      localStorage.removeItem('wahana_user')
      localStorage.removeItem('wahana_token')
    },

    /**
     * Ambil daftar semua user dari service (local/API).
     */
    async fetchUsers() {
      try {
        this.users = await svcGetUsers()
      } catch (err) {
        this.error = err.message
      }
    },

    /**
     * Tambah user baru.
     */
    async addUser(newUserData) {
      this.isLoading = true
      try {
        const result = await svcAddUser(newUserData)
        if (result.success) {
          await this.fetchUsers()
        }
        return result
      } catch (err) {
        return { success: false, message: err.message }
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Update data user.
     */
    async updateUser(userId, userData) {
      this.isLoading = true
      try {
        const result = await svcUpdateUser(userId, userData)
        if (result.success) {
          await this.fetchUsers()
        }
        return result
      } catch (err) {
        return { success: false, message: err.message }
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Hapus user.
     */
    async deleteUser(userId) {
      this.isLoading = true
      try {
        const result = await svcDeleteUser(userId)
        if (result.success) {
          await this.fetchUsers()
        }
        return result
      } catch (err) {
        return { success: false, message: err.message }
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Toggle status user (ACTIVE <-> DISABLED).
     */
    async toggleUserStatus(userId) {
      try {
        const result = await svcToggleUserStatus(userId)
        if (result.success) {
          await this.fetchUsers()
        }
        return result
      } catch (err) {
        return { success: false, message: err.message }
      }
    }
  }
})
