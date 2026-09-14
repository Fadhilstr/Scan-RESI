/**
 * tests/test_rss_expanded_patch.js
 * Automated test suite for GS1 DataBar Expanded (RSS Expanded) ZXing patch
 * and Customer Buat Paket barcode format dropdown filtering.
 */

import assert from 'node:assert/strict'
import bwipjs from 'bwip-js'
import { PNG } from 'pngjs'
import {
  RGBLuminanceSource,
  BinaryBitmap,
  HybridBinarizer,
  RSSExpandedReader
} from '@zxing/library'

import { applyZxingRssExpandedPatch } from '../src/utils/zxingRssExpandedPatcher.js'
import {
  BARCODE_FORMAT_OPTIONS,
  resolveBarcodePayload,
  normalizeScannedBarcode
} from '../src/utils/barcodeGenerator.js'

async function runTests() {
  console.log('===============================================================')
  console.log('TEST SUITE: GS1 DATABAR EXPANDED (RSS EXPANDED) PATCH & MAXICODE')
  console.log('===============================================================\n')

  // Test 1: Verify MAXICODE & UPC_EAN_EXTENSION removal from BARCODE_FORMAT_OPTIONS
  console.log('TEST 1: Verifikasi MAXICODE & UPC_EAN_EXTENSION telah dihapus dari generator...')
  const maxiOpt = BARCODE_FORMAT_OPTIONS.find((opt) => opt.value === 'MAXICODE')
  const upcExtOpt = BARCODE_FORMAT_OPTIONS.find((opt) => opt.value === 'UPC_EAN_EXTENSION')
  assert.strictEqual(maxiOpt, undefined, 'MAXICODE tidak boleh terdaftar di BARCODE_FORMAT_OPTIONS!')
  assert.strictEqual(upcExtOpt, undefined, 'UPC_EAN_EXTENSION tidak boleh terdaftar di BARCODE_FORMAT_OPTIONS!')
  console.log('  -> PASS: MAXICODE & UPC_EAN_EXTENSION berhasil dihapus dari master generator.\n')

  // Test 2: Verify Customer Buat Paket dropdown options (15 active formats)
  console.log('TEST 2: Verifikasi 15 format aktif pada dropdown customer (tanpa MAXICODE & UPC_EAN_EXTENSION)...')
  const customerFormatOptions = BARCODE_FORMAT_OPTIONS
  assert.strictEqual(customerFormatOptions.length, 15, 'Total format barcode customer harus tepat 15 format.')
  assert.ok(customerFormatOptions.some((opt) => opt.value === 'RSS_14'), 'RSS_14 harus tersedia.')
  assert.ok(customerFormatOptions.some((opt) => opt.value === 'RSS_EXPANDED'), 'RSS_EXPANDED harus tersedia.')
  console.log(`  -> PASS: Total ${customerFormatOptions.length} format untuk customer (RSS_14 & RSS_EXPANDED aktif).\n`)

  // Test 3: Apply ZXing RSS Expanded Patch
  console.log('TEST 3: Menerapkan patch runtime ZXing RSS Expanded...')
  const patchResult = applyZxingRssExpandedPatch()
  assert.strictEqual(patchResult, true, 'Patch harus berhasil diterapkan.')
  // Verifikasi idempotensi (panggilan kedua tetap true)
  const patchIdempotent = applyZxingRssExpandedPatch()
  assert.strictEqual(patchIdempotent, true, 'Panggilan berulang harus idempotent.')
  console.log('  -> PASS: Patch berhasil diterapkan & idempotent.\n')

  // Test 4: End-to-end decoding test with synthetic barcodes
  console.log('TEST 4: Pengujian decode citra bilah RSS Expanded sintetis via ZXing...')
  const testCases = [
    'WAH12345678',
    'DIJAK987654321',
    'PKG88291029',
    'ABC98765432'
  ]

  for (const testResi of testCases) {
    const payload = resolveBarcodePayload(testResi, 'RSS_EXPANDED')
    assert.ok(payload.barcode_value, `Payload untuk ${testResi} harus terdefinisi.`)
    assert.match(payload.barcode_value, /^\(01\)\d{14}\(10\)/, 'Format payload harus GS1 (01)GTIN(10)Resi')

    const buf = await bwipjs.toBuffer({
      bcid: 'databarexpanded',
      text: payload.barcode_value,
      scale: 3,
      height: 15,
      paddingwidth: 15,
      paddingheight: 10,
      backgroundcolor: 'ffffff'
    })

    const png = PNG.sync.read(buf)
    const gray = new Uint8ClampedArray(png.width * png.height)
    for (let i = 0; i < png.width * png.height; i++) {
      const r = png.data[i * 4]
      const g = png.data[i * 4 + 1]
      const b = png.data[i * 4 + 2]
      gray[i] = (r * 306 + g * 601 + b * 117) >> 10
    }

    const lumSource = new RGBLuminanceSource(gray, png.width, png.height)
    const bitmap = new BinaryBitmap(new HybridBinarizer(lumSource))

    const reader = new RSSExpandedReader()
    const decodedResult = reader.decode(bitmap)
    const decodedText = decodedResult.getText()

    assert.ok(decodedText, `Decoded text untuk ${testResi} tidak boleh kosong.`)
    assert.strictEqual(decodedText, payload.barcode_value, 'Teks decode harus sama dengan payload.')

    const normalized = normalizeScannedBarcode(decodedText, 'RSS_EXPANDED')
    assert.strictEqual(normalized, testResi, `Nomor resi hasil normalisasi harus kembali ke ${testResi}`)

    console.log(`  -> [PASS] Input: ${testResi} | GS1: ${decodedText} | Normalized: ${normalized}`)
  }

  console.log('\n===============================================================')
  console.log('SEMUA PENGUJIAN RSS EXPANDED & CUSTOMER DROPDOWN BERHASIL (PASS)')
  console.log('===============================================================')
}

runTests().catch((err) => {
  console.error('\n❌ TEST FAILED:', err)
  process.exit(1)
})
