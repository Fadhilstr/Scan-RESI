<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Report Performa Tim</h4>
        <div class="text-subtitle2 text-grey-7">Ringkasan statistik dan pencapaian target tim operasional</div>
      </div>

      <q-btn flat round dense icon="refresh" color="primary" @click="refresh">
        <q-tooltip>Muat ulang data laporan</q-tooltip>
      </q-btn>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Metric Cards -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-md-6">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-900 q-mb-xs">Tingkat Pencapaian Target</div>
            <div class="text-h3 text-weight-bolder font-mono" :class="targetAchievement >= 80 ? 'text-positive' : 'text-orange-9'">
              {{ targetAchievement }}%
            </div>
            <div class="text-caption text-grey-7">Rata-rata progres task aktif tim ({{ supervisedIds.length }} petugas)</div>
            <q-linear-progress :value="targetAchievement / 100" size="10px" rounded color="positive" track-color="grey-3" class="q-mt-sm" />
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-md-6">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-900 q-mb-xs">Rasio Duplikasi Scan Tim</div>
            <div class="text-h3 text-weight-bolder font-mono" :class="duplicateRate > 5 ? 'text-negative' : 'text-amber-9'">
              {{ duplicateRate }}%
            </div>
            <div class="text-caption text-grey-7">{{ teamStats.duplicate }} duplikat dari {{ teamStats.total }} scan event tim</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Volume & Kualitas per Petugas -->
    <q-card class="scan-card">
      <q-card-section>
        <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-sm row items-center">
          <q-icon name="groups" color="primary" class="q-mr-xs" />
          PERFORMA PETUGAS SAYA
        </div>

        <q-table
          :rows="teamRows"
          :columns="columns"
          row-key="user_id"
          flat
          bordered
          :pagination="{ rowsPerPage: 0 }"
          no-data-label="Belum ada petugas di bawah supervisi Anda"
        >
          <template v-slot:body-cell-name="props">
            <q-td :props="props">
              <div class="text-weight-bold text-slate-900">{{ props.row.name }}</div>
              <div class="text-caption text-grey-6 font-mono">{{ props.row.user_id }}</div>
            </q-td>
          </template>

          <template v-slot:body-cell-status="props">
            <q-td :props="props">
              <q-badge :color="props.row.status === 'ONLINE' ? 'green-2' : 'grey-3'" text-color="slate-900" class="font-mono text-weight-bold">
                {{ props.row.status }}
              </q-badge>
            </q-td>
          </template>

          <template v-slot:body-cell-target_progress="props">
            <q-td :props="props" style="min-width: 180px">
              <div class="row items-center q-gutter-x-sm">
                <q-linear-progress :value="props.row.target_ratio" size="8px" rounded color="primary" track-color="grey-3" style="flex: 1" />
                <span class="font-mono text-caption text-weight-bold">{{ props.row.progress }}/{{ props.row.target }}</span>
              </div>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import { useAuthStore } from '../../stores/authStore'
import { useTaskStore } from '../../stores/taskStore'
import { useScanStore } from '../../stores/scanStore'

const authStore = useAuthStore()
const taskStore = useTaskStore()
const scanStore = useScanStore()

const refresh = () => {
  taskStore.fetchTasks()
  scanStore.fetchScans()
}

onMounted(refresh)

// ====== SCOPE SUPERVISOR: HANYA TIM BAWAHAN ======
const currentUser = computed(() => authStore.currentUser)

const supervisedIds = computed(() =>
  authStore.supervisedPetugas(currentUser.value?.id).map((u) => u.id)
)

const teamScans = computed(() =>
  scanStore.getFilteredScans(currentUser.value, supervisedIds.value)
)

const teamTasks = computed(() =>
  taskStore.getTasksForSupervisor(supervisedIds.value)
)

const teamStats = computed(() => {
  const success = teamScans.value.filter((s) => s.status_scan === 'SUCCESS').length
  const duplicate = teamScans.value.filter((s) => s.status_scan === 'DUPLICATE').length
  const total = teamScans.value.length
  return { success, duplicate, total }
})

const duplicateRate = computed(() =>
  teamStats.value.total ? ((teamStats.value.duplicate / teamStats.value.total) * 100).toFixed(1) : '0.0'
)

const targetAchievement = computed(() => {
  const active = teamTasks.value.filter((t) => t.status !== 'SELESAI' && Number(t.target) > 0)
  if (!active.length) return '0.0'
  const avg = active.reduce((acc, t) => acc + Math.min(t.progress / t.target, 1), 0) / active.length
  return (avg * 100).toFixed(1)
})

const teamRows = computed(() => {
  return authStore.supervisedPetugas(currentUser.value?.id).map((u) => {
    const userScans = teamScans.value.filter((s) => s.user_id === u.id)
    const success = userScans.filter((s) => s.status_scan === 'SUCCESS').length
    const duplicate = userScans.filter((s) => s.status_scan === 'DUPLICATE').length

    const userTasks = teamTasks.value.filter((t) => t.user_id === u.id && t.status !== 'SELESAI')
    const target = userTasks.reduce((acc, t) => acc + Number(t.target || 0), 0)
    const progress = userTasks.reduce((acc, t) => acc + Number(t.progress || 0), 0)

    return {
      user_id: u.id,
      name: u.name,
      status: u.status,
      total: userScans.length,
      success,
      duplicate,
      target,
      progress,
      target_ratio: target ? Math.min(progress / target, 1) : 0
    }
  })
})

const columns = [
  { name: 'name', label: 'Petugas', field: 'name', align: 'left', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
  { name: 'success', label: 'SUCCESS', field: 'success', align: 'center', sortable: true },
  { name: 'duplicate', label: 'DUPLICATE', field: 'duplicate', align: 'center', sortable: true },
  { name: 'target_progress', label: 'Capaian Target Aktif', field: 'target_progress', align: 'left' }
]
</script>
