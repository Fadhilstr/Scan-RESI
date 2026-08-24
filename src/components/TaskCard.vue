<template>
  <q-card class="scan-card q-pa-sm">
    <q-card-section>
      <div class="row items-center justify-between q-mb-xs">
        <div class="row items-center">
          <q-badge color="wahana-navy" text-color="amber-4" class="font-mono text-weight-bolder text-subtitle2 q-mr-sm">
            {{ task.task_id }}
          </q-badge>
          <span class="text-subtitle1 text-weight-bold text-slate-900">{{ task.user_name }}</span>
        </div>
        <StatusBadge :status="task.status" size="sm" />
      </div>

      <div class="row items-center text-caption text-grey-7 q-mb-md">
        <q-icon name="schedule" size="14px" class="q-mr-xs" /> Shift {{ task.shift }} • {{ task.tanggal }} • {{ task.lokasi }}
      </div>

      <!-- Progress Section -->
      <div class="q-mb-xs">
        <div class="row items-center justify-between text-caption text-weight-bold q-mb-xs">
          <span class="text-grey-7">PROGRESS SCAN</span>
          <span class="font-mono text-primary">{{ task.progress }} / {{ task.target }}</span>
        </div>
        <q-linear-progress
          :value="progressPercent"
          color="amber-6"
          track-color="amber-1"
          size="10px"
          class="rounded-borders"
        />
      </div>

      <div class="row items-center justify-between text-caption text-grey-6 q-mt-xs">
        <span>Capaian: {{ Math.round(progressPercent * 100) }}%</span>
        <span v-if="task.status === 'SELESAI'" class="text-positive text-weight-bold row items-center">
          <q-icon name="check_circle" size="12px" class="q-mr-xs" /> Terkunci
        </span>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup>
import { computed } from 'vue'
import StatusBadge from './StatusBadge.vue'

const props = defineProps({
  task: {
    type: Object,
    required: true
  }
})

const progressPercent = computed(() => {
  if (!props.task.target || props.task.target === 0) return 0
  return Math.min(props.task.progress / props.task.target, 1)
})
</script>
