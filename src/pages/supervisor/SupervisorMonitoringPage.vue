<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Monitoring Scan Tim</h4>
        <div class="text-subtitle2 text-grey-7">Daftar scan event dari petugas bawahan dalam scope supervisor</div>
      </div>

      <q-chip color="wahana-navy" text-color="amber-4" class="font-mono text-weight-bold">
        ROLE: SUPERVISOR
      </q-chip>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Scan Event Table Filtered for Supervised Team (Requirement P) -->
    <ScanEventTable :scans="teamScans" :show-petugas-filter="true" />
  </q-page>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '../../stores/authStore'
import { useScanStore } from '../../stores/scanStore'
import ScanEventTable from '../../components/ScanEventTable.vue'

const authStore = useAuthStore()
const scanStore = useScanStore()

const teamScans = computed(() => {
  if (!authStore.currentUser) return []
  const teamIds = authStore.supervisedPetugas(authStore.currentUser.id).map((p) => p.id)
  return scanStore.getFilteredScans(authStore.currentUser, teamIds)
})
</script>
