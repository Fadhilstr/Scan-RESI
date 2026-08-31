import { route } from 'quasar/wrappers'
import { Notify } from 'quasar'
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory
} from 'vue-router'

import routes from './routes.js'
import { useAuthStore } from '../stores/authStore'

export default route((/* { store, ssrContext } */) => {
  const createHistory = import.meta.env.QUASAR_SERVER
    ? createMemoryHistory
    : (import.meta.env.QUASAR_VUE_ROUTER_MODE === 'history' ? createWebHistory : createWebHashHistory)

  const Router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,
    history: createHistory(import.meta.env.QUASAR_VUE_ROUTER_BASE)
  })

  // Role Protection Guard (Strict Multi-Layer RBAC)
  Router.beforeEach((to, from, next) => {
    const authStore = useAuthStore()

    // 1. Jika belum login dan mengakses rute berproteksi -> arahkan ke login
    if (to.meta.requiresAuth && !authStore.isLoggedIn) {
      return next({ name: 'login' })
    }

    // 2. Jika sudah login dan membuka halaman login -> arahkan ke dashboard masing-masing
    if (to.path === '/login' && authStore.isLoggedIn) {
      if (authStore.isAdmin) return next({ name: 'admin-dashboard' })
      if (authStore.isCustomer) return next({ name: 'customer-dashboard' })
      return next({ name: 'petugas-dashboard' })
    }

    // 3. Pembatasan Akses Role Ketat:
    // Setiap rute utama (/admin, /petugas, /customer) memiliki meta.role yang harus cocok
    if (authStore.isLoggedIn) {
      const requiredRole = to.matched.find((r) => r.meta && r.meta.role)?.meta?.role
      if (requiredRole && requiredRole !== authStore.role) {
        // Tampilkan Alert Akses Ditolak
        Notify.create({
          type: 'negative',
          icon: 'gpp_bad',
          message: 'Akses Ditolak!',
          caption: `Halaman ini khusus untuk ${requiredRole}. Akun Anda adalah ${authStore.role}.`,
          position: 'top',
          timeout: 3000
        })

        if (authStore.isAdmin) return next({ name: 'admin-dashboard' })
        if (authStore.isCustomer) return next({ name: 'customer-dashboard' })
        return next({ name: 'petugas-dashboard' })
      }
    }

    next()
  })

  return Router
})
