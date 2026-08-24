import { route } from 'quasar/wrappers'
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

  // Role Protection Guard (Requirement J & TEST 8)
  Router.beforeEach((to, from, next) => {
    const authStore = useAuthStore()

    // 1. If not logged in and accessing protected route
    if (to.meta.requiresAuth && !authStore.isLoggedIn) {
      return next({ name: 'login' })
    }

    // 2. If logged in and visiting login page
    if (to.path === '/login' && authStore.isLoggedIn) {
      if (authStore.isAdmin) return next({ name: 'admin-dashboard' })
      if (authStore.isSupervisor) return next({ name: 'supervisor-dashboard' })
      return next({ name: 'petugas-dashboard' })
    }

    // 3. Role Access Restrictions
    if (authStore.isLoggedIn) {
      // Petugas trying to access Admin or Supervisor routes
      if (authStore.isPetugas && (to.path.startsWith('/admin') || to.path.startsWith('/supervisor'))) {
        return next({ name: 'petugas-dashboard' })
      }

      // Supervisor trying to access Admin routes
      if (authStore.isSupervisor && to.path.startsWith('/admin')) {
        return next({ name: 'supervisor-dashboard' })
      }
    }

    next()
  })

  return Router
})
