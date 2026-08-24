<template>
  <div>
    <q-card class="scan-card">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-subtitle1 text-weight-bold text-slate-800 row items-center">
          <q-icon name="list_alt" size="24px" color="primary" class="q-mr-sm" />
          DAFTAR PAKET ({{ scanStore.totalPaket }})
        </div>
        <q-chip outline color="primary" size="sm" class="text-weight-bold">
          Desktop Table View
        </q-chip>
      </q-card-section>

      <q-card-section>
        <q-table
          :rows="tableRows"
          :columns="columns"
          row-key="id"
          flat
          bordered
          :pagination="pagination"
          no-data-label="Belum ada data paket"
          class="no-shadow"
        >
          <template v-slot:body-cell-no="props">
            <q-td :props="props" class="text-weight-bold text-grey-7">
              {{ props.row.index }}
            </q-td>
          </template>

          <template v-slot:body-cell-nomor_resi="props">
            <q-td :props="props">
              <span class="font-mono text-weight-bolder text-subtitle2 text-slate-900">
                {{ props.row.nomor_resi }}
              </span>
            </q-td>
          </template>

          <template v-slot:body-cell-waktu_scan="props">
            <q-td :props="props" class="font-mono text-grey-8">
              {{ props.row.waktu_scan }}
            </q-td>
          </template>

          <template v-slot:body-cell-status="props">
            <q-td :props="props">
              <StatusBadge :status="props.row.status" size="sm" />
            </q-td>
          </template>

          <template v-slot:body-cell-aksi="props">
            <q-td :props="props" class="text-center">
              <q-btn
                color="negative"
                icon="delete"
                flat
                round
                dense
                :disabled="scanStore.isFinished"
                @click="confirmDelete(props.row)"
              >
                <q-tooltip>Hapus Paket</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- Delete Confirmation Dialog (Requirement Section 10) -->
    <q-dialog v-model="showDeleteDialog" persistent>
      <q-card style="min-width: 350px; border-radius: 16px;">
        <q-card-section class="row items-center q-pb-none">
          <q-avatar icon="delete_outline" color="red-1" text-color="negative" />
          <span class="q-ml-sm text-h6 text-weight-bold">Konfirmasi Hapus</span>
        </q-card-section>

        <q-card-section class="q-pt-md">
          Apakah Anda yakin ingin menghapus paket dengan nomor resi:
          <div class="q-mt-sm font-mono text-weight-bolder text-h6 text-negative text-center bg-red-1 q-pa-sm rounded-borders">
            {{ targetItem?.nomor_resi }}
          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md">
          <q-btn flat label="BATAL" color="grey-7" v-close-popup class="text-weight-bold" />
          <q-btn label="HAPUS" color="negative" @click="executeDelete" class="text-weight-bold" unelevated />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useQuasar } from 'quasar'
import { useScanStore } from '../stores/scanStore'
import StatusBadge from './StatusBadge.vue'

const $q = useQuasar()
const scanStore = useScanStore()

const showDeleteDialog = ref(false)
const targetItem = ref(null)

const pagination = ref({
  rowsPerPage: 10
})

const columns = [
  { name: 'no', label: 'No', field: 'index', align: 'center', sortable: false },
  { name: 'nomor_resi', label: 'Nomor Resi', field: 'nomor_resi', align: 'left', sortable: true },
  { name: 'waktu_scan', label: 'Waktu Scan', field: 'waktu_scan', align: 'center', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: false },
  { name: 'aksi', label: 'Aksi', field: 'aksi', align: 'center' }
]

const tableRows = computed(() => {
  return scanStore.paketList.map((item, idx) => ({
    ...item,
    index: idx + 1
  }))
})

const confirmDelete = (item) => {
  targetItem.value = item
  showDeleteDialog.value = true
}

const executeDelete = () => {
  if (!targetItem.value) return
  
  const resi = targetItem.value.nomor_resi
  const result = scanStore.removePaket(targetItem.value.id)
  
  showDeleteDialog.value = false
  
  if (result.success) {
    $q.notify({
      type: 'info',
      icon: 'delete_sweep',
      message: `Nomor resi ${resi} berhasil dihapus.`,
      position: 'top',
      timeout: 2000
    })
  }
}
</script>
