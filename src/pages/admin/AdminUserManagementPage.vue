<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <h4 class="text-h4 text-weight-bolder text-wahana-navy q-my-none">User Management</h4>
        <div class="text-subtitle2 text-grey-7">Kelola akun, role, dan hak akses pengguna sistem</div>
      </div>

      <q-btn
        color="primary"
        icon="person_add"
        label="TAMBAH USER BARU"
        unelevated
        class="text-weight-bold"
        @click="openAddDialog"
      />
    </div>

    <q-separator class="q-mb-lg" />

    <!-- User Table (Requirement N) -->
    <q-card class="scan-card">
      <q-card-section>
        <q-table
          :rows="authStore.users"
          :columns="columns"
          row-key="id"
          flat
          bordered
          no-data-label="Belum ada data user"
        >
          <template v-slot:body-cell-id="props">
            <q-td :props="props" class="font-mono text-weight-bold text-primary">
              {{ props.row.id }}
            </q-td>
          </template>

          <template v-slot:body-cell-name="props">
            <q-td :props="props" class="text-weight-bold text-slate-900">
              {{ props.row.name }}
            </q-td>
          </template>

          <template v-slot:body-cell-username="props">
            <q-td :props="props" class="font-mono text-grey-8">
              {{ props.row.username }}
            </q-td>
          </template>

          <template v-slot:body-cell-role="props">
            <q-td :props="props">
              <q-badge
                :color="props.row.role === 'ADMIN' ? 'red-9' : props.row.role === 'SUPERVISOR' ? 'indigo-9' : 'amber-9'"
                text-color="white"
                class="font-mono text-weight-bold"
              >
                {{ props.row.role }}
              </q-badge>
            </q-td>
          </template>

          <template v-slot:body-cell-status="props">
            <q-td :props="props" class="text-center">
              <StatusBadge :status="props.row.status" size="xs" />
            </q-td>
          </template>

          <template v-slot:body-cell-lastLogin="props">
            <q-td :props="props" class="font-mono text-caption text-grey-7">
              {{ props.row.lastLogin }}
            </q-td>
          </template>

          <template v-slot:body-cell-aksi="props">
            <q-td :props="props" class="text-center">
              <q-btn
                color="warning"
                icon="block"
                flat
                round
                dense
                @click="toggleDisable(props.row)"
              >
                <q-tooltip>{{ props.row.status === 'DISABLED' ? 'Enable User' : 'Disable User' }}</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- Add User Modal Dialog -->
    <q-dialog v-model="showAddDialog">
      <q-card style="min-width: 360px; border-radius: 16px;">
        <q-card-section class="row items-center justify-between q-pb-xs">
          <div class="text-h6 text-weight-bold row items-center">
            <q-icon name="person_add" color="primary" class="q-mr-xs" />
            Tambah User Baru
          </div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-pt-md">
          <q-form @submit.prevent="saveNewUser" class="q-gutter-y-md">
            <q-input v-model="form.name" outlined dense label="Nama Lengkap" required />
            <q-input v-model="form.username" outlined dense label="Username" required />
            <q-input v-model="form.password" outlined dense type="password" label="Password" required />
            <q-select
              v-model="form.role"
              :options="['ADMIN', 'SUPERVISOR', 'PETUGAS_SCAN']"
              outlined
              dense
              label="Role"
            />
            <q-card-actions align="right" class="q-px-none">
              <q-btn flat label="BATAL" color="grey-7" v-close-popup class="text-weight-bold" />
              <q-btn type="submit" label="SIMPAN USER" color="primary" class="text-weight-bold" unelevated />
            </q-card-actions>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref } from 'vue'
import { useQuasar } from 'quasar'
import { useAuthStore } from '../../stores/authStore'
import StatusBadge from '../../components/StatusBadge.vue'

const $q = useQuasar()
const authStore = useAuthStore()

const showAddDialog = ref(false)
const form = ref({
  name: '',
  username: '',
  password: '',
  role: 'PETUGAS_SCAN'
})

const columns = [
  { name: 'id', label: 'User ID', field: 'id', align: 'left', sortable: true },
  { name: 'name', label: 'Nama', field: 'name', align: 'left', sortable: true },
  { name: 'username', label: 'Username', field: 'username', align: 'left', sortable: true },
  { name: 'role', label: 'Role', field: 'role', align: 'center', sortable: true },
  { name: 'status', label: 'Status', field: 'status', align: 'center', sortable: true },
  { name: 'lastLogin', label: 'Last Login', field: 'lastLogin', align: 'center' },
  { name: 'aksi', label: 'Aksi', field: 'aksi', align: 'center' }
]

const openAddDialog = () => {
  form.value = { name: '', username: '', password: '', role: 'PETUGAS_SCAN' }
  showAddDialog.value = true
}

const saveNewUser = async () => {
  const res = await authStore.addUser(form.value)
  if (res.success) {
    $q.notify({
      type: 'positive',
      icon: 'check_circle',
      message: `User ${res.user.name} berhasil ditambahkan.`,
      position: 'top',
      timeout: 2000
    })
    showAddDialog.value = false
  } else {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: res.message || 'Gagal menambahkan user.',
      position: 'top',
      timeout: 2500
    })
  }
}

const toggleDisable = async (user) => {
  const res = await authStore.toggleUserStatus(user.id)
  if (res.success) {
    $q.notify({
      type: 'info',
      icon: 'sync',
      message: `Status user ${user.name} diubah menjadi ${res.newStatus}.`,
      position: 'top',
      timeout: 1800
    })
  } else {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: res.message || 'Gagal mengubah status user.',
      position: 'top',
      timeout: 2500
    })
  }
}
</script>
