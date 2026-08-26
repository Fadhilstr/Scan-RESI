<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-lg">
      <div>
        <h4 class="page-title">Dashboard Supervisor</h4>
        <div class="text-subtitle2 text-grey-7">Pengawasan operasional tim petugas scan (Rayon A)</div>
      </div>

      <q-btn
        color="primary"
        icon="monitoring"
        label="Monitoring Scan Tim" no-caps
        to="/supervisor/monitoring"
        unelevated
        class="text-weight-bold"
      />
    </div>

    <!-- Supervisor Stat Cards (Requirement O) -->
    <div class="row q-col-gutter-md q-mb-xl">
      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-none">
            <div class="row items-center justify-between q-mb-sm">
              <span class="overline-label">Petugas Tim</span>
              <q-avatar icon="groups" color="blue-1" text-color="primary" size="36px" style="border-radius: 10px;" />
            </div>
            <div class="kpi-value text-slate-900 font-mono">
              {{ teamMembers.length }}
            </div>
            <div class="text-caption text-positive text-weight-medium q-mt-xs row items-center">
              <q-icon name="circle" size="7px" class="q-mr-xs" /> {{ onlineTeamCount }} petugas online
            </div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-none">
            <div class="row items-center justify-between q-mb-sm">
              <span class="overline-label">Total Scan Tim</span>
              <q-avatar icon="qr_code_scanner" color="amber-2" text-color="amber-9" size="36px" style="border-radius: 10px;" />
            </div>
            <div class="kpi-value text-slate-900 font-mono">
              {{ teamTotalScans }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">Total scan event hari ini</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-none">
            <div class="row items-center justify-between q-mb-sm">
              <span class="overline-label">Scan Berhasil</span>
              <q-avatar icon="task_alt" color="green-1" text-color="positive" size="36px" style="border-radius: 10px;" />
            </div>
            <div class="kpi-value text-slate-900 font-mono">
              {{ teamSuccessScans }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">Non-duplicate events</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Supervised Petugas Status List (Requirement O Example) -->
    <q-card class="scan-card q-pa-md q-mb-lg">
      <q-card-section>
        <div class="section-title q-mb-md">
          <q-icon name="person_search" size="20px" color="primary" class="q-mr-sm" />
          Status &amp; Progress Petugas Bawahan
        </div>

        <div class="row q-col-gutter-md">
          <div v-for="p in teamMembersWithStats" :key="p.id" class="col-12 col-md-4">
            <q-card flat bordered class="q-pa-sm rounded-borders bg-slate-50">
              <div class="row items-center justify-between q-mb-xs">
                <div class="row items-center">
                  <q-avatar color="wahana-navy" text-color="amber-4" size="36px" class="q-mr-sm font-mono text-weight-bold">
                    {{ p.name.slice(0, 1) }}
                  </q-avatar>
                  <div>
                    <div class="text-subtitle1 text-weight-bold text-slate-900">{{ p.name }}</div>
                    <div class="text-caption text-grey-7 font-mono">{{ p.id }}</div>
                  </div>
                </div>

                <StatusBadge :status="p.status" size="xs" />
              </div>

              <q-separator class="q-my-xs" />

              <div class="row items-center justify-between text-caption font-mono">
                <span class="text-grey-7">Total Scan:</span>
                <span class="text-weight-bolder text-primary">{{ p.stats.total }} Scan</span>
              </div>
              <div class="row items-center justify-between text-caption font-mono">
                <span class="text-grey-7">Task Aktif:</span>
                <span class="text-weight-bold text-slate-800">{{ p.activeTask?.task_id || '-' }}</span>
              </div>
            </q-card>
          </div>
        </div>
      </q-card-section>
    </q-card>
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

const teamMembers = computed(() => {
  if (!authStore.currentUser) return []
  return authStore.supervisedPetugas(authStore.currentUser.id)
})

const onlineTeamCount = computed(() => {
  return teamMembers.value.filter((p) => p.status === 'ONLINE').length
})

const teamScans = computed(() => {
  const teamIds = teamMembers.value.map((p) => p.id)
  return scanStore.getFilteredScans(authStore.currentUser, teamIds)
})

const teamTotalScans = computed(() => teamScans.value.length)
const teamSuccessScans = computed(() => teamScans.value.filter((s) => s.status_scan === 'SUCCESS').length)

const teamMembersWithStats = computed(() => {
  return teamMembers.value.map((p) => ({
    ...p,
    stats: scanStore.getUserScanStats(p.id),
    activeTask: taskStore.getActiveTaskForUser(p.id)
  }))
})
</script>
