<template>
  <div>
    <q-card class="scan-card">
      <q-card-section class="row items-center justify-between q-pb-xs">
        <div class="text-subtitle1 text-weight-bold text-slate-800 row items-center">
          <q-icon name="view_headline" size="24px" color="primary" class="q-mr-sm" />
          DAFTAR PAKET ({{ scanStore.totalPaket }})
        </div>
        <q-chip outline color="accent" size="sm" class="text-weight-bold">
          Mobile Card View
        </q-chip>
      </q-card-section>

      <q-card-section class="q-pt-xs">
        <div v-if="scanStore.paketList.length === 0" class="text-center q-pa-lg text-grey-6">
          <q-icon name="inbox" size="48px" class="q-mb-xs" />
          <div>Belum ada data paket yang discan.</div>
        </div>

        <div v-else class="column q-gutter-y-sm">
          <q-card
            v-for="(item, index) in scanStore.paketList"
            :key="item.id"
            flat
            bordered
            class="bg-white rounded-borders q-pa-sm shadow-1"
          >
            <div class="row items-center justify-between">
              <div class="row items-center col-8">
                <q-badge color="grey-3" text-color="dark" class="q-mr-sm text-weight-bold font-mono">
                  #{{ index + 1 }}
                </q-badge>

                <div>
                  <div class="font-mono text-weight-bolder text-subtitle1 text-slate-900">
                    {{ item.nomor_resi }}
                  </div>
                  <div class="text-caption text-grey-6 row items-center">
                    <q-icon name="schedule" size="12px" class="q-mr-xs" />
                    {{ item.waktu_scan }}
                  </div>
                </div>
              </div>

              <div class="row items-center col-4 justify-end">
                <StatusBadge :status="item.status" size="xs" class="q-mr-xs" />
                <q-btn
                  color="negative"
                  icon="delete"
                  flat
                  round
                  dense
                  :disabled="scanStore.isFinished"
                  @click="confirmDelete(item)"
                />
              </div>
            </div>
          </q-card>
        </div>
      </q-card-section>
    </q-card>

    <!-- Delete Confirmation Dialog Mobile -->
    <q-dialog v-model="showDeleteDialog" persistent>
      <q-card style="min-width: 320px; border-radius: 16px;">
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
import { ref } from 'vue'
import { useQuasar } from 'quasar'
import { useScanStore } from '../stores/scanStore'
import StatusBadge from './StatusBadge.vue'

const $q = useQuasar()
const scanStore = useScanStore()

const showDeleteDialog = ref(false)
const targetItem = ref(null)

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
