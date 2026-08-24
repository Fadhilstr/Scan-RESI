<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Monitoring Scan System</h4>
        <div class="text-subtitle2 text-grey-7">Lihat dan filter seluruh aktivitas scan event di seluruh gerai/rayon</div>
      </div>

      <q-chip color="wahana-navy" text-color="amber-4" class="font-mono text-weight-bold">
        ROLE: ADMIN ACCESS
      </q-chip>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Scan Event Table Component with All System Scans (Requirement L) -->
    <ScanEventTable :scans="allScans" :show-petugas-filter="true" />
  </q-page>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '../../stores/authStore'
import { useScanStore } from '../../stores/scanStore'
import ScanEventTable from '../../components/ScanEventTable.vue'

const authStore = useAuthStore()
const scanStore = useScanStore()

const allScans = computed(() => {
  return scanStore.getFilteredScans(authStore.currentUser)
})
</script>
