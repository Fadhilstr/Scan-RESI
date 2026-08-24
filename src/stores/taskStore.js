import { defineStore } from 'pinia'

export const useTaskStore = defineStore('task', {
  state: () => ({
    // Dummy Task/Batch records (Requirement R & AB)
    tasks: [
      {
        task_id: 'TASK-001',
        user_id: 'USR-001',
        user_name: 'Fadhil',
        shift: 'Pagi',
        tanggal: '24-08-2026',
        target: 100,
        progress: 3,
        status: 'PROSES_SCAN', // DRAFT | PROSES_SCAN | SELESAI
        lokasi: 'CIPUTAT'
      },
      {
        task_id: 'TASK-002',
        user_id: 'USR-002',
        user_name: 'Budi',
        shift: 'Pagi',
        tanggal: '24-08-2026',
        target: 80,
        progress: 2,
        status: 'PROSES_SCAN',
        lokasi: 'CIPUTAT'
      },
      {
        task_id: 'TASK-003',
        user_id: 'USR-003',
        user_name: 'Andi',
        shift: 'Pagi',
        tanggal: '24-08-2026',
        target: 120,
        progress: 2,
        status: 'PROSES_SCAN',
        lokasi: 'CIPUTAT'
      }
    ]
  }),

  getters: {
    allTasks: (state) => state.tasks,
    
    // Get active task for a specific petugas user_id
    getActiveTaskForUser: (state) => (userId) => {
      return state.tasks.find(
        (t) => t.user_id === userId && t.status === 'PROSES_SCAN'
      ) || state.tasks.find((t) => t.user_id === userId) || null
    },

    // Get tasks assigned to supervised team members
    getTasksForSupervisor: (state) => (supervisedUserIds) => {
      return state.tasks.filter((t) => supervisedUserIds.includes(t.user_id))
    }
  },

  actions: {
    incrementTaskProgress(taskId) {
      const task = this.tasks.find((t) => t.task_id === taskId)
      if (task) {
        task.progress += 1
      }
    },

    completeTask(taskId) {
      const task = this.tasks.find((t) => t.task_id === taskId)
      if (task) {
        task.status = 'SELESAI'
        return { success: true, message: `Task ${taskId} berhasil diselesaikan.` }
      }
      return { success: false, message: 'Task tidak ditemukan.' }
    },

    createNewTask(newTaskData) {
      const newId = `TASK-${String(this.tasks.length + 1).padStart(3, '0')}`
      const taskObj = {
        task_id: newId,
        user_id: newTaskData.user_id,
        user_name: newTaskData.user_name,
        shift: newTaskData.shift || 'Pagi',
        tanggal: newTaskData.tanggal || '24-08-2026',
        target: Number(newTaskData.target) || 100,
        progress: 0,
        status: 'PROSES_SCAN',
        lokasi: newTaskData.lokasi || 'CIPUTAT'
      }
      this.tasks.unshift(taskObj)
      return { success: true, task: taskObj }
    }
  }
})
