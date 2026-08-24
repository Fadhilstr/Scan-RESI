<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <!-- Header Page Section -->
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="row items-center">
          <h4 class="text-h4 text-weight-bolder text-slate-900 q-my-none q-mr-sm">SCAN PAKET</h4>
          <StatusBadge :status="scanStore.scanStatus" size="md" />
        </div>
        <div class="text-subtitle2 text-grey-7">Core Feature: Masukkan atau scan barcode paket ekspedisi</div>
      </div>

      <div v-if="scanStore.isFinished">
        <q-btn
          color="positive"
          icon="analytics"
          label="LIHAT HASIL SCAN"
          unelevated
          to="/hasil"
          class="text-weight-bold"
        />
        <q-btn
          color="primary"
          icon="add_circle"
          label="MULAI SCAN BARU"
          outline
          class="q-ml-sm text-weight-bold"
          @click="resetNewSession"
        />
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Barcode Input Component -->
    <ScanInput :disabled="scanStore.isFinished" />

    <!-- Total Paket & Last Scanned Summary Component -->
    <ScanSummary />

    <!-- Daftar Paket View (Responsive: QTable for Desktop, PaketCard for Mobile) -->
    <div class="q-mb-xl">
      <PaketTable v-if="$q.screen.gt.xs" />
      <PaketCard v-else />
    </div>

    <!-- Finish Scan Action Footer Button (Requirement Section 5 & 9) -->
    <div class="row justify-end q-mt-lg">
      <q-btn
        v-if="!scanStore.isFinished"
        color="primary"
        size="lg"
        icon="check_circle"
        label="SELESAI SCAN"
        class="text-weight-bolder q-px-xl shadow-4"
        unelevated
        :disabled="scanStore.paketList.length === 0"
        @click="confirmFinish"
      >
        <q-tooltip>Selesaikan sesi scan dan kunci daftar paket</q-tooltip>
      </q-btn>
    </div>

    <!-- Confirmation Dialog for Selesaikan Scan (Requirement Section 9) -->
    <q-dialog v-model="showFinishDialog" persistent>
      <q-card style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="row items-center q-pb-none">
          <q-avatar icon="help_outline" color="blue-1" text-color="primary" />
          <span class="q-ml-sm text-h6 text-weight-bold">Konfirmasi Selesai</span>
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div class="text-body1 text-slate-800">
            Apakah Anda yakin ingin menyelesaikan proses scan?
          </div>
          <div class="q-mt-md bg-blue-1 q-pa-md rounded-borders text-center">
            <div class="text-caption text-grey-7">TOTAL PAKET DISCAN</div>
            <div class="text-h3 text-weight-bolder text-primary font-mono">
              {{ scanStore.totalPaket }}
            </div>
          </div>
          <div class="text-caption text-negative q-mt-sm text-center">
            * Setelah proses selesai, paket baru tidak dapat ditambahkan pada sesi ini.
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="BATAL" color="grey-7" v-close-popup class="text-weight-bold" />
          <q-btn label="SELESAI" color="primary" @click="executeFinish" class="text-weight-bold" unelevated />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useScanStore } from '../stores/scanStore'
import StatusBadge from '../components/StatusBadge.vue'
import ScanInput from '../components/ScanInput.vue'
import ScanSummary from '../components/ScanSummary.vue'
import PaketTable from '../components/PaketTable.vue'
import PaketCard from '../components/PaketCard.vue'

const $q = useQuasar()
const router = useRouter()
const scanStore = useScanStore()

const showFinishDialog = ref(false)

const confirmFinish = () => {
  showFinishDialog.value = true
}

const executeFinish = () => {
  scanStore.finishScanSession()
  showFinishDialog.value = false

  $q.notify({
    type: 'positive',
    icon: 'task_alt',
    message: 'Proses scan berhasil diselesaikan!',
    position: 'top',
    timeout: 2000
  })

  // Navigate to Hasil Scan page (Section 16 Routing Flow)
  router.push('/hasil')
}

const resetNewSession = () => {
  scanStore.resetNewSession()
  $q.notify({
    type: 'info',
    icon: 'refresh',
    message: 'Sesi scan baru telah dimulai.',
    position: 'top',
    timeout: 1800
  })
}
</script>
