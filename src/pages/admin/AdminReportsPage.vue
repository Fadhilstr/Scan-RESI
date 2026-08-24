<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Laporan Operasional Scan</h4>
        <div class="text-subtitle2 text-grey-7">Rekapitulasi statistik volume scan, duplikasi, dan performa petugas</div>
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <div class="row q-col-gutter-md">
      <div class="col-12 col-md-4">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-xs">Kualitas Pengindaian</div>
            <div class="text-h3 text-weight-bolder text-positive font-mono">98.5%</div>
            <div class="text-caption text-grey-7">Tingkat Keberhasilan (Non-Duplicate)</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-md-4">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-xs">Rata-Rata Kecepatan Scan</div>
            <div class="text-h3 text-weight-bolder text-primary font-mono">1.8s</div>
            <div class="text-caption text-grey-7">Per Barcode Paket</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-md-4">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-xs">Puncak Volume Shift</div>
            <div class="text-h3 text-weight-bolder text-amber-9 font-mono">Shift Pagi</div>
            <div class="text-caption text-grey-7">08:00 - 12:00 WIB</div>
          </q-card-section>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
</script>
