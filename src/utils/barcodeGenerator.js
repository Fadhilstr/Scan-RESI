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
  {
    label: 'MAXICODE',
    value: 'MAXICODE',
    supported: false,
    disable: true,
    warning: 'Memerlukan scanner hardware/laser industri 2D (tidak didukung kamera webcam)',
    category: '2D Matrix'
  },
  { label: 'PDF_417', value: 'PDF_417', supported: true, category: '2D Stacked' },
  { label: 'CODE_39', value: 'CODE_39', supported: true, category: '1D' },
  { label: 'CODE_93', value: 'CODE_93', supported: true, category: '1D' },
  { label: 'CODABAR', value: 'CODABAR', supported: true, category: '1D' },
  { label: 'ITF (Interleaved 2 of 5)', value: 'ITF', supported: true, category: '1D' },
  { label: 'EAN_13', value: 'EAN_13', supported: true, category: '1D Numerik' },
  { label: 'EAN_8', value: 'EAN_8', supported: true, category: '1D Numerik' },
  { label: 'UPC_A', value: 'UPC_A', supported: true, category: '1D Numerik' },
  { label: 'UPC_E', value: 'UPC_E', supported: true, category: '1D Numerik' },
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
  RSS_14: 'databaromni',
  RSS_EXPANDED: 'databarexpanded'
}

/**
 * Menghasilkan digit angka deterministik dan unik dari sebuah string (tracking number)
 * Menggunakan algoritma hash FNV-1a 32-bit standar yang 100% identik dengan implementasi Perl backend.
 */
export function stringToDeterministicDigits(str, targetLength) {
  const cleanStr = (str || '').trim().toUpperCase()
  let h = 2166136261 >>> 0
  for (let i = 0; i < cleanStr.length; i++) {
    h = Math.imul(h ^ cleanStr.charCodeAt(i), 16777619) >>> 0
  }
  let digits = String(h)
  let h2 = h
  while (digits.length < targetLength) {
    h2 = Math.imul(h2 ^ 0x12345678, 16777619) >>> 0
    digits += String(h2)
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
  if (!raw) return ''
  let s = String(raw).trim()
  // 1. Hapus karakter kontrol tak terlihat (FNC1, GS ASCII 29, RS ASCII 30, dsb)
  s = s.replace(/[\x00-\x1F\x7F-\x9F]/g, '').trim().toUpperCase()
  // 2. Hapus AIM Symbology Identifier jika dikirim scanner (misal ]e0, ]C1, ]A0, ]G0)
  s = s.replace(/^\][A-Z0-9]{2}/i, '').trim()
  // Tolak noise / artefak terlalu pendek
  if (s.length < 3) return ''

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

  let fmt = ''
  if (typeof format === 'string') {
    fmt = format.toUpperCase()
  } else if (typeof format === 'number') {
    const FORMAT_ENUM_MAP = {
      0: 'AZTEC', 1: 'CODABAR', 2: 'CODE_39', 3: 'CODE_93', 4: 'CODE_128',
      5: 'DATA_MATRIX', 6: 'EAN_8', 7: 'EAN_13', 8: 'ITF', 9: 'MAXICODE', 10: 'PDF_417',
      11: 'QR_CODE', 12: 'RSS_14', 13: 'RSS_EXPANDED', 14: 'UPC_A', 15: 'UPC_E', 18: 'CODABAR', 29: 'RSS_14'
    }
    fmt = FORMAT_ENUM_MAP[format] || ''
  } else if (format && typeof format === 'object') {
    fmt = String(format.formatName || format.name || '').toUpperCase()
  }

  // 2. RSS_EXPANDED: Parsing format GS1 DataBar Expanded (01)GTIN-14(10)TrackingNo
  if (fmt === 'RSS_EXPANDED' || /\(01\).+\(10\)/i.test(s) || /^01\d{14}10/i.test(s) || s.includes('(10)')) {
    const mGs1 = s.match(/^(?:\(01\)|01)\s*\d{14}\s*(?:\(10\)|10)\s*([A-Z0-9]+)$/i)
    if (mGs1 && mGs1[1]) {
      const extracted = mGs1[1].toUpperCase()
      return checkLocalStorage(extracted) || checkLocalStorage(s) || extracted
    }
    const m10Paren = s.match(/\(10\)\s*([A-Z0-9]+)$/i)
    if (m10Paren && m10Paren[1]) {
      const extracted = m10Paren[1].toUpperCase()
      return checkLocalStorage(extracted) || checkLocalStorage(s) || extracted
    }
  }

  // 3. RSS_14: Parsing format GS1 DataBar Omni (01)GTIN-14 (14 digit angka murni)
  if (fmt === 'RSS_14' || /^(?:\(01\)|01)\d{14}$/i.test(s)) {
    const m01 = s.match(/^(?:\(01\)|01)?(\d{14})$/i)
    if (m01 && m01[1]) {
      const gtin = m01[1]
      return (
        checkLocalStorage(gtin) ||
        checkLocalStorage(`(01)${gtin}`) ||
        checkLocalStorage(`01${gtin}`) ||
        gtin
      )
    }
  }

  // 4. MAXICODE: Ekstrak tracking number jika scanner mendukung
  if (fmt === 'MAXICODE' || s.includes('[C3') || s.includes('ANSI ') || s.includes('[)>')) {
    const m10 = s.match(/\(10\)\s*([A-Z0-9]+)/i)
    if (m10 && m10[1]) {
      const extracted = m10[1].toUpperCase()
      return checkLocalStorage(extracted) || checkLocalStorage(`(10)${extracted}`) || extracted
    }
    const mMaxi = s.match(/([A-Z0-9]{6,32})/i)
    if (mMaxi && mMaxi[1]) {
      const extracted = mMaxi[1].toUpperCase()
      return checkLocalStorage(extracted) || extracted
    }
  }

  // 5. CODABAR: Hapus start/stop A, B, C, D wrapping
  // CATATAN: Codabar resi logistik valid minimal 6 karakter.
  // Garis scan parsial sependek 1-2 digit (misal A1B -> '1' atau A-B -> '-') harus ditolak (return '')
  if (fmt === 'CODABAR' || /^[ABCD][0-9\-\$\:\/\.\+]+[ABCD]$/i.test(s)) {
    const mCoda = s.match(/^[ABCD]([0-9\-\$\:\/\.\+]+)[ABCD]$/i)
    if (mCoda && mCoda[1]) {
      const inner = mCoda[1]
      if (inner.length < 6) return '' // Tolak glitch parsial 1 digit
      return checkLocalStorage(inner) || checkLocalStorage(s) || inner
    }
    const digitsOnly = s.replace(/\D/g, '')
    if (digitsOnly && digitsOnly.length >= 6) {
      return checkLocalStorage(digitsOnly) || checkLocalStorage(`A${digitsOnly}B`) || digitsOnly
    }
    return ''
  }

  // 6. CODE_93: Hapus non-alfanumerik, tetap kapital
  if (fmt === 'CODE_93') {
    const clean93 = s.replace(/[^A-Z0-9]/g, '')
    if (clean93 && clean93.length >= 4) {
      return checkLocalStorage(clean93) || clean93
    }
  }

  // 7. CODE_39: Hapus bintang wrapping dan karakter non-Code39
  if (fmt === 'CODE_39' || /^\*[^*]+\*$/.test(s)) {
    const unstar = s.replace(/^\*|\*$/g, '')
    const clean39 = unstar.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '').trim()
    if (clean39 && clean39.length >= 4) {
      return checkLocalStorage(clean39) || checkLocalStorage(unstar) || clean39
    }
  }

  // 8. UPC-E: Ekspansi ke UPC-A dengan check digit
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

  // 9. UPC_A: Tambahkan check digit atau tetap
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

  // 10. EAN_13: Tambahkan / check digit
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

  // 11. EAN_8: Tambahkan / check digit
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

  // 12. ITF: Angka genap 4-16 digit (kecuali jika dikenali sebagai format lain)
  if (fmt === 'ITF' || (fmt !== 'RSS_14' && /^\d{4,16}$/.test(s) && s.length % 2 === 0)) {
    const digits = s.replace(/\D/g, '')
    if (digits.length >= 4 && digits.length <= 16) {
      return checkLocalStorage(digits) || digits
    }
  }

  // Generic GS1 AI (01) 14 digit GTIN: (01)XXXXX
  const m01Gen = s.match(/^(?:\(01\)|01)\s*(\d{14})/i)
  if (m01Gen && m01Gen[1]) {
    const gtin = m01Gen[1]
    return checkLocalStorage(gtin) || gtin
  }

  // Generic Codabar start/stop A, B, C, D wrapping
  const mCodaGen = s.match(/^[ABCD]([0-9\-\$\:\/\.\+]{6,})[ABCD]$/i)
  if (mCodaGen && mCodaGen[1]) {
    return checkLocalStorage(mCodaGen[1]) || mCodaGen[1]
  }

  // Tolak teks artefak pendek (misal '-' atau '1')
  if (s.length < 4) return ''

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
  let checkDigits = null

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
      barcodeValue = cleanTracking.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '') || cleanTracking
      break

    case 'CODE_93': {
      barcodeValue = cleanTracking.replace(/[^A-Z0-9\-\.\ \$\/\+\%]/g, '') || cleanTracking
      checkDigits = calculateCode93CheckDigits(barcodeValue)
      break
    }

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

    case 'RSS_EXPANDED': {
      if (/^\(01\)\d{14}/.test(cleanTracking)) {
        isMapped = false
        barcodeValue = cleanTracking
      } else {
        isMapped = true
        // Generate GTIN-14 unik & deterministik dari cleanTracking (BUG-005)
        // 1 digit prefix '1' + 12 digit hash unik + 1 digit mod10 check digit
        const d13 = '1' + stringToDeterministicDigits(cleanTracking, 12)
        const cd = calculateMod10CheckDigit(d13)
        const uniqueGtin = d13 + cd
        const cleanAlpha = cleanTracking.replace(/[^A-Za-z0-9]/g, '').slice(0, 16) || 'WAHANA'
        barcodeValue = `(01)${uniqueGtin}(10)${cleanAlpha}`
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
        svgEl.style.maxWidth = options.maxWidth || `${size}px`
        svgEl.style.maxHeight = options.maxHeight || `${size}px`
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (is2DMatrix) {
        const size = String(options.qrSize || 120)
        svgEl.setAttribute('width', size)
        svgEl.setAttribute('height', size)
        svgEl.style.maxWidth = options.maxWidth || `${size}px`
        svgEl.style.maxHeight = options.maxHeight || `${size}px`
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (isStacked) {
        const w = options.width ? String(options.width) : '240'
        svgEl.setAttribute('width', w)
        svgEl.style.maxWidth = options.maxWidth || `${w}px`
        svgEl.style.maxHeight = options.maxHeight || '80px'
        svgEl.style.width = 'auto'
        svgEl.style.height = 'auto'
      } else if (format === 'RSS_EXPANDED') {
        svgEl.removeAttribute('width')
        svgEl.removeAttribute('height')
        svgEl.style.maxWidth = options.maxWidth || '320px'
        svgEl.style.maxHeight = options.maxHeight || '95px'
        svgEl.style.width = '100%'
        svgEl.style.height = 'auto'
      } else {
        svgEl.removeAttribute('width')
        svgEl.removeAttribute('height')
        svgEl.style.maxWidth = options.maxWidth || '280px'
        svgEl.style.maxHeight = options.maxHeight || '85px'
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
