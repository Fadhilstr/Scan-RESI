<template>
  <div class="login-shell flex flex-center q-pa-md">
    <div class="row login-card shadow-6">
      <!-- Brand Panel (desktop only) -->
      <div class="col gt-sm bg-wahana-gradient text-white brand-panel">
        <div class="brand-inner column justify-between full-height">
          <div class="row items-center q-gutter-x-sm">
            <q-avatar size="38px" class="bg-wahana-yellow" style="border-radius: 10px;">
              <q-icon name="qr_code_scanner" size="22px" class="text-wahana-navy" />
            </q-avatar>
            <span class="text-subtitle1 text-weight-bold">Dijak Express</span>
          </div>

          <div>
            <div class="text-h4 text-weight-bold" style="letter-spacing: -0.02em; line-height: 1.25;">
              Platform pemindaian<br>barcode logistik
            </div>
            <p class="text-body2 text-blue-grey-3 q-mt-md" style="max-width: 320px;">
              Lacak pergerakan paket secara real-time, kelola task operasional, dan jaga akurasi data pengiriman dari satu aplikasi.
            </p>
          </div>

          <div class="text-caption text-blue-grey-4">
            &copy; 2026 Dijak Express &middot; Seluruh aktivitas terekam pada audit log
          </div>
        </div>
      </div>

      <!-- Form Panel -->
      <div class="col-12 col-sm bg-white form-panel">
        <div class="form-inner">
          <div class="lt-md text-center q-mb-lg">
            <q-avatar size="48px" class="bg-wahana-navy text-amber-4 q-mb-sm" style="border-radius: 12px;">
              <q-icon name="local_shipping" size="28px" />
            </q-avatar>
            <div class="text-h6 text-weight-bold">Dijak Express</div>
            <div class="text-caption text-grey-6">Logistics Barcode Scan Platform</div>
          </div>

          <div class="text-h6 text-weight-bold">Masuk ke akun Anda</div>
          <p class="text-body2 text-grey-6 q-mt-xs q-mb-lg">
            Gunakan username dan password yang diberikan operator.
          </p>

          <q-form @submit.prevent="handleLogin" class="column q-gutter-y-md">
            <q-input
              v-model="username"
              outlined
              label="Username"
              placeholder="cth: fadhil, admin, supervisor"
              autocomplete="username"
              autofocus
              :rules="[v => !!v || 'Username wajib diisi']"
            >
              <template v-slot:prepend><q-icon name="person" size="20px" class="text-grey-6" /></template>
            </q-input>

            <q-input
              v-model="password"
              outlined
              type="password"
              label="Password"
              placeholder="••••••••"
              autocomplete="current-password"
              :rules="[v => !!v || 'Password wajib diisi']"
            >
              <template v-slot:prepend><q-icon name="lock" size="20px" class="text-grey-6" /></template>
            </q-input>

            <q-btn
              type="submit"
              color="primary"
              size="lg"
              unelevated
              no-caps
              class="full-width"
              label="Masuk"
            />
          </q-form>

          <q-separator class="q-my-lg" />

          <div class="overline-label text-center q-mb-sm">Quick Login Demo</div>

          <div class="row q-col-gutter-sm">
            <div v-for="account in quickAccounts" :key="account.userId" class="col-6">
              <q-btn
                outline
                no-caps
                dense
                color="primary"
                :icon="account.icon"
                :label="account.label"
                align="left"
                class="full-width quick-btn"
                @click="quickLogin(account.userId)"
              />
            </div>
          </div>

          <div class="text-caption text-grey-5 text-center q-mt-lg">
            Prototype internal &middot; bukan untuk produksi
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar } from 'quasar'
import { useAuthStore } from '../stores/authStore'

const $q = useQuasar()
const router = useRouter()
const authStore = useAuthStore()

const username = ref('fadhil')
const password = ref('fadhil123')

const quickAccounts = [
  { userId: 'USR-ADMIN-001', label: 'Admin', icon: 'admin_panel_settings' },
  { userId: 'USR-SPV-001', label: 'Supervisor', icon: 'supervisor_account' },
  { userId: 'USR-CUST-001', label: 'Customer', icon: 'person' },
  { userId: 'USR-001', label: 'Fadhil', icon: 'badge' },
  { userId: 'USR-002', label: 'Budi', icon: 'badge' },
  { userId: 'USR-003', label: 'Andi', icon: 'badge' }
]

const handleLogin = async () => {
  const res = await authStore.login(username.value, password.value)
  if (res.success) {
    $q.notify({
      type: 'positive',
      icon: 'check_circle',
      message: res.message,
      position: 'top',
      timeout: 1800
    })

    redirectByRole(res.role)
  } else {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: res.message || 'Login gagal. Periksa koneksi ke server.',
      position: 'top',
      timeout: 2500
    })
  }
}

const quickLogin = async (userId) => {
  const res = await authStore.quickLogin(userId)
  if (res.success) {
    $q.notify({
      type: 'info',
      icon: 'flash_on',
      message: res.message,
      position: 'top',
      timeout: 1500
    })

    redirectByRole(res.role)
  } else {
    $q.notify({
      type: 'negative',
      icon: 'error',
      message: res.message || 'Quick login gagal.',
      position: 'top',
      timeout: 2500
    })
  }
}

const redirectByRole = (role) => {
  if (role === 'ADMIN') router.push('/admin')
  else if (role === 'SUPERVISOR') router.push('/supervisor')
  else if (role === 'CUSTOMER') router.push('/customer')
  else router.push('/petugas')
}
</script>

<style scoped>
.login-shell {
  min-height: 100vh;
  min-height: 100dvh;
  background:
    radial-gradient(1200px 600px at 80% -10%, rgba(11, 35, 65, 0.08), transparent 60%),
    #eef2f7;
}

.login-card {
  width: 100%;
  max-width: 880px;
  margin: auto;
  border-radius: 18px;
  overflow: hidden;
  background: #fff;
  border: 1px solid var(--dj-border);
}

.brand-panel {
  min-height: 560px;
}

.brand-inner {
  padding: 32px;
}

.form-panel {
  display: flex;
  align-items: center;
  justify-content: center;
}

.form-inner {
  width: 100%;
  max-width: 380px;
  padding: 40px 36px;
}

.quick-btn {
  border-radius: 10px;
}
</style>
