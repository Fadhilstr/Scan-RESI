<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="page-title">Buat Paket Baru</h4>
        <div class="text-subtitle2 text-grey-7">
          Generate resi → barcode terbit → isi data barang → simpan
        </div>
      </div>

      <q-btn outline color="grey-8" icon="list" label="Paket Saya" no-caps to="/customer/paket" class="text-weight-bold" />
    </div>

    <q-separator class="q-mb-lg" />

    <!-- LANGKAH 1: GENERATE NOMOR RESI -->
    <q-card class="scan-card q-pa-md q-mb-md">
      <q-card-section>
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle1 text-weight-bold text-slate-800 row items-center">
            <q-icon name="pin" color="primary" size="22px" class="q-mr-sm" />
            LANGKAH 1 — NOMOR RESI DARI SISTEM
          </div>
          <q-badge v-if="paket" :color="paket.status === 'TERDAFTAR' ? 'green-8' : 'amber-8'"
            text-color="white" class="text-weight-bold">
            {{ paket.status }}
          </q-badge>
        </div>

        <!-- Belum generate -->
        <div v-if="!paket" class="text-center q-pa-lg">
          <q-icon name="qr_code_2" size="56px" color="grey-5" class="q-mb-sm" />
          <div class="text-body2 text-grey-7 q-mb-md">
            Nomor resi dibuat otomatis oleh server — Anda tidak perlu (dan tidak bisa) mengetikkannya sendiri.
          </div>
          <q-btn
            color="primary"
            size="lg"
            unelevated
            icon="auto_awesome"
            label="Generate Nomor Resi" no-caps
            class="text-weight-bolder q-px-xl"
            :loading="generating"
            @click="handleGenerate"
          />
        </div>

        <!-- Sudah generate: tampil resi + barcode preview -->
        <div v-else class="row items-center justify-center q-col-gutter-md">
          <div class="col-12 col-md-5 text-center">
            <div class="overline-label">Nomor Resi Anda</div>
            <div class="kpi-value text-slate-900 font-mono">
              {{ paket.nomor_resi }}
            </div>
            <div class="text-caption text-grey-6 q-mt-xs">
              Disimpan sistem dengan status <b>{{ paket.status }}</b> — simpan/isi data barang di Langkah 2.
            </div>
          </div>
          <div class="col-12 col-md-7 flex flex-center">
            <div class="bg-white q-pa-md rounded-borders shadow-2 inline-block text-center">
              <svg ref="svgRef"></svg>
              <div class="text-caption text-grey-6 q-mt-xs">
                CODE 128 • dirender dari nomor resi di atas
              </div>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- LANGKAH 2: INPUT DATA BARANG -->
    <q-card class="scan-card q-pa-md">
      <q-card-section :class="{ 'opacity-40 pointer-events-none': !paket || saved }">
        <div class="text-subtitle1 text-weight-bold text-slate-800 row items-center q-mb-sm">
          <q-icon name="inventory_2" color="primary" size="22px" class="q-mr-sm" />
          LANGKAH 2 — DATA BARANG
        </div>

        <div v-if="!paket" class="text-caption text-grey-6 q-pa-sm bg-amber-1 rounded-borders">
          <q-icon name="lock" size="16px" class="q-mr-xs" />
          Generate nomor resi dulu untuk membuka formulir ini.
        </div>

        <div v-else-if="saved" class="text-center q-pa-md bg-green-1 rounded-borders">
          <q-icon name="check_circle" color="positive" size="42px" />
          <div class="text-subtitle1 text-weight-bold text-slate-900 q-mt-xs">
            Paket {{ paket.nomor_resi }} TERDAFTAR!
          </div>
          <div class="text-caption text-grey-7 q-mb-md">
            Petugas cabang kini dapat memindai resi ini. Jangan lupa tempel/cetak label barcodenya.
          </div>
          <div class="row justify-center q-gutter-sm">
            <q-btn outline color="primary" icon="print" label="Cetak Label Barcode" no-caps @click="showLabel = true" class="text-weight-bold" />
            <q-btn unelevated color="primary" icon="add_box" label="Buat Paket Lagi" no-caps @click="resetForm" class="text-weight-bold" />
          </div>
        </div>

        <q-form v-else class="q-gutter-y-sm" @submit.prevent="handleSave">
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-md-6">
              <q-input v-model="form.nama_barang" outlined dense label="Nama Barang *" bg-color="white" required />
            </div>
            <div class="col-12 col-md-6">
              <q-select
                v-model="form.jenis_layanan"
                :options="layananOptions"
                emit-value
                map-options
                outlined
                dense
                label="Jenis Layanan"
                bg-color="white"
              />
            </div>
          </div>

          <div class="row q-col-gutter-sm">
            <div class="col-12 col-md-6">
              <q-input v-model="form.pengirim" outlined dense label="Pengirim *" bg-color="white" required />
            </div>
            <div class="col-12 col-md-6">
              <q-input v-model="form.penerima" outlined dense label="Penerima *" bg-color="white" required />
            </div>
          </div>

          <q-input
            v-model="form.alamat_tujuan"
            outlined
            dense
            type="textarea"
            autogrow
            label="Alamat Tujuan"
            bg-color="white"
          />

          <div class="row items-center q-col-gutter-sm">
            <div class="col-6 col-sm-3">
              <q-input
                v-model.number="form.berat_kg"
                outlined
                dense
                type="number"
                step="0.1"
                min="0"
                suffix="kg"
                label="Berat"
                bg-color="white"
              />
            </div>
            <q-space />
            <div class="col-auto">
              <q-btn
                type="submit"
                color="primary"
                size="lg"
                unelevated
                icon="save"
                label="Simpan Paket" no-caps
                class="text-weight-bolder"
                :loading="saving"
              />
            </div>
          </div>
        </q-form>
      </q-card-section>
    </q-card>

    <!-- Dialog cetak label (komponen barcode dipakai ulang) -->
    <BarcodeLabel v-model="showLabel" :resi="paket?.nomor_resi || ''" />
  </q-page>
</template>

<script setup>
import { ref, reactive, watch, nextTick, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useQuasar } from 'quasar'
import JsBarcode from 'jsbarcode'
import { useAuthStore } from '../../stores/authStore'
import { usePaketStore } from '../../stores/paketStore'
import BarcodeLabel from '../../components/BarcodeLabel.vue'

const $q = useQuasar()
const route = useRoute()
const authStore = useAuthStore()
const paketStore = usePaketStore()

const generating = ref(false)
const saving = ref(false)
const saved = ref(false)
const paket = ref(null)

const svgRef = ref(null)
const showLabel = ref(false)

const layananOptions = [
  { label: 'REGULER', value: 'REGULER' },
  { label: 'EXPRESS', value: 'EXPRESS' },
  { label: 'SAME_DAY', value: 'SAME_DAY' }
]

const emptyForm = () => ({
  nama_barang: '',
  pengirim: '',
  penerima: '',
  alamat_tujuan: '',
  berat_kg: 0,
  jenis_layanan: 'REGULER'
})
const form = reactive(emptyForm())

// Render ulang barcode setiap resi baru terbit (barcode DARI resi backend)
watch(
  () => paket.value?.nomor_resi,
  async (resi) => {
    if (!resi) return
    await nextTick()
    if (!svgRef.value) return
    try {
      JsBarcode(svgRef.value, resi, {
        format: 'CODE128',
        displayValue: false,
        width: 2,
        height: 90,
        margin: 10,
        background: '#ffffff',
        lineColor: '#0b2341'
      })
    } catch (err) {
      console.error('[BUAT-PAKET] Gagal render barcode:', err)
    }
  }
)

const handleGenerate = async () => {
  generating.value = true
  const result = await paketStore.createResi(authStore.currentUser)
  generating.value = false

  if (result.success) {
    Object.assign(form, emptyForm())
    saved.value = false
    paket.value = result.paket
    $q.notify({
      type: 'positive',
      icon: 'verified',
      message: `Nomor resi ${result.paket.nomor_resi} berhasil dibuat oleh sistem.`,
      position: 'top',
      timeout: 2200
    })
  } else {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: result.message || 'Gagal membuat nomor resi.',
      position: 'top',
      timeout: 2500
    })
  }
}

const handleSave = async () => {
  saving.value = true
  const result = await paketStore.saveData(paket.value.nomor_resi, { ...form }, authStore.currentUser)
  saving.value = false

  if (result.success) {
    paket.value = result.paket || { ...paket.value, status: 'TERDAFTAR' }
    saved.value = true
    $q.notify({
      type: 'positive',
      icon: 'task_alt',
      message: result.message,
      position: 'top',
      timeout: 2200
    })
  } else {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: result.message || 'Gagal menyimpan data paket.',
      position: 'top',
      timeout: 2500
    })
  }
}

const resetForm = () => {
  paket.value = null
  saved.value = false
  Object.assign(form, emptyForm())
}

// Lanjutkan draft dari halaman "Paket Saya" (?resi=XXXX)
onMounted(async () => {
  const resi = (route.query.resi || '').toString().toUpperCase()
  if (!resi) return

  await paketStore.fetchPakets()
  const draft = paketStore.findPaketByResi(resi)
  if (draft && draft.status === 'DRAFT' && authStore.isCustomer) {
    paket.value = draft
    form.nama_barang = draft.nama_barang || ''
    form.pengirim = draft.pengirim || ''
    form.penerima = draft.penerima || ''
    form.alamat_tujuan = draft.alamat_tujuan || ''
    form.berat_kg = draft.berat_kg || 0
    form.jenis_layanan = draft.jenis_layanan || 'REGULER'
  }
})
</script>

<style scoped>
.opacity-40 {
  opacity: 0.45;
}
.pointer-events-none {
  pointer-events: none;
}
</style>
