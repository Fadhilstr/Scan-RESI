<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-lg">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Dashboard Admin</h4>
        <div class="text-subtitle1 text-grey-7">Monitoring operasional seluruh sistem scan Dijak Express</div>
      </div>

      <div class="row q-gutter-sm">
        <q-btn
          color="primary"
          icon="display_settings"
          label="MONITORING SCAN"
          to="/admin/monitoring"
          unelevated
          class="text-weight-bold"
        />
        <q-btn
          color="amber-6"
          text-color="slate-900"
          icon="manage_accounts"
          label="USER MANAGEMENT"
          to="/admin/users"
          unelevated
          class="text-weight-bold"
        />
      </div>
    </div>

    <!-- Admin Metric Stat Cards (Requirement K) -->
    <div class="row q-col-gutter-md q-mb-xl">
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Total Petugas</span>
              <q-avatar icon="badge" color="blue-1" text-color="primary" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-wahana-navy font-mono">25</div>
            <div class="text-caption text-positive text-weight-bold q-mt-xs">4 Petugas Online</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Total Supervisor</span>
              <q-avatar icon="supervisor_account" color="indigo-1" text-color="indigo" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-slate-900 font-mono">3</div>
            <div class="text-caption text-grey-6 q-mt-xs">3 Rayon Operasional</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Total Task</span>
              <q-avatar icon="assignment" color="amber-1" text-color="amber-9" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-amber-9 font-mono">10</div>
            <div class="text-caption text-grey-6 q-mt-xs">8 Aktif • 2 Selesai</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Total Scan</span>
              <q-avatar icon="qr_code_scanner" color="green-1" text-color="positive" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-positive font-mono">1,250</div>
            <div class="text-caption text-positive text-weight-bold q-mt-xs">350 Scan Hari Ini</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Active Tasks Overview & System Live Scan -->
    <div class="row q-col-gutter-md">
      <div class="col-12 col-md-6">
        <q-card class="scan-card full-height">
          <q-card-section class="row items-center justify-between">
            <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
              <q-icon name="task" color="primary" class="q-mr-sm" size="24px" />
              TASK AKTIF SAAT INI
            </div>
            <q-btn flat dense label="Lihat Semua" color="primary" to="/admin/tasks" class="text-weight-bold" />
          </q-card-section>

          <q-separator />

          <q-card-section class="column q-gutter-y-sm">
            <TaskCard v-for="t in taskStore.allTasks" :key="t.task_id" :task="t" />
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-md-6">
        <q-card class="scan-card full-height">
          <q-card-section class="row items-center justify-between">
            <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
              <q-icon name="history" color="primary" class="q-mr-sm" size="24px" />
              AKTIVITAS SCAN TERAKHIR (ALL USER)
            </div>
            <q-btn flat dense label="Monitoring" color="primary" to="/admin/monitoring" class="text-weight-bold" />
          </q-card-section>

          <q-separator />

          <q-card-section>
            <q-list class="q-gutter-y-xs">
              <q-item v-for="scan in recentScans" :key="scan.scan_id" class="bg-slate-50 rounded-borders q-pa-xs">
                <q-item-section avatar>
                  <q-avatar color="wahana-navy" text-color="amber-4" size="32px" class="font-mono text-caption text-weight-bold">
                    {{ scan.user_name.slice(0, 1) }}
                  </q-avatar>
                </q-item-section>

                <q-item-section>
                  <q-item-label class="font-mono text-weight-bolder text-slate-900">
                    {{ scan.nomor_resi }}
                  </q-item-label>
                  <q-item-label caption>
                    By {{ scan.user_name }} • {{ scan.task_id }} • {{ scan.lokasi }}
                  </q-item-label>
                </q-item-section>

                <q-item-section side>
                  <StatusBadge :status="scan.status_scan" size="xs" />
                  <div class="text-caption font-mono text-grey-6 q-mt-xs">{{ scan.waktu_scan.split(' ')[1] }}</div>
                </q-item-section>
              </q-item>
            </q-list>
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
import TaskCard from '../../components/TaskCard.vue'

const authStore = useAuthStore()
const taskStore = useTaskStore()
const scanStore = useScanStore()

const recentScans = computed(() => {
  return scanStore.scanEvents.slice(0, 5)
})
</script>
