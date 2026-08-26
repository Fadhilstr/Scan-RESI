/**
 * scanStore.js — Pinia Store Scan Event
 *
 * Store ini hanya mengelola STATE (data reaktif).
 * Semua logika I/O (local data / HTTP API) didelegasikan ke scan.service.js.
 *
 * Untuk switch ke backend Perl:
 *   → Ubah VITE_USE_LOCAL_DATA=false di file .env
 *   → Tidak ada perubahan di file ini maupun di komponen UI.
 */

import { defineStore } from 'pinia'
import {
  getScans as svcGetScans,
  addScan as svcAddScan,
  getUserScanStats as svcGetUserStats,
  LOCAL_SCANS
} from '../services/scan.service'
import { useTaskStore } from './taskStore'
import { USE_LOCAL_DATA } from '../services/api'

export const useScanStore = defineStore('scan', {
  state: () => ({
    // Scan events list (diisi via fetchScans)
    scanEvents: [],

    // Loading & error state
    isLoading: false,
    error: null
  }),

  getters: {
    /**
     * Filter scan events berdasarkan role & scope user.
     * Logic ini selalu berjalan di frontend (tidak berubah meski data dari API).
     *
     * - ADMIN       : Semua data
     * - SUPERVISOR  : Hanya data tim bawahan (supervisedUserIds)
     * - PETUGAS_SCAN: Hanya data milik sendiri
     */
    getFilteredScans: (state) => (currentUser, supervisedUserIds = []) => {
      if (!currentUser) return []

      if (currentUser.role === 'ADMIN') {
        return state.scanEvents
      }

      if (currentUser.role === 'SUPERVISOR') {
        return state.scanEvents.filter((scan) => supervisedUserIds.includes(scan.user_id))
      }

      if (currentUser.role === 'PETUGAS_SCAN') {
        return state.scanEvents.filter((scan) => scan.user_id === currentUser.id)
      }

      return []
    },

    /**
     * Statistik scan untuk user tertentu (dihitung dari state lokal).
     * Jika MODE API, gunakan action fetchUserScanStats() untuk data real dari server.
     */
    getUserScanStats: (state) => (userId) => {
      const userScans = state.scanEvents.filter((s) => s.user_id === userId)
      const successScans = userScans.filter((s) => s.status_scan === 'SUCCESS')
      const duplicateScans = userScans.filter((s) => s.status_scan === 'DUPLICATE')
      const lastScan = userScans.length > 0 ? userScans[0].waktu_scan : '-'
      return {
        total: successScans.length,
        success: successScans.length,
        duplicate: duplicateScans.length,
        lastScan
      }
    }
  },

  actions: {
    /**
     * Ambil semua scan events dari service (local/API).
     */
    async fetchScans(filters = {}) {
      this.isLoading = true
      try {
        this.scanEvents = await svcGetScans(filters)
      } catch (err) {
        this.error = err.message
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Proses scan barcode resi.
     * Memanggil scan.service.js → validasi duplikat → increment task progress.
     */
    async addScanEvent({ resi, currentUser, activeTask, lokasi, device_id, jenis_scan }) {
      const result = await svcAddScan({ resi, currentUser, activeTask, lokasi, device_id, jenis_scan })

      if (USE_LOCAL_DATA) {
        // Sync state dari LOCAL_SCANS (sudah diupdate oleh service)
        this.scanEvents = [...LOCAL_SCANS]

        // Sync task progress di taskStore
        if (result.success) {
          const taskStore = useTaskStore()
          taskStore.incrementTaskProgress(activeTask.task_id)
        }
      } else {
        // MODE API: increment progress dilakukan server-side secara transaksional.
        // Sinkronkan ulang scan list + task agar UI (capaian target) reaktif.
        if (result.success || result.reason === 'DUPLICATE') {
          const taskStore = useTaskStore()
          await Promise.all([this.fetchScans(), taskStore.fetchTasks()])
        }
      }

      return result
    }
  }
})
