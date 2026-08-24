<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-slate-900 q-my-none">HASIL SCAN PAKET</h4>
        <div class="text-subtitle2 text-grey-7">Rekapitulasi lengkap sesi pengindaian paket ekspedisi</div>
      </div>

      <div class="row q-gutter-sm">
        <q-btn
          color="primary"
          icon="add_circle"
          label="MULAI SCAN BARU"
          unelevated
          class="text-weight-bold"
          @click="startNewScan"
        />
        <q-btn
          outline
          color="slate-700"
          icon="dashboard"
          label="DASHBOARD"
          to="/"
          class="text-weight-bold"
        />
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Result Banner Card (Requirement Section 8) -->
    <q-card class="scan-card q-pa-md q-mb-lg bg-green-1 border-green">
      <q-card-section>
        <div class="row items-center justify-between">
          <div class="row items-center">
            <q-avatar icon="verified" color="positive" text-color="white" size="50px" class="q-mr-md shadow-2" />
            <div>
              <div class="text-h5 text-weight-bolder text-green-10">SESI SCAN TELAH SELESAI</div>
              <div class="text-subtitle2 text-green-9">Semua data resi paket telah terkunci dan tersimpan dalam riwayat.</div>
            </div>
          </div>

          <div class="q-mt-sm q-mt-md-none text-right">
            <StatusBadge status="SELESAI" size="lg" />
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Stats Rekap Card -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="scan-card text-center q-pa-sm">
          <q-card-section>
            <div class="text-caption text-grey-7 text-weight-bold">TOTAL PAKET TERINDAI</div>
            <div class="text-h2 text-weight-bolder text-primary font-mono q-my-xs">
              {{ scanStore.totalPaket }}
            </div>
            <div class="text-caption text-grey-6">Nomor Resi Unik</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-4">
        <q-card class="scan-card text-center q-pa-sm">
          <q-card-section>
            <div class="text-caption text-grey-7 text-weight-bold">WAKTU MULAI SCAN</div>
            <div class="text-h4 text-weight-bolder text-slate-800 font-mono q-my-xs">
              {{ scanStore.scanStartTime }}
            </div>
            <div class="text-caption text-grey-6">Jam Operasional</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-12 col-md-4">
        <q-card class="scan-card text-center q-pa-sm">
          <q-card-section>
            <div class="text-caption text-grey-7 text-weight-bold">STATUS SESI</div>
            <div class="text-h4 text-weight-bolder text-positive font-mono q-my-xs row items-center justify-center">
              <q-icon name="check_circle" class="q-mr-xs" />
              LENGKAP
            </div>
            <div class="text-caption text-grey-6">Siap dikirim / diproses lanjut</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Scanned Package List Details (Requirement Section 8) -->
    <q-card class="scan-card">
      <q-card-section class="row items-center justify-between">
        <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
          <q-icon name="fact_check" color="primary" class="q-mr-sm" size="24px" />
          DAFTAR HASIL RESI PAKET ({{ scanStore.totalPaket }})
        </div>
      </q-card-section>

      <q-separator />

      <q-card-section>
        <div v-if="scanStore.paketList.length === 0" class="text-center q-pa-lg text-grey-6">
          Tidak ada data resi paket pada sesi ini.
        </div>

        <div v-else class="row q-col-gutter-sm">
          <div
            v-for="(item, index) in scanStore.paketList"
            :key="item.id"
            class="col-12 col-sm-6 col-md-4"
          >
            <q-card flat bordered class="q-pa-sm bg-slate-50 rounded-borders">
              <div class="row items-center justify-between">
                <div class="row items-center">
                  <q-badge color="primary" text-color="white" class="q-mr-sm text-weight-bold font-mono">
                    {{ index + 1 }}
                  </q-badge>
                  <span class="font-mono text-weight-bolder text-subtitle1 text-slate-900">
                    {{ item.nomor_resi }}
                  </span>
                </div>
                <div class="text-caption text-grey-7 font-mono">
                  <q-icon name="schedule" size="12px" /> {{ item.waktu_scan }}
                </div>
              </div>
            </q-card>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useScanStore } from '../stores/scanStore'
import StatusBadge from '../components/StatusBadge.vue'

const $q = useQuasar()
const router = useRouter()
const scanStore = useScanStore()

const startNewScan = () => {
  scanStore.resetNewSession()
  $q.notify({
    type: 'info',
    icon: 'play_arrow',
    message: 'Sesi scan baru dimulai.',
    position: 'top',
    timeout: 1800
  })
  router.push('/scan')
}
</script>
