<template>
  <q-card class="scan-card q-pa-md q-mb-lg">
    <q-card-section class="q-pa-sm">
      <div class="row items-center justify-between q-mb-sm">
        <div class="text-subtitle1 text-weight-bold text-slate-800 row items-center">
          <q-icon name="qr_code_scanner" size="24px" color="primary" class="q-mr-sm" />
          Nomor Resi / Hasil Barcode
        </div>
        <div class="text-caption text-grey-7 flex items-center" v-if="!disabled">
          <span class="scanner-dot q-mr-xs"></span> Simulator Input Barcode Active
        </div>
      </div>

      <div class="row q-col-gutter-sm items-center">
        <div class="col-12 col-sm-9 col-md-10">
          <q-input
            ref="inputRef"
            v-model="barcodeValue"
            outlined
            dense
            placeholder="Scan atau masukkan barcode..."
            class="scanner-input-box font-mono text-weight-bold text-h6"
            :disabled="disabled"
            autofocus
            @keyup.enter="handleScan"
            bg-color="white"
          >
            <template v-slot:prepend>
              <q-icon name="barcode_reader" color="primary" />
            </template>
            <template v-slot:append>
              <q-btn
                flat
                round
                dense
                icon="photo_camera"
                color="primary"
                :disable="disabled"
                @click="showCamera = true"
              >
                <q-tooltip>Scan via kamera</q-tooltip>
              </q-btn>
              <q-btn
                v-if="barcodeValue"
                flat
                round
                dense
                icon="close"
                @click="clearInput"
              />
            </template>
          </q-input>
        </div>

        <div class="col-12 col-sm-3 col-md-2">
          <q-btn
            color="primary"
            class="full-width text-weight-bold"
            size="lg"
            icon="search"
            label="SCAN"
            :disabled="disabled || !barcodeValue.trim()"
            @click="handleScan"
            unelevated
          />
        </div>
      </div>
    </q-card-section>
  </q-card>

  <!-- Dialog Scan Kamera -->
  <CameraScannerDialog v-model="showCamera" @detected="handleCameraDetected" />
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'
import { useQuasar } from 'quasar'
import CameraScannerDialog from './CameraScannerDialog.vue'

const props = defineProps({
  disabled: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['scan'])
const $q = useQuasar()
const barcodeValue = ref('')
const inputRef = ref(null)
const showCamera = ref(false)

const focusInput = () => {
  nextTick(() => {
    if (inputRef.value) {
      inputRef.value.focus()
    }
  })
}

const clearInput = () => {
  barcodeValue.value = ''
  focusInput()
}

const handleScan = () => {
  if (props.disabled || !barcodeValue.value.trim()) return

  const val = barcodeValue.value.trim()
  emit('scan', val)
  barcodeValue.value = ''
  focusInput()
}

// Hasil deteksi kamera → alur scan yang sama dengan input manual (FR-3)
const handleCameraDetected = (val) => {
  const resi = (val || '').trim()
  if (props.disabled || !resi) return
  emit('scan', resi)
}

onMounted(() => {
  focusInput()
})
</script>
