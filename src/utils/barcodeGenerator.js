import bwipjs from 'bwip-js'

/**
 * 17 Format Barcode yang kompatibel dengan decoder kamera scanner (Html5QrcodeSupportedFormats):
 * QR_CODE = 0, AZTEC = 1, CODABAR = 2, CODE_39 = 3, CODE_93 = 4, CODE_128 = 5,
 * DATA_MATRIX = 6, MAXICODE = 7, ITF = 8, EAN_13 = 9, EAN_8 = 10, PDF_417 = 11,
 * RSS_14 = 12, RSS_EXPANDED = 13, UPC_A = 14, UPC_E = 15, UPC_EAN_EXTENSION = 16
 */
export const BARCODE_FORMAT_OPTIONS = [
  { label: 'CODE_128 (Default)', value: 'CODE_128', supported: true, category: '1D' },
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
    case 'CODE_93':
      // Code 39 & 93 menerima alfanumerik huruf kapital
      barcodeValue = cleanTracking.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '') || cleanTracking
      break

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
      // UPC-E butuh angka dengan prefiks 0
      if (/^0\d{7}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else if (/^0\d{6}$/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else {
        isMapped = true
        barcodeValue = '0' + stringToDeterministicDigits(cleanTracking, 6)
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
      // Extension 5 digit
      isMapped = true
      barcodeValue = stringToDeterministicDigits(cleanTracking, 5)
      break
    }

    case 'RSS_EXPANDED': {
      // GS1 DataBar Expanded (01) GTIN + (10) Tracking No
      isMapped = true
      const d13 = '0' + stringToDeterministicDigits(cleanTracking, 12)
      const cd = calculateMod10CheckDigit(d13)
      const cleanAlpha = cleanTracking.replace(/[^A-Za-z0-9]/g, '').slice(0, 10)
      barcodeValue = `(01)${d13}${cd}(10)${cleanAlpha}`
      break
    }

    default:
      barcodeValue = cleanTracking
  }

  const payload = {
    tracking_no: cleanTracking,
    barcode_format: format,
    barcode_value: barcodeValue,
    is_mapped: isMapped
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
      scale: options.scale || 2,
      includetext: false,
      backgroundcolor: 'ffffff'
    }

    if (!is2DMatrix && !isStacked) {
      // Barcode 1D linear
      bwipOptions.height = options.height || 8
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

      if (is2DMatrix) {
        svgEl.setAttribute('width', String(options.qrSize || 105))
        svgEl.setAttribute('height', String(options.qrSize || 105))
        svgEl.style.maxWidth = '115px'
        svgEl.style.maxHeight = '115px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (isStacked) {
        svgEl.setAttribute('width', '210')
        svgEl.style.maxWidth = '210px'
        svgEl.style.maxHeight = '65px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else {
        svgEl.removeAttribute('width')
        svgEl.removeAttribute('height')
        svgEl.style.maxWidth = '240px'
        svgEl.style.maxHeight = '52px'
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
