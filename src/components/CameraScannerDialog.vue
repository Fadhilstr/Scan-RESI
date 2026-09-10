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
          <div v-if="status === 'scanning' && !isHolding" class="scan-guide absolute-center"></div>

          <!-- Overlay Stabilisasi / Jeda 3 Detik Pembacaan Lengkap -->
          <div
            v-if="isHolding"
            class="absolute-full flex flex-center column q-pa-md text-center"
            style="background: rgba(15, 23, 42, 0.82); backdrop-filter: blur(4px); z-index: 20;"
          >
            <q-circular-progress
              :value="holdProgress"
              size="72px"
              :thickness="0.18"
              color="amber-4"
              track-color="blue-grey-8"
              class="q-mb-xs"
            >
              <span class="text-weight-bolder text-white font-mono" style="font-size: 1.25rem;">
                {{ holdCountdownSeconds }}s
              </span>
            </q-circular-progress>

            <div class="text-weight-bold text-amber-4 text-subtitle2 q-mt-xs">
              Menstabilkan Barcode...
            </div>
            <div class="text-caption text-white font-mono bg-black-60 q-px-sm q-py-xs rounded-borders q-my-xs text-weight-bold" style="max-width: 90%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
              {{ candidateCode }}
            </div>
            <div class="text-caption text-grey-3" style="font-size: 11px;">
              Tahan posisi barcode selama 3 detik agar kode terbaca lengkap
            </div>

            <q-btn
              flat
              dense
              no-caps
              color="amber-4"
              label="Proses Sekarang"
              icon="bolt"
              class="q-mt-sm text-weight-bold"
              @click="commitScan"
            />
          </div>
        </div>

        <div class="text-caption text-grey-7 text-center q-mt-sm row items-center justify-center">
          <q-icon name="info" size="16px" color="grey-6" class="q-mr-xs" />
          <span>Arahkan barcode ke kamera — tahan posisi 3 detik untuk pembacaan stabil &amp; lengkap</span>
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
import { Html5Qrcode, Html5QrcodeSupportedFormats } from 'html5-qrcode'
import { BrowserMultiFormatReader, DecodeHintType, BarcodeFormat } from '@zxing/library'
import { normalizeScannedBarcode } from '../utils/barcodeGenerator'

const ALL_SUPPORTED_FORMATS = [
  Html5QrcodeSupportedFormats.QR_CODE,
  Html5QrcodeSupportedFormats.AZTEC,
  Html5QrcodeSupportedFormats.CODABAR,
  Html5QrcodeSupportedFormats.CODE_39,
  Html5QrcodeSupportedFormats.CODE_93,
  Html5QrcodeSupportedFormats.CODE_128,
  Html5QrcodeSupportedFormats.DATA_MATRIX,
  Html5QrcodeSupportedFormats.MAXICODE,
  Html5QrcodeSupportedFormats.ITF,
  Html5QrcodeSupportedFormats.EAN_13,
  Html5QrcodeSupportedFormats.EAN_8,
  Html5QrcodeSupportedFormats.PDF_417,
  Html5QrcodeSupportedFormats.RSS_14,
  Html5QrcodeSupportedFormats.RSS_EXPANDED,
  Html5QrcodeSupportedFormats.UPC_A,
  Html5QrcodeSupportedFormats.UPC_E,
  Html5QrcodeSupportedFormats.UPC_EAN_EXTENSION
]

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
let zxingReader = null
let lastEmitAt = 0
let audioCtx = null

const stopZxing = () => {
  if (zxingReader) {
    try {
      zxingReader.stopContinuousDecode()
    } catch {
      /* ignore */
    }
    try {
      zxingReader.reset()
    } catch {
      /* ignore */
    }
    zxingReader = null
  }
}

const startZxingFallback = (videoElement) => {
  if (!videoElement || zxingReader) return
  try {
    const hints = new Map()
    hints.set(DecodeHintType.TRY_HARDER, true)
    hints.set(DecodeHintType.POSSIBLE_FORMATS, [
      BarcodeFormat.CODE_93,
      BarcodeFormat.CODABAR,
      BarcodeFormat.RSS_EXPANDED,
      BarcodeFormat.RSS_14,
      BarcodeFormat.CODE_39,
      BarcodeFormat.CODE_128,
      BarcodeFormat.ITF,
      BarcodeFormat.EAN_13,
      BarcodeFormat.EAN_8,
      BarcodeFormat.UPC_A,
      BarcodeFormat.UPC_E,
      BarcodeFormat.QR_CODE,
      BarcodeFormat.DATA_MATRIX,
      BarcodeFormat.AZTEC,
      BarcodeFormat.PDF_417
    ])
    zxingReader = new BrowserMultiFormatReader(hints, 200)
    zxingReader.decodeContinuously(videoElement, (result, err) => {
      if (result && result.getText && result.getText()) {
        const text = result.getText()
        console.log('[CAMERA] Terdeteksi via ZXing auxiliary:', text, result.getBarcodeFormat())
        onScanSuccess(text)
      }
    })
    console.log('[CAMERA] ZXing auxiliary engine aktif memindai video.')
  } catch (err) {
    console.warn('[CAMERA] ZXing auxiliary engine could not bind:', err)
  }
}

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
      scanner = new Html5Qrcode(REGION_ID, {
        formatsToSupport: ALL_SUPPORTED_FORMATS,
        verbose: false,
        experimentalFeatures: {
          useBarCodeDetectorIfSupported: true
        }
      })
      await scanner.start(
        cameraConfig,
        {
          fps: 15,
          qrbox: (viewfinderWidth, viewfinderHeight) => {
            return {
              width: Math.floor(Math.min(viewfinderWidth * 0.9, 520)),
              height: Math.floor(Math.min(viewfinderHeight * 0.8, 340))
            }
          }
        },
        onScanSuccess,
        () => {} // frame tanpa barcode — abaikan
      )

      // Sambungkan auxiliary engine ZXing untuk membaca Code 93 & GS1 Expanded
      let bindAttempts = 0
      const bindInterval = setInterval(() => {
        bindAttempts++
        const videoEl = document.querySelector(`#${REGION_ID} video`)
        if (videoEl && videoEl.videoWidth > 0) {
          clearInterval(bindInterval)
          startZxingFallback(videoEl)
        } else if (bindAttempts > 20) {
          clearInterval(bindInterval)
          if (videoEl) startZxingFallback(videoEl)
        }
      }, 200)

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

const HOLD_DURATION_MS = 3000
const isHolding = ref(false)
const candidateCode = ref('')
const holdProgress = ref(0)
const holdCountdownSeconds = ref(3)
let holdTimer = null
let holdStartAt = 0
let lastCandidateSeenAt = 0
let watchdogTimer = null

const resetHold = () => {
  if (holdTimer) {
    clearInterval(holdTimer)
    holdTimer = null
  }
  if (watchdogTimer) {
    clearInterval(watchdogTimer)
    watchdogTimer = null
  }
  isHolding.value = false
  candidateCode.value = ''
  holdProgress.value = 0
  holdCountdownSeconds.value = 3
}

const commitScan = () => {
  const raw = candidateCode.value
  resetHold()

  if (!raw) return
  const resi = normalizeScannedBarcode(raw)
  if (!resi) return

  stopCamera()
  show.value = false

  playBeep()
  navigator.vibrate?.(80)

  emit('detected', resi)
}

const stopCamera = () => {
  resetHold()
  stopZxing()
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
  resetHold()
  stopZxing()
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
  resetHold()
  show.value = false
}

// ---------------------------------------------------------------------
// Deteksi dengan Jeda Stabilisasi 3 Detik
// ---------------------------------------------------------------------
const onScanSuccess = (decodedText) => {
  const raw = String(decodedText || '').trim()
  if (!raw) return

  const now = Date.now()
  lastCandidateSeenAt = now

  if (!isHolding.value) {
    // Mulai jeda 3 detik untuk memastikan barcode terbaca utuh dan kamera stabil
    isHolding.value = true
    candidateCode.value = raw
    holdStartAt = now
    holdProgress.value = 0
    holdCountdownSeconds.value = 3

    holdTimer = setInterval(() => {
      const elapsed = Date.now() - holdStartAt
      const progress = Math.min(100, Math.floor((elapsed / HOLD_DURATION_MS) * 100))
      holdProgress.value = progress
      holdCountdownSeconds.value = Math.max(1, Math.ceil((HOLD_DURATION_MS - elapsed) / 1000))

      if (elapsed >= HOLD_DURATION_MS) {
        commitScan()
      }
    }, 100)

    // Watchdog: jika barcode tidak terlihat lagi selama > 1500ms, batalkan proses
    watchdogTimer = setInterval(() => {
      if (Date.now() - lastCandidateSeenAt > 1500) {
        resetHold()
      }
    }, 300)
  } else {
    // Sedang menstabilkan: perbarui jika frame berikutnya menangkap kode yang lebih panjang/lengkap
    if (raw.length > candidateCode.value.length || raw.includes('(10)')) {
      candidateCode.value = raw
    }
  }
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
