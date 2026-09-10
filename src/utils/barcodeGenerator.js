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
export function calculateMod10CheckDigit(digits) {
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
export function calculateUpceCheckDigit(payload6) {
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
 * Ekspansi UPC-E (8 digit) ke UPC-A (12 digit)
 */
export function expandUpceToUpca(upceStr) {
  const clean = String(upceStr).padStart(8, '0').slice(-8)
  const d = clean.slice(1, 7).split('').map(Number)
  const cd = clean.slice(7, 8)
  const last = d[5]
  let upcaDigits = []

  if (last === 0 || last === 1 || last === 2) {
    upcaDigits = [0, d[0], d[1], last, 0, 0, 0, 0, d[2], d[3], d[4]]
  } else if (last === 3) {
    upcaDigits = [0, d[0], d[1], d[2], 0, 0, 0, 0, 0, d[3], d[4]]
  } else if (last === 4) {
    upcaDigits = [0, d[0], d[1], d[2], d[3], 0, 0, 0, 0, 0, d[4]]
  } else {
    upcaDigits = [0, d[0], d[1], d[2], d[3], d[4], 0, 0, 0, 0, last]
  }

  let sum = 0
  for (let i = 0; i < 11; i++) {
    sum += upcaDigits[i] * (i % 2 === 0 ? 3 : 1)
  }
  const calcCd = (10 - (sum % 10)) % 10
  return upcaDigits.join('') + (cd || calcCd)
}

/**
 * Kompresi UPC-A (12 digit) ke UPC-E (8 digit) jika memungkinkan
 */
export function compressUpcaToUpce(upcaStr) {
  const clean = String(upcaStr).replace(/\D/g, '')
  if (clean.length !== 12 || !clean.startsWith('0')) return null

  const d = clean.split('').map(Number)
  const cd = d[11]

  if (d[3] <= 2 && d[4] === 0 && d[5] === 0 && d[6] === 0 && d[7] === 0) {
    return `0${d[1]}${d[2]}${d[8]}${d[9]}${d[10]}${d[3]}${cd}`
  }
  if (d[4] === 0 && d[5] === 0 && d[6] === 0 && d[7] === 0 && d[8] === 0) {
    return `0${d[1]}${d[2]}${d[3]}${d[9]}${d[10]}3${cd}`
  }
  if (d[5] === 0 && d[6] === 0 && d[7] === 0 && d[8] === 0 && d[9] === 0) {
    return `0${d[1]}${d[2]}${d[3]}${d[4]}${d[10]}4${cd}`
  }
  if (d[6] === 0 && d[7] === 0 && d[8] === 0 && d[9] === 0 && d[10] >= 5) {
    return `0${d[1]}${d[2]}${d[3]}${d[4]}${d[5]}${d[10]}${cd}`
  }

  return null
}

/**
 * Normalisasi nomor resi dari output scanner kamera/laser (GS1 AI, Codabar start/stop, MaxiCode, UPC-E, dsb)
 * @param {string} raw - Output mentah dari scanner
 * @param {string|null} format - Format barcode opsional (misal: 'MAXICODE', 'CODE_93', 'UPC_E', dsb)
 * @returns {string} - Nomor resi yang sudah ter-normalisasi ke format resi awal (tracking number)
 */
export function normalizeScannedBarcode(raw, format = null) {
  let s = (raw || '').trim().replace(/[\r\n\t]/g, '').toUpperCase()
  if (!s) return ''

  const checkLocalStorage = (key) => {
    if (typeof localStorage === 'undefined' || !key) return null
    const cleanKey = String(key).trim()
    return (
      localStorage.getItem(`barcode_mapping_${cleanKey}`) ||
      localStorage.getItem(`barcode_mapping_${cleanKey.toUpperCase()}`) ||
      null
    )
  }

  // 1. Direct local storage mapping check
  let localMapped = checkLocalStorage(s)
  if (localMapped) return localMapped

  const sCleanBracket = s.replace(/[\(\)\-\s]/g, '')
  localMapped = checkLocalStorage(sCleanBracket)
  if (localMapped) return localMapped

  const fmt = (format || '').toUpperCase()

  // 2. MAXICODE: Ekstrak tracking number dari (10)XXXXX atau header MaxiCode
  if (fmt === 'MAXICODE' || s.includes('[C3') || s.includes('ANSI ') || /\(10\)|10[A-Z0-9]{6,}/.test(s)) {
    const m10 = s.match(/\(10\)([A-Z0-9]+)/i) || s.match(/10([A-Z0-9]{6,16})/i) || s.match(/^01\d{14}10([A-Z0-9]+)/i)
    if (m10 && m10[1]) {
      const extracted = m10[1].toUpperCase()
      return checkLocalStorage(extracted) || checkLocalStorage(`(10)${extracted}`) || extracted
    }
    const mMaxi = s.match(/([A-Z0-9]{8,16})/i)
    if (mMaxi && mMaxi[1]) {
      const extracted = mMaxi[1].toUpperCase()
      return checkLocalStorage(extracted) || extracted
    }
  }

  // 3. CODE_93: Hapus non-alfanumerik, tetap kapital
  if (fmt === 'CODE_93') {
    const clean93 = s.replace(/[^A-Z0-9]/g, '')
    if (clean93) {
      return checkLocalStorage(clean93) || clean93
    }
  }

  // 4. CODE_39: Hapus bintang wrapping dan karakter non-Code39
  if (fmt === 'CODE_39' || /^\*[^*]+\*$/.test(s)) {
    const unstar = s.replace(/^\*|\*$/g, '')
    const clean39 = unstar.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '').trim()
    if (clean39) {
      return checkLocalStorage(clean39) || checkLocalStorage(unstar) || clean39
    }
  }

  // 5. CODABAR: Hapus start/stop A, B, C, D wrapping
  if (fmt === 'CODABAR' || /^[ABCD][0-9\-\$\:\/\.\+]+[ABCD]$/i.test(s)) {
    const mCoda = s.match(/^[ABCD]([0-9\-\$\:\/\.\+]+)[ABCD]$/i)
    if (mCoda && mCoda[1]) {
      const inner = mCoda[1]
      return checkLocalStorage(inner) || checkLocalStorage(s) || inner
    }
  }

  // 6. UPC-E: Ekspansi ke UPC-A dengan check digit
  if (fmt === 'UPC_E' || /^0\d{7}$/.test(s) || /^0\d{6}$/.test(s)) {
    let upceStr = s.replace(/\D/g, '')
    if (upceStr.length === 6) {
      const cd = calculateUpceCheckDigit(upceStr)
      upceStr = '0' + upceStr + cd
    }
    if (upceStr.length === 8 && upceStr.startsWith('0')) {
      const upcaExpanded = expandUpceToUpca(upceStr)
      return (
        checkLocalStorage(upceStr) ||
        checkLocalStorage(upcaExpanded) ||
        upceStr
      )
    }
  }

  // 7. UPC-A: Tambahkan check digit atau tetap
  if (fmt === 'UPC_A' || (/^\d{11,12}$/.test(s) && fmt !== 'EAN_13')) {
    let digits = s.replace(/\D/g, '')
    if (digits.length === 11) {
      const cd = calculateMod10CheckDigit(digits)
      digits = digits + cd
    }
    if (digits.length === 12) {
      const upceCompressed = compressUpcaToUpce(digits)
      return (
        checkLocalStorage(digits) ||
        checkLocalStorage(digits.slice(0, 11)) ||
        (upceCompressed ? checkLocalStorage(upceCompressed) : null) ||
        digits
      )
    }
  }

  // 8. EAN_13: Tambahkan / check digit
  if (fmt === 'EAN_13' || (/^\d{12,13}$/.test(s) && fmt !== 'UPC_A')) {
    let digits = s.replace(/\D/g, '')
    if (digits.length === 12) {
      const cd = calculateMod10CheckDigit(digits)
      digits = digits + cd
    }
    if (digits.length === 13) {
      return (
        checkLocalStorage(digits) ||
        checkLocalStorage(digits.slice(0, 12)) ||
        digits
      )
    }
  }

  // 9. EAN_8: Tambahkan / check digit
  if (fmt === 'EAN_8' || /^\d{7,8}$/.test(s)) {
    let digits = s.replace(/\D/g, '')
    if (digits.length === 7) {
      let sum = 0
      for (let i = 0; i < 7; i++) {
        sum += parseInt(digits[i], 10) * (i % 2 === 0 ? 3 : 1)
      }
      const cd = (10 - (sum % 10)) % 10
      digits = digits + cd
    }
    if (digits.length === 8) {
      return (
        checkLocalStorage(digits) ||
        checkLocalStorage(digits.slice(0, 7)) ||
        digits
      )
    }
  }

  // 10. RSS_14 & RSS_EXPANDED: Parsing format GS1 (01) GTIN / (10) Tracking No
  if (fmt === 'RSS_14' || fmt === 'RSS_EXPANDED' || s.includes('(01)') || s.includes('(10)')) {
    const m10 = s.match(/\(10\)([A-Z0-9]+)/i) || s.match(/10([A-Z0-9]{6,16})/i)
    if (m10 && m10[1]) {
      const extracted = m10[1].toUpperCase()
      return checkLocalStorage(extracted) || checkLocalStorage(`(10)${extracted}`) || extracted
    }
    const m01 = s.match(/^\(01\)(\d{13,14})/i) || s.match(/^01(\d{14})/i)
    if (m01 && m01[1]) {
      let gtin = m01[1]
      if (gtin.length === 13) {
        gtin = gtin + calculateMod10CheckDigit(gtin)
      }
      return (
        checkLocalStorage(gtin) ||
        checkLocalStorage(`(01)${gtin}`) ||
        gtin
      )
    }
  }

  // 11. ITF: Angka genap 4-16 digit
  if (fmt === 'ITF' || (/^\d{4,16}$/.test(s) && s.length % 2 === 0)) {
    const digits = s.replace(/\D/g, '')
    if (digits.length >= 4 && digits.length <= 16) {
      return checkLocalStorage(digits) || digits
    }
  }

  // 12. UPC_EAN_EXTENSION: 2 atau 5 digit langsung
  if (fmt === 'UPC_EAN_EXTENSION' || /^\d{2}$/.test(s) || /^\d{5}$/.test(s)) {
    const digits = s.replace(/\D/g, '')
    if (digits.length === 2 || digits.length === 5) {
      return checkLocalStorage(digits) || digits
    }
  }

  // Generic GS1 AI (10) Serial/Tracking: (10)XXXXX atau 01...10XXXXX
  const m10Gen = s.match(/\(10\)([A-Z0-9]+)/i) || s.match(/^01\d{14}10([A-Z0-9]+)/i)
  if (m10Gen && m10Gen[1]) {
    const extracted = m10Gen[1].toUpperCase()
    return checkLocalStorage(extracted) || extracted
  }

  // Generic GS1 AI (01) 14 digit GTIN: (01)XXXXX
  const m01Gen = s.match(/^\(01\)(\d{13,14})/i) || s.match(/^01(\d{14})/i)
  if (m01Gen && m01Gen[1]) {
    const gtin = m01Gen[1]
    return checkLocalStorage(gtin) || gtin
  }

  // Generic Codabar start/stop A, B, C, D wrapping
  const mCodaGen = s.match(/^[ABCD]([0-9\-\$\:\/\.\+]+)[ABCD]$/i)
  if (mCodaGen && mCodaGen[1]) {
    return checkLocalStorage(mCodaGen[1]) || mCodaGen[1]
  }

  return s
}

/**
 * Memisahkan dan menyelesaikan payload barcode untuk ke-17 format:
 * Menyimpan seluruh variasi barcode_value -> cleanTracking di localStorage.
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
    case 'PDF_417':
      barcodeValue = cleanTracking
      break

    case 'MAXICODE':
      barcodeValue = cleanTracking.startsWith('(10)') ? cleanTracking : `(10)${cleanTracking}`
      isMapped = true
      break

    case 'CODE_39':
    case 'CODE_93':
      barcodeValue = cleanTracking.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '') || cleanTracking
      break

    case 'ITF': {
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
      if (/^\(01\)\d{14}/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else {
        isMapped = true
        const cleanAlpha = cleanTracking.replace(/[^A-Za-z0-9]/g, '').slice(0, 16) || 'WAHANA'
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
    is_mapped: isMapped
  }

  // Simpan seluruh pemetaan variasi ke localStorage
  if (typeof localStorage !== 'undefined' && cleanTracking) {
    try {
      localStorage.setItem(`barcode_mapping_${barcodeValue}`, cleanTracking)
      localStorage.setItem(`barcode_mapping_${cleanTracking}`, cleanTracking)

      if (format === 'UPC_E' && barcodeValue.length === 8) {
        const upca = expandUpceToUpca(barcodeValue)
        localStorage.setItem(`barcode_mapping_${upca}`, cleanTracking)
      }
      if (format === 'UPC_A' && barcodeValue.length === 12) {
        localStorage.setItem(`barcode_mapping_${barcodeValue.slice(0, 11)}`, cleanTracking)
        const upce = compressUpcaToUpce(barcodeValue)
        if (upce) localStorage.setItem(`barcode_mapping_${upce}`, cleanTracking)
      }
      if (format === 'EAN_13' && barcodeValue.length === 13) {
        localStorage.setItem(`barcode_mapping_${barcodeValue.slice(0, 12)}`, cleanTracking)
      }
      if (format === 'EAN_8' && barcodeValue.length === 8) {
        localStorage.setItem(`barcode_mapping_${barcodeValue.slice(0, 7)}`, cleanTracking)
      }
      if (format === 'MAXICODE') {
        localStorage.setItem(`barcode_mapping_(10)${cleanTracking}`, cleanTracking)
      }
      if (format === 'CODABAR') {
        const inner = barcodeValue.replace(/^[ABCD]|[ABCD]$/gi, '')
        localStorage.setItem(`barcode_mapping_${inner}`, cleanTracking)
      }
      if (format === 'RSS_14') {
        localStorage.setItem(`barcode_mapping_${barcodeValue.replace('(01)', '')}`, cleanTracking)
      }
      if (format === 'RSS_EXPANDED') {
        localStorage.setItem(`barcode_mapping_(10)${cleanTracking}`, cleanTracking)
      }

      localStorage.setItem(`barcode_meta_${cleanTracking}_${format}`, JSON.stringify(payload))
    } catch {
      /* ignore quota errors */
    }
  }

  return payload
}

/**
 * Render barcode atau QR Code / 2D Matrix ke dalam elemen SVG
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

    if (!is2DMatrix && !isStacked) {
      bwipOptions.height = options.height || 12
      bwipOptions.paddingwidth = 8
      bwipOptions.paddingheight = 4
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
        const size = String(options.qrSize || 115)
        svgEl.setAttribute('width', size)
        svgEl.setAttribute('height', size)
        svgEl.style.maxWidth = '125px'
        svgEl.style.maxHeight = '125px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (isStacked) {
        svgEl.setAttribute('width', '220')
        svgEl.style.maxWidth = '220px'
        svgEl.style.maxHeight = '65px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else {
        svgEl.removeAttribute('width')
        svgEl.removeAttribute('height')
        svgEl.style.maxWidth = '260px'
        svgEl.style.maxHeight = '65px'
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
