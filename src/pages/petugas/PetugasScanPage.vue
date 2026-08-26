<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <!-- Header Page Section (Requirement T) -->
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="row items-center">
          <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none q-mr-sm">SCAN PAKET</h4>
          <StatusBadge :status="activeTask?.status || 'SELESAI'" size="md" />
        </div>
        <div class="text-subtitle2 text-grey-7 font-mono">
          Petugas: <span class="text-weight-bold text-slate-900">{{ authStore.currentUser?.name }}</span> •
          Task: <span class="text-weight-bold text-primary">{{ activeTask?.task_id || '-' }}</span> •
          Shift: {{ activeTask?.shift || '-' }}
        </div>
      </div>

      <div v-if="isTaskFinished">
        <q-btn
          color="positive"
          icon="analytics"
          label="HASIL SCAN SAYA"
          unelevated
          to="/petugas/hasil"
          class="text-weight-bold"
        />
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Barcode Input Component (Requirement T & U) -->
    <BarcodeInput :disabled="isTaskFinished" @scan="handleBarcodeScan" />

    <!-- Active Task Progress Summary -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-md-5">
        <q-card class="scan-card full-height q-pa-sm">
          <q-card-section>
            <div class="row items-center justify-between q-mb-xs">
              <span class="text-subtitle2 text-weight-bold text-grey-8">TOTAL SCAN HARI INI</span>
              <q-chip color="amber-5" text-color="slate-900" class="font-mono text-weight-bolder">
                {{ userScans.length }} Paket
              </q-chip>
            </div>

            <q-separator class="q-my-sm" />

            <div class="row items-center justify-between q-pt-xs">
              <div>
                <div class="text-caption text-grey-7 text-weight-medium">CAPAIAN TARGET TASK</div>
                <div class="text-h3 text-weight-bolder text-primary font-mono q-my-none">
                  {{ activeTask?.progress || 0 }} / {{ activeTask?.target || 0 }}
                </div>
                <div class="text-caption text-grey-6 font-mono">Lokasi: {{ activeTask?.lokasi || 'CIPUTAT' }}</div>
              </div>

              <div class="q-pa-md bg-amber-1 rounded-borders text-center" style="border-radius: 12px;">
                <q-icon name="inventory_2" size="42px" color="amber-9" />
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Last Scanned Event Card -->
      <div class="col-12 col-md-7">
        <q-card class="scan-card full-height q-pa-sm">
          <q-card-section>
            <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs row items-center">
              <q-icon name="history" color="primary" class="q-mr-xs" /> RESI TERAKHIR DISCAN
            </div>

            <q-separator class="q-my-sm" />

            <div v-if="lastScannedEvent" class="row items-center justify-between q-pt-xs">
              <div>
                <div class="text-h5 text-weight-bolder text-slate-900 font-mono">
                  {{ lastScannedEvent.nomor_resi }}
                </div>
                <div class="row items-center q-mt-xs">
                  <StatusBadge :status="lastScannedEvent.status_scan" size="xs" />
                </div>
              </div>

              <div class="text-right">
                <q-badge color="slate-100" text-color="slate-900" class="q-pa-xs font-mono text-subtitle2">
                  <q-icon name="schedule" size="14px" class="q-mr-xs" />
                  {{ lastScannedEvent.waktu_scan.split(' ')[1] }}
                </q-badge>
              </div>
            </div>

            <div v-else class="text-center q-pa-md text-grey-6">
              <q-icon name="qr_code_scanner" size="32px" class="q-mb-xs" />
              <div>Belum ada paket yang discan pada task ini.</div>
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Scanned Items Table View -->
    <div class="q-mb-xl">
      <ScanEventTable :scans="userScans" :show-petugas-filter="false" />
    </div>

    <!-- Finish Task Action Button (Requirement Z) -->
    <div class="row justify-end q-mt-lg">
      <q-btn
        v-if="!isTaskFinished"
        color="primary"
        size="lg"
        icon="check_circle"
        label="SELESAIKAN TASK"
        class="text-weight-bolder q-px-xl shadow-4"
        unelevated
        @click="confirmFinishTask"
      >
        <q-tooltip>Selesaikan task dan kunci proses pengindaian</q-tooltip>
      </q-btn>
    </div>

    <!-- Selesaikan Task Confirmation Dialog (Requirement Z) -->
    <q-dialog v-model="showFinishModal" persistent>
      <q-card style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="row items-center q-pb-none">
          <q-avatar icon="help_outline" color="blue-1" text-color="primary" />
          <span class="q-ml-sm text-h6 text-weight-bold">Konfirmasi Selesaikan Task</span>
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div class="text-body1 text-slate-800">
            Apakah Anda yakin ingin menyelesaikan task?
          </div>

          <div class="q-mt-md bg-blue-1 q-pa-md rounded-borders text-center">
            <div class="text-caption text-grey-7">CAPAIAN SCAN TASK</div>
            <div class="text-h3 text-weight-bolder text-primary font-mono">
              {{ activeTask?.progress }} / {{ activeTask?.target }}
            </div>
            <div class="text-caption text-grey-7">Task ID: {{ activeTask?.task_id }}</div>
          </div>

          <div class="text-caption text-negative q-mt-sm text-center">
            * Setelah dikonfirmasi, input barcode akan dikunci dan task berstatus SELESAI.
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="BATAL" color="grey-7" v-close-popup class="text-weight-bold" />
          <q-btn label="SELESAI" color="primary" @click="executeFinishTask" class="text-weight-bold" unelevated />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '../../stores/authStore'
import { useTaskStore } from '../../stores/taskStore'
import { useScanStore } from '../../stores/scanStore'
import StatusBadge from '../../components/StatusBadge.vue'
import BarcodeInput from '../../components/BarcodeInput.vue'
import ScanEventTable from '../../components/ScanEventTable.vue'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()
const taskStore = useTaskStore()
const scanStore = useScanStore()

const showFinishModal = ref(false)

const activeTask = computed(() => {
  if (!authStore.currentUser) return null
  return taskStore.getActiveTaskForUser(authStore.currentUser.id)
})

const isTaskFinished = computed(() => {
  return !activeTask.value || activeTask.value.status === 'SELESAI'
})

const userScans = computed(() => {
  if (!authStore.currentUser) return []
  return scanStore.getFilteredScans(authStore.currentUser)
})

const lastScannedEvent = computed(() => {
  return userScans.value.length > 0 ? userScans.value[0] : null
})

const handleBarcodeScan = async (resiInput) => {
  if (isTaskFinished.value) {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: 'Task sudah selesai dan tidak dapat melakukan scan.',
      position: 'top',
      timeout: 2500
    })
    return
  }

  const result = await scanStore.addScanEvent({
    resi: resiInput,
    currentUser: authStore.currentUser,
    activeTask: activeTask.value,
    lokasi: activeTask.value.lokasi || 'CIPUTAT',
    device_id: 'SCAN-DEVICE-01',
    jenis_scan: 'INBOUND'
  })

  if (result.success) {
    $q.notify({
      type: 'positive',
      icon: 'check_circle',
      message: result.message,
      position: 'top',
      timeout: 1800
    })
  } else {
    if (result.reason === 'DUPLICATE') {
      $q.notify({
        type: 'warning',
        icon: 'warning',
        message: result.message,
        position: 'top',
        timeout: 3000
      })
    } else {
      $q.notify({
        type: 'negative',
        icon: 'error',
        message: result.message,
        position: 'top',
        timeout: 2500
      })
    }
  }
}

const confirmFinishTask = () => {
  showFinishModal.value = true
}

const executeFinishTask = async () => {
  if (!activeTask.value) return
  const taskId = activeTask.value.task_id
  const result = await taskStore.completeTask(taskId)
  showFinishModal.value = false

  if (result?.success === false) {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: result.message || `Gagal menyelesaikan task ${taskId}.`,
      position: 'top',
      timeout: 2500
    })
    return
  }

  $q.notify({
    type: 'positive',
    icon: 'task_alt',
    message: `Task ${taskId} telah diselesaikan!`,
    position: 'top',
    timeout: 2000
  })

  router.push('/petugas/hasil')
}
</script>
