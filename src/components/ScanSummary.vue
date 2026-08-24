<template>
  <div class="row q-col-gutter-md q-mb-lg">
    <!-- Status & Total Paket Card -->
    <div class="col-12 col-md-5">
      <q-card class="scan-card full-height q-pa-sm">
        <q-card-section>
          <div class="row items-center justify-between q-mb-xs">
            <span class="text-subtitle2 text-weight-bold text-grey-8">STATUS SESI SCAN</span>
            <StatusBadge :status="scanStore.scanStatus" size="md" />
          </div>

          <q-separator class="q-my-sm" />

          <div class="row items-center justify-between q-pt-xs">
            <div>
              <div class="text-caption text-grey-7 text-weight-medium">TOTAL PAKET DISCAN</div>
              <div class="text-h3 text-weight-bolder text-primary font-mono q-my-none">
                {{ scanStore.totalPaket }}
              </div>
              <div class="text-caption text-grey-6">Dimulai pukul {{ scanStore.scanStartTime }}</div>
            </div>

            <div class="q-pa-md bg-blue-1 rounded-borders text-center" style="border-radius: 12px;">
              <q-icon name="inventory_2" size="42px" color="primary" />
            </div>
          </div>
        </q-card-section>
      </q-card>
    </div>

    <!-- Paket Terakhir Card -->
    <div class="col-12 col-md-7">
      <q-card class="scan-card full-height q-pa-sm">
        <q-card-section>
          <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs row items-center">
            <q-icon name="history" color="primary" class="q-mr-xs" /> PAKET TERAKHIR
          </div>

          <q-separator class="q-my-sm" />

          <div v-if="scanStore.lastScanned" class="row items-center justify-between q-pt-xs">
            <div>
              <div class="text-h5 text-weight-bolder text-slate-900 font-mono">
                {{ scanStore.lastScanned.nomor_resi }}
              </div>
              <div class="row items-center text-positive text-weight-bold q-mt-xs">
                <q-icon name="check_circle" size="18px" class="q-mr-xs" />
                Berhasil discan
              </div>
            </div>

            <div class="text-right">
              <q-badge color="grey-3" text-color="slate-900" class="q-pa-xs font-mono text-subtitle2">
                <q-icon name="schedule" size="14px" class="q-mr-xs" />
                {{ scanStore.lastScanned.waktu_scan }}
              </q-badge>
            </div>
          </div>

          <div v-else class="text-center q-pa-md text-grey-6">
            <q-icon name="qr_code_scanner" size="32px" class="q-mb-xs" />
            <div>Belum ada paket yang discan pada sesi ini.</div>
          </div>
        </q-card-section>
      </q-card>
    </div>
  </div>
</template>

<script setup>
import { useScanStore } from '../stores/scanStore'
import StatusBadge from './StatusBadge.vue'

const scanStore = useScanStore()
</script>
