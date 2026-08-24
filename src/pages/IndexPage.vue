<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-lg">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Dashboard Wahana Express</h4>
        <div class="text-subtitle1 text-grey-7">Ringkasan status pengindaian paket ekspedisi hari ini</div>
      </div>

      <div>
        <q-btn
          color="primary"
          size="lg"
          icon="qr_code_scanner"
          label="MULAI SCAN PAKET"
          class="text-weight-bolder shadow-3 q-px-md bg-wahana-navy"
          unelevated
          to="/scan"
        >
          <q-tooltip>Buka halaman utama scan paket Wahana Express</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- Stat Cards Section -->
    <div class="row q-col-gutter-md q-mb-xl">
      <!-- Card 1: Total Paket Hari Ini -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Paket Hari Ini</span>
              <q-avatar icon="inventory_2" color="blue-1" text-color="primary" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-wahana-navy font-mono">
              {{ scanStore.dashboardStats.totalHariIni }}
            </div>
            <div class="text-caption text-positive text-weight-bold q-mt-xs row items-center">
              <q-icon name="trending_up" class="q-mr-xs" /> Target operasional 150 paket
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Card 2: Total Paket Discan -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Sudah Discan</span>
              <q-avatar icon="task_alt" color="amber-1" text-color="amber-9" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-amber-9 font-mono">
              {{ scanStore.dashboardStats.totalDiscan + scanStore.totalPaket }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">Termasuk sesi aktif saat ini</div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Card 3: Total Proses -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Proses Selesai</span>
              <q-avatar icon="fact_check" color="green-1" text-color="positive" size="40px" />
            </div>
            <div class="text-h3 text-weight-bolder text-slate-900 font-mono">
              {{ scanStore.dashboardStats.totalProses }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">Sesi scan diselesaikan</div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Card 4: Status Scanner -->
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="stat-card q-pa-md">
          <q-card-section class="q-pa-xs">
            <div class="row items-center justify-between q-mb-sm">
              <span class="text-caption text-weight-bold text-grey-7 text-uppercase">Status Scanner</span>
              <q-avatar icon="sensors" color="amber-2" text-color="amber-10" size="40px" />
            </div>
            <div class="text-h5 text-weight-bolder text-slate-900 font-mono row items-center">
              <span class="scanner-dot q-mr-sm"></span>
              {{ scanStore.dashboardStats.scannerStatus }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">Mode simulator Input Text Active</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Banner Wahana Express -->
    <q-card class="scan-card bg-wahana-gradient text-white q-pa-md">
      <q-card-section class="row items-center justify-between">
        <div class="col-12 col-md-8">
          <div class="row items-center q-mb-xs">
            <q-badge color="amber-5" text-color="slate-900" class="text-weight-bolder q-mr-sm">WAHANA EXPRESS</q-badge>
            <div class="text-h5 text-weight-bolder text-white">
              Sistem Pengindaian Paket Ekspedisi Fast-Track
            </div>
          </div>
          <div class="text-body2 text-grey-3">
            Gunakan barcode scanner USB/Bluetooth atau masukkan nomor resi secara manual. Sistem otomatis mendeteksi resi duplikat dan mencatat waktu scan secara presisi untuk efisiensi sorting Wahana Express.
          </div>
        </div>
        <div class="col-12 col-md-4 text-right q-mt-md q-mt-md-none">
          <q-btn
            color="amber-5"
            text-color="slate-900"
            size="lg"
            icon="play_arrow"
            label="MULAI SCAN SEKARANG"
            unelevated
            to="/scan"
            class="text-weight-bolder shadow-2"
          />
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup>
import { useScanStore } from '../stores/scanStore'

const scanStore = useScanStore()
</script>
