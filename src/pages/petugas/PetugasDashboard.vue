<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <!-- Greeting Header (Requirement Q) -->
    <div class="row items-center justify-between q-mb-lg">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">
          Selamat Datang, {{ authStore.currentUser?.name }} 👋
        </h4>
        <div class="text-subtitle1 text-grey-7">Dashboard operasional petugas pengindaian paket</div>
      </div>

      <div>
        <q-btn
          color="primary"
          size="lg"
          icon="qr_code_scanner"
          label="MULAI SCAN"
          to="/petugas/scan"
          unelevated
          class="text-weight-bolder shadow-3 q-px-lg"
          :disabled="!activeTask || activeTask.status === 'SELESAI'"
        />
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Active Task Card Overview (Requirement Q) -->
    <div class="row q-col-gutter-md q-mb-xl">
      <div class="col-12 col-md-8">
        <q-card class="scan-card q-pa-md border-left-yellow">
          <q-card-section>
            <div class="row items-center justify-between q-mb-sm">
              <div class="row items-center">
                <q-icon name="assignment" size="28px" color="primary" class="q-mr-xs" />
                <span class="text-h5 text-weight-bolder text-slate-900">
                  TASK AKTIF: {{ activeTask?.task_id || 'TIDAK ADA' }}
                </span>
              </div>
              <StatusBadge :status="activeTask?.status || 'SELESAI'" size="md" />
            </div>

            <div v-if="activeTask" class="q-mt-md">
              <div class="row q-col-gutter-sm text-center q-mb-md">
                <div class="col-4 bg-blue-1 q-pa-sm rounded-borders">
                  <div class="text-caption text-grey-7 text-weight-bold">TARGET</div>
                  <div class="text-h4 text-weight-bolder text-primary font-mono q-mt-xs">
                    {{ activeTask.target }}
                  </div>
                </div>

                <div class="col-4 bg-amber-1 q-pa-sm rounded-borders">
                  <div class="text-caption text-grey-7 text-weight-bold">PROGRESS</div>
                  <div class="text-h4 text-weight-bolder text-amber-9 font-mono q-mt-xs">
                    {{ activeTask.progress }} / {{ activeTask.target }}
                  </div>
                </div>

                <div class="col-4 bg-green-1 q-pa-sm rounded-borders">
                  <div class="text-caption text-grey-7 text-weight-bold">TOTAL SCAN</div>
                  <div class="text-h4 text-weight-bolder text-positive font-mono q-mt-xs">
                    {{ userStats.total }}
                  </div>
                </div>
              </div>

              <!-- Progress Bar -->
              <q-linear-progress
                :value="activeTask.progress / activeTask.target"
                color="amber-6"
                track-color="amber-1"
                size="12px"
                class="rounded-borders q-mb-xs"
              />
              <div class="row justify-between text-caption text-grey-7 font-mono">
                <span>Shift {{ activeTask.shift }} • {{ activeTask.lokasi }}</span>
                <span>Capaian: {{ Math.round((activeTask.progress / activeTask.target) * 100) }}%</span>
              </div>
            </div>

            <div v-else class="text-center q-pa-lg text-grey-6">
              Tidak ada task aktif saat ini.
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Quick Stats Card -->
      <div class="col-12 col-md-4">
        <q-card class="scan-card full-height q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-md row items-center">
              <q-icon name="insights" color="primary" class="q-mr-xs" /> STATISTIK SAYA
            </div>

            <div class="column q-gutter-y-sm">
              <div class="row justify-between items-center bg-slate-50 q-pa-sm rounded-borders font-mono">
                <span class="text-grey-7">Scan Berhasil:</span>
                <q-badge color="positive" class="text-weight-bold">{{ userStats.success }}</q-badge>
              </div>

              <div class="row justify-between items-center bg-slate-50 q-pa-sm rounded-borders font-mono">
                <span class="text-grey-7">Scan Duplicate:</span>
                <q-badge color="warning" text-color="dark" class="text-weight-bold">{{ userStats.duplicate }}</q-badge>
              </div>

              <div class="row justify-between items-center bg-slate-50 q-pa-sm rounded-borders font-mono">
                <span class="text-grey-7">Terakhir Scan:</span>
                <span class="text-weight-bold text-slate-900">{{ userStats.lastScan }}</span>
              </div>
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

const activeTask = computed(() => {
  if (!authStore.currentUser) return null
  return taskStore.getActiveTaskForUser(authStore.currentUser.id)
})

const userStats = computed(() => {
  if (!authStore.currentUser) return { total: 0, success: 0, duplicate: 0, lastScan: '-' }
  return scanStore.getUserScanStats(authStore.currentUser.id)
})
</script>
