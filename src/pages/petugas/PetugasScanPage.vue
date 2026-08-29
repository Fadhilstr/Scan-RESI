<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <!-- Header Page Section (Requirement T) -->
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="row items-center">
          <h4 class="page-title q-mr-sm">Scan Paket</h4>
          <StatusBadge :status="activeTask?.status || 'SELESAI'" size="md" />
        </div>
        <div class="page-subtitle">
          Petugas <span class="text-weight-medium text-slate-800">{{ authStore.currentUser?.name }}</span> &middot;
          Task <span class="font-mono text-weight-medium text-slate-800">{{ activeTask?.task_id || '-' }}</span> &middot;
          Shift {{ activeTask?.shift || '-' }}
        </div>
      </div>

      <div v-if="isTaskFinished">
        <q-btn
          color="primary"
          icon="analytics"
          label="Hasil Scan Saya"
          no-caps
          unelevated
          to="/petugas/hasil"
        />
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Barcode Input Component (Requirement T & U) -->
    <BarcodeInput :disabled="isTaskFinished" :feedback="scanFeedback" @scan="handleBarcodeScan" />

    <!-- Active Task Progress Summary -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-md-5">
        <q-card class="scan-card full-height q-pa-sm">
          <q-card-section>
            <div class="row items-center justify-between q-mb-xs">
              <span class="overline-label">Total Scan Hari Ini</span>
              <span class="font-mono text-weight-bold text-primary bg-blue-1 q-px-sm" style="border-radius: 6px;">
                {{ userScans.length }} paket
              </span>
            </div>

            <q-separator class="q-my-sm" />

            <div class="row items-center justify-between q-pt-xs">
              <div>
                <div class="overline-label">Capaian Target Task</div>
                <div class="kpi-value text-slate-900 font-mono q-my-xs">
                  {{ activeTask?.progress || 0 }} / {{ activeTask?.target || 0 }}
                </div>
                <div class="text-caption text-grey-6">Lokasi: {{ activeTask?.lokasi || 'CIPUTAT' }}</div>
              </div>

              <div class="q-pa-md bg-grey-1 text-center" style="border-radius: 12px; border: 1px solid var(--dj-border);">
                <q-icon name="inventory_2" size="40px" color="grey-7" />
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Last Scanned Event Card -->
      <div class="col-12 col-md-7">
        <q-card class="scan-card full-height q-pa-sm">
          <q-card-section>
            <div class="section-title q-mb-xs">
              <q-icon name="history" size="20px" color="primary" class="q-mr-sm" /> Resi Terakhir Discan
            </div>

            <q-separator class="q-my-sm" />

            <div v-if="lastScannedEvent" class="row items-center justify-between q-pt-xs">
              <div>
                <div class="text-h5 text-weight-bold text-slate-900 font-mono">
                  {{ lastScannedEvent.nomor_resi }}
                </div>
                <div class="row items-center q-mt-xs">
                  <StatusBadge :status="lastScannedEvent.status_scan" size="xs" />
                </div>
              </div>

              <div class="text-right">
                <span class="text-caption font-mono text-grey-6 bg-grey-1 q-px-sm q-py-xs" style="border-radius: 6px;">
                  {{ lastScannedEvent.waktu_scan.split(' ')[1] }}
                </span>
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

    <!-- Data Paket Terakhir (hasil lookup by nomor resi) -->
    <q-card v-if="lastPaket" class="scan-card q-pa-sm q-mb-lg">
      <q-card-section>
        <div class="section-title q-mb-xs">
          <q-icon name="inventory_2" size="20px" color="primary" class="q-mr-sm" /> Data Paket
          <span class="font-mono text-caption text-grey-6 q-ml-sm">{{ lastPaket.nomor_resi }}</span>
        </div>
        <q-separator class="q-my-sm" />

        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-4">
            <div class="text-caption text-grey-7">Nama Barang</div>
            <div class="text-weight-bolder text-slate-900">{{ lastPaket.nama_barang || '-' }}</div>
            <div class="text-caption text-grey-6 q-mt-xs">Layanan: {{ lastPaket.jenis_layanan }} • {{ lastPaket.berat_kg }} kg</div>
          </div>
          <div class="col-12 col-md-4">
            <div class="text-caption text-grey-7">Pengirim</div>
            <div class="text-weight-bold text-slate-800">{{ lastPaket.pengirim || '-' }}</div>
          </div>
          <div class="col-12 col-md-4">
            <div class="text-caption text-grey-7">Penerima / Tujuan</div>
            <div class="text-weight-bold text-slate-800">{{ lastPaket.penerima || '-' }}</div>
            <div class="text-caption text-grey-6">{{ lastPaket.alamat_tujuan || '' }}</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Scanned Items Table View -->
    <div class="q-mb-xl">
      <ScanEventTable :scans="userScans" :show-petugas-filter="false" show-label-action @label="openLabel" />
    </div>

    <!-- Finish Task Action Button (Requirement Z) -->
    <div class="row justify-end q-mt-lg">
      <q-btn
        v-if="!isTaskFinished"
        color="primary"
        size="lg"
        icon="check_circle"
        label="Selesaikan Task"
        no-caps
        class="q-px-xl"
        unelevated
        @click="confirmFinishTask"
      >
        <q-tooltip>Selesaikan task dan kunci proses pemindaian</q-tooltip>
      </q-btn>
    </div>

    <!-- Selesaikan Task Confirmation Dialog (Requirement Z) -->
    <q-dialog v-model="showFinishModal" persistent>
      <q-card style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="row items-center q-pb-none">
          <q-avatar icon="task_alt" color="blue-1" text-color="primary" />
          <span class="q-ml-sm text-h6 text-weight-bold">Selesaikan task?</span>
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div class="text-body2 text-grey-7">
            Pastikan seluruh paket telah discan. Setelah dikonfirmasi, input barcode akan terkunci dan status task menjadi Selesai.
          </div>

          <div class="q-mt-md bg-grey-1 q-pa-md text-center" style="border-radius: 12px; border: 1px solid var(--dj-border);">
            <div class="overline-label">Capaian Scan Task</div>
            <div class="kpi-value text-primary font-mono">
              {{ activeTask?.progress }} / {{ activeTask?.target }}
            </div>
            <div class="text-caption text-grey-6 font-mono">Task ID: {{ activeTask?.task_id }}</div>
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="Batal" no-caps color="grey-7" v-close-popup />
          <q-btn label="Selesaikan" no-caps color="primary" unelevated @click="executeFinishTask" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Konfirmasi Scan Barcode Dialog -->
    <q-dialog v-model="showConfirmScanModal" persistent>
      <q-card style="min-width: 380px; max-width: 480px; border-radius: 16px;">
        <q-card-section class="row items-center q-pb-none">
          <q-avatar icon="qr_code_scanner" color="blue-1" text-color="primary" />
          <div class="q-ml-sm">
            <div class="text-h6 text-weight-bold leading-tight">Konfirmasi Scan Resi</div>
            <div class="text-caption text-grey-6">Verifikasi nomor resi sebelum diproses</div>
          </div>
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div class="q-pa-md text-center q-mb-md" style="border-radius: 12px; border: 1.5px dashed var(--q-primary); background-color: #f0f7ff;">
            <div class="overline-label text-grey-7">Nomor Resi</div>
            <div class="text-h5 text-weight-bolder text-primary font-mono q-my-xs">
              {{ pendingResi }}
            </div>
            <div class="text-caption text-grey-6 font-mono">
              Task: {{ activeTask?.task_id || '-' }} &middot; {{ activeTask?.lokasi || 'CIPUTAT' }}
            </div>
          </div>

          <!-- Preview Paket Data jika ada -->
          <div v-if="previewPaket" class="bg-grey-1 q-pa-sm q-mb-sm rounded-borders" style="border: 1px solid var(--dj-border); font-size: 0.85rem;">
            <div class="row justify-between items-center q-mb-xs">
              <span class="text-weight-bold text-slate-800">{{ previewPaket.nama_barang || '(Nama barang kosong)' }}</span>
              <StatusBadge :status="previewPaket.status" size="xs" />
            </div>
            <div class="text-caption text-grey-7">
              {{ previewPaket.pengirim || '-' }} &rarr; {{ previewPaket.penerima || '-' }} <span v-if="previewPaket.alamat_tujuan">({{ previewPaket.alamat_tujuan }})</span>
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              Layanan: {{ previewPaket.jenis_layanan || '-' }} &bull; {{ previewPaket.berat_kg || '-' }} kg
            </div>
          </div>
          <div v-else class="text-caption text-grey-6 bg-grey-1 q-pa-sm rounded-borders q-mb-sm text-center">
            <q-icon name="info" size="16px" class="q-mr-xs text-grey-5" />
            Data paket belum terdaftar di master data
          </div>

          <div class="text-body2 text-grey-7 text-center q-mt-sm">
            Apakah Anda yakin ingin memproses scan untuk nomor resi di atas?
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md q-pt-none">
          <q-btn flat label="Batal" no-caps color="grey-7" v-close-popup @click="cancelScanConfirmation" />
          <q-btn
            label="Konfirmasi Scan"
            icon="check_circle"
            no-caps
            color="primary"
            unelevated
            :loading="isProcessingScan"
            @click="executeScan"
            autofocus
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Dialog Generate Barcode Label -->
    <BarcodeLabel v-model="showLabel" :resi="labelResi" :paket-data="labelPaketData" />
  </q-page>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '../../stores/authStore'
import { useTaskStore } from '../../stores/taskStore'
import { useScanStore } from '../../stores/scanStore'
import { usePaketStore } from '../../stores/paketStore'
import StatusBadge from '../../components/StatusBadge.vue'
import BarcodeInput from '../../components/BarcodeInput.vue'
import ScanEventTable from '../../components/ScanEventTable.vue'
import BarcodeLabel from '../../components/BarcodeLabel.vue'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()
const taskStore = useTaskStore()
const scanStore = useScanStore()
const paketStore = usePaketStore()

const showFinishModal = ref(false)
const showConfirmScanModal = ref(false)
const pendingResi = ref('')
const previewPaket = ref(null)
const isProcessingScan = ref(false)
const lastPaket = ref(null)
const showLabel = ref(false)
const labelResi = ref('')
const labelPaketData = ref(null)

// Umpan balik hasil validasi scan terakhir → ditampilkan di dialog kamera
// dan komponen input. { seq, resi, level, label, message, detail }
let feedbackSeq = 0
const scanFeedback = ref(null)

const setFeedback = (resi, level, label, message, detail = '') => {
  scanFeedback.value = { seq: ++feedbackSeq, resi, level, label, message, detail }
}

const openLabel = async (row) => {
  const resi = row?.nomor_resi || ''
  labelResi.value = resi
  let p = paketStore.findPaketByResi(resi)
  if (!p && resi) {
    const res = await paketStore.lookupByResi(resi)
    if (res.success) p = res.paket
  }
  labelPaketData.value = p || null
  showLabel.value = true
}

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
    const msg = activeTask.value
      ? `Task ${activeTask.value.task_id} sudah selesai — tidak dapat melakukan scan.`
      : 'Tidak ada task aktif — minta admin membuat task terlebih dahulu.'

    setFeedback(resiInput, 'danger', 'DITOLAK', msg)
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: msg,
      position: 'top',
      timeout: 3000
    })
    return
  }

  const cleanResi = (resiInput || '').trim().toUpperCase()
  if (!cleanResi) return

  // Lookup paket preview untuk konfirmasi
  pendingResi.value = cleanResi
  const lookup = await paketStore.lookupByResi(cleanResi)
  previewPaket.value = lookup.success ? lookup.paket : null

  // Tampilkan alert / dialog konfirmasi scan
  showConfirmScanModal.value = true
}

const cancelScanConfirmation = () => {
  showConfirmScanModal.value = false
  pendingResi.value = ''
  previewPaket.value = null
}

const executeScan = async () => {
  const resiToScan = pendingResi.value
  if (!resiToScan) return

  isProcessingScan.value = true
  try {
    const result = await scanStore.addScanEvent({
      resi: resiToScan,
      currentUser: authStore.currentUser,
      activeTask: activeTask.value,
      lokasi: activeTask.value?.lokasi || 'CIPUTAT',
      device_id: 'SCAN-DEVICE-01',
      jenis_scan: 'INBOUND'
    })

    // Lookup paket selalu dijalankan — untuk kartu data paket dan
    // memperkaya pesan penolakan (tahap "Cari Data Paket").
    const lookup = await paketStore.lookupByResi(resiToScan)
    lastPaket.value = lookup.success ? lookup.paket : null

    showConfirmScanModal.value = false
    pendingResi.value = ''
    previewPaket.value = null

    if (result.success) {
      setFeedback(resiToScan, 'success', 'MASUK', result.message)
      $q.notify({
        type: 'positive',
        icon: 'check_circle',
        message: result.message,
        position: 'top',
        timeout: 1800
      })
      return
    }

    if (result.reason === 'DUPLICATE') {
      setFeedback(resiToScan, 'warning', 'DUPLIKAT', result.message)
      $q.notify({
        type: 'warning',
        icon: 'warning',
        message: result.message,
        position: 'top',
        timeout: 3000
      })
      return
    }

    if (result.reason === 'DRAFT') {
      const draft = lookup.success ? lookup.paket : null
      const detail = draft
        ? `${draft.nama_barang || '(nama barang kosong)'} • ${draft.pengirim || '-'} → ${draft.penerima || '-'}`
        : ''
      const msg = draft
        ? `Resi masih DRAFT — customer belum menyelesaikan data barang.`
        : result.message

      setFeedback(resiToScan, 'danger', 'MASIH DRAFT', msg, detail)
      $q.notify({
        type: 'warning',
        icon: 'gpp_bad',
        message: detail ? `${msg} (${detail})` : msg,
        position: 'top',
        timeout: 4500
      })
      return
    }

    if (result.reason === 'UNKNOWN_RESI') {
      setFeedback(resiToScan, 'danger', 'TAK DIKENAL', result.message)
      $q.notify({
        type: 'warning',
        icon: 'gpp_bad',
        message: result.message,
        position: 'top',
        timeout: 3500
      })
      return
    }

    // FINISHED / EMPTY / ERROR / lainnya
    setFeedback(resiToScan, 'danger', 'GAGAL', result.message)
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: result.message,
      position: 'top',
      timeout: 2500
    })
  } finally {
    isProcessingScan.value = false
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
