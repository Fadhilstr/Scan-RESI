<template>
  <q-dialog v-model="show" persistent>
    <q-card style="width: 440px; max-width: 95vw; border-radius: 16px">
      <!-- Header Dialog -->
      <q-card-section class="row items-center justify-between q-pb-xs no-print">
        <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
          <q-icon name="local_shipping" color="primary" size="22px" class="q-mr-xs" />
          Preview Label Dijak Express
        </div>
        <q-btn flat round dense icon="close" color="grey-7" v-close-popup />
      </q-card-section>

      <q-separator class="no-print" />

      <!-- Body Preview Label -->
      <q-card-section class="q-pa-md flex flex-center bg-grey-2" style="max-height: 75vh; overflow-y: auto;">
        <div v-if="renderError" class="text-negative text-caption bg-red-1 q-pa-md rounded-borders full-width text-center">
          {{ renderError }}
        </div>

        <!-- Wadah Label Ekspedisi Compact Dijak Express -->
        <div v-else class="express-label-box bg-white text-black shadow-3">
          <!-- 1. HEADER -->
          <div class="label-header text-left">
            <div class="brand-title">DIJAK EXPRESS</div>
          </div>

          <div class="label-divider"></div>

          <!-- 2. NOMOR RESI & BARCODE (ALIGNMENT CENTER) -->
          <div class="label-resi-section text-center">
            <div class="resi-label-heading">NO. RESI</div>
            <div class="resi-number-main">{{ displayResi }}</div>
            <div class="barcode-svg-container">
              <svg ref="svgRef"></svg>
            </div>
            <div class="resi-number-sub">{{ displayResi }}</div>
          </div>

          <div class="label-divider"></div>

          <!-- 3. DATA PENGIRIM (ALIGNMENT KIRI) -->
          <div class="label-section text-left">
            <div class="section-title-bold">PENGIRIM</div>
            <div class="person-name">{{ displayPengirimNama }}</div>
            <div v-if="displayPengirimTlp" class="person-phone">{{ displayPengirimTlp }}</div>
            <div v-if="displayPengirimAlamat && displayPengirimAlamat !== '-'" class="address-block">{{ displayPengirimAlamat }}</div>
          </div>

          <div class="label-divider"></div>

          <!-- 4. DATA PENERIMA (ALIGNMENT KIRI) -->
          <div class="label-section text-left">
            <div class="section-title-bold">PENERIMA</div>
            <div class="person-name recipient-highlight">{{ displayPenerimaNama }}</div>
            <div v-if="displayPenerimaTlp" class="person-phone">{{ displayPenerimaTlp }}</div>
            <div v-if="displayPenerimaAlamat && displayPenerimaAlamat !== '-'" class="address-block">{{ displayPenerimaAlamat }}</div>
          </div>

          <div class="label-divider"></div>

          <!-- 5. DETAIL PAKET (ALIGNMENT KIRI) -->
          <div class="label-section text-left">
            <div class="section-title-bold">DETAIL PAKET</div>
            <div class="detail-line font-medium">{{ displayJenisDanJumlah }}</div>
            <div class="detail-line">Berat: {{ displayBerat }}</div>
            <div class="detail-line">Dimensi: {{ displayDimensi }}</div>
            <div class="detail-line">COD: {{ displayCodText }}</div>
          </div>

          <div class="label-divider"></div>

          <!-- 6. INFORMASI RUTE (ALIGNMENT KIRI) -->
          <div class="label-section text-left">
            <div class="route-info">{{ displayRute }}</div>
          </div>
        </div>
      </q-card-section>

      <q-separator class="no-print" />

      <!-- Footer Aksi Dialog -->
      <q-card-actions align="right" class="q-pa-md bg-white no-print">
        <q-btn flat label="Tutup" no-caps color="grey-7" v-close-popup />
        <q-btn
          unelevated
          color="primary"
          icon="print"
          label="Cetak Label"
          no-caps
          :disable="!!renderError"
          class="text-weight-bold q-px-lg"
          @click="printLabel"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'
import JsBarcode from 'jsbarcode'
import { usePaketStore } from '../stores/paketStore'
import { formatAddressInfo, extractCityFromAddress } from '../utils/addressFormatter'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  resi: {
    type: String,
    default: ''
  },
  paketData: {
    type: Object,
    default: null
  }
})

const emit = defineEmits(['update:modelValue'])
const paketStore = usePaketStore()

const show = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

const svgRef = ref(null)
const renderError = ref('')
const currentPaket = ref(null)

const displayResi = computed(() => {
  return (currentPaket.value?.nomor_resi || props.resi || 'DJK987654321').toUpperCase()
})

const pengirimFormatted = computed(() => {
  return formatAddressInfo(
    currentPaket.value?.pengirim_detail,
    currentPaket.value?.pengirim || currentPaket.value?.creator_name || '',
    currentPaket.value?.pengirim_alamat || currentPaket.value?.alamat_pengirim || ''
  )
})

const penerimaFormatted = computed(() => {
  return formatAddressInfo(
    currentPaket.value?.penerima_detail,
    currentPaket.value?.penerima || '',
    currentPaket.value?.alamat_tujuan || ''
  )
})

const displayPengirimNama = computed(() => {
  return (
    pengirimFormatted.value?.name ||
    currentPaket.value?.pengirim ||
    currentPaket.value?.creator_name ||
    '-'
  )
})

const displayPengirimTlp = computed(() => {
  return (
    pengirimFormatted.value?.phone ||
    currentPaket.value?.pengirim_detail?.telepon ||
    currentPaket.value?.telepon_pengirim ||
    ''
  )
})

const displayPengirimAlamat = computed(() => {
  const lines = pengirimFormatted.value?.addressLines
  if (lines && lines.length > 0) return lines.join(', ')
  if (currentPaket.value?.pengirim_alamat || currentPaket.value?.alamat_pengirim) {
    return currentPaket.value.pengirim_alamat || currentPaket.value.alamat_pengirim
  }
  if (currentPaket.value?.hub_asal || currentPaket.value?.kota_asal) {
    return currentPaket.value.hub_asal || currentPaket.value.kota_asal
  }
  return '-'
})

const displayPenerimaNama = computed(() => {
  return penerimaFormatted.value?.name || currentPaket.value?.penerima || '-'
})

const displayPenerimaTlp = computed(() => {
  return (
    penerimaFormatted.value?.phone ||
    currentPaket.value?.penerima_detail?.telepon ||
    currentPaket.value?.telepon_penerima ||
    ''
  )
})

const displayPenerimaAlamat = computed(() => {
  const lines = penerimaFormatted.value?.addressLines
  if (lines && lines.length > 0) return lines.join(', ')
  if (currentPaket.value?.alamat_tujuan) return currentPaket.value.alamat_tujuan
  return '-'
})

const displayJenisDanJumlah = computed(() => {
  const jenis = currentPaket.value?.nama_barang || currentPaket.value?.jenis_barang || 'Elektronik'
  const jumlah = currentPaket.value?.jumlah_barang || currentPaket.value?.jumlah || 1
  return `${jenis} — ${jumlah} PCS`
})

const displayBerat = computed(() => {
  const b = currentPaket.value?.berat_kg
  return (b !== undefined && b !== null && b !== '' && b !== 0) ? `${b} KG` : '2 KG'
})

const displayDimensi = computed(() => {
  return currentPaket.value?.dimensi || '30 × 20 × 15 CM'
})

const displayCodText = computed(() => {
  if (currentPaket.value) {
    if (currentPaket.value.cod_amount && Number(currentPaket.value.cod_amount) > 0) return 'YA'
    if (currentPaket.value.is_cod !== undefined && currentPaket.value.is_cod) return 'YA'
    if (currentPaket.value.cod === 'YA') return 'YA'
  }
  return 'YA'
})

const displayRute = computed(() => {
  // 1. Kabupaten/Kota Asal
  let asal =
    currentPaket.value?.hub_asal ||
    currentPaket.value?.kota_asal ||
    currentPaket.value?.pengirim_detail?.kota ||
    currentPaket.value?.pengirim_detail?.kabupaten ||
    currentPaket.value?.pengirim_detail?.kota_kabupaten

  if (!asal && currentPaket.value?.pengirim_detail) {
    asal = extractCityFromAddress(currentPaket.value.pengirim_detail)
  }
  if (!asal && (currentPaket.value?.pengirim_alamat || currentPaket.value?.alamat_pengirim)) {
    asal = extractCityFromAddress(currentPaket.value.pengirim_alamat || currentPaket.value.alamat_pengirim)
  }
  if (!asal && pengirimFormatted.value?.addressLines?.length > 0) {
    asal = extractCityFromAddress(pengirimFormatted.value.addressLines)
  }
  if (!asal) {
    asal = 'JAKARTA'
  }

  // 2. Kabupaten/Kota Tujuan (sesuai database / alamat tujuan penerima)
  let tujuan =
    currentPaket.value?.hub_tujuan ||
    currentPaket.value?.kota_tujuan ||
    currentPaket.value?.penerima_detail?.kota ||
    currentPaket.value?.penerima_detail?.kabupaten ||
    currentPaket.value?.penerima_detail?.kota_kabupaten

  if (!tujuan && currentPaket.value?.penerima_detail) {
    tujuan = extractCityFromAddress(currentPaket.value.penerima_detail)
  }
  if (!tujuan && currentPaket.value?.alamat_tujuan) {
    tujuan = extractCityFromAddress(currentPaket.value.alamat_tujuan)
  }
  if (!tujuan && penerimaFormatted.value?.addressLines?.length > 0) {
    tujuan = extractCityFromAddress(penerimaFormatted.value.addressLines)
  }
  if (!tujuan) {
    tujuan = 'BANDUNG'
  }

  return `${asal.toUpperCase()} → ${tujuan.toUpperCase()}`
})

// Load paket detail setiap kali dialog dibuka
watch(
  () => [props.modelValue, props.resi, props.paketData],
  async ([open]) => {
    if (!open) return
    renderError.value = ''

    if (props.paketData) {
      currentPaket.value = props.paketData
    } else if (props.resi) {
      const found = paketStore.findPaketByResi(props.resi)
      if (found) {
        currentPaket.value = found
      } else {
        const res = await paketStore.lookupByResi(props.resi)
        if (res.success) {
          currentPaket.value = res.paket
        } else {
          currentPaket.value = null
        }
      }
    } else {
      currentPaket.value = null
    }

    await nextTick()
    renderBarcode()
  },
  { immediate: true }
)

const renderBarcode = () => {
  if (!svgRef.value) return
  const targetResi = displayResi.value
  if (!targetResi) return

  try {
    JsBarcode(svgRef.value, targetResi, {
      format: 'CODE128',
      displayValue: false,
      width: 2.0,
      height: 60,
      margin: 2,
      background: '#ffffff',
      lineColor: '#000000'
    })
  } catch (err) {
    console.error('[LABEL] Gagal render barcode:', err)
    renderError.value = `Karakter pada resi tidak didukung CODE 128: "${targetResi}"`
  }
}

// Print label terisolasi dengan CSS compact
const printLabel = () => {
  const svgHtml = svgRef.value?.outerHTML || ''
  const win = window.open('', '_blank', 'width=600,height=750')
  if (!win) return

  win.document.write(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Label Resi ${displayResi.value}</title>
    <style>
      @page {
        size: 10cm 14cm;
        margin: 0;
      }
      * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
      }
      html, body {
        width: 100%;
        height: 100%;
        background: #ffffff;
        font-family: Arial, Helvetica, sans-serif;
        color: #000000;
      }
      body {
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .express-label {
        width: 10cm;
        padding: 12px 14px;
        border: 1px solid #000000;
        background: #ffffff;
        margin: 0 auto;
        box-sizing: border-box;
      }
      .text-center { text-align: center; }
      .text-left { text-align: left; }
      .brand-title {
        font-size: 18px;
        font-weight: 800;
        letter-spacing: 0.5px;
      }
      .label-divider {
        border-top: 1px solid #000000;
        margin: 7px 0;
      }
      .resi-label-heading {
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.5px;
      }
      .resi-number-main {
        font-size: 22px;
        font-weight: 800;
        font-family: 'Courier New', Courier, monospace;
        margin: 2px 0;
      }
      .barcode-box {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        margin: 3px 0;
      }
      .barcode-box svg {
        max-width: 100%;
        height: auto;
        display: block;
      }
      .resi-number-sub {
        font-size: 12px;
        font-weight: 700;
        font-family: 'Courier New', Courier, monospace;
        margin-top: 2px;
      }
      .section-title-bold {
        font-size: 11px;
        font-weight: 800;
        text-transform: uppercase;
        margin-bottom: 2px;
        letter-spacing: 0.5px;
      }
      .person-name {
        font-size: 13px;
        font-weight: 600;
      }
      .recipient-highlight {
        font-size: 14px;
        font-weight: 800;
      }
      .person-phone {
        font-size: 12px;
        margin-bottom: 1px;
      }
      .address-block {
        font-size: 11px;
        line-height: 1.35;
      }
      .detail-line {
        font-size: 12px;
        line-height: 1.4;
      }
      .font-medium {
        font-weight: 700;
      }
      .route-info {
        font-size: 15px;
        font-weight: 800;
        letter-spacing: 0.5px;
      }
    </style>
  </head>
  <body>
    <div class="express-label">
      <!-- 1. HEADER -->
      <div class="text-left">
        <div class="brand-title">DIJAK EXPRESS</div>
      </div>

      <div class="label-divider"></div>

      <!-- 2. NOMOR RESI & BARCODE -->
      <div class="text-center">
        <div class="resi-label-heading">NO. RESI</div>
        <div class="resi-number-main">${displayResi.value}</div>
        <div class="barcode-box">
          ${svgHtml}
          <div class="resi-number-sub">${displayResi.value}</div>
        </div>
      </div>

      <div class="label-divider"></div>

      <!-- 3. PENGIRIM -->
      <div class="text-left">
        <div class="section-title-bold">PENGIRIM</div>
        <div class="person-name">${displayPengirimNama.value}</div>
        ${displayPengirimTlp.value ? `<div class="person-phone">${displayPengirimTlp.value}</div>` : ''}
        ${displayPengirimAlamat.value && displayPengirimAlamat.value !== '-' ? `<div class="address-block">${displayPengirimAlamat.value}</div>` : ''}
      </div>

      <div class="label-divider"></div>

      <!-- 4. PENERIMA -->
      <div class="text-left">
        <div class="section-title-bold">PENERIMA</div>
        <div class="person-name recipient-highlight">${displayPenerimaNama.value}</div>
        ${displayPenerimaTlp.value ? `<div class="person-phone">${displayPenerimaTlp.value}</div>` : ''}
        ${displayPenerimaAlamat.value && displayPenerimaAlamat.value !== '-' ? `<div class="address-block">${displayPenerimaAlamat.value}</div>` : ''}
      </div>

      <div class="label-divider"></div>

      <!-- 5. DETAIL PAKET -->
      <div class="text-left">
        <div class="section-title-bold">DETAIL PAKET</div>
        <div class="detail-line font-medium">${displayJenisDanJumlah.value}</div>
        <div class="detail-line">Berat: ${displayBerat.value}</div>
        <div class="detail-line">Dimensi: ${displayDimensi.value}</div>
        <div class="detail-line">COD: ${displayCodText.value}</div>
      </div>

      <div class="label-divider"></div>

      <!-- 6. INFORMASI RUTE -->
      <div class="text-left">
        <div class="route-info">${displayRute.value}</div>
      </div>
    </div>
  </body>
</html>`)

  win.document.close()
  win.onload = () => {
    win.focus()
    win.print()
  }
}
</script>

<style scoped>
.express-label-box {
  width: 9.5cm;
  padding: 12px 14px;
  border: 1px solid #000000;
  box-sizing: border-box;
  font-family: Arial, Helvetica, sans-serif;
  color: #000000;
  background-color: #ffffff;
  border-radius: 4px;
}

.brand-title {
  font-size: 18px;
  font-weight: 800;
  letter-spacing: 0.5px;
}

.label-divider {
  border-top: 1px solid #000000;
  margin: 7px 0;
}

.resi-label-heading {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.5px;
}

.resi-number-main {
  font-size: 22px;
  font-weight: 800;
  font-family: 'Courier New', Courier, monospace;
  margin: 2px 0;
}

.barcode-svg-container {
  display: flex;
  justify-content: center;
  align-items: center;
  margin: 3px 0;
}

.barcode-svg-container :deep(svg) {
  max-width: 100%;
  height: auto;
}

.resi-number-sub {
  font-size: 12px;
  font-weight: 700;
  font-family: 'Courier New', Courier, monospace;
}

.section-title-bold {
  font-size: 11px;
  font-weight: 800;
  text-transform: uppercase;
  margin-bottom: 2px;
  letter-spacing: 0.5px;
}

.person-name {
  font-size: 13px;
  font-weight: 600;
}

.recipient-highlight {
  font-size: 14px;
  font-weight: 800;
}

.person-phone {
  font-size: 12px;
}

.address-block {
  font-size: 11px;
  line-height: 1.35;
}

.detail-line {
  font-size: 12px;
  line-height: 1.4;
}

.font-medium {
  font-weight: 700;
}

.route-info {
  font-size: 15px;
  font-weight: 800;
  letter-spacing: 0.5px;
}
</style>
