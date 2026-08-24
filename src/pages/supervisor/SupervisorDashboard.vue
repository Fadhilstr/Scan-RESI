<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-lg">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Dashboard Supervisor</h4>
        <div class="text-subtitle2 text-grey-7">Pengawasan operasional tim petugas scan (Rayon A)</div>
      </div>

      <q-btn
        color="primary"
        icon="monitoring"
        label="MONITORING SCAN TIM"
        to="/supervisor/monitoring"
        unelevated
        class="text-weight-bold"
      />
    </div>

    <!-- Supervisor Stat Cards (Requirement O) -->
    <div class="row q-col-gutter-md q-mb-xl">
      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">PETUGAS TIM</span>
              <q-avatar icon="groups" color="blue-1" text-color="primary" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-wahana-navy font-mono">
              {{ teamMembers.length }}
            </div>
            <div class="text-caption text-positive text-weight-bold q-mt-xs">
              {{ onlineTeamCount }} Petugas Online
            </div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">TOTAL SCAN TIM</span>
              <q-avatar icon="qr_code_scanner" color="amber-1" text-color="amber-9" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-amber-9 font-mono">
              {{ teamTotalScans }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">Total Scan Event Hari Ini</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">SCAN BERHASIL</span>
              <q-avatar icon="task_alt" color="green-1" text-color="positive" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-positive font-mono">
              {{ teamSuccessScans }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">Non-Duplicate Events</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Supervised Petugas Status List (Requirement O Example) -->
    <q-card class="scan-card q-pa-md q-mb-lg">
      <q-card-section>
        <div class="text-subtitle1 text-weight-bold text-slate-900 q-mb-md row items-center">
          <q-icon name="person_search" color="primary" class="q-mr-sm" size="24px" />
          STATUS & PROGRESS PETUGAS BAWAHAN
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
