<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Report Performa Tim</h4>
        <div class="text-subtitle2 text-grey-7">Ringkasan statistik dan pencapaian target tim operasional</div>
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <div class="row q-col-gutter-md">
      <div class="col-12 col-md-6">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-900 q-mb-xs">Tingkat Pencapaian Target</div>
            <div class="text-h3 text-weight-bolder text-positive font-mono">92%</div>
            <div class="text-caption text-grey-7">Rata-rata progres task tim hari ini</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-md-6">
        <q-card class="scan-card q-pa-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold text-slate-900 q-mb-xs">Rasio Duplikasi Scan</div>
            <div class="text-h3 text-weight-bolder text-amber-9 font-mono">0.0%</div>
            <div class="text-caption text-grey-7">Tingkat duplikasi terkontrol</div>
          </q-card-section>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup>
</script>
