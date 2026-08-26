<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Hasil Scan Saya</h4>
        <div class="text-subtitle2 text-grey-7">Rekapitulasi log scan event khusus milik {{ authStore.currentUser?.name }}</div>
      </div>

      <div class="row q-gutter-sm">
        <q-btn
          color="primary"
          icon="qr_code_scanner"
          label="SCAN PAKET"
          to="/petugas/scan"
          unelevated
          class="text-weight-bold"
        />
        <q-btn
          outline
          color="slate-700"
          icon="dashboard"
          label="DASHBOARD"
          to="/petugas"
          class="text-weight-bold"
        />
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Total Scan Summary Box (Requirement Y) -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="scan-card text-center q-pa-sm">
          <q-card-section>
            <div class="text-caption text-grey-7 text-weight-bold">TOTAL SCAN SAYA</div>
            <div class="text-h2 text-weight-bolder text-primary font-mono q-my-xs">
              {{ myScans.length }}
            </div>
            <div class="text-caption text-grey-6">Scan Event Recorded</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="scan-card text-center q-pa-sm">
          <q-card-section>
            <div class="text-caption text-grey-7 text-weight-bold">SCAN SUCCESS</div>
            <div class="text-h2 text-weight-bolder text-positive font-mono q-my-xs">
              {{ userStats.success }}
            </div>
            <div class="text-caption text-grey-6">Resi Unik Berhasil</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-12 col-md-4">
        <q-card class="scan-card text-center q-pa-sm">
          <q-card-section>
            <div class="text-caption text-grey-7 text-weight-bold">DUPLICATE REJECTED</div>
            <div class="text-h2 text-weight-bolder text-amber-9 font-mono q-my-xs">
              {{ userStats.duplicate }}
            </div>
            <div class="text-caption text-grey-6">Terdeteksi Duplikat</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Scanned Items Table filtered for Logged-In User (Requirement Y) -->
    <ScanEventTable
      :scans="myScans"
      :show-petugas-filter="false"
      show-label-action
      @label="openLabel"
    />

    <!-- Dialog Generate Barcode Label -->
    <BarcodeLabel v-model="showLabel" :resi="labelResi" />
  </q-page>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useAuthStore } from '../../stores/authStore'
import { useScanStore } from '../../stores/scanStore'
import ScanEventTable from '../../components/ScanEventTable.vue'
import BarcodeLabel from '../../components/BarcodeLabel.vue'

const authStore = useAuthStore()
const scanStore = useScanStore()

const showLabel = ref(false)
const labelResi = ref('')

const openLabel = (row) => {
  labelResi.value = row?.nomor_resi || ''
  showLabel.value = true
}

const myScans = computed(() => {
  if (!authStore.currentUser) return []
  return scanStore.getFilteredScans(authStore.currentUser)
})

const userStats = computed(() => {
  if (!authStore.currentUser) return { total: 0, success: 0, duplicate: 0 }
  return scanStore.getUserScanStats(authStore.currentUser.id)
})
</script>
