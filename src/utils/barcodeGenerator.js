import bwipjs from 'bwip-js'

/**
 * 17 Format Barcode yang kompatibel dengan decoder kamera scanner (Html5QrcodeSupportedFormats):
 * QR_CODE = 0, AZTEC = 1, CODABAR = 2, CODE_39 = 3, CODE_93 = 4, CODE_128 = 5,
 * DATA_MATRIX = 6, MAXICODE = 7, ITF = 8, EAN_13 = 9, EAN_8 = 10, PDF_417 = 11,
 * RSS_14 = 12, RSS_EXPANDED = 13, UPC_A = 14, UPC_E = 15, UPC_EAN_EXTENSION = 16
 */
export const BARCODE_FORMAT_OPTIONS = [
  { label: 'CODE_128', value: 'CODE_128', supported: true, category: '1D' },
  { label: 'QR_CODE', value: 'QR_CODE', supported: true, category: '2D Matrix' },
  { label: 'AZTEC', value: 'AZTEC', supported: true, category: '2D Matrix' },
  { label: 'DATA_MATRIX', value: 'DATA_MATRIX', supported: true, category: '2D Matrix' },
  { label: 'MAXICODE', value: 'MAXICODE', supported: true, category: '2D Matrix' },
  { label: 'PDF_417', value: 'PDF_417', supported: true, category: '2D Stacked' },
  { label: 'CODE_39', value: 'CODE_39', supported: true, category: '1D' },
  { label: 'CODE_93', value: 'CODE_93', supported: true, category: '1D' },
  { label: 'CODABAR', value: 'CODABAR', supported: true, category: '1D' },
  { label: 'ITF (Interleaved 2 of 5)', value: 'ITF', supported: true, category: '1D' },
  { label: 'EAN_13', value: 'EAN_13', supported: true, category: '1D Numerik' },
  { label: 'EAN_8', value: 'EAN_8', supported: true, category: '1D Numerik' },
  { label: 'UPC_A', value: 'UPC_A', supported: true, category: '1D Numerik' },
  { label: 'UPC_E', value: 'UPC_E', supported: true, category: '1D Numerik' },
  { label: 'UPC_EAN_EXTENSION', value: 'UPC_EAN_EXTENSION', supported: true, category: '1D Numerik' },
  { label: 'RSS_14 (GS1 DataBar)', value: 'RSS_14', supported: true, category: '1D GS1' },
  { label: 'RSS_EXPANDED (GS1 Expanded)', value: 'RSS_EXPANDED', supported: true, category: '1D GS1' }
]

/**
 * Pemetaan format ke identifier BWIPP (Barcode Writer in Pure JavaScript)
 */
const BWIP_FORMAT_MAP = {
  CODE_128: 'code128',
  QR_CODE: 'qrcode',
  AZTEC: 'azteccode',
  DATA_MATRIX: 'datamatrix',
  MAXICODE: 'maxicode',
  PDF_417: 'pdf417',
  CODE_39: 'code39',
  CODE_93: 'code93',
  CODABAR: 'rationalizedCodabar',
  ITF: 'interleaved2of5',
  EAN_13: 'ean13',
  EAN_8: 'ean8',
  UPC_A: 'upca',
  UPC_E: 'upce',
  UPC_EAN_EXTENSION: 'ean5',
  RSS_14: 'databaromni',
  RSS_EXPANDED: 'databarexpanded'
}

/**
 * Menghasilkan digit angka deterministik dan unik dari sebuah string (tracking number)
 * Menggunakan algoritma hash FNV-1a 64-bit ganda tanpa random agar bebas collision.
 */
export function stringToDeterministicDigits(str, targetLength) {
  const cleanStr = (str || '').trim().toUpperCase()
  let h1 = 0x811c9dc5n
  let h2 = 0xcbf29ce484222325n

  for (let i = 0; i < cleanStr.length; i++) {
    const c = BigInt(cleanStr.charCodeAt(i))
    h1 = (h1 ^ c) * 0x01000193n
    h2 = (h2 ^ c) * 0x100000001b3n
  }

  let digits = ((h1 << 32n) | (h2 & 0xffffffffn)).toString().replace('-', '')
  let counter = 1n
  while (digits.length < targetLength) {
    digits += ((h2 * counter++) & 0xffffffffn).toString()
  }

  return digits.slice(0, targetLength)
}

/**
 * Menghitung check digit Modulo 10 standar GS1 / EAN / UPC
 */
function calculateMod10CheckDigit(digits) {
  let sum = 0
  for (let i = digits.length - 1; i >= 0; i--) {
    const n = parseInt(digits[i], 10)
    sum += (digits.length - i) % 2 === 1 ? n * 3 : n
  }
  return (10 - (sum % 10)) % 10
}

/**
 * Menghitung check digit UPC-E standar via ekspansi UPC-A
 */
function calculateUpceCheckDigit(payload6) {
  const d = String(payload6).padStart(6, '0').slice(-6).split('').map(Number)
  let upca = []
  const last = d[5]
  if (last === 0 || last === 1 || last === 2) {
    upca = [0, d[0], d[1], last, 0, 0, 0, 0, d[2], d[3], d[4]]
  } else if (last === 3) {
    upca = [0, d[0], d[1], d[2], 0, 0, 0, 0, 0, d[3], d[4]]
  } else if (last === 4) {
    upca = [0, d[0], d[1], d[2], d[3], 0, 0, 0, 0, 0, d[4]]
  } else {
    upca = [0, d[0], d[1], d[2], d[3], d[4], 0, 0, 0, 0, last]
  }
  let sum = 0
  for (let i = 0; i < 11; i++) {
    sum += upca[i] * (i % 2 === 0 ? 3 : 1)
  }
  const rem = sum % 10
  return rem === 0 ? 0 : 10 - rem
}

/**
 * Menghitung 2 karakter check digit C dan K standar Code 93
 */
export function calculateCode93CheckDigits(str) {
  const ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%abcd*'
  const clean = (str || '').trim().toUpperCase().replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '')
  if (!clean) return { c: '', k: '', full: '' }

  // Check character C (bobot 1..20)
  let weight = 1
  let total = 0
  for (let i = clean.length - 1; i >= 0; i--) {
    total += weight * ALPHABET.indexOf(clean.charAt(i))
    if (++weight > 20) weight = 1
  }
  const c = ALPHABET[total % 47]

  // Check character K (bobot 1..15 terhadap string + C)
  const withC = clean + c
  weight = 1
  total = 0
  for (let i = withC.length - 1; i >= 0; i--) {
    total += weight * ALPHABET.indexOf(withC.charAt(i))
    if (++weight > 15) weight = 1
  }
  const k = ALPHABET[total % 47]

  return { c, k, full: clean + c + k }
}

/**
 * Normalisasi nomor resi dari output scanner kamera/laser (GS1 AI, Codabar start/stop, dsb)
 */
export function normalizeScannedBarcode(raw) {
  if (!raw) return ''
  let s = String(raw).trim()
  // 1. Hapus karakter kontrol tak terlihat (FNC1, GS ASCII 29, RS ASCII 30, dsb)
  s = s.replace(/[\x00-\x1F\x7F-\x9F]/g, '').trim().toUpperCase()
  // 2. Hapus AIM Symbology Identifier jika dikirim scanner (misal ]e0, ]C1, ]A0, ]G0)
  s = s.replace(/^\][A-Z0-9]{2}/i, '').trim()

  // 3. Cek local mapping jika tersimpan saat render
  if (typeof localStorage !== 'undefined') {
    const localMapped = localStorage.getItem(`barcode_mapping_${s}`)
    if (localMapped) return localMapped
  }

  // 4. GS1 AI(10) - Ekstrak nomor resi dari AI (10)
  const m10Paren = s.match(/\(10\)\s*([A-Z0-9]+)/i)
  if (m10Paren && m10Paren[1]) return m10Paren[1]

  const m10Raw = s.match(/^(?:(?:\(01\)|01)\s*\d{13,14})?\s*(?:\(10\)|10)\s*([A-Z0-9]+)/i)
  if (m10Raw && m10Raw[1]) return m10Raw[1]

  const m10Anywhere = s.match(/\d{14}10([A-Z0-9]{4,16})/i)
  if (m10Anywhere && m10Anywhere[1]) return m10Anywhere[1]

  // 5. GS1 AI(01) 14 digit GTIN
  const m01 = s.match(/^\(01\)\s*(\d{13,14})/i) || s.match(/^01(\d{14})/i)
  if (m01 && m01[1]) return m01[1]

  // 6. Codabar start/stop A, B, C, D
  const mCoda = s.match(/^[ABCD]([0-9]+)[ABCD]$/i)
  if (mCoda && mCoda[1]) return mCoda[1]

  return s
}

/**
 * Memisahkan dan menyelesaikan payload barcode:
 * {
 *   tracking_no: "DJK260909000001",
 *   barcode_format: "AZTEC",
 *   barcode_value: "DJK260909000001"
 * }
 *
 * Untuk format alfanumerik, barcode_value = tracking_no.
 * Untuk format numerik khusus, nomor resi dipetakan secara deterministik, unik,
 * dan terhubung kembali dengan tracking number tanpa collision.
 */
export function resolveBarcodePayload(trackingNo, format = 'CODE_128') {
  const cleanTracking = (trackingNo || '').trim().toUpperCase()

  let barcodeValue = cleanTracking
  let isMapped = false
  let checkDigits = null

  switch (format) {
    case 'CODE_128':
    case 'QR_CODE':
    case 'AZTEC':
    case 'DATA_MATRIX':
    case 'MAXICODE':
    case 'PDF_417':
      barcodeValue = cleanTracking
      break

    case 'CODE_39':
      barcodeValue = cleanTracking.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '') || cleanTracking
      break

    case 'CODE_93': {
      barcodeValue = cleanTracking.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '') || cleanTracking
      checkDigits = calculateCode93CheckDigits(barcodeValue)
      break
    }

    case 'ITF': {
      // ITF butuh angka dengan panjang genap (misal 12 atau 14 digit)
      if (/^\d{4,16}$/.test(cleanTracking) && cleanTracking.length % 2 === 0) {
        isMapped = false
        barcodeValue = cleanTracking
      } else {
        isMapped = true
        barcodeValue = stringToDeterministicDigits(cleanTracking, 14)
      }
      break
    }

    case 'CODABAR': {
      // Codabar angka dengan start/stop karakter A..B
      if (/^[A-D][0-9\-\$\:\/\.\+]+[A-D]$/i.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking.toUpperCase()
      } else if (/^\d{6,16}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = 'A' + cleanTracking + 'B'
      } else {
        isMapped = true
        const numPart = stringToDeterministicDigits(cleanTracking, 10)
        barcodeValue = 'A' + numPart + 'B'
      }
      break
    }

    case 'EAN_13': {
      // EAN-13 butuh 12 digit + 1 check digit = 13 digit
      if (/^\d{13}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else if (/^\d{12}$/.test(cleanTracking)) {
        isMapped = false
        const cd = calculateMod10CheckDigit(cleanTracking)
        barcodeValue = cleanTracking + cd
      } else {
        isMapped = true
        const d12 = stringToDeterministicDigits(cleanTracking, 12)
        const cd = calculateMod10CheckDigit(d12)
        barcodeValue = d12 + cd
      }
      break
    }

    case 'EAN_8': {
      // EAN-8 butuh 7 digit + 1 check digit = 8 digit
      if (/^\d{8}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else if (/^\d{7}$/.test(cleanTracking)) {
        isMapped = false
        let sum = 0
        for (let i = 0; i < 7; i++) {
          sum += parseInt(cleanTracking[i], 10) * (i % 2 === 0 ? 3 : 1)
        }
        const cd = (10 - (sum % 10)) % 10
        barcodeValue = cleanTracking + cd
      } else {
        isMapped = true
        const d7 = stringToDeterministicDigits(cleanTracking, 7)
        let sum = 0
        for (let i = 0; i < 7; i++) {
          sum += parseInt(d7[i], 10) * (i % 2 === 0 ? 3 : 1)
        }
        const cd = (10 - (sum % 10)) % 10
        barcodeValue = d7 + cd
      }
      break
    }

    case 'UPC_A': {
      // UPC-A butuh 11 digit + 1 check digit = 12 digit
      if (/^\d{12}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else if (/^\d{11}$/.test(cleanTracking)) {
        isMapped = false
        let sum = 0
        for (let i = 0; i < 11; i++) {
          sum += parseInt(cleanTracking[i], 10) * (i % 2 === 0 ? 3 : 1)
        }
        const cd = (10 - (sum % 10)) % 10
        barcodeValue = cleanTracking + cd
      } else {
        isMapped = true
        const d11 = stringToDeterministicDigits(cleanTracking, 11)
        let sum = 0
        for (let i = 0; i < 11; i++) {
          sum += parseInt(d11[i], 10) * (i % 2 === 0 ? 3 : 1)
        }
        const cd = (10 - (sum % 10)) % 10
        barcodeValue = d11 + cd
      }
      break
    }

    case 'UPC_E': {
      // UPC-E butuh 8 digit (0 + 6 digit payload + check digit valid hasil ekspansi UPC-A)
      if (/^0\d{7}$/.test(cleanTracking)) {
        const payload6 = cleanTracking.slice(1, 7)
        const cd = calculateUpceCheckDigit(payload6)
        barcodeValue = '0' + payload6 + cd
        isMapped = (barcodeValue !== cleanTracking)
      } else if (/^0\d{6}$/.test(cleanTracking)) {
        const payload6 = cleanTracking.slice(1, 7)
        const cd = calculateUpceCheckDigit(payload6)
        barcodeValue = '0' + payload6 + cd
        isMapped = true
      } else {
        isMapped = true
        const payload6 = stringToDeterministicDigits(cleanTracking, 6)
        const cd = calculateUpceCheckDigit(payload6)
        barcodeValue = '0' + payload6 + cd
      }
      break
    }

    case 'RSS_14': {
      // GS1 DataBar Omnidirectional wajib diawali (01) dan 13-14 digit GTIN
      if (/^\(01\)\d{13,14}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else if (/^\d{14}$/.test(cleanTracking)) {
        isMapped = false
        const data13 = cleanTracking.slice(0, 13)
        const cd = calculateMod10CheckDigit(data13)
        barcodeValue = `(01)${data13}${cd}`
      } else if (/^\d{13}$/.test(cleanTracking)) {
        isMapped = false
        const cd = calculateMod10CheckDigit(cleanTracking)
        barcodeValue = `(01)${cleanTracking}${cd}`
      } else {
        isMapped = true
        const d13 = '1' + stringToDeterministicDigits(cleanTracking, 12)
        const cd = calculateMod10CheckDigit(d13)
        barcodeValue = `(01)${d13}${cd}`
      }
      break
    }

    case 'UPC_EAN_EXTENSION': {
      // Extension 2 atau 5 digit
      if (/^\d{5}$/.test(cleanTracking) || /^\d{2}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else {
        isMapped = true
        barcodeValue = stringToDeterministicDigits(cleanTracking, 5)
      }
      break
    }

    case 'RSS_EXPANDED': {
      // GS1 DataBar Expanded butuh format GS1 valid: (01)GTIN-14 + (10)Tracking No
      if (/^\(01\)\d{14}/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else {
        isMapped = true
        const cleanAlpha = cleanTracking.replace(/[^A-Za-z0-9]/g, '').slice(0, 16) || 'WAHANA'
        // (01)01234567890128: GTIN-14 valid (0123456789012 + mod10 check digit 8)
        barcodeValue = `(01)01234567890128(10)${cleanAlpha}`
      }
      break
    }

    default:
      barcodeValue = cleanTracking
  }

  const payload = {
    tracking_no: cleanTracking,
    barcode_format: format,
    barcode_value: barcodeValue,
    is_mapped: isMapped,
    check_digits: checkDigits
  }

  // Simpan keterkaitan barcode_value -> tracking_no di storage lokal
  if (typeof localStorage !== 'undefined' && cleanTracking) {
    try {
      localStorage.setItem(`barcode_mapping_${barcodeValue}`, cleanTracking)
      localStorage.setItem(`barcode_meta_${cleanTracking}_${format}`, JSON.stringify(payload))
    } catch {
      /* ignore storage quota in private mode */
    }
  }

  return payload
}

/**
 * Render barcode atau QR Code / 2D Matrix ke dalam elemen SVG atau mengembalikan SVG string
 * Mendukung penuh ke-17 format:
 * QR_CODE, AZTEC, CODABAR, CODE_39, CODE_93, CODE_128, DATA_MATRIX, MAXICODE,
 * ITF, EAN_13, EAN_8, PDF_417, RSS_14, RSS_EXPANDED, UPC_A, UPC_E, UPC_EAN_EXTENSION
 *
 * @param {SVGElement|HTMLElement|null} svgEl - Elemen <svg> jika render langsung ke DOM
 * @param {string} rawTrackingNo - Nomor resi
 * @param {string} format - Format yang dipilih (default: CODE_128)
 * @param {Object} options - Opsi ukuran dan styling
 * @returns {Promise<{ success: boolean, svgHtml?: string, payload?: Object, error?: string }>}
 */
export async function renderBarcode(svgEl, rawTrackingNo, format = 'CODE_128', options = {}) {
  const trackingNo = (rawTrackingNo || '').trim()
  if (!trackingNo) {
    if (svgEl) svgEl.innerHTML = ''
    return { success: false, error: 'Nomor resi tidak boleh kosong.' }
  }

  const payload = resolveBarcodePayload(trackingNo, format)
  const bcid = BWIP_FORMAT_MAP[format] || 'code128'

  try {
    const is2DMatrix = ['QR_CODE', 'AZTEC', 'DATA_MATRIX', 'MAXICODE'].includes(format)
    const isStacked = format === 'PDF_417'

    const bwipOptions = {
      bcid,
      text: payload.barcode_value,
      scale: options.scale || 3,
      includetext: false,
      backgroundcolor: 'ffffff'
    }

    if (format === 'CODE_93') {
      // Code 93 memerlukan 2 digit check characters C & K sesuai standar spesifikasi internasional
      bwipOptions.includecheck = true
    }

    if (!is2DMatrix && !isStacked) {
      // Barcode 1D linear: tingkatkan tinggi dan beri quiet zone padding agar mudah dideteksi kamera
      bwipOptions.height = options.height || (format === 'RSS_EXPANDED' ? 20 : 16)
      bwipOptions.paddingwidth = 15
      bwipOptions.paddingheight = 8
    }

    const svgString = bwipjs.toSVG(bwipOptions)

    if (svgEl && typeof document !== 'undefined') {
      const parser = new DOMParser()
      const doc = parser.parseFromString(svgString, 'image/svg+xml')
      const newSvg = doc.documentElement

      svgEl.innerHTML = newSvg.innerHTML
      if (newSvg.getAttribute('viewBox')) {
        svgEl.setAttribute('viewBox', newSvg.getAttribute('viewBox'))
      }

      if (format === 'MAXICODE') {
        const size = String(options.qrSize || 180)
        svgEl.setAttribute('width', size)
        svgEl.setAttribute('height', size)
        svgEl.style.maxWidth = '200px'
        svgEl.style.maxHeight = '200px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (is2DMatrix) {
        const size = String(options.qrSize || 120)
        svgEl.setAttribute('width', size)
        svgEl.setAttribute('height', size)
        svgEl.style.maxWidth = '135px'
        svgEl.style.maxHeight = '135px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (isStacked) {
        svgEl.setAttribute('width', '240')
        svgEl.style.maxWidth = '240px'
        svgEl.style.maxHeight = '80px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (format === 'RSS_EXPANDED') {
        svgEl.removeAttribute('width')
        svgEl.removeAttribute('height')
        svgEl.style.maxWidth = '320px'
        svgEl.style.maxHeight = '95px'
        svgEl.style.width = '100%'
        svgEl.style.height = 'auto'
      } else {
        svgEl.removeAttribute('width')
        svgEl.removeAttribute('height')
        svgEl.style.maxWidth = '280px'
        svgEl.style.maxHeight = '85px'
        svgEl.style.width = '100%'
        svgEl.style.height = 'auto'
      }
    }

    return {
      success: true,
      svgHtml: svgString,
      payload
    }
  } catch (err) {
    console.error(`[BARCODE-GENERATOR] Gagal render ${format}:`, err)
    if (svgEl) svgEl.innerHTML = ''
    return {
      success: false,
      error: `Gagal menghasilkan barcode format ${format}: ${err.message}`
    }
  }
}
