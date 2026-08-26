<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="page-title">Petugas Tim Saya</h4>
        <div class="text-subtitle2 text-grey-7">Inspeksi anggota petugas operasional dalam scope supervisor</div>
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <div class="row q-col-gutter-md">
      <div v-for="p in teamList" :key="p.id" class="col-12 col-md-4">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="row items-center justify-between q-mb-sm">
              <div class="row items-center">
                <q-avatar color="wahana-navy" text-color="amber-4" size="40px" class="q-mr-sm font-mono text-weight-bold">
                  {{ p.name.slice(0, 1) }}
                </q-avatar>
                <div>
                  <div class="text-h6 text-weight-bold text-slate-900">{{ p.name }}</div>
                  <div class="text-caption text-grey-7 font-mono">{{ p.id }}</div>
                </div>
              </div>
              <StatusBadge :status="p.status" size="xs" />
            </div>

            <q-separator class="q-my-sm" />

            <div class="column q-gutter-y-xs font-mono text-caption text-grey-8">
              <div>Task: <span class="text-weight-bold text-primary">{{ getActiveTask(p.id) }}</span></div>
              <div>Total Scan: <span class="text-weight-bold text-slate-900">{{ getStats(p.id).total }}</span></div>
              <div>SUCCESS: <span class="text-weight-bold text-positive">{{ getStats(p.id).success }}</span></div>
              <div>DUPLICATE: <span class="text-weight-bold text-amber-9">{{ getStats(p.id).duplicate }}</span></div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '../../stores/authStore'
import { useTaskStore } from '../../stores/taskStore'
import { useScanStore } from '../../stores/scanStore'
import StatusBadge from '../../components/StatusBadge.vue'

const authStore = useAuthStore()
const taskStore = useTaskStore()
const scanStore = useScanStore()

const teamList = computed(() => {
  if (!authStore.currentUser) return []
  return authStore.supervisedPetugas(authStore.currentUser.id)
})

const getActiveTask = (userId) => {
  const t = taskStore.getActiveTaskForUser(userId)
  return t ? t.task_id : 'Tidak ada'
}

const getStats = (userId) => {
  return scanStore.getUserScanStats(userId)
}
</script>
