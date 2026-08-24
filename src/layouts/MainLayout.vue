<template>
  <q-layout view="lHh Lpr lFf" class="bg-slate-50">
    <!-- App Header (Wahana Yellow Theme & Navy Controls) -->
    <q-header elevated class="bg-wahana-yellow text-slate-900 shadow-3" height-hint="64">
      <q-toolbar class="q-py-xs q-px-md">
        <q-btn
          flat
          dense
          round
          icon="menu"
          aria-label="Menu"
          @click="toggleLeftDrawer"
          class="q-mr-sm text-wahana-navy"
        />

        <q-avatar size="36px" class="bg-wahana-navy text-amber-4 text-weight-bold q-mr-sm shadow-2">
          <q-icon name="qr_code_scanner" size="22px" />
        </q-avatar>

        <q-toolbar-title class="text-weight-bolder text-h6 font-mono tracking-wide text-wahana-navy">
          WAHANA <span class="text-slate-900 text-weight-bold">EXPRESS</span>
          <span class="text-caption text-slate-800 text-weight-medium q-ml-xs gt-xs">
            | Logistics Scanner
          </span>
        </q-toolbar-title>

        <q-space />

        <!-- User Role Indicator & Profile in Header -->
        <div class="row items-center q-gutter-x-sm">
          <q-chip
            dense
            color="slate-900"
            text-color="amber-4"
            class="font-mono text-weight-bolder bg-wahana-navy shadow-1"
          >
            <q-icon name="account_circle" size="16px" class="q-mr-xs text-amber-4" />
            {{ authStore.currentUser?.name }} ({{ roleLabel }})
          </q-chip>

          <q-btn
            flat
            dense
            round
            icon="logout"
            color="slate-900"
            @click="handleLogout"
          >
            <q-tooltip>Keluar / Switch Role</q-tooltip>
          </q-btn>
        </div>
      </q-toolbar>
    </q-header>

    <!-- Sidebar / Navigation Drawer (Requirement AD) -->
    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      bordered
      class="bg-white"
      :width="270"
    >
      <!-- Sidebar Header Anchor: Navy Blue with Yellow Accents -->
      <div class="q-pa-md bg-wahana-navy text-white border-bottom-yellow">
        <div class="row items-center">
          <q-avatar size="42px" class="bg-amber-4 text-slate-900 q-mr-sm shadow-2">
            <q-icon name="local_shipping" size="26px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bolder text-amber-4">WAHANA EXPRESS</div>
            <div class="text-caption text-grey-4">Logistics Scanner Platform</div>
          </div>
        </div>

        <div class="q-mt-sm bg-slate-800 q-pa-xs rounded-borders row items-center justify-between">
          <span class="text-caption text-grey-3 font-mono">User: {{ authStore.currentUser?.username }}</span>
          <q-badge color="amber-5" text-color="slate-900" class="text-weight-bold">
            {{ roleLabel }}
          </q-badge>
        </div>
      </div>

      <q-separator />

      <q-list class="q-pa-sm">
        <q-item-label header class="text-caption text-weight-bold text-uppercase text-grey-6">
          Menu {{ roleLabel }}
        </q-item-label>

        <!-- ADMIN MENU (Requirement E & AD) -->
        <template v-if="authStore.isAdmin">
          <q-item clickable v-ripple to="/admin" exact active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="dashboard" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Dashboard</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/admin/monitoring" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="display_settings" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Monitoring Scan</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/admin/petugas" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="people" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Petugas</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/admin/tasks" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="assignment" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Task / Batch</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/admin/users" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="manage_accounts" color="primary" /></q-item-section>
            <q-item-section><q-item-label>User Management</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/admin/reports" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="analytics" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Report</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/admin/audit-logs" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="receipt_long" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Audit Log</q-item-label></q-item-section>
          </q-item>
        </template>

        <!-- SUPERVISOR MENU (Requirement F & AD) -->
        <template v-else-if="authStore.isSupervisor">
          <q-item clickable v-ripple to="/supervisor" exact active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="dashboard" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Dashboard</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/supervisor/petugas" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="groups" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Petugas Saya</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/supervisor/tasks" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="task" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Task Tim</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/supervisor/monitoring" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="monitoring" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Monitoring Scan</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/supervisor/reports" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="assessment" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Report</q-item-label></q-item-section>
          </q-item>
        </template>

        <!-- PETUGAS MENU (Requirement G & AD) -->
        <template v-else-if="authStore.isPetugas">
          <q-item clickable v-ripple to="/petugas" exact active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="dashboard" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Dashboard</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/petugas/tasks" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="assignment" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Tugas Saya</q-item-label></q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/petugas/scan" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="qr_code_scanner" color="primary" /></q-item-section>
            <q-item-section>
              <q-item-label class="row items-center justify-between">
                Scan Paket
                <q-badge color="amber-6" text-color="slate-900" size="xs" label="CORE" class="text-weight-bold" />
              </q-item-label>
            </q-item-section>
          </q-item>

          <q-item clickable v-ripple to="/petugas/hasil" active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow">
            <q-item-section avatar><q-icon name="fact_check" color="primary" /></q-item-section>
            <q-item-section><q-item-label>Hasil Scan Saya</q-item-label></q-item-section>
          </q-item>
        </template>

        <q-separator class="q-my-md" />

        <q-item clickable v-ripple class="text-negative" @click="handleLogout">
          <q-item-section avatar><q-icon name="logout" color="negative" /></q-item-section>
          <q-item-section><q-item-label class="text-weight-bold">Logout / Ganti User</q-item-label></q-item-section>
        </q-item>
      </q-list>
    </q-drawer>

    <!-- Main Content Area -->
    <q-page-container>
      <router-view />
    </q-page-container>

    <!-- Simple Footer -->
    <q-footer class="bg-white text-grey-8 bordered-top q-py-xs q-px-md">
      <div class="row items-center justify-between text-caption font-mono">
        <div>
          <span class="text-weight-bold text-wahana-navy">Wahana Express Scan Paket Berbasis Barcode</span> &copy; 2026
        </div>
        <div class="gt-xs text-grey-6">
          Status: Multi-Role Prototype ({{ roleLabel }})
        </div>
      </div>
    </q-footer>
  </q-layout>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '../stores/authStore'
import { useScanStore } from '../stores/scanStore'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()
const scanStore = useScanStore()
const leftDrawerOpen = ref(false)

const toggleLeftDrawer = () => {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

const roleLabel = computed(() => {
  if (authStore.isAdmin) return 'ADMIN'
  if (authStore.isSupervisor) return 'SUPERVISOR'
  if (authStore.isPetugas) return 'PETUGAS SCAN'
  return 'GUEST'
})

const handleLogout = () => {
  authStore.logout()
  $q.notify({
    type: 'info',
    icon: 'logout',
    message: 'Anda telah keluar dari aplikasi.',
    position: 'top',
    timeout: 1800
  })
  router.push('/login')
}
</script>

<style scoped>
.bordered-top {
  border-top: 1px solid #e2e8f0;
}
.border-bottom-yellow {
  border-bottom: 3px solid #ffc700;
}
.border-left-yellow {
  border-left: 4px solid #ffc700;
}
</style>
