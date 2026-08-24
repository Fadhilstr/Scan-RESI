<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">System Audit Log</h4>
        <div class="text-subtitle2 text-grey-7">Log Jejak Aktivitas Keamanan & Perubahan Data Sistem</div>
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <q-card class="scan-card">
      <q-card-section>
        <q-table
          :rows="auditLogs"
          :columns="columns"
          row-key="id"
          flat
          bordered
          no-data-label="Belum ada audit log"
        >
          <template v-slot:body-cell-timestamp="props">
            <q-td :props="props" class="font-mono text-grey-8">
              {{ props.row.timestamp }}
            </q-td>
          </template>

          <template v-slot:body-cell-user="props">
            <q-td :props="props" class="text-weight-bold text-slate-900">
              {{ props.row.user }}
            </q-td>
          </template>

          <template v-slot:body-cell-action="props">
            <q-td :props="props">
              <q-badge color="blue-1" text-color="primary" class="font-mono text-weight-bold">
                {{ props.row.action }}
              </q-badge>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'

const auditLogs = ref([
  { id: 1, timestamp: '24-08-2026 10:20:00', user: 'Fadhil (USR-001)', action: 'LOGIN_SUCCESS', details: 'IP: 192.168.3.189' },
  { id: 2, timestamp: '24-08-2026 10:21:32', user: 'Fadhil (USR-001)', action: 'SCAN_EVENT_CREATED', details: 'Resi: GJXL8FLB, Status: SUCCESS' },
  { id: 3, timestamp: '24-08-2026 09:45:00', user: 'Budi (USR-002)', action: 'LOGIN_SUCCESS', details: 'IP: 192.168.3.102' },
  { id: 4, timestamp: '24-08-2026 08:15:00', user: 'Supervisor A (USR-SPV-001)', action: 'SUPERVISOR_LOGIN', details: 'Monitoring rayon active' }
])

const columns = [
  { name: 'timestamp', label: 'Waktu', field: 'timestamp', align: 'left', sortable: true },
  { name: 'user', label: 'Pengguna', field: 'user', align: 'left', sortable: true },
  { name: 'action', label: 'Aksi System', field: 'action', align: 'center', sortable: true },
  { name: 'details', label: 'Detail Aktivitas', field: 'details', align: 'left' }
]
</script>
