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

          <!-- HANYA SATU FRAME SCANNING RESMI DENGAN CORNER BRACKETS -->
          <div
            v-if="status === 'scanning'"
            class="scan-frame-box"
            :class="{ 'scan-frame-box--paused': isPaused || isProcessingScan }"
          >
            <div class="scan-corner scan-corner--top-left"></div>
            <div class="scan-corner scan-corner--top-right"></div>
            <div class="scan-corner scan-corner--bottom-left"></div>
            <div class="scan-corner scan-corner--bottom-right"></div>
          </div>
        </div>

        <!-- Status State Machine Barcode Scanner -->
        <div class="text-caption text-grey-7 text-center q-mt-sm row items-center justify-center">
          <template v-if="scannerState === 'PAUSED' || scannerState === 'PROCESSING'">
            <q-spinner-dots size="16px" color="amber-9" class="q-mr-xs" />
            <span class="text-weight-bold text-amber-9">PAUSED — Memproses resi {{ lastScannedResi }}...</span>
          </template>
          <template v-else-if="scannerState === 'ALERT' || scannerState === 'COOLDOWN'">
            <q-icon name="check_circle" size="16px" color="positive" class="q-mr-xs" v-if="latest?.level === 'success'" />
            <q-icon name="warning" size="16px" color="negative" class="q-mr-xs" v-else />
            <span class="text-weight-bold" :class="latest?.level === 'success' ? 'text-positive' : 'text-negative'">
              {{ latest ? `${latest.label}: ${latest.message}` : 'Hasil scan diproses' }}
            </span>
          </template>
          <template v-else-if="status === 'scanning'">
            <q-icon name="center_focus_strong" size="16px" color="primary" class="q-mr-xs" />
            <span class="text-weight-bold text-slate-700">SCANNING — Arahkan barcode ke dalam kotak</span>
          </template>
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
import { useQuasar } from 'quasar'
import { Html5Qrcode, Html5QrcodeSupportedFormats } from 'html5-qrcode'
import { BrowserMultiFormatReader, DecodeHintType, BarcodeFormat } from '@zxing/library'
import { normalizeScannedBarcode } from '../utils/barcodeGenerator'
import { applyZxingRssExpandedPatch } from '../utils/zxingRssExpandedPatcher'

// Terapkan perbaikan translasi Java->JS ZXing untuk RSS Expanded secara transparan
applyZxingRssExpandedPatch()

const $q = useQuasar()

const ALL_SUPPORTED_FORMATS = [
  Html5QrcodeSupportedFormats.QR_CODE,
  Html5QrcodeSupportedFormats.AZTEC,
  Html5QrcodeSupportedFormats.CODABAR,
  Html5QrcodeSupportedFormats.CODE_39,
  Html5QrcodeSupportedFormats.CODE_93,
  Html5QrcodeSupportedFormats.CODE_128,
  Html5QrcodeSupportedFormats.DATA_MATRIX,
  Html5QrcodeSupportedFormats.ITF,
  Html5QrcodeSupportedFormats.EAN_13,
  Html5QrcodeSupportedFormats.EAN_8,
  Html5QrcodeSupportedFormats.PDF_417,
  Html5QrcodeSupportedFormats.RSS_14,
  Html5QrcodeSupportedFormats.RSS_EXPANDED,
  Html5QrcodeSupportedFormats.UPC_A,
  Html5QrcodeSupportedFormats.UPC_E
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

const show = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
})

// Lifecycle & State Machine Variables
let scanner = null
let zxingReader = null
let bindInterval = null
let audioCtx = null

let lastScanTimestamp = 0
let lastScannedResi = ''
let emptyFramesCount = 0

// State Machine Status: IDLE -> STARTING -> SCANNING -> PAUSED -> PROCESSING -> ALERT -> COOLDOWN -> RESUME -> SCANNING
const status = ref('idle') // idle | starting | scanning | error
const scannerState = ref('IDLE') // IDLE | SCANNING | PAUSED | PROCESSING | ALERT | COOLDOWN | RESUME
const isPaused = ref(false)
const isProcessingScan = ref(false)

const errorMessage = ref('')
const technicalError = ref('')
const latest = ref(null)
const history = ref([])

let feedbackTimer = null
let lockFallbackTimer = null
let cooldownTimer = null

const stopZxing = () => {
  if (bindInterval) {
    clearInterval(bindInterval)
    bindInterval = null
  }
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
    applyZxingRssExpandedPatch()
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

    const ZXING_FORMAT_NAME_MAP = {
      [BarcodeFormat.AZTEC]: 'AZTEC',
      [BarcodeFormat.CODABAR]: 'CODABAR',
      [BarcodeFormat.CODE_39]: 'CODE_39',
      [BarcodeFormat.CODE_93]: 'CODE_93',
      [BarcodeFormat.CODE_128]: 'CODE_128',
      [BarcodeFormat.DATA_MATRIX]: 'DATA_MATRIX',
      [BarcodeFormat.EAN_8]: 'EAN_8',
      [BarcodeFormat.EAN_13]: 'EAN_13',
      [BarcodeFormat.ITF]: 'ITF',
      [BarcodeFormat.PDF_417]: 'PDF_417',
      [BarcodeFormat.QR_CODE]: 'QR_CODE',
      [BarcodeFormat.RSS_14]: 'RSS_14',
      [BarcodeFormat.RSS_EXPANDED]: 'RSS_EXPANDED',
      [BarcodeFormat.UPC_A]: 'UPC_A',
      [BarcodeFormat.UPC_E]: 'UPC_E'
    }

    zxingReader = new BrowserMultiFormatReader(hints, 250)
    zxingReader.decodeContinuously(videoElement, (result, err) => {
      // KUNCI STATE MACHINE: Jika scanner dalam kondisi PAUSED atau PROCESSING, abaikan hasil decode!
      if (isPaused.value || isProcessingScan.value || scannerState.value !== 'SCANNING' || status.value !== 'scanning') {
        return
      }
      if (result && result.getText && result.getText()) {
        const text = result.getText()
        const fmtEnum = result.getBarcodeFormat()
        const formatName = ZXING_FORMAT_NAME_MAP[fmtEnum] || null
        onScanSuccess(text, { result: { format: { format: fmtEnum, formatName } } })
      } else {
        onScanFailure()
      }
    })
    console.log('[CAMERA] ZXing auxiliary engine aktif memindai video.')
  } catch (err) {
    console.warn('[CAMERA] ZXing auxiliary engine could not bind:', err)
  }
}

// Ikon sesuai tingkat hasil terakhir
const levelIcon = computed(() => {
  switch (latest.value?.level) {
    case 'success': return 'check_circle'
    case 'warning': return 'warning'
    default: return 'cancel'
  }
})

// Parent mengirim hasil validasi baru -> tampilkan alert + catat riwayat -> masuk cooldown -> resume scanner
watch(
  () => props.feedback,
  (fb) => {
    if (!fb) return
    if (lockFallbackTimer) {
      clearTimeout(lockFallbackTimer)
      lockFallbackTimer = null
    }

    latest.value = fb
    history.value = [fb, ...history.value.filter((h) => h.resi !== fb.resi)].slice(0, 3)

    scannerState.value = 'ALERT'

    if (feedbackTimer) clearTimeout(feedbackTimer)
    // Tampilkan alert selama 1.2 detik, kemudian masuk fase COOLDOWN dan RESUME
    feedbackTimer = setTimeout(() => {
      resumeScanner()
    }, 1200)
  }
)

// ---------------------------------------------------------------------
// RESUME SCANNER AUTOMATION
// ---------------------------------------------------------------------
const resumeScanner = () => {
  if (feedbackTimer) { clearTimeout(feedbackTimer); feedbackTimer = null }
  if (lockFallbackTimer) { clearTimeout(lockFallbackTimer); lockFallbackTimer = null }
  if (cooldownTimer) { clearTimeout(cooldownTimer); cooldownTimer = null }

  scannerState.value = 'COOLDOWN'

  // Resume native html5-qrcode jika didukung
  if (scanner && typeof scanner.resume === 'function') {
    try {
      scanner.resume()
    } catch {
      /* ignore */
    }
  }

  // Cooldown singkat 300ms untuk memastikan buffer frame kamera bersih
  cooldownTimer = setTimeout(() => {
    emptyFramesCount = 0
    isPaused.value = false
    isProcessingScan.value = false
    if (status.value === 'scanning' && show.value) {
      scannerState.value = 'SCANNING'
    }
  }, 300)
}

// ---------------------------------------------------------------------
// SIKLUS HIDUP KAMERA & SINGLE INSTANCE GUARANTEE
// ---------------------------------------------------------------------
const onOpen = () => {
  latest.value = null
  history.value = []
  lastScannedResi = ''
  lastScanTimestamp = 0
  emptyFramesCount = 0
  isPaused.value = false
  isProcessingScan.value = false
  scannerState.value = 'IDLE'

  if (feedbackTimer) clearTimeout(feedbackTimer)
  if (lockFallbackTimer) clearTimeout(lockFallbackTimer)
  if (cooldownTimer) clearTimeout(cooldownTimer)
  startCamera()
}

const FRIENDLY_ERRORS = {
  NotAllowedError: 'Izin kamera ditolak. Klik ikon 🔒/📷 di address bar → izinkan Kamera → muat ulang halaman.',
  NotFound: 'Tidak ada kamera yang terdeteksi pada perangkat ini.',
  NotReadableError: 'Kamera sedang dipakai aplikasi lain. Tutup aplikasi tersebut lalu coba lagi.',
  OverconstrainedError: 'Kamera tidak mendukung mode yang diminta.'
}

const startCamera = async () => {
  // Pastikan instance lama terhenti total (mencegah kamera/overlay ganda)
  cleanupScanner()

  // Konteks tidak aman → getUserMedia diblokir browser
  if (!window.isSecureContext) {
    status.value = 'error'
    scannerState.value = 'IDLE'
    errorMessage.value =
      `Halaman ini dibuka via ${location.protocol}//${location.host}. ` +
      `Kamera hanya aktif di http://localhost atau halaman HTTPS.`
    technicalError.value = 'insecure context'
    return
  }

  status.value = 'starting'
  scannerState.value = 'IDLE'
  errorMessage.value = ''
  technicalError.value = ''

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
          useBarCodeDetectorIfSupported: false
        }
      })
      await scanner.start(
        cameraConfig,
        {
          fps: 15
        },
        onScanSuccess,
        onScanFailure
      )

      // Sambungkan auxiliary engine ZXing untuk membaca Code 93 & GS1 Expanded
      if (bindInterval) clearInterval(bindInterval)
      let bindAttempts = 0
      bindInterval = setInterval(() => {
        bindAttempts++
        const videoEl = document.querySelector(`#${REGION_ID} video`)
        if (videoEl && videoEl.videoWidth > 0) {
          if (bindInterval) clearInterval(bindInterval)
          bindInterval = null
          startZxingFallback(videoEl)
        } else if (bindAttempts > 20) {
          if (bindInterval) clearInterval(bindInterval)
          bindInterval = null
          if (videoEl) startZxingFallback(videoEl)
        }
      }, 200)

      status.value = 'scanning'
      scannerState.value = 'SCANNING'
      isPaused.value = false
      isProcessingScan.value = false
      emptyFramesCount = 0
      return
    } catch (err) {
      lastError = err
      console.error('[CAMERA] Gagal dengan config', cameraConfig, err)
      cleanupScanner()
    }
  }

  console.error('[CAMERA] Semua percobaan kamera gagal:', lastError)
  status.value = 'error'
  scannerState.value = 'IDLE'
  const errName = lastError?.name || 'UnknownError'
  errorMessage.value =
    FRIENDLY_ERRORS[errName] ||
    'Pastikan halaman dibuka via http://localhost atau https:// dan izinkan akses kamera.'
  technicalError.value = `${errName}: ${lastError?.message || '(tanpa pesan)'}`
}

const stopCamera = () => {
  if (feedbackTimer) { clearTimeout(feedbackTimer); feedbackTimer = null }
  if (lockFallbackTimer) { clearTimeout(lockFallbackTimer); lockFallbackTimer = null }
  if (cooldownTimer) { clearTimeout(cooldownTimer); cooldownTimer = null }

  stopZxing()
  if (scanner) {
    try {
      const s = scanner
      scanner = null
      s.stop()
        .then(() => s.clear())
        .catch(() => {})
    } catch {
      /* sudah terhenti */
    }
  }
  status.value = 'idle'
  scannerState.value = 'IDLE'
  isPaused.value = false
  isProcessingScan.value = false
  lastScannedResi = ''
  emptyFramesCount = 0
}

const cleanupScanner = () => {
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
  show.value = false
}

// Handler frame tanpa barcode: hitung berturut-turut untuk mereset lock resi saat barcode diangkat/dijauhkan dari kamera
const onScanFailure = () => {
  if (status.value === 'scanning' && !isPaused.value) {
    emptyFramesCount++
    if (emptyFramesCount >= 5) {
      if (lastScannedResi) {
        lastScannedResi = ''
      }
    }
  }
}

// ---------------------------------------------------------------------
// DETEKSI OTOMATIS BERDASARKAN STATE MACHINE & LOCKING RIGID
// SCANNING -> DETECTED -> PAUSED -> PROCESSING -> RESULT/ALERT -> COOLDOWN -> RESUME -> SCANNING
// ---------------------------------------------------------------------
const onScanSuccess = (decodedText, decodedResult) => {
  // Guard 1: Jika scanner sedang PAUSED / PROCESSING / BUKAN SCANNING, langsung batalkan callback!
  if (isPaused.value || isProcessingScan.value || scannerState.value !== 'SCANNING' || status.value !== 'scanning') {
    return
  }

  const now = Date.now()

  // Guard 2: Sanitasi input decode
  const raw = String(decodedText || '').trim()
  if (!raw || raw.length < 4) return

  const formatName =
    decodedResult?.result?.format?.formatName ||
    decodedResult?.format?.formatName ||
    decodedResult?.result?.formatName ||
    null

  const resi = normalizeScannedBarcode(raw, formatName) || raw
  if (!resi || resi.length < 4) return

  // Guard 3: KUNCI KETAT resi yang sama jika masih ditahan di depan kamera (< 3.0 detik)
  if (lastScannedResi === resi && (now - lastScanTimestamp) < 3000) {
    emptyFramesCount = 0
    return
  }

  // === MASUK KE STATE PAUSED & PROCESSING SEKETIKA (LANGSUNG KUNCI CALLBACK) ===
  isPaused.value = true
  isProcessingScan.value = true
  scannerState.value = 'PAUSED'
  lastScannedResi = resi
  lastScanTimestamp = now
  emptyFramesCount = 0

  // Pause native html5-qrcode jika didukung
  if (scanner && typeof scanner.pause === 'function') {
    try {
      scanner.pause(true)
    } catch {
      /* ignore */
    }
  }

  playBeep()
  navigator.vibrate?.(60)

  // Emisikan hasil deteksi ke parent HANYA 1 KALI (Single Event Emission)
  emit('detected', resi, formatName)

  // Fallback lock timer (jika respon backend/store terhambat)
  if (lockFallbackTimer) clearTimeout(lockFallbackTimer)
  lockFallbackTimer = setTimeout(() => {
    if (scannerState.value === 'PAUSED' || scannerState.value === 'PROCESSING') {
      resumeScanner()
    }
  }, 4000)
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

<!-- Unscoped CSS khusus untuk elemen dinamis html5-qrcode — matikan seluruh overlay bawaan agar HANYA ADA 1 FRAME SCANNING -->
<style>
#camera-scanner-region__scan_region,
#camera-scanner-region__scan_region svg,
#camera-scanner-region__scan_region img,
#camera-scanner-region__scan_region canvas,
#camera-scanner-region__shaded_region,
#camera-scanner-region__dashboard,
#camera-scanner-region__status_span,
#camera-scanner-region__header_message,
.html5-qrcode-element {
  border: none !important;
  box-shadow: none !important;
  outline: none !important;
  background: transparent !important;
  display: none !important;
}
</style>

<style scoped>
.camera-frame {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
}

#camera-scanner-region {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

#camera-scanner-region video {
  border-radius: 12px;
  object-fit: cover;
  width: 100% !important;
  display: block;
  margin: 0 auto;
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
  border-color: #22c55e;
}

.scan-result--warning {
  background-color: #fee2e2;
  color: #b91c1c;
  border-color: #ef4444;
}

.scan-result--danger {
  background-color: #fee2e2;
  color: #b91c1c;
  border-color: #ef4444;
}

.history-chip {
  font-size: 0.68rem;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 999px;
}

.history-chip--success { background-color: #dcfce7; color: #15803d; }
.history-chip--warning { background-color: #fee2e2; color: #b91c1c; }
.history-chip--danger  { background-color: #fee2e2; color: #b91c1c; }

/* HANYA SATU BOX FRAME AREA SCANNING RESMI (BERADA TEPAT DI TENGAH PREVIEW KAMERA) */
.scan-frame-box {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: min(78%, 340px);
  height: min(48%, 150px);
  box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.42);
  overflow: hidden;
  pointer-events: none;
  z-index: 5;
  border-radius: 12px;
  transition: all 0.3s ease;
}

.scan-frame-box--paused {
  box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.65) !important;
}

.scan-frame-box--paused .scan-corner {
  border-color: #f59e0b !important;
}

/* Corner Brackets Frame (┌ ┐ └ ┘) Modern */
.scan-corner {
  position: absolute;
  width: 18px;
  height: 18px;
  border-color: rgba(255, 255, 255, 0.92);
  border-style: solid;
  pointer-events: none;
  transition: border-color 0.3s ease;
}

.scan-corner--top-left {
  top: 0;
  left: 0;
  border-width: 2.5px 0 0 2.5px;
  border-top-left-radius: 8px;
}

.scan-corner--top-right {
  top: 0;
  right: 0;
  border-width: 2.5px 2.5px 0 0;
  border-top-right-radius: 8px;
}

.scan-corner--bottom-left {
  bottom: 0;
  left: 0;
  border-width: 0 0 2.5px 2.5px;
  border-bottom-left-radius: 8px;
}

.scan-corner--bottom-right {
  bottom: 0;
  right: 0;
  border-width: 0 2.5px 2.5px 0;
  border-bottom-right-radius: 8px;
}
</style>
