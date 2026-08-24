import { defineStore } from 'pinia'

export const useScanStore = defineStore('scan', {
  state: () => ({
    // Status Flow: DRAFT -> PROSES_SCAN -> SELESAI
    scanStatus: 'PROSES_SCAN',
    
    // Barcode input model
    barcodeInput: '',
    
    // Start time of current session
    scanStartTime: '10:20:00',
    
    // Initial dummy paket list based on requirement section 17
    paketList: [
      { id: 1, nomor_resi: 'GJXL8FLB', waktu_scan: '10:20:32', status: 'SCANNED' },
      { id: 2, nomor_resi: 'WHN123456', waktu_scan: '10:21:15', status: 'SCANNED' },
      { id: 3, nomor_resi: 'AB12345678', waktu_scan: '10:22:04', status: 'SCANNED' },
      { id: 4, nomor_resi: 'XYZ987654', waktu_scan: '10:23:41', status: 'SCANNED' },
      { id: 5, nomor_resi: '899123456789', waktu_scan: '10:24:50', status: 'SCANNED' }
    ],
    
    // Last scanned item
    lastScanned: {
      nomor_resi: '899123456789',
      waktu_scan: '10:24:50',
      status: 'SCANNED'
    },
    
    // Total stats for dashboard
    dashboardStats: {
      totalHariIni: 125,
      totalDiscan: 87,
      totalProses: 3,
      scannerStatus: 'Aktif / Ready'
    },
    
    // History list for Riwayat Page (Requirement section 18)
    historyList: [
      {
        id: 'HIST-20260824-01',
        tanggal: '24-08-2026',
        total_paket: 15,
        status: 'SELESAI',
        scan_start: '09:00:15',
        scan_end: '10:15:20'
      },
      {
        id: 'HIST-20260823-01',
        tanggal: '23-08-2026',
        total_paket: 21,
        status: 'SELESAI',
        scan_start: '08:30:00',
        scan_end: '11:10:45'
      },
      {
        id: 'HIST-20260822-01',
        tanggal: '22-08-2026',
        total_paket: 18,
        status: 'SELESAI',
        scan_start: '13:15:00',
        scan_end: '15:40:10'
      }
    ]
  }),

  getters: {
    totalPaket: (state) => state.paketList.length,
    isScanActive: (state) => state.scanStatus === 'PROSES_SCAN',
    isFinished: (state) => state.scanStatus === 'SELESAI'
  },

  actions: {
    startScanSession() {
      if (this.scanStatus === 'DRAFT' || this.scanStatus === 'SELESAI') {
        this.scanStatus = 'PROSES_SCAN'
        const now = new Date()
        this.scanStartTime = now.toTimeString().split(' ')[0]
      }
    },

    addBarcode(rawInput) {
      const resi = (rawInput || '').trim()
      
      // Error Handling 1: Barcode Kosong
      if (!resi) {
        return {
          success: false,
          reason: 'EMPTY',
          message: 'Nomor resi tidak boleh kosong.'
        }
      }

      // Error Handling 2: Process Already Finished
      if (this.scanStatus === 'SELESAI') {
        return {
          success: false,
          reason: 'FINISHED',
          message: 'Proses scan telah selesai. Tidak dapat menambahkan paket baru.'
        }
      }

      // Error Handling 3: Duplikasi (Section 7)
      const exists = this.paketList.some(
        (item) => item.nomor_resi.toUpperCase() === resi.toUpperCase()
      )
      
      if (exists) {
        return {
          success: false,
          reason: 'DUPLICATE',
          message: `Nomor resi ${resi} sudah pernah discan.`
        }
      }

      // Add New Resi
      const now = new Date()
      const waktu = now.toTimeString().split(' ')[0]

      const newItem = {
        id: Date.now() + Math.random(),
        nomor_resi: resi,
        waktu_scan: waktu,
        status: 'SCANNED'
      }

      // Unshift to show newest item first
      this.paketList.unshift(newItem)
      
      this.lastScanned = {
        nomor_resi: resi,
        waktu_scan: waktu,
        status: 'SCANNED'
      }

      this.barcodeInput = ''

      return {
        success: true,
        resi: resi,
        message: `Nomor resi ${resi} berhasil discan.`
      }
    },

    removePaket(targetId) {
      const index = this.paketList.findIndex((item) => item.id === targetId)
      if (index !== -1) {
        const removed = this.paketList[index]
        this.paketList.splice(index, 1)

        // Update lastScanned if needed
        if (this.lastScanned && this.lastScanned.nomor_resi === removed.nomor_resi) {
          this.lastScanned = this.paketList.length > 0 ? this.paketList[0] : null
        }

        return {
          success: true,
          message: `Paket ${removed.nomor_resi} berhasil dihapus.`
        }
      }
      return { success: false, message: 'Paket tidak ditemukan.' }
    },

    finishScanSession() {
      this.scanStatus = 'SELESAI'
      const now = new Date()
      const todayStr = `${String(now.getDate()).padStart(2, '0')}-${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()}`
      
      // Save session to history
      const newHistoryRecord = {
        id: `HIST-${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}-${Date.now().toString().slice(-4)}`,
        tanggal: todayStr,
        total_paket: this.paketList.length,
        status: 'SELESAI',
        scan_start: this.scanStartTime,
        scan_end: now.toTimeString().split(' ')[0]
      }
      
      this.historyList.unshift(newHistoryRecord)
      
      return { success: true }
    },

    resetNewSession() {
      this.scanStatus = 'PROSES_SCAN'
      this.paketList = []
      this.lastScanned = null
      const now = new Date()
      this.scanStartTime = now.toTimeString().split(' ')[0]
      this.barcodeInput = ''
    }
  }
})
