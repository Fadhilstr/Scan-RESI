import { defineStore } from 'pinia'
import { useTaskStore } from './taskStore'

export const useScanStore = defineStore('scan', {
  state: () => ({
    // Scan Events List (Requirement C, V, AC)
    scanEvents: [
      // Fadhil (USR-001, TASK-001)
      {
        scan_id: 'SCN-00001',
        nomor_resi: 'GJXL8FLB',
        user_id: 'USR-001',
        user_name: 'Fadhil',
        task_id: 'TASK-001',
        waktu_scan: '24-08-2026 10:21:32',
        lokasi: 'CIPUTAT',
        status_scan: 'SUCCESS',
        device_id: 'SCAN-DEVICE-01',
        jenis_scan: 'INBOUND'
      },
      {
        scan_id: 'SCN-00002',
        nomor_resi: 'AB123456',
        user_id: 'USR-001',
        user_name: 'Fadhil',
        task_id: 'TASK-001',
        waktu_scan: '24-08-2026 10:22:10',
        lokasi: 'CIPUTAT',
        status_scan: 'SUCCESS',
        device_id: 'SCAN-DEVICE-01',
        jenis_scan: 'INBOUND'
      },
      {
        scan_id: 'SCN-00003',
        nomor_resi: 'WHN555555',
        user_id: 'USR-001',
        user_name: 'Fadhil',
        task_id: 'TASK-001',
        waktu_scan: '24-08-2026 10:23:45',
        lokasi: 'CIPUTAT',
        status_scan: 'SUCCESS',
        device_id: 'SCAN-DEVICE-01',
        jenis_scan: 'INBOUND'
      },

      // Budi (USR-002, TASK-002)
      {
        scan_id: 'SCN-00004',
        nomor_resi: 'XYZ123456',
        user_id: 'USR-002',
        user_name: 'Budi',
        task_id: 'TASK-002',
        waktu_scan: '24-08-2026 10:22:10',
        lokasi: 'CIPUTAT',
        status_scan: 'SUCCESS',
        device_id: 'SCAN-DEVICE-02',
        jenis_scan: 'INBOUND'
      },
      {
        scan_id: 'SCN-00005',
        nomor_resi: 'WHN777777',
        user_id: 'USR-002',
        user_name: 'Budi',
        task_id: 'TASK-002',
        waktu_scan: '24-08-2026 10:24:12',
        lokasi: 'CIPUTAT',
        status_scan: 'SUCCESS',
        device_id: 'SCAN-DEVICE-02',
        jenis_scan: 'INBOUND'
      },

      // Andi (USR-003, TASK-003)
      {
        scan_id: 'SCN-00006',
        nomor_resi: 'ABC111111',
        user_id: 'USR-003',
        user_name: 'Andi',
        task_id: 'TASK-003',
        waktu_scan: '24-08-2026 10:15:00',
        lokasi: 'CIPUTAT',
        status_scan: 'SUCCESS',
        device_id: 'SCAN-DEVICE-03',
        jenis_scan: 'INBOUND'
      },
      {
        scan_id: 'SCN-00007',
        nomor_resi: 'ABC222222',
        user_id: 'USR-003',
        user_name: 'Andi',
        task_id: 'TASK-003',
        waktu_scan: '24-08-2026 10:18:30',
        lokasi: 'CIPUTAT',
        status_scan: 'SUCCESS',
        device_id: 'SCAN-DEVICE-03',
        jenis_scan: 'INBOUND'
      }
    ]
  }),

  getters: {
    // Role & User Permission Filtering Logic (Requirement H & AH)
    getFilteredScans: (state) => (currentUser, supervisedUserIds = []) => {
      if (!currentUser) return []

      if (currentUser.role === 'ADMIN') {
        return state.scanEvents
      }

      if (currentUser.role === 'SUPERVISOR') {
        return state.scanEvents.filter((scan) => supervisedUserIds.includes(scan.user_id))
      }

      if (currentUser.role === 'PETUGAS_SCAN') {
        return state.scanEvents.filter((scan) => scan.user_id === currentUser.id)
      }

      return []
    },

    // Stats for specific user
    getUserScanStats: (state) => (userId) => {
      const userScans = state.scanEvents.filter((s) => s.user_id === userId)
      const successScans = userScans.filter((s) => s.status_scan === 'SUCCESS')
      const duplicateScans = userScans.filter((s) => s.status_scan === 'DUPLICATE')
      
      const lastScan = userScans.length > 0 ? userScans[0].waktu_scan : '-'

      return {
        total: successScans.length,
        success: successScans.length,
        duplicate: duplicateScans.length,
        lastScan
      }
    }
  },

  actions: {
    addScanEvent({ resi, currentUser, activeTask, lokasi = 'CIPUTAT', device_id = 'SCAN-DEVICE-01', jenis_scan = 'INBOUND' }) {
      const sanitizedResi = (resi || '').trim()

      // Error 1: Barcode kosong
      if (!sanitizedResi) {
        return { success: false, reason: 'EMPTY', message: 'Nomor resi tidak boleh kosong.' }
      }

      // Error 2: Task status bukan PROSES_SCAN
      if (!activeTask || activeTask.status === 'SELESAI') {
        return { success: false, reason: 'FINISHED', message: 'Task sudah selesai dan tidak dapat melakukan scan.' }
      }

      const now = new Date()
      const dateStr = `${String(now.getDate()).padStart(2, '0')}-${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()}`
      const timeStr = `${dateStr} ${now.toTimeString().split(' ')[0]}`

      // Error 3: Duplicate Validation (Requirement W & TEST 6)
      const isDuplicate = this.scanEvents.some(
        (evt) =>
          evt.task_id === activeTask.task_id &&
          evt.nomor_resi.toUpperCase() === sanitizedResi.toUpperCase() &&
          evt.status_scan === 'SUCCESS'
      )

      if (isDuplicate) {
        // Record DUPLICATE scan event
        const duplicateEvent = {
          scan_id: `SCN-${String(this.scanEvents.length + 1).padStart(5, '0')}`,
          nomor_resi: sanitizedResi,
          user_id: currentUser.id,
          user_name: currentUser.name,
          task_id: activeTask.task_id,
          waktu_scan: timeStr,
          lokasi,
          status_scan: 'DUPLICATE',
          device_id,
          jenis_scan
        }
        this.scanEvents.unshift(duplicateEvent)

        return {
          success: false,
          reason: 'DUPLICATE',
          message: `Nomor resi ${sanitizedResi} sudah pernah discan.`
        }
      }

      // Record SUCCESS scan event
      const successEvent = {
        scan_id: `SCN-${String(this.scanEvents.length + 1).padStart(5, '0')}`,
        nomor_resi: sanitizedResi,
        user_id: currentUser.id,
        user_name: currentUser.name,
        task_id: activeTask.task_id,
        waktu_scan: timeStr,
        lokasi,
        status_scan: 'SUCCESS',
        device_id,
        jenis_scan
      }

      this.scanEvents.unshift(successEvent)

      // Increment task progress
      const taskStore = useTaskStore()
      taskStore.incrementTaskProgress(activeTask.task_id)

      return {
        success: true,
        resi: sanitizedResi,
        message: `Nomor resi ${sanitizedResi} berhasil discan.`
      }
    }
  }
})
