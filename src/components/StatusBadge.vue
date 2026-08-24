<template>
  <q-chip
    :color="badgeColor"
    :text-color="textColor"
    :size="size"
    class="text-weight-bold shadow-1"
  >
    <q-icon :name="badgeIcon" class="q-mr-xs" />
    {{ formattedStatus }}
  </q-chip>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  status: {
    type: String,
    required: true,
    default: 'PROSES_SCAN'
  },
  size: {
    type: String,
    default: 'md'
  }
})

const badgeColor = computed(() => {
  switch (props.status) {
    case 'PROSES_SCAN':
      return 'primary'
    case 'SELESAI':
      return 'positive'
    case 'DRAFT':
      return 'warning'
    case 'SUCCESS':
      return 'positive'
    case 'DUPLICATE':
      return 'warning'
    case 'ONLINE':
      return 'positive'
    case 'OFFLINE':
      return 'grey-6'
    case 'DISABLED':
      return 'negative'
    default:
      return 'grey-7'
  }
})

const textColor = computed(() => {
  if (props.status === 'DUPLICATE' || props.status === 'DRAFT') return 'dark'
  return 'white'
})

const badgeIcon = computed(() => {
  switch (props.status) {
    case 'PROSES_SCAN':
      return 'qr_code_scanner'
    case 'SELESAI':
      return 'check_circle'
    case 'DRAFT':
      return 'edit_note'
    case 'SUCCESS':
      return 'task_alt'
    case 'DUPLICATE':
      return 'warning'
    case 'ONLINE':
      return 'sensors'
    case 'OFFLINE':
      return 'sensors_off'
    case 'DISABLED':
      return 'block'
    default:
      return 'help_outline'
  }
})

const formattedStatus = computed(() => {
  switch (props.status) {
    case 'PROSES_SCAN':
      return 'PROSES SCAN'
    case 'SELESAI':
      return 'SELESAI'
    case 'DRAFT':
      return 'DRAFT'
    case 'SUCCESS':
      return 'SUCCESS'
    case 'DUPLICATE':
      return 'DUPLICATE'
    case 'ONLINE':
      return 'ONLINE'
    case 'OFFLINE':
      return 'OFFLINE'
    case 'DISABLED':
      return 'DISABLED'
    default:
      return props.status
  }
})
</script>
