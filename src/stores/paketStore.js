/**
 * paketStore.js — Pinia Store Paket (Master Data Barang)
 *
 * Store ini hanya mengelola STATE (data reaktif).
 * Semua logika I/O didelegasikan ke paket.service.js.
 *
 * Prinsip inti: nomor resi dibuat BACKEND (via generateResi),
 * barcode dirender komponen UI dari nomor resi tersebut.
 */

import { defineStore } from 'pinia'
import {
  getPakets as svcGetPakets,
  generateResi as svcGenerateResi,
  savePaketData as svcSavePaketData,
  getPaketByResi as svcGetPaketByResi,
  parseDateToTime,
  LOCAL_PAKETS
} from '../services/paket.service'
import { USE_LOCAL_DATA } from '../services/api'

export const usePaketStore = defineStore('paket', {
  state: () => ({
    // Daftar paket sesuai scope user aktif
    pakets: [],

    isLoading: false,
    error: null
  }),

  getters: {
    /**
     * Scope daftar paket berdasarkan role:
     * - CUSTOMER : hanya paket buatannya sendiri
     * - Role lain: semua (backend juga menegakkan ini)
     */
    getScopedPakets: (state) => (currentUser) => {
      if (!currentUser) return []
      let list = state.pakets
      if (currentUser.role === 'CUSTOMER' && USE_LOCAL_DATA) {
        list = state.pakets.filter((p) => p.created_by === currentUser.id)
      }
      return [...list].sort((a, b) => parseDateToTime(b.created_at) - parseDateToTime(a.created_at))
    },

    /**
     * Cari paket by resi dari state yang sudah termuat.
     */
    findPaketByResi: (state) => (nomorResi) => {
      const resi = (nomorResi || '').trim().toUpperCase()
      return state.pakets.find((p) => p.nomor_resi === resi) || null
    },

    stats: (state) => {
      const terdaftar = state.pakets.filter((p) => p.status === 'TERDAFTAR')
      const draft = state.pakets.filter((p) => p.status === 'DRAFT')
      return { total: state.pakets.length, terdaftar: terdaftar.length, draft: draft.length }
    }
  },

  actions: {
    /**
     * Muat daftar paket dari service.
     */
    async fetchPakets(filters = {}) {
      this.isLoading = true
      try {
        this.pakets = await svcGetPakets(filters)
      } catch (err) {
        this.error = err.message
      } finally {
        this.isLoading = false
      }
    },

    /**
     * Generate nomor resi baru via backend → baris DRAFT.
     * @returns {{success, paket?, reason?, message?}}
     */
    async createResi(currentUser) {
      const result = await svcGenerateResi(currentUser)

      if (USE_LOCAL_DATA) {
        if (result.success) {
          this.pakets = [...LOCAL_PAKETS]
        }
      } else if (result.success) {
        // Sinkronkan ulang agar daftar reaktif dengan data server
        await this.fetchPakets()
      }

      return result
    },

    /**
     * Simpan data barang paket DRAFT → TERDAFTAR.
     */
    async saveData(nomorResi, data, currentUser) {
      const result = await svcSavePaketData(nomorResi, data, currentUser)

      if (USE_LOCAL_DATA) {
        this.pakets = [...LOCAL_PAKETS]
      } else if (result.success) {
        await this.fetchPakets()
      }

      return result
    },

    /**
     * Lookup satu paket by resi — selalu langsung ke service
     * agar data terbaru (dipakai petugas setelah scan).
     */
    async lookupByResi(nomorResi) {
      return await svcGetPaketByResi(nomorResi)
    }
  }
})
