<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">Task Tim Saya</h4>
        <div class="text-subtitle2 text-grey-7">Daftar tugas/batch anggota petugas dalam tanggung jawab</div>
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <div class="row q-col-gutter-md">
      <div v-for="t in teamTasks" :key="t.task_id" class="col-12 col-sm-6 col-md-4">
        <TaskCard :task="t" />
      </div>
    </div>
  </q-page>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '../../stores/authStore'
import { useTaskStore } from '../../stores/taskStore'
import TaskCard from '../../components/TaskCard.vue'

const authStore = useAuthStore()
const taskStore = useTaskStore()

const teamTasks = computed(() => {
  if (!authStore.currentUser) return []
  const teamIds = authStore.supervisedPetugas(authStore.currentUser.id).map((p) => p.id)
  return taskStore.getTasksForSupervisor(teamIds)
})
</script>
