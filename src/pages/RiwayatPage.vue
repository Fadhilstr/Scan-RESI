<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-slate-900 q-my-none">RIWAYAT SCAN PAKET</h4>
        <div class="text-subtitle2 text-grey-7">Daftar riwayat sesi pengindaian resi paket terdahulu</div>
      </div>

      <q-btn
        color="primary"
        icon="qr_code_scanner"
        label="MULAI SCAN PAKET"
        to="/scan"
        unelevated
        class="text-weight-bold"
      />
    </div>

    <q-separator class="q-mb-lg" />

    <q-card class="scan-card">
      <q-card-section class="row items-center justify-between">
        <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
          <q-icon name="history" color="primary" class="q-mr-sm" size="24px" />
          LOG SESI OPERASIONAL
        </div>
      </q-card-section>

      <q-card-section>
        <q-table
          :rows="scanStore.historyList"
          :columns="columns"
          row-key="id"
          flat
          bordered
          no-data-label="Belum ada riwayat scan"
        >
          <template v-slot:body-cell-tanggal="props">
            <q-td :props="props">
              <span class="font-mono text-weight-bold text-slate-900">
                <q-icon name="event" size="16px" class="q-mr-xs text-primary" />
                {{ props.row.tanggal }}
              </span>
            </q-td>
          </template>

          <template v-slot:body-cell-total_paket="props">
            <q-td :props="props" class="text-center">
              <q-badge color="blue-1" text-color="primary" class="q-pa-xs font-mono text-weight-bolder text-subtitle2">
                {{ props.row.total_paket }} Paket
              </q-badge>
            </q-td>
          </template>

          <template v-slot:body-cell-status="props">
            <q-td :props="props" class="text-center">
              <StatusBadge :status="props.row.status" size="sm" />
            </q-td>
          </template>

          <template v-slot:body-cell-jam="props">
            <q-td :props="props" class="text-center font-mono text-grey-8">
              {{ props.row.scan_start }} - {{ props.row.scan_end }}
            </q-td>
          </template>

          <template v-slot:body-cell-aksi="props">
            <q-td :props="props" class="text-center">
              <q-btn
                color="primary"
                icon="visibility"
                label="Detail"
                flat
                dense
                class="text-weight-bold"
                @click="showDetail(props.row)"
              />
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- Detail Dialog -->
    <q-dialog v-model="showDetailDialog">
      <q-card style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="row items-center justify-between q-pb-xs">
          <div class="text-h6 text-weight-bold row items-center">
            <q-icon name="receipt_long" color="primary" class="q-mr-xs" />
            Detail Sesi {{ selectedHistory?.tanggal }}
          </div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-pt-md">
          <div class="row q-col-gutter-sm q-mb-md text-center">
            <div class="col-6 bg-blue-1 q-pa-sm rounded-borders">
              <div class="text-caption text-grey-7">TOTAL PAKET</div>
              <div class="text-h5 text-weight-bolder text-primary font-mono">
                {{ selectedHistory?.total_paket }} Paket
              </div>
            </div>

            <div class="col-6 bg-green-1 q-pa-sm rounded-borders">
              <div class="text-caption text-grey-7">STATUS</div>
              <StatusBadge :status="selectedHistory?.status || 'SELESAI'" size="sm" class="q-mt-xs" />
            </div>
          </div>

          <div class="text-subtitle2 text-weight-bold q-mb-xs">Waktu Operasional:</div>
          <div class="font-mono text-grey-8 bg-grey-2 q-pa-xs rounded-borders text-center">
            {{ selectedHistory?.scan_start }} WIB s/d {{ selectedHistory?.scan_end }} WIB
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn label="TUTUP" color="primary" v-close-popup class="text-weight-bold" unelevated />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import { useScanStore } from '../stores/scanStore'
import StatusBadge from '../components/StatusBadge.vue'

const scanStore = useScanStore()
const showDetailDialog = ref(false)
const selectedHistory = ref(null)

const columns = [
  { name: 'tanggal', label: 'Tanggal', field: 'tanggal', align: 'left', sortable: true },
  { name: 'total_paket', label: 'Total Paket', field: 'total_paket', align: 'center', sortable: true },
  { name: 'jam', label: 'Waktu Operasional', field: 'scan_start', align: 'center' },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: false },
  { name: 'aksi', label: 'Aksi', field: 'aksi', align: 'center' }
]

const showDetail = (row) => {
  selectedHistory.value = row
  showDetailDialog.value = true
}
</script>
