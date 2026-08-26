/**
 * api.js — Axios Instance Terpusat
 *
 * File ini adalah satu-satunya tempat yang perlu diubah
 * ketika integrasi backend Perl + Nginx dilakukan.
 *
 * Cara switch ke backend nyata:
 *   1. Set VITE_API_BASE_URL=http://<IP-SERVER>:<PORT> di file .env
 *   2. Set VITE_USE_LOCAL_DATA=false di file .env
 *   3. Restart dev server
 *
 * TIDAK ADA perubahan pada UI, komponen, halaman, atau store logic.
 */

import axios from 'axios'

// =====================================================================
// MODE FLAG — dikontrol dari .env
// =====================================================================
export const USE_LOCAL_DATA = import.meta.env.VITE_USE_LOCAL_DATA !== 'false'

// =====================================================================
// AXIOS INSTANCE
// Digunakan ketika USE_LOCAL_DATA = false (mode produksi / backend real)
// =====================================================================
const api = axios.create({
  // Kosongkan VITE_API_BASE_URL agar request same-origin ('/api/...'):
  //   - quasar dev        → diproxy ke backend oleh devServer.proxy
  //   - produksi (Nginx)  → diproxy oleh deploy/nginx.conf
  baseURL: import.meta.env.VITE_API_BASE_URL || '',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json'
  }
})

// =====================================================================
// REQUEST INTERCEPTOR — inject token JWT/HMAC dari localStorage
// Token diterbitkan oleh POST /api/auth/login (backend Perl).
// =====================================================================
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('wahana_token')
    if (token) config.headers.Authorization = `Bearer ${token}`
    return config
  },
  (error) => Promise.reject(error)
)

// =====================================================================
// RESPONSE INTERCEPTOR — Global error handler
// =====================================================================
api.interceptors.response.use(
  (response) => response.data,
  (error) => {
    const status = error.response?.status
    const message = error.response?.data?.message || error.message || 'Terjadi kesalahan pada server.'

    // Token expired / unauthorized
    if (status === 401) {
      // Optional: redirect ke /login
      console.warn('[API] Unauthorized - session mungkin sudah habis.')
    }

    return Promise.reject({ status, message })
  }
)

export default api
