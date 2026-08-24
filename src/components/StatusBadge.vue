<template>
  <q-chip
    :color="badgeColor"
    text-color="white"
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
    case 'SCANNED':
      return 'info'
    default:
      return 'grey-7'
  }
})

const badgeIcon = computed(() => {
  switch (props.status) {
    case 'PROSES_SCAN':
      return 'qr_code_scanner'
    case 'SELESAI':
      return 'check_circle'
    case 'DRAFT':
      return 'edit_note'
    case 'SCANNED':
      return 'inventory_2'
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
    case 'SCANNED':
      return 'SCANNED'
    default:
      return props.status
  }
})
</script>
