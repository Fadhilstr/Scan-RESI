<template>
  <q-dialog v-model="show" @before-show="onOpen" @hide="stopCamera">
    <q-card style="width: 500px; max-width: 94vw">
      <!-- Header -->
      <q-card-section class="row items-center q-pb-none">
        <div class="text-subtitle1 text-weight-bold text-slate-900 row items-center">
          <q-icon name="photo_camera" color="primary" size="22px" class="q-mr-xs" />
          SCAN BARCODE VIA KAMERA
        </div>
        <q-space />
        <q-btn flat round dense icon="close" color="grey-7" @click="closeDialog">
          <q-tooltip>Tutup kamera</q-tooltip>
        </q-btn>
      </q-card-section>

      <q-separator class="q-mt-sm" />

      <!-- Area Kamera -->
      <q-card-section class="q-pa-md">
        <div
          class="camera-frame bg-black rounded-borders overflow-hidden position-relative"
          style="min-height: 260px"
        >
          <div id="camera-scanner-region"></div>

          <!-- Overlay loading / error -->
          <div
            v-if="status === 'starting'"
            class="absolute-full flex flex-center bg-black-75"
          >
            <div class="text-center text-white">
              <q-spinner-dots size="40px" color="amber-4" />
              <div class="text-caption q-mt-xs">Mengaktifkan kamera...</div>
            </div>
          </div>

          <div v-if="status === 'error'" class="absolute-full flex flex-center q-pa-lg">
            <div class="text-center text-white">
              <q-icon name="no_photography" size="40px" color="negative" />
              <div class="text-body2 text-weight-bold q-mt-xs">Kamera tidak dapat diakses</div>
              <div class="text-caption text-grey-4 q-mt-xs">{{ errorMessage }}</div>
              <div class="text-caption text-grey-5 font-mono q-mt-sm" style="font-size: 10px">
                {{ technicalError }}
              </div>
              <q-btn outline dense color="amber-4" icon="refresh" label="Coba Lagi" no-caps class="q-mt-md" @click="startCamera" />
            </div>
          </div>

          <!-- Garis bantu scan -->
          <div v-if="status === 'scanning'" class="scan-guide absolute-center"></div>
        </div>

        <div class="text-caption text-grey-7 text-center q-mt-sm row items-center justify-center">
          <q-icon name="info" size="16px" color="grey-6" class="q-mr-xs" />
          <span>Arahkan barcode ke kamera — deteksi otomatis dengan jeda 1,2 detik</span>
        </div>

        <!-- Hasil scan TERAKHIR sesungguhnya (tervalidasi backend) -->
        <div v-if="latest" class="scan-result q-mt-sm" :class="`scan-result--${latest.level}`" role="status">
          <q-icon :name="levelIcon" size="22px" />
          <div class="col">
            <div class="row items-center q-gutter-x-xs">
              <span class="font-mono text-weight-bold">{{ latest.resi }}</span>
              <span class="text-weight-bold">{{ latest.label }}</span>
            </div>
            <div class="text-caption">{{ latest.message }}</div>
            <div v-if="latest.detail" class="text-caption" style="opacity: 0.85;">{{ latest.detail }}</div>
          </div>
        </div>

        <!-- Riwayat scan sesi ini (maks. 3 terakhir) -->
        <div v-if="history.length > 1" class="row justify-center q-gutter-x-xs q-mt-xs">
          <span
            v-for="h in history"
            :key="h.seq"
            class="history-chip font-mono"
            :class="`history-chip--${h.level}`"
          >
            {{ h.resi }}
          </span>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup>
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import { Html5Qrcode } from 'html5-qrcode'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  },
  // Hasil validasi scan terakhir dari parent:
  // { seq, resi, level: 'success'|'warning'|'danger', label, message, detail? }
  feedback: {
    type: Object,
    default: null
  }
})

const emit = defineEmits(['update:modelValue', 'detected'])

const REGION_ID = 'camera-scanner-region'
const COOLDOWN_MS = 1200 // anti double-read saat barcode diam di depan kamera

const show = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

let scanner = null
let lastEmitAt = 0
let audioCtx = null

const status = ref('idle') // idle | starting | scanning | error
const errorMessage = ref('')
const technicalError = ref('')
const latest = ref(null)
const history = ref([])

// Ikon sesuai tingkat hasil terakhir
const levelIcon = computed(() => {
  switch (latest.value?.level) {
    case 'success': return 'check_circle'
    case 'warning': return 'warning'
    default: return 'cancel'
  }
})

// Parent mengirim hasil validasi baru → tampilkan + catat riwayat sesi
watch(
  () => props.feedback,
  (fb) => {
    if (!fb) return
    latest.value = fb
    history.value = [fb, ...history.value].slice(0, 3)
  }
)

// ---------------------------------------------------------------------
// Siklus hidup kamera
// ---------------------------------------------------------------------
const onOpen = () => {
  latest.value = null
  history.value = []
  startCamera()
}

const FRIENDLY_ERRORS = {
  NotAllowedError: 'Izin kamera ditolak. Klik ikon 🔒/📷 di address bar → izinkan Kamera → muat ulang halaman.',
  NotFoundError: 'Tidak ada kamera yang terdeteksi pada perangkat ini.',
  NotReadableError: 'Kamera sedang dipakai aplikasi lain. Tutup aplikasi tersebut lalu coba lagi.',
  OverconstrainedError: 'Kamera tidak mendukung mode yang diminta.'
}

const startCamera = async () => {
  // 1. Konteks tidak aman → getUserMedia pasti diblokir browser
  if (!window.isSecureContext) {
    status.value = 'error'
    errorMessage.value =
      `Halaman ini dibuka via ${location.protocol}//${location.host}. ` +
      `Kamera hanya aktif di http://localhost atau halaman HTTPS. ` +
      `Gunakan: https://${location.hostname || 'localhost'}:9000`
    technicalError.value = 'insecure context'
    return
  }

  status.value = 'starting'
  errorMessage.value = ''
  technicalError.value = ''

  // 2. Rantai percobaan: kamera belakang/default → kamera mana pun
  const attempts = [
    { facingMode: 'environment' },
    true
  ]

  let lastError = null

  for (const cameraConfig of attempts) {
    try {
      scanner = new Html5Qrcode(REGION_ID)
      await scanner.start(
        cameraConfig,
        {
          fps: 10,
          qrbox: (w) => ({
            width: Math.floor(Math.min(w * 0.85, 420)),
            height: Math.floor(Math.min(w * 0.4, 200))
          })
        },
        onScanSuccess,
        () => {} // frame tanpa barcode — abaikan
      )
      status.value = 'scanning'
      return
    } catch (err) {
      lastError = err
      console.error('[CAMERA] Gagal dengan config', cameraConfig, err)
      cleanupScanner()
    }
  }

  // 3. Semua percobaan gagal — tampilkan pesan ramah + detail teknis
  console.error('[CAMERA] Semua percobaan kamera gagal:', lastError)
  status.value = 'error'
  const errName = lastError?.name || 'UnknownError'
  errorMessage.value =
    FRIENDLY_ERRORS[errName] ||
    'Pastikan halaman dibuka via http://localhost atau https:// dan izinkan akses kamera.'
  technicalError.value = `${errName}: ${lastError?.message || '(tanpa pesan)'}`
}

const stopCamera = () => {
  if (!scanner) return
  try {
    const s = scanner
    scanner = null
    s.stop()
      .then(() => s.clear())
      .catch(() => {})
  } catch {
    /* sudah terhenti */
  }
  status.value = 'idle'
}

const cleanupScanner = () => {
  if (scanner) {
    try {
      scanner.clear()
    } catch {
      /* elemen belum siap */
    }
    scanner = null
  }
}

const closeDialog = () => {
  show.value = false
}

// ---------------------------------------------------------------------
// Deteksi
// ---------------------------------------------------------------------
const onScanSuccess = (decodedText) => {
  const now = Date.now()
  if (now - lastEmitAt < COOLDOWN_MS) return

  lastEmitAt = now
  const resi = String(decodedText || '').trim()
  if (!resi) return

  playBeep()
  navigator.vibrate?.(80)

  // Hasil validasi sesungguhnya dikirim parent lewat prop `feedback`
  emit('detected', resi)
}

// Bunyi "beep" singkat tanpa file audio (WebAudio API)
const playBeep = () => {
  try {
    audioCtx = audioCtx || new (window.AudioContext || window.webkitAudioContext)()
    const osc = audioCtx.createOscillator()
    const gain = audioCtx.createGain()
    osc.type = 'square'
    osc.frequency.value = 880
    gain.gain.setValueAtTime(0.08, audioCtx.currentTime)
    osc.connect(gain).connect(audioCtx.destination)
    osc.start()
    osc.stop(audioCtx.currentTime + 0.1)
  } catch {
    /* autoplay policy — beep boleh gagal senyap */
  }
}

watch(
  () => props.modelValue,
  (val) => {
    if (!val) stopCamera()
  }
)

onBeforeUnmount(stopCamera)
</script>

<style scoped>
.camera-frame {
  border-radius: 12px;
}
#camera-scanner-region video {
  border-radius: 12px;
  object-fit: cover;
}

/* Panel hasil scan — tonal sesuai tingkat keberhasilan */
.scan-result {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 14px;
  border-radius: 12px;
  border: 1px solid transparent;
}

.scan-result--success {
  background-color: #dcfce7;
  color: #15803d;
  border-color: #bbf7d0;
}

.scan-result--warning {
  background-color: #fef3c7;
  color: #b45309;
  border-color: #fde68a;
}

.scan-result--danger {
  background-color: #fee2e2;
  color: #b91c1c;
  border-color: #fecaca;
}

.history-chip {
  font-size: 0.68rem;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 999px;
}

.history-chip--success { background-color: #dcfce7; color: #15803d; }
.history-chip--warning { background-color: #fef3c7; color: #b45309; }
.history-chip--danger  { background-color: #fee2e2; color: #b91c1c; }

.scan-guide {
  width: 78%;
  height: 3px;
  background: linear-gradient(90deg, transparent, #ffc700, transparent);
  animation: scanline 1.6s ease-in-out infinite alternate;
  pointer-events: none;
}
@keyframes scanline {
  from { transform: translateY(-90px); opacity: 0.4; }
  to   { transform: translateY(90px);  opacity: 1; }
}
</style>
