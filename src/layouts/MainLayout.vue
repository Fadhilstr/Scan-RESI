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
            | Scan Paket v1.0
          </span>
        </q-toolbar-title>

        <q-space />

        <!-- Status Indicator in Header -->
        <div class="row items-center q-gutter-x-sm">
          <q-chip
            dense
            clickable
            color="slate-900"
            text-color="white"
            class="q-px-sm font-mono text-weight-bold bg-wahana-navy shadow-1"
          >
            <span class="scanner-dot q-mr-xs"></span>
            <span class="gt-xs">SCANNER: </span>READY
          </q-chip>

          <q-chip
            dense
            color="slate-900"
            text-color="amber-4"
            class="font-mono text-weight-bolder bg-wahana-navy shadow-1"
            to="/scan"
          >
            <q-icon name="inventory_2" size="14px" class="q-mr-xs text-amber-4" />
            {{ scanStore.totalPaket }} Paket
          </q-chip>
        </div>
      </q-toolbar>
    </q-header>

    <!-- Sidebar / Navigation Drawer -->
    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      bordered
      class="bg-white"
      :width="260"
    >
      <!-- Sidebar Header Anchor: Navy Blue with Yellow Accents -->
      <div class="q-pa-md bg-wahana-navy text-white border-bottom-yellow">
        <div class="row items-center">
          <q-avatar size="40px" class="bg-amber-4 text-slate-900 q-mr-sm shadow-2">
            <q-icon name="local_shipping" size="26px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bolder text-amber-4">WAHANA EXPRESS</div>
            <div class="text-caption text-grey-4">Operational Scan Paket</div>
          </div>
        </div>
      </div>

      <q-separator />

      <q-list class="q-pa-sm">
        <q-item-label header class="text-caption text-weight-bold text-uppercase text-grey-6">
          Menu Utama
        </q-item-label>

        <!-- Dashboard Link -->
        <q-item
          clickable
          v-ripple
          to="/"
          exact
          active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow"
        >
          <q-item-section avatar>
            <q-icon name="dashboard" color="primary" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Dashboard</q-item-label>
          </q-item-section>
        </q-item>

        <!-- Scan Paket Link (CORE FEATURE) -->
        <q-item
          clickable
          v-ripple
          to="/scan"
          active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow"
        >
          <q-item-section avatar>
            <q-icon name="qr_code_scanner" color="primary" />
          </q-item-section>
          <q-item-section>
            <q-item-label class="row items-center justify-between">
              Scan Paket
              <q-badge color="amber-6" text-color="slate-900" size="xs" label="CORE" class="text-weight-bold" />
            </q-item-label>
          </q-item-section>
        </q-item>

        <!-- Hasil Scan Link -->
        <q-item
          clickable
          v-ripple
          to="/hasil"
          active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow"
        >
          <q-item-section avatar>
            <q-icon name="fact_check" color="primary" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Hasil Scan</q-item-label>
          </q-item-section>
        </q-item>

        <!-- Riwayat Link -->
        <q-item
          clickable
          v-ripple
          to="/riwayat"
          active-class="bg-amber-1 text-wahana-navy text-weight-bold rounded-borders border-left-yellow"
        >
          <q-item-section avatar>
            <q-icon name="history" color="primary" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Riwayat</q-item-label>
          </q-item-section>
        </q-item>

        <q-separator class="q-my-md" />

        <q-item-label header class="text-caption text-weight-bold text-uppercase text-grey-6">
          Pengembangan Mendatang
        </q-item-label>

        <!-- Coming Soon Item -->
        <q-item class="text-grey-5" clickable v-ripple @click="showComingSoon">
          <q-item-section avatar>
            <q-icon name="cloud_sync" />
          </q-item-section>
          <q-item-section>
            <q-item-label class="row items-center justify-between">
              Integrasi USG & API
              <q-badge color="grey-5" text-color="dark" size="xs" label="Coming Soon" />
            </q-item-label>
          </q-item-section>
        </q-item>

        <!-- Coming Soon Item 2 -->
        <q-item class="text-grey-5" clickable v-ripple @click="showComingSoon">
          <q-item-section avatar>
            <q-icon name="photo_camera" />
          </q-item-section>
          <q-item-section>
            <q-item-label class="row items-center justify-between">
              Camera Scan Mode
              <q-badge color="grey-5" text-color="dark" size="xs" label="Coming Soon" />
            </q-item-label>
          </q-item-section>
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
          Status: Frontend Prototype (Wahana Yellow & Navy Theme)
        </div>
      </div>
    </q-footer>
  </q-layout>
</template>

<script setup>
import { ref } from 'vue'
import { useQuasar } from 'quasar'
import { useScanStore } from '../stores/scanStore'

const $q = useQuasar()
const scanStore = useScanStore()
const leftDrawerOpen = ref(false)

const toggleLeftDrawer = () => {
  leftDrawerOpen.value = !leftDrawerOpen.value
}

const showComingSoon = () => {
  $q.notify({
    type: 'info',
    icon: 'hourglass_empty',
    message: 'Fitur ini dalam status "Coming Soon" untuk tahap integrasi backend berikutnya.',
    position: 'top',
    timeout: 2000
  })
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
