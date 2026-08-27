<template>
  <q-dialog v-model="show" persistent>
    <q-card style="width: 480px; max-width: 95vw; border-radius: 16px">
      <!-- Header Dialog -->
      <q-card-section class="row items-center justify-between q-pb-xs no-print">
        <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
          <q-icon name="local_shipping" color="primary" size="22px" class="q-mr-xs" />
          Preview Label Ekspedisi (10 × 15 cm)
        </div>
        <q-btn flat round dense icon="close" color="grey-7" v-close-popup />
      </q-card-section>

      <q-separator class="no-print" />

      <!-- Body Preview Label -->
      <q-card-section class="q-pa-md flex flex-center bg-grey-2" style="max-height: 75vh; overflow-y: auto;">
        <div v-if="renderError" class="text-negative text-caption bg-red-1 q-pa-md rounded-borders full-width text-center">
          {{ renderError }}
        </div>

        <!-- Wadah Label Ekspedisi 10x15 cm -->
        <div v-else class="express-label-box bg-white text-black shadow-3">
          <!-- 1. HEADER (DIJAK EXPRESS & LAYANAN) -->
          <div class="label-header text-center">
            <div class="brand-title">DIJAK EXPRESS</div>
            <div class="service-badge">{{ displayLayanan }}</div>
          </div>

          <div class="label-divider"></div>

          <!-- 2. NOMOR RESI -->
          <div class="label-resi-section text-center">
            <div class="resi-label-heading">NO. RESI</div>
            <div class="resi-number-main">{{ displayResi }}</div>
          </div>

          <!-- 3. BARCODE -->
          <div class="label-barcode-section text-center">
            <div class="barcode-svg-container">
              <svg ref="svgRef"></svg>
            </div>
            <div class="resi-number-sub">{{ displayResi }}</div>
          </div>

          <div class="label-divider"></div>

          <!-- 4. PENGIRIM -->
          <div class="label-section text-left">
            <div class="section-title-bold">PENGIRIM</div>
            <div class="person-name">{{ pengirimInfo.name || '-' }}</div>
            <div v-if="pengirimInfo.phone" class="person-phone">{{ pengirimInfo.phone }}</div>
            <div class="address-block">
              <div v-for="(line, idx) in pengirimInfo.addressLines" :key="'pgr-' + idx">
                {{ line }}
              </div>
            </div>
          </div>

          <div class="label-divider"></div>

          <!-- 5. PENERIMA -->
          <div class="label-section text-left">
            <div class="section-title-bold">PENERIMA</div>
            <div class="person-name recipient-highlight">{{ penerimaInfo.name || '-' }}</div>
            <div v-if="penerimaInfo.phone" class="person-phone">{{ penerimaInfo.phone }}</div>
            <div class="address-block">
              <div v-for="(line, idx) in penerimaInfo.addressLines" :key="'pnr-' + idx">
                {{ line }}
              </div>
            </div>
          </div>

          <div class="label-divider"></div>

          <!-- 6. DETAIL PAKET -->
          <div class="label-section text-left">
            <div class="section-title-bold">DETAIL PAKET</div>
            <table class="detail-table">
              <tbody>
                <tr>
                  <td class="lbl font-bold">Berat</td>
                  <td class="sep">:</td>
                  <td class="val">{{ displayBerat }}</td>
                </tr>
                <tr>
                  <td class="lbl font-bold">Layanan</td>
                  <td class="sep">:</td>
                  <td class="val">{{ displayLayanan }}</td>
                </tr>
                <tr>
                  <td class="lbl font-bold">Hub Asal</td>
                  <td class="sep">:</td>
                  <td class="val">{{ displayHubAsal }}</td>
                </tr>
                <tr>
                  <td class="lbl font-bold">Hub Tujuan</td>
                  <td class="sep">:</td>
                  <td class="val">{{ displayHubTujuan }}</td>
                </tr>
                <tr v-if="displayCod">
                  <td class="lbl font-bold">COD</td>
                  <td class="sep">:</td>
                  <td class="val font-bold">{{ displayCod }}</td>
                </tr>
                <tr>
                  <td class="lbl font-bold">Tanggal</td>
                  <td class="sep">:</td>
                  <td class="val">{{ displayTanggal }}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <!-- TIDAK ADA SECTION STATUS -->
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
import { formatAddressInfo } from '../utils/addressFormatter'

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
  return (currentPaket.value?.nomor_resi || props.resi || 'GJXL8FLB').toUpperCase()
})

const displayLayanan = computed(() => {
  return currentPaket.value?.jenis_layanan || 'REG'
})

const displayBerat = computed(() => {
  const b = currentPaket.value?.berat_kg
  return b ? `${b} Kg` : '1.5 Kg'
})

const displayHubAsal = computed(() => {
  return currentPaket.value?.hub_asal || 'Jakarta'
})

const displayHubTujuan = computed(() => {
  if (currentPaket.value?.hub_tujuan) return currentPaket.value.hub_tujuan
  if (penerimaInfo.value?.addressLines?.length > 1) {
    const lastLine = penerimaInfo.value.addressLines[1]
    const parts = lastLine.split(',')
    if (parts.length > 1) return parts[1].trim()
    return parts[0].trim()
  }
  return 'Bandung'
})

const displayCod = computed(() => {
  const cod = currentPaket.value?.cod_amount
  if (cod && Number(cod) > 0) {
    return `Rp${Number(cod).toLocaleString('id-ID')}`
  }
  return null
})

const displayTanggal = computed(() => {
  if (currentPaket.value?.created_at) {
    return currentPaket.value.created_at.split(' ')[0]
  }
  return '27-08-2026'
})

const pengirimInfo = computed(() => {
  return formatAddressInfo(
    currentPaket.value?.pengirim_detail,
    currentPaket.value?.pengirim || 'Fadhil Satria Widodo',
    ''
  )
})

const penerimaInfo = computed(() => {
  return formatAddressInfo(
    currentPaket.value?.penerima_detail,
    currentPaket.value?.penerima || 'Budi Santoso',
    currentPaket.value?.alamat_tujuan || ''
  )
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
      width: 2.2,
      height: 65,
      margin: 4,
      background: '#ffffff',
      lineColor: '#000000'
    })
  } catch (err) {
    console.error('[LABEL] Gagal render barcode:', err)
    renderError.value = `Karakter pada resi tidak didukung CODE 128: "${targetResi}"`
  }
}

// Print label terisolasi dengan CSS @page 10cm x 15cm centered
const printLabel = () => {
  const svgHtml = svgRef.value?.outerHTML || ''
  const win = window.open('', '_blank', 'width=620,height=800')
  if (!win) return

  const pgr = pengirimInfo.value
  const pnr = penerimaInfo.value

  const pgrAddressHtml = pgr.addressLines.map((l) => `<div>${l}</div>`).join('')
  const pnrAddressHtml = pnr.addressLines.map((l) => `<div>${l}</div>`).join('')

  const pgrPhoneHtml = pgr.phone ? `<div>${pgr.phone}</div>` : ''
  const pnrPhoneHtml = pnr.phone ? `<div>${pnr.phone}</div>` : ''

  const codRowHtml = displayCod.value
    ? `<tr><td class="lbl">COD</td><td class="sep">:</td><td class="val font-bold">${displayCod.value}</td></tr>`
    : ''

  win.document.write(`<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Label Resi ${displayResi.value}</title>
    <style>
      @page {
        size: 10cm 15cm;
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
      .print-wrapper {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .express-label {
        width: 10cm;
        min-height: 15cm;
        padding: 10px 12px;
        border: 1px solid #000000;
        background: #ffffff;
        margin: 0 auto;
        box-sizing: border-box;
        display: flex;
        flex-direction: column;
      }
      .text-center { text-align: center; }
      .text-left { text-align: left; }
      .font-bold { font-weight: bold; }
      .brand-title {
        font-size: 20px;
        font-weight: 800;
        letter-spacing: 1px;
        margin-bottom: 2px;
      }
      .service-badge {
        font-size: 15px;
        font-weight: bold;
      }
      .label-divider {
        border-top: 1px solid #000000;
        margin: 6px 0;
      }
      .resi-label-heading {
        font-size: 11px;
        font-weight: bold;
        letter-spacing: 0.5px;
      }
      .resi-number-main {
        font-size: 24px;
        font-weight: 800;
        font-family: monospace;
        margin: 2px 0;
      }
      .barcode-box {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        margin: 4px 0;
      }
      .barcode-box svg {
        max-width: 100%;
        height: auto;
        display: block;
      }
      .resi-number-sub {
        font-size: 13px;
        font-weight: bold;
        font-family: monospace;
        margin-top: 2px;
      }
      .section-title-bold {
        font-size: 11px;
        font-weight: bold;
        text-transform: uppercase;
        margin-bottom: 3px;
      }
      .person-name {
        font-size: 13px;
        font-weight: normal;
      }
      .recipient-highlight {
        font-size: 14px;
        font-weight: bold;
      }
      .person-phone {
        font-size: 12px;
        margin-bottom: 2px;
      }
      .address-block {
        font-size: 11px;
        line-height: 1.35;
      }
      .detail-table {
        width: 100%;
        font-size: 11px;
        border-collapse: collapse;
      }
      .detail-table td {
        padding: 1px 0;
        vertical-align: top;
      }
      .detail-table td.lbl {
        width: 85px;
        font-weight: bold;
      }
      .detail-table td.sep {
        width: 12px;
      }
    </style>
  </head>
  <body>
    <div class="print-wrapper">
      <div class="express-label">
        <!-- 1. HEADER -->
        <div class="text-center">
          <div class="brand-title">DIJAK EXPRESS</div>
          <div class="service-badge">${displayLayanan.value}</div>
        </div>

        <div class="label-divider"></div>

        <!-- 2. NOMOR RESI -->
        <div class="text-center">
          <div class="resi-label-heading">NO. RESI</div>
          <div class="resi-number-main">${displayResi.value}</div>
        </div>

        <!-- 3. BARCODE -->
        <div class="text-center barcode-box">
          ${svgHtml}
          <div class="resi-number-sub">${displayResi.value}</div>
        </div>

        <div class="label-divider"></div>

        <!-- 4. PENGIRIM -->
        <div class="text-left">
          <div class="section-title-bold">PENGIRIM</div>
          <div class="person-name">${pgr.name || '-'}</div>
          ${pgrPhoneHtml}
          <div class="address-block">
            ${pgrAddressHtml}
          </div>
        </div>

        <div class="label-divider"></div>

        <!-- 5. PENERIMA -->
        <div class="text-left">
          <div class="section-title-bold">PENERIMA</div>
          <div class="person-name recipient-highlight">${pnr.name || '-'}</div>
          ${pnrPhoneHtml}
          <div class="address-block">
            ${pnrAddressHtml}
          </div>
        </div>

        <div class="label-divider"></div>

        <!-- 6. DETAIL PAKET -->
        <div class="text-left">
          <div class="section-title-bold">DETAIL PAKET</div>
          <table class="detail-table">
            <tbody>
              <tr>
                <td class="lbl">Berat</td>
                <td class="sep">:</td>
                <td class="val">${displayBerat.value}</td>
              </tr>
              <tr>
                <td class="lbl">Layanan</td>
                <td class="sep">:</td>
                <td class="val">${displayLayanan.value}</td>
              </tr>
              <tr>
                <td class="lbl">Hub Asal</td>
                <td class="sep">:</td>
                <td class="val">${displayHubAsal.value}</td>
              </tr>
              <tr>
                <td class="lbl">Hub Tujuan</td>
                <td class="sep">:</td>
                <td class="val">${displayHubTujuan.value}</td>
              </tr>
              ${codRowHtml}
              <tr>
                <td class="lbl">Tanggal</td>
                <td class="sep">:</td>
                <td class="val">${displayTanggal.value}</td>
              </tr>
            </tbody>
          </table>
        </div>
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
  width: 10cm;
  min-height: 15cm;
  padding: 12px;
  border: 1px solid #000000;
  box-sizing: border-box;
  font-family: Arial, Helvetica, sans-serif;
  color: #000000;
  background-color: #ffffff;
}

.brand-title {
  font-size: 20px;
  font-weight: 800;
  letter-spacing: 1px;
}

.service-badge {
  font-size: 15px;
  font-weight: 700;
}

.label-divider {
  border-top: 1px solid #000000;
  margin: 6px 0;
}

.resi-label-heading {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.5px;
}

.resi-number-main {
  font-size: 24px;
  font-weight: 800;
  font-family: monospace;
  margin: 2px 0;
}

.barcode-svg-container {
  display: flex;
  justify-content: center;
  align-items: center;
  margin: 4px 0;
}

.barcode-svg-container :deep(svg) {
  max-width: 100%;
  height: auto;
}

.resi-number-sub {
  font-size: 13px;
  font-weight: 700;
  font-family: monospace;
}

.section-title-bold {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  margin-bottom: 2px;
}

.person-name {
  font-size: 13px;
}

.recipient-highlight {
  font-size: 14px;
  font-weight: 700;
}

.person-phone {
  font-size: 12px;
}

.address-block {
  font-size: 11px;
  line-height: 1.35;
}

.detail-table {
  width: 100%;
  font-size: 11px;
  border-collapse: collapse;
}

.detail-table td {
  padding: 1px 0;
  vertical-align: top;
}

.detail-table td.lbl {
  width: 85px;
}

.detail-table td.sep {
  width: 12px;
}
</style>
