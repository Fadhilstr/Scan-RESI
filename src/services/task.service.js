/**
 * task.service.js — Service Layer Manajemen Task / Batch (Request Object Style)
 *
 * Menggunakan gaya pemanggilan:
 *   api({
 *     url: '/api/tasks',
 *     method: 'POST',
 *     data: { ... }
 *   })
 */
import api, { USE_LOCAL_DATA } from './api'
import { addAuditLog } from './audit.service'

export const LOCAL_TASKS = [
  {
    task_id: 'TASK-001',
    user_id: 'USR-001',
    user_name: 'Fadhil',
    shift: 'Pagi',
    tanggal: '28-08-2026',
    target: 100,
    progress: 3,
    status: 'PROSES_SCAN',
    lokasi: 'CIPUTAT'
  }
]

export async function getTasks(filters = {}) {
  if (USE_LOCAL_DATA) {
    let result = [...LOCAL_TASKS]
    if (filters.user_id) result = result.filter((t) => t.user_id === filters.user_id)
    if (filters.status) result = result.filter((t) => t.status === filters.status)
    return result
  }

  // --- API MODE (Object Style with url) ---
  const params = {}
  if (filters.user_id) params.user_id = filters.user_id
  if (filters.status) params.status = filters.status
  const data = await api({
    url: '/api/tasks',
    method: 'GET',
    params
  })
  return data.tasks || []
}

const todayString = () => {
  const now = new Date()
  const d = String(now.getDate()).padStart(2, '0')
  const m = String(now.getMonth() + 1).padStart(2, '0')
  return `${d}-${m}-${now.getFullYear()}`
}

export async function createTask(newTaskData) {
  if (USE_LOCAL_DATA) {
    const newId = `TASK-${String(LOCAL_TASKS.length + 1).padStart(3, '0')}`
    const taskObj = {
      task_id: newId,
      user_id: newTaskData.user_id,
      user_name: newTaskData.user_name,
      shift: newTaskData.shift || 'Pagi',
      tanggal: newTaskData.tanggal || todayString(),
      target: Number(newTaskData.target) || 100,
      progress: 0,
      status: 'PROSES_SCAN',
      lokasi: newTaskData.lokasi || 'CIPUTAT'
    }
    LOCAL_TASKS.unshift(taskObj)
    return { success: true, task: { ...taskObj } }
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: '/api/tasks',
    method: 'POST',
    data: newTaskData
  })
  return { success: true, task: data.task }
}

export async function incrementTaskProgress(taskId) {
  if (USE_LOCAL_DATA) {
    const task = LOCAL_TASKS.find((t) => t.task_id === taskId)
    if (task) task.progress += 1
    return { success: true }
  }

  // --- API MODE (Object Style with url) ---
  await api({
    url: `/api/tasks/${encodeURIComponent(taskId)}/progress`,
    method: 'PATCH'
  })
  return { success: true }
}

export async function completeTask(taskId) {
  if (USE_LOCAL_DATA) {
    const task = LOCAL_TASKS.find((t) => t.task_id === taskId)
    if (!task) return { success: false, message: 'Task tidak ditemukan.' }
    task.status = 'SELESAI'

    await addAuditLog({
      user_id: task.user_id,
      user_name: task.user_name,
      action: 'TASK_COMPLETED',
      details: `Task ${taskId} diselesaikan (${task.progress}/${task.target}).`
    })

    return { success: true, message: `Task ${taskId} berhasil diselesaikan.` }
  }

  // --- API MODE (Object Style with url) ---
  const data = await api({
    url: `/api/tasks/${encodeURIComponent(taskId)}/complete`,
    method: 'PATCH'
  })
  return { success: true, message: data.message }
}
