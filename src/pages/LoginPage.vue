<template>
  <div class="fullscreen bg-slate-900 flex flex-center q-pa-md">
    <div style="width: 100%; max-width: 440px;">
      <!-- Brand Logo Header -->
      <div class="text-center q-mb-lg">
        <q-avatar size="64px" class="bg-wahana-yellow text-slate-900 text-weight-bold shadow-4 q-mb-sm">
          <q-icon name="local_shipping" size="40px" />
        </q-avatar>
        <h4 class="text-h4 text-weight-bolder text-amber-4 q-my-none font-mono tracking-wide">
          DIJAK EXPRESS
        </h4>
        <div class="text-subtitle2 text-grey-4">Logistics Barcode Scan Platform</div>
      </div>

      <!-- Login Form Card -->
      <q-card class="scan-card q-pa-md shadow-5">
        <q-card-section>
          <div class="text-h6 text-weight-bold text-slate-900 q-mb-xs">Sign In ke Akun Anda</div>
          <div class="text-caption text-grey-7 q-mb-md">Masukkan username & password atau gunakan Quick Login.</div>

          <q-form @submit.prevent="handleLogin" class="q-gutter-y-md">
            <q-input
              v-model="username"
              outlined
              dense
              label="Username"
              placeholder="Contoh: fadhil, admin, supervisor"
              autofocus
            >
              <template v-slot:prepend>
                <q-icon name="person" color="primary" />
              </template>
            </q-input>

            <q-input
              v-model="password"
              outlined
              dense
              type="password"
              label="Password"
              placeholder="••••••••"
            >
              <template v-slot:prepend>
                <q-icon name="lock" color="primary" />
              </template>
            </q-input>

            <q-btn
              type="submit"
              color="primary"
              size="lg"
              class="full-width text-weight-bold shadow-2"
              label="LOGIN"
              unelevated
            />
          </q-form>
        </q-card-section>

        <q-separator class="q-my-sm" />

        <!-- Quick Login Simulator Buttons (Requirement I) -->
        <q-card-section>
          <div class="text-caption text-weight-bold text-grey-8 q-mb-sm text-center">
            ⚡ QUICK LOGIN DEMO (1-Click Test)
          </div>

          <div class="column q-gutter-y-xs">
            <q-btn
              color="deep-orange-9"
              icon="admin_panel_settings"
              label="Login Admin (admin)"
              dense
              unelevated
              class="text-weight-bold"
              @click="quickLogin('USR-ADMIN-001')"
            />
            <q-btn
              color="indigo-9"
              icon="supervisor_account"
              label="Login Supervisor (supervisor)"
              dense
              unelevated
              class="text-weight-bold"
              @click="quickLogin('USR-SPV-001')"
            />
            <div class="row q-col-gutter-xs q-mt-xs">
              <div class="col-4">
                <q-btn
                  color="amber-9"
                  text-color="dark"
                  icon="badge"
                  label="Fadhil"
                  dense
                  unelevated
                  class="full-width text-weight-bold"
                  @click="quickLogin('USR-001')"
                />
              </div>
              <div class="col-4">
                <q-btn
                  color="teal-8"
                  icon="badge"
                  label="Budi"
                  dense
                  unelevated
                  class="full-width text-weight-bold"
                  @click="quickLogin('USR-002')"
                />
              </div>
              <div class="col-4">
                <q-btn
                  color="purple-8"
                  icon="badge"
                  label="Andi"
                  dense
                  unelevated
                  class="full-width text-weight-bold"
                  @click="quickLogin('USR-003')"
                />
              </div>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Footer Info -->
      <div class="text-center text-caption text-grey-5 q-mt-md font-mono">
        Dijak Express Barcode Prototype &copy; 2026
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
  else router.push('/petugas')
}
</script>
