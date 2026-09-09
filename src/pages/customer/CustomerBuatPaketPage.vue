<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="page-title">Buat Paket Baru</h4>
        <div class="text-subtitle2 text-grey-7">
          Generate resi → barcode terbit → isi data pengirim & penerima → simpan
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

        <!-- Belum generate / sedang memuat dari backend -->
        <div v-if="!paket" class="text-center q-pa-xl">
          <q-spinner-dots size="48px" color="primary" class="q-mb-sm" />
          <div class="text-subtitle1 text-weight-bold text-slate-800 q-mb-xs">
            Membuat Nomor Resi Otomatis dari Server...
          </div>
          <div class="text-caption text-grey-6 q-mb-md">
            Sistem sedang menghubungi backend untuk menerbitkan nomor resi unik.
          </div>
          <q-btn
            v-if="!generating"
            color="primary"
            unelevated
            icon="refresh"
            label="Minta Resi Baru dari Server" no-caps
            class="text-weight-bold"
            @click="handleGenerate"
          />
        </div>

        <!-- Sudah generate: tampil resi terkunci + format barcode + preview -->
        <div v-else class="q-pa-sm">
          <div class="row q-col-gutter-lg items-start">
            <!-- Kolom Form: Nomor Resi (Terkunci), Format Barcode, Tombol Generate -->
            <div class="col-12 col-md-5">
              <div class="text-subtitle1 text-weight-bolder text-slate-900 q-mb-md flex items-center">
                <q-icon name="qr_code_2" color="primary" size="22px" class="q-mr-xs" />
                GENERATE BARCODE
              </div>

              <!-- Input Nomor Resi (Strictly Readonly & Disabled - Otomatis dari Backend) -->
              <div class="q-mb-md">
                <div class="row items-center justify-between q-mb-xs">
                  <div class="text-subtitle2 text-weight-bold text-slate-700">
                    Nomor Resi
                  </div>
                  <q-badge color="green-1" text-color="green-9" class="text-caption text-weight-bold q-pa-xs">
                    <q-icon name="lock" size="12px" class="q-mr-xs" /> Otomatis dari Backend
                  </q-badge>
                </div>
                <q-input
                  :model-value="paket?.nomor_resi || ''"
                  readonly
                  disable
                  outlined
                  dense
                  class="font-mono text-weight-bolder bg-grey-2"
                  style="cursor: not-allowed;"
                >
                  <template v-slot:prepend>
                    <q-icon name="lock" color="primary" />
                  </template>
                  <template v-slot:append>
                    <q-btn
                      flat
                      round
                      dense
                      icon="refresh"
                      color="primary"
                      :loading="generating"
                      @click="handleGenerate"
                    >
                      <q-tooltip>Generate Resi Baru dari Backend</q-tooltip>
                    </q-btn>
                  </template>
                </q-input>
                <div class="text-caption text-grey-6 q-mt-xs">
                  <q-icon name="info" size="13px" class="q-mr-xs" />
                  Nomor resi dihasilkan secara otomatis oleh server backend dan tidak dapat diedit secara manual.
                </div>
              </div>

              <!-- Dropdown Format Barcode -->
              <div class="q-mb-lg">
                <div class="text-subtitle2 text-weight-bold text-slate-700 q-mb-xs">
                  Format Barcode
                </div>
                <q-select
                  v-model="selectedFormat"
                  :options="BARCODE_FORMAT_OPTIONS"
                  emit-value
                  map-options
                  outlined
                  dense
                  bg-color="white"
                  class="text-weight-medium"
                  @update:model-value="handleFormatChange"
                >
                  <template v-slot:option="scope">
                    <q-item v-bind="scope.itemProps">
                      <q-item-section>
                        <q-item-label class="text-weight-medium">
                          {{ scope.opt.value }}
                        </q-item-label>
                        <q-item-label caption>
                          {{ scope.opt.category }}
                        </q-item-label>
                      </q-item-section>
                    </q-item>
                  </template>
                </q-select>
                <div class="text-caption text-grey-6 q-mt-xs">
                  Pilih format barcode untuk langsung di-generate dari nomor resi server.
                </div>
              </div>

              <!-- Tombol Generate Barcode -->
              <div>
                <q-btn
                  unelevated
                  color="primary"
                  icon="auto_awesome"
                  label="GENERATE BARCODE"
                  no-caps
                  class="full-width text-weight-bolder q-py-sm"
                  :loading="generatingBarcode"
                  @click="renderCurrentBarcode"
                />
              </div>

              <div class="text-caption text-grey-6 q-mt-sm">
                Disimpan sistem dengan status <b>{{ paket.status }}</b> — isi formulir pengiriman di Langkah 2.
              </div>
            </div>

            <!-- Kolom Preview Barcode -->
            <div class="col-12 col-md-7 flex flex-center">
              <div class="bg-white q-pa-lg rounded-borders shadow-2 full-width text-center" style="min-height: 220px; display: flex; flex-direction: column; align-items: center; justify-content: center; border: 1px solid #e2e8f0;">
                
                <!-- Pesan Error jika terjadi kegagalan sistem -->
                <div v-if="barcodeError" class="q-pa-md bg-red-1 text-negative rounded-borders full-width text-center" style="border: 1px solid #fca5a5;">
                  <q-icon name="error_outline" size="32px" class="q-mb-xs" />
                  <div class="text-weight-bold text-subtitle2">{{ barcodeError }}</div>
                </div>

                <!-- Kontainer Barcode/QR/Matrix SVG -->
                <div v-show="!barcodeError" class="barcode-preview-container flex flex-center full-width">
                  <svg ref="svgRef" style="max-width: 100%; height: auto;"></svg>
                </div>

                <div v-if="!barcodeError" class="q-mt-sm full-width text-center">
                  <div class="text-caption text-grey-8 text-weight-bold">
                    {{ selectedFormat }} &bull; Tracking: {{ paket?.nomor_resi }}
                  </div>
                  
                  <div class="q-mt-md">
                    <q-btn
                      outline
                      color="primary"
                      icon="print"
                      label="Print Barcode"
                      no-caps
                      class="text-weight-bold"
                      @click="showLabel = true"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- LANGKAH 2: INPUT DATA PAKET, PENGIRIM & PENERIMA -->
    <q-card class="scan-card q-pa-md">
      <q-card-section :class="{ 'opacity-40 pointer-events-none': !paket || saved }">
        <div class="text-subtitle1 text-weight-bold text-slate-800 row items-center q-mb-sm">
          <q-icon name="inventory_2" color="primary" size="22px" class="q-mr-sm" />
          LANGKAH 2 — DATA BARANG & ALAMAT TERSTRUKTUR
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
            Petugas cabang kini dapat memindai resi ini. Cetak label ekspedisi profesional berukuran 10 × 15 cm.
          </div>
          <div class="row justify-center q-gutter-sm">
            <q-btn outline color="primary" icon="print" label="Cetak Label Paket" no-caps @click="showLabel = true" class="text-weight-bold" />
            <q-btn unelevated color="primary" icon="add_box" label="Buat Paket Lagi" no-caps @click="resetForm" class="text-weight-bold" />
          </div>
        </div>

        <q-form v-else class="q-gutter-y-md" @submit.prevent="handleSave">
          <!-- SUBSECTION: DETAIL PAKET & BARANG -->
          <div class="bg-blue-1/30 q-pa-md rounded-borders" style="border: 1px solid #e2e8f0">
            <div class="text-subtitle2 text-weight-bold text-slate-900 q-mb-sm row items-center">
              <q-icon name="box" color="primary" class="q-mr-xs" /> Informasi Barang & Layanan
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-md-5">
                <q-input v-model="form.nama_barang" outlined dense label="Nama Barang *" bg-color="white" required />
              </div>
              <div class="col-12 col-sm-6 col-md-3">
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
              <div class="col-6 col-sm-3 col-md-2">
                <q-input
                  v-model.number="form.berat_kg"
                  outlined
                  dense
                  type="number"
                  step="0.1"
                  min="0"
                  suffix="kg"
                  label="Berat *"
                  bg-color="white"
                  required
                />
              </div>
              <div class="col-6 col-sm-3 col-md-2">
                <q-input
                  v-model.number="form.cod_amount"
                  outlined
                  dense
                  type="number"
                  prefix="Rp"
                  label="COD (Opsional)"
                  bg-color="white"
                />
              </div>
            </div>
          </div>

          <div class="row q-col-gutter-md">
            <!-- SUBSECTION: DATA PENGIRIM (9 FIELD) -->
            <div class="col-12 col-md-6">
              <div class="bg-grey-1 q-pa-md rounded-borders full-height" style="border: 1px solid #e2e8f0">
                <div class="text-subtitle2 text-weight-bold text-slate-900 q-mb-sm row items-center">
                  <q-icon name="person" color="primary" class="q-mr-xs" /> DATA PENGIRIM
                </div>
                <div class="column q-gutter-y-xs">
                  <q-input v-model="form.pengirim_nama" outlined dense label="1. Nama Lengkap *" bg-color="white" required />
                  <q-input
                    v-model="form.pengirim_telepon"
                    outlined
                    dense
                    label="2. Nomor Telepon *"
                    bg-color="white"
                    required
                    :rules="[val => val && /^\d{8,15}$/.test(val) || 'Nomor telepon 8-15 digit angka']"
                    type="tel"
                    inputmode="numeric"
                  />
                  <q-input v-model="form.pengirim_alamat" outlined dense label="3. Alamat / Nama Jalan *" bg-color="white" required />
                  
                  <div class="row q-col-gutter-xs">
                    <div class="col-6">
                      <q-input v-model="form.pengirim_no_rumah" outlined dense label="4. Nomor Rumah" bg-color="white" />
                    </div>
                    <div class="col-6">
                      <q-input v-model="form.pengirim_kelurahan" outlined dense label="5. Kelurahan/Desa" bg-color="white" />
                    </div>
                  </div>

                  <div class="row q-col-gutter-xs">
                    <div class="col-6">
                      <q-input v-model="form.pengirim_kecamatan" outlined dense label="6. Kecamatan" bg-color="white" />
                    </div>
                    <div class="col-6">
                      <q-input v-model="form.pengirim_kota" outlined dense label="7. Kota/Kabupaten *" bg-color="white" placeholder="Contoh: Jakarta" required />
                    </div>
                  </div>

                  <div class="row q-col-gutter-xs">
                    <div class="col-6">
                      <q-input v-model="form.pengirim_provinsi" outlined dense label="8. Provinsi" bg-color="white" />
                    </div>
                    <div class="col-6">
                      <q-input v-model="form.pengirim_kode_pos" outlined dense label="9. Kode Pos" bg-color="white" />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- SUBSECTION: DATA PENERIMA (9 FIELD) -->
            <div class="col-12 col-md-6">
              <div class="bg-grey-1 q-pa-md rounded-borders full-height" style="border: 1px solid #e2e8f0">
                <div class="text-subtitle2 text-weight-bold text-slate-900 q-mb-sm row items-center">
                  <q-icon name="location_on" color="primary" class="q-mr-xs" /> DATA PENERIMA
                </div>
                <div class="column q-gutter-y-xs">
                  <q-input v-model="form.penerima_nama" outlined dense label="1. Nama Lengkap *" bg-color="white" required />
                  <q-input
                    v-model="form.penerima_telepon"
                    outlined
                    dense
                    label="2. Nomor Telepon *"
                    bg-color="white"
                    required
                    :rules="[val => val && /^\d{8,15}$/.test(val) || 'Nomor telepon 8-15 digit angka']"
                    type="tel"
                    inputmode="numeric"
                  />
                  <q-input v-model="form.penerima_alamat" outlined dense label="3. Alamat / Nama Jalan *" bg-color="white" required />

                  <div class="row q-col-gutter-xs">
                    <div class="col-6">
                      <q-input v-model="form.penerima_no_rumah" outlined dense label="4. Nomor Rumah" bg-color="white" />
                    </div>
                    <div class="col-6">
                      <q-input v-model="form.penerima_kelurahan" outlined dense label="5. Kelurahan/Desa" bg-color="white" />
                    </div>
                  </div>

                  <div class="row q-col-gutter-xs">
                    <div class="col-6">
                      <q-input v-model="form.penerima_kecamatan" outlined dense label="6. Kecamatan" bg-color="white" />
                    </div>
                    <div class="col-6">
                      <q-input v-model="form.penerima_kota" outlined dense label="7. Kota/Kabupaten *" bg-color="white" placeholder="Contoh: Bandung" required />
                    </div>
                  </div>

                  <div class="row q-col-gutter-xs">
                    <div class="col-6">
                      <q-input v-model="form.penerima_provinsi" outlined dense label="8. Provinsi" bg-color="white" />
                    </div>
                    <div class="col-6">
                      <q-input v-model="form.penerima_kode_pos" outlined dense label="9. Kode Pos" bg-color="white" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="row items-center justify-end q-mt-md">
            <q-btn
              type="submit"
              color="primary"
              size="lg"
              unelevated
              icon="save"
              label="Simpan Paket & Terbitkan Label" no-caps
              class="text-weight-bolder q-px-xl"
              :loading="saving"
            />
          </div>
        </q-form>
      </q-card-section>
    </q-card>

    <!-- Dialog cetak label (komponen barcode terintegrasi) -->
    <BarcodeLabel v-model="showLabel" :resi="paket?.nomor_resi || ''" :paket-data="paket" :initial-format="selectedFormat" />
  </q-page>
</template>

<script setup>
import { ref, reactive, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { BARCODE_FORMAT_OPTIONS, renderBarcode as utilRenderBarcode } from '../../utils/barcodeGenerator'
import { useAuthStore } from '../../stores/authStore'
import { usePaketStore } from '../../stores/paketStore'
import { buildSingleLineAddress } from '../../utils/addressFormatter'
import BarcodeLabel from '../../components/BarcodeLabel.vue'

const $q = useQuasar()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const paketStore = usePaketStore()

const generating = ref(false)
const saving = ref(false)
const saved = ref(false)
const paket = ref(null)

const svgRef = ref(null)
const showLabel = ref(false)

const selectedFormat = ref('CODE_128')
const generatingBarcode = ref(false)
const barcodeError = ref('')
const currentPayload = ref(null)

const layananOptions = [
  { label: 'REG (REGULER)', value: 'REG' },
  { label: 'EXPRESS', value: 'EXPRESS' },
  { label: 'SAME_DAY', value: 'SAME_DAY' }
]

const emptyForm = () => ({
  nama_barang: '',
  jenis_layanan: 'REG',
  berat_kg: 1.0,
  cod_amount: 0,

  pengirim_nama: '',
  pengirim_telepon: '',
  pengirim_alamat: '',
  pengirim_no_rumah: '',
  pengirim_kelurahan: '',
  pengirim_kecamatan: '',
  pengirim_kota: '',
  pengirim_provinsi: '',
  pengirim_kode_pos: '',

  penerima_nama: '',
  penerima_telepon: '',
  penerima_alamat: '',
  penerima_no_rumah: '',
  penerima_kelurahan: '',
  penerima_kecamatan: '',
  penerima_kota: '',
  penerima_provinsi: '',
  penerima_kode_pos: ''
})

const form = reactive(emptyForm())

const renderCurrentBarcode = async () => {
  const resi = (paket.value?.nomor_resi || '').trim()
  if (!resi) return
  await nextTick()
  if (!svgRef.value) return

  // Simpan format barcode terpilih agar otomatis digunakan label cetak
  localStorage.setItem(`paket_barcode_format_${resi.toUpperCase()}`, selectedFormat.value)
  if (paket.value) {
    paket.value.barcode_format = selectedFormat.value
  }

  barcodeError.value = ''

  generatingBarcode.value = true
  try {
    const res = await utilRenderBarcode(svgRef.value, resi, selectedFormat.value, {
      scale: 2,
      height: 8,
      qrSize: 105,
      background: '#ffffff',
      lineColor: '#0b2341'
    })

    if (!res.success) {
      barcodeError.value = res.error
      currentPayload.value = null
    } else {
      currentPayload.value = res.payload
    }
  } finally {
    generatingBarcode.value = false
  }
}

// Render ulang barcode setiap resi baru terbit dari backend
watch(
  () => paket.value?.nomor_resi,
  async (resi) => {
    if (!resi) return
    await nextTick()
    renderCurrentBarcode()
  }
)

const handleGenerate = async (targetFormat = selectedFormat.value) => {
  generating.value = true
  const result = await paketStore.createResi(authStore.currentUser, targetFormat)
  generating.value = false

  if (result.success) {
    saved.value = false
    paket.value = result.paket

    // Auto-fill nama pengirim jika customer login
    if (authStore.currentUser?.name && !form.pengirim_nama) {
      form.pengirim_nama = authStore.currentUser.name
    }

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

const handleFormatChange = async (newFormat) => {
  selectedFormat.value = newFormat
  const currentResi = (paket.value?.nomor_resi || '').trim()

  const isNumericFormat = ['EAN_13', 'EAN_8', 'UPC_A', 'UPC_E', 'ITF', 'CODABAR', 'RSS_14', 'UPC_EAN_EXTENSION'].includes(newFormat)
  const isCurrentlyNumeric = /^\d+$/.test(currentResi)

  let needsNewResi = false
  if (isNumericFormat && !isCurrentlyNumeric) {
    needsNewResi = true
  } else if (!isNumericFormat && isCurrentlyNumeric) {
    needsNewResi = true
  } else if (newFormat === 'EAN_13' && currentResi.length !== 13) {
    needsNewResi = true
  } else if (newFormat === 'EAN_8' && currentResi.length !== 8) {
    needsNewResi = true
  } else if (newFormat === 'UPC_A' && currentResi.length !== 12) {
    needsNewResi = true
  } else if (newFormat === 'UPC_E' && currentResi.length !== 8) {
    needsNewResi = true
  } else if (newFormat === 'UPC_EAN_EXTENSION' && currentResi.length !== 5) {
    needsNewResi = true
  } else if (newFormat === 'ITF' && currentResi.length !== 12) {
    needsNewResi = true
  } else if (newFormat === 'CODABAR' && currentResi.length !== 10) {
    needsNewResi = true
  } else if (newFormat === 'RSS_14' && currentResi.length !== 14) {
    needsNewResi = true
  }

  if (needsNewResi) {
    // Generate nomor resi yang sesuai dari backend
    await handleGenerate(newFormat)
  } else {
    await renderCurrentBarcode()
  }
}

const handleSave = async () => {
  saving.value = true

  const pengirim_detail = {
    nama: form.pengirim_nama,
    telepon: form.pengirim_telepon,
    alamat: form.pengirim_alamat,
    no_rumah: form.pengirim_no_rumah,
    kelurahan: form.pengirim_kelurahan,
    kecamatan: form.pengirim_kecamatan,
    kota: form.pengirim_kota,
    provinsi: form.pengirim_provinsi,
    kode_pos: form.pengirim_kode_pos
  }

  const penerima_detail = {
    nama: form.penerima_nama,
    telepon: form.penerima_telepon,
    alamat: form.penerima_alamat,
    no_rumah: form.penerima_no_rumah,
    kelurahan: form.penerima_kelurahan,
    kecamatan: form.penerima_kecamatan,
    kota: form.penerima_kota,
    provinsi: form.penerima_provinsi,
    kode_pos: form.penerima_kode_pos
  }

  const payload = {
    nama_barang: form.nama_barang,
    jenis_layanan: form.jenis_layanan,
    berat_kg: form.berat_kg,
    pengirim: form.pengirim_nama,
    alamat_pengirim: buildSingleLineAddress(pengirim_detail),
    telepon_pengirim: form.pengirim_telepon,
    penerima: form.penerima_nama,
    alamat_tujuan: buildSingleLineAddress(penerima_detail),
    telepon_penerima: form.penerima_telepon,
    pengirim_detail,
    penerima_detail,
    hub_asal: form.pengirim_kota || 'Jakarta',
    hub_tujuan: form.penerima_kota || 'Bandung',
    cod_amount: Number(form.cod_amount) || 0,
    barcode_format: selectedFormat.value
  }

  const result = await paketStore.saveData(paket.value.nomor_resi, payload, authStore.currentUser)
  saving.value = false

  if (result.success) {
    localStorage.removeItem(`draft_paket_${paket.value.nomor_resi}`)
    localStorage.setItem(`paket_barcode_format_${paket.value.nomor_resi.toUpperCase()}`, selectedFormat.value)
    paket.value = { ...payload, ...(result.paket || {}), barcode_format: selectedFormat.value, pengirim_detail, penerima_detail, status: 'TERDAFTAR' }
    saved.value = true
    $q.notify({
      type: 'positive',
      icon: 'task_alt',
      message: result.message || 'Paket berhasil disimpan!',
      position: 'top',
      timeout: 1500
    })
    // Re-fetch data terbaru dari backend & redirect ke halaman Paket Saya
    await paketStore.fetchPakets()
    setTimeout(() => {
      router.push('/customer/paket')
    }, 800)
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

const resetForm = async () => {
  paket.value = null
  saved.value = false
  selectedFormat.value = 'CODE_128'
  barcodeError.value = ''
  currentPayload.value = null
  Object.assign(form, emptyForm())
  await handleGenerate()
}

const saveDraftToStorage = () => {
  if(paket.value?.nomor_resi && !saved.value){
    localStorage.setItem(`draft_paket_${paket.value.nomor_resi}`, JSON.stringify(form))
    localStorage.setItem(`paket_barcode_format_${paket.value.nomor_resi.toUpperCase()}`, selectedFormat.value)
  }
}

onBeforeRouteLeave((to, from, next)=>{
  if(paket.value?.nomor_resi && !saved.value){
    saveDraftToStorage()
    $q.notify({
      type: 'info',
      icon: 'bookmark',
      message: `Draft resi ${paket.value.nomor_resi} telah disimpan`,
      position: 'bottom-right',
      timeout: 2000
    })
  }
  next()
})

onBeforeUnmount(()=>{
  saveDraftToStorage()
})

// Lanjutkan draft dari halaman "Paket Saya" (?resi=XXXX) atau minta resi otomatis dari backend
onMounted(async () => {
  const resi = (route.query.resi || '').toString().toUpperCase()
  if (!resi) {
    // Otomatis minta nomor resi dari server backend saat customer membuka halaman ini
    await handleGenerate()
    return
  }

  await paketStore.fetchPakets()
  const draft = paketStore.findPaketByResi(resi)
  if (draft && draft.status === 'DRAFT' && authStore.isCustomer) {
    paket.value = draft
    const savedFormat = localStorage.getItem(`paket_barcode_format_${resi}`)
    if (savedFormat) {
      selectedFormat.value = savedFormat
    }
    await nextTick()
    renderCurrentBarcode()
    const localDraft = localStorage.getItem(`draft_paket_${resi}`)
    if (localDraft) {
      try {
        Object.assign(form, JSON.parse(localDraft))
        $q.notify({
          type: 'info',
          icon: 'restore',
          message: `Draft resi ${resi} telah dimuat`,
          position: 'top',
          timeout: 2000
        })
      }catch(err){
        $q.notify({
          type: 'warning',
          icon: 'error',
          message: 'Gagal memuat draft paket.',
          position: 'top',
          timeout: 2500
        })
      }
    }else{
    form.nama_barang = draft.nama_barang || ''
    form.pengirim_nama = draft.pengirim || authStore.currentUser?.name || ''
    form.penerima_nama = draft.penerima || ''
    form.penerima_alamat = draft.alamat_tujuan || ''
    form.berat_kg = draft.berat_kg || 1.0
    form.jenis_layanan = draft.jenis_layanan || 'REG'
    }
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
.barcode-preview-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 70px;
  max-height: 120px;
  margin: 6px auto;
}
.barcode-preview-container :deep(svg) {
  max-width: 250px;
  max-height: 80px;
  width: auto;
  height: auto;
}
</style>
