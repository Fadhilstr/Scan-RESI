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
              <q-btn outline dense color="amber-4" icon="refresh" label="COBA LAGI" class="q-mt-md" @click="startCamera" />
            </div>
          </div>

          <!-- Garis bantu scan -->
          <div v-if="status === 'scanning'" class="scan-guide absolute-center"></div>
        </div>

        <div class="text-caption text-grey-7 text-center q-mt-sm row items-center justify-center">
          <q-icon :name="lastResi ? 'check_circle' : 'info'" size="16px"
                  :color="lastResi ? 'positive' : 'grey-6'" class="q-mr-xs" />
          <span v-if="lastResi">
            Terbaca: <span class="text-weight-bold font-mono">{{ lastResi }}</span> — arahkan barcode berikutnya
          </span>
          <span v-else>Arahkan barcode ke kamera — deteksi otomatis dengan jeda 1,2 detik</span>
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
const lastResi = ref('')

// ---------------------------------------------------------------------
// Siklus hidup kamera
// ---------------------------------------------------------------------
const onOpen = () => {
  lastResi.value = ''
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

  lastResi.value = resi
  playBeep()
  navigator.vibrate?.(80)

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
