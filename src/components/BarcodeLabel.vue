<template>
  <q-dialog v-model="show">
    <q-card style="width: 420px; max-width: 92vw">
      <!-- Header -->
      <q-card-section class="row items-center q-pb-none">
        <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
          <q-icon name="qr_code_2" color="primary" size="22px" class="q-mr-xs" />
          LABEL BARCODE RESI
        </div>
        <q-space />
        <q-btn flat round dense icon="close" color="grey-7" v-close-popup />
      </q-card-section>

      <q-separator class="q-mt-sm" />

      <!-- Isi Label -->
      <q-card-section class="text-center q-py-lg">
        <div
          v-if="renderError"
          class="text-negative text-caption bg-red-1 q-pa-sm rounded-borders"
        >
          {{ renderError }}
        </div>

        <div v-show="!renderError" class="label-box inline-block bg-white q-pa-md rounded-borders">
          <svg ref="svgRef"></svg>
        </div>

        <div class="text-caption text-grey-7 q-mt-md">
          Format: <span class="text-weight-bold">CODE 128</span> •
          Resi: <span class="font-mono text-weight-bold text-slate-900">{{ resi }}</span>
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          Barcode ini berisi teks resi — scan kembali untuk menghasilkan nomor yang sama.
        </div>
      </q-card-section>

      <q-separator />

      <!-- Aksi -->
      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat label="TUTUP" color="grey-7" v-close-popup class="text-weight-bold" />
        <q-btn
          unelevated
          color="primary"
          icon="print"
          label="CETAK"
          :disable="!!renderError"
          class="text-weight-bold"
          @click="printLabel"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'
import JsBarcode from 'jsbarcode'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  resi: {
    type: String,
    default: ''
  }
})

const emit = defineEmits(['update:modelValue'])

const show = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const svgRef = ref(null)
const renderError = ref('')

// Render ulang barcode setiap dialog dibuka / resi berganti
watch(
  () => [props.modelValue, props.resi],
  ([open]) => {
    if (!open || !props.resi) return
    renderError.value = ''
    nextTick(renderBarcode)
  },
  { immediate: true }
)

const renderBarcode = () => {
  if (!svgRef.value) return
  try {
    // CODE 128 menampung ASCII alfanumerik — cocok untuk semua pola resi PRD
    JsBarcode(svgRef.value, props.resi, {
      format: 'CODE128',
      displayValue: true,
      fontSize: 18,
      font: 'monospace',
      width: 2,
      height: 90,
      margin: 10,
      background: '#ffffff',
      lineColor: '#0b2341'
    })
  } catch (err) {
    console.error('[LABEL] Gagal render barcode:', err)
    renderError.value = `Karakter pada resi tidak didukung CODE 128: "${props.resi}"`
  }
}

// Cetak hanya label via window terisolasi (bebas CSS aplikasi)
const printLabel = () => {
  const svgHtml = svgRef.value?.outerHTML || ''
  const win = window.open('', '_blank', 'width=460,height=340')
  if (!win) return

  win.document.write(`<!doctype html>
<html>
  <head>
    <title>Label ${props.resi}</title>
    <style>
      @page { margin: 12mm; }
      body { display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    </style>
  </head>
  <body>${svgHtml}</body>
</html>`)
  win.document.close()

  win.onload = () => {
    win.focus()
    win.print()
  }
}
</script>
