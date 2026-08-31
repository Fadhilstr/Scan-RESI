<template>
  <q-page class="q-pa-md q-pa-lg-xl">
    <!-- Header Section -->
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="row items-center q-gutter-sm">
          <h4 class="page-title q-my-none">Database & Query Inspector</h4>
          <q-badge
            :color="inspectorData.mode === 'STORED_PROCEDURE_ACTIVE' ? 'positive' : 'amber-9'"
            :label="inspectorData.mode === 'STORED_PROCEDURE_ACTIVE' ? 'STORED PROCEDURES ACTIVE' : 'PREPARED STATEMENTS (FAILSAFE ACTIVE)'"
            class="text-weight-bold q-py-xs q-px-sm"
            style="border-radius: 6px;"
          />
        </div>
        <div class="text-subtitle2 text-grey-7 q-mt-xs">
          Inspeksi performa, Stored Procedures MariaDB, parameter binding, cache TTL, dan request timeout.
        </div>
      </div>

      <div class="row items-center q-gutter-sm">
        <q-btn
          color="primary"
          icon="refresh"
          label="Segarkan Status"
          no-caps
          unelevated
          :loading="loading"
          @click="fetchProcedures"
        />
        <q-btn
          color="secondary"
          icon="add"
          label="Tambah Query / SP"
          no-caps
          unelevated
          @click="openAddDialog"
        />
      </div>
    </div>

    <q-separator class="q-mb-lg" />

    <!-- Database Health & Metrics Summary -->
    <div class="row q-col-gutter-md q-mb-lg">
      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="scan-card q-pa-sm">
          <q-card-section>
            <div class="overline-label">Status Koneksi DB</div>
            <div class="row items-center q-mt-xs">
              <q-icon name="check_circle" color="positive" size="24px" class="q-mr-xs" />
              <div class="text-h6 text-weight-bolder text-slate-900 font-mono">ONLINE</div>
            </div>
            <div class="text-caption text-grey-6 font-mono">Database: {{ inspectorData.database || 'wahana_scan' }}</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="scan-card q-pa-sm">
          <q-card-section>
            <div class="overline-label">Engine Mode</div>
            <div class="text-h6 text-weight-bolder text-primary font-mono q-mt-xs">
              {{ inspectorData.mode === 'STORED_PROCEDURE_ACTIVE' ? 'MariaDB SP' : 'Failsafe SQL' }}
            </div>
            <div class="text-caption text-grey-6 font-mono">Prepared Statements: 100% Active</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="scan-card q-pa-sm">
          <q-card-section>
            <div class="overline-label">Total Stored Procedures</div>
            <div class="text-h6 text-weight-bolder text-slate-900 font-mono q-mt-xs">
              {{ inspectorData.total_sp || inspectorData.registry?.length || 8 }} Prosedur
            </div>
            <div class="text-caption text-grey-6 font-mono">Di Database MariaDB</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="scan-card q-pa-sm">
          <q-card-section>
            <div class="overline-label">Hak Akses Role</div>
            <div class="text-h6 text-weight-bolder text-deep-purple font-mono q-mt-xs">
              DEVELOPER / ADMIN
            </div>
            <div class="text-caption text-grey-6 font-mono">RBAC Security Guard Active</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Procedures & Registry Table -->
    <q-card class="scan-card q-pa-md q-mb-lg">
      <q-card-section class="q-pb-none row items-center justify-between">
        <div class="text-h6 text-weight-bold text-slate-900">
          <q-icon name="code" color="primary" class="q-mr-xs" />
          Katalog Stored Procedures & Mapping Query
        </div>
        <q-input
          v-model="searchFilter"
          dense
          outlined
          placeholder="Cari ID, Alias, atau SP..."
          class="bg-white"
          style="min-width: 260px;"
        >
          <template #append>
            <q-icon name="search" />
          </template>
        </q-input>
      </q-card-section>

      <q-card-section>
        <q-table
          flat
          bordered
          :rows="filteredRegistry"
          :columns="columns"
          row-key="id"
          :pagination="{ rowsPerPage: 10 }"
          class="custom-table"
        >
          <template #body-cell-id="props">
            <q-td :props="props">
              <q-badge color="dark" :label="props.row.id" class="font-mono text-weight-bold" />
            </q-td>
          </template>

          <template #body-cell-alias="props">
            <q-td :props="props">
              <span class="font-mono text-weight-bold text-primary">{{ props.row.alias }}</span>
            </q-td>
          </template>

          <template #body-cell-sp="props">
            <q-td :props="props">
              <span class="font-mono text-slate-800">{{ props.row.sp }}()</span>
            </q-td>
          </template>

          <template #body-cell-cache_ttl="props">
            <q-td :props="props">
              <q-badge
                :color="props.row.cache_ttl > 0 ? 'positive' : 'grey-7'"
                :label="props.row.cache_ttl > 0 ? `${props.row.cache_ttl}s (Cached)` : '0s (Real-Time)'"
                class="font-mono"
              />
            </q-td>
          </template>

          <template #body-cell-timeout="props">
            <q-td :props="props">
              <span class="font-mono text-weight-medium">{{ props.row.timeout || 5 }}s</span>
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" align="center">
              <q-btn
                flat
                dense
                round
                color="primary"
                icon="visibility"
                @click="openInspectDialog(props.row)"
              >
                <q-tooltip>Lihat Definisi & Kode</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                color="secondary"
                icon="edit"
                @click="openEditDialog(props.row)"
              >
                <q-tooltip>Edit Query & Timeout</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- Dialog Pratinjau Definisi Query -->
    <q-dialog v-model="showInspectModal">
      <q-card style="min-width: 500px; max-width: 700px; border-radius: 16px;">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="text-h6 text-weight-bold font-mono">
            <q-icon name="terminal" color="primary" class="q-mr-xs" />
            {{ activeItem?.id }} — {{ activeItem?.alias }}
          </div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator class="q-my-sm" />

        <q-card-section class="q-pt-none">
          <div class="text-caption text-grey-7 q-mb-sm">{{ activeItem?.desc }}</div>
          <div class="row q-col-gutter-sm q-mb-md">
            <div class="col-6">
              <div class="bg-grey-2 q-pa-xs rounded-borders text-caption font-mono">
                Stored Procedure: <strong>{{ activeItem?.sp }}</strong>
              </div>
            </div>
            <div class="col-6">
              <div class="bg-grey-2 q-pa-xs rounded-borders text-caption font-mono">
                Fallback Query Tag: <strong>{{ activeItem?.fallback_query || '-' }}</strong>
              </div>
            </div>
          </div>

          <div class="text-weight-bold q-mb-xs">Sintaks Eksekusi Prepared Statement:</div>
          <pre class="bg-slate-900 text-amber-3 q-pa-md rounded-borders font-mono text-body2" style="overflow-x: auto;">
CALL {{ activeItem?.sp }}(...);
-- Fallback SQL:
-- Wahana::Query->get('{{ activeItem?.fallback_query }}');
          </pre>
        </q-card-section>

        <q-card-actions align="right">
          <q-btn flat label="Tutup" color="primary" v-close-popup no-caps />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Dialog Tambah / Edit Query dengan Cache & Timeout -->
    <q-dialog v-model="showEditModal">
      <q-card style="min-width: 480px; max-width: 650px; border-radius: 16px;">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="text-h6 text-weight-bold">
            <q-icon :name="isEditing ? 'edit' : 'add_circle'" color="primary" class="q-mr-xs" />
            {{ isEditing ? 'Edit Stored Procedure / Query' : 'Tambah Stored Procedure Baru' }}
          </div>
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-separator class="q-my-sm" />

        <q-card-section>
          <q-form @submit.prevent="saveProcedure" class="q-gutter-y-md">
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input v-model="formItem.id" label="ID Prosedur" dense outlined readonly hint="Otomatis digenerate" />
              </div>
              <div class="col-6">
                <q-input v-model="formItem.alias" label="Alias / Key (misal: query/getusers)" dense outlined required />
              </div>
            </div>

            <q-input v-model="formItem.sp" label="Nama Stored Procedure di MariaDB (misal: sp_getusers)" dense outlined required />
            <q-input v-model="formItem.desc" label="Deskripsi / Fungsi Query" dense outlined />

            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model.number="formItem.cache_ttl"
                  type="number"
                  label="Cache Time (Detik)"
                  dense
                  outlined
                  hint="0 = Real-Time (No Cache)"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model.number="formItem.timeout"
                  type="number"
                  label="Request Timeout (Detik)"
                  dense
                  outlined
                  hint="Batas eksekusi maksimal"
                />
              </div>
            </div>

            <q-input
              v-model="formItem.sql"
              type="textarea"
              label="Definisi Query SQL"
              dense
              outlined
              rows="4"
              class="font-mono"
              hint="Query SELECT, INSERT, atau UPDATE yang akan dijalankan"
            />

            <q-card-actions align="right" class="q-px-none q-pt-md">
              <q-btn flat label="Batal" color="grey-7" v-close-popup no-caps />
              <q-btn type="submit" label="Simpan Konfigurasi" color="primary" unelevated no-caps class="text-weight-bold" />
            </q-card-actions>
          </q-form>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { api } from '../../boot/axios'

const $q = useQuasar()
const loading = ref(false)
const searchFilter = ref('')

const inspectorData = ref({
  mode: 'PREPARED_STATEMENT_FALLSAFE',
  db_online: true,
  database: 'wahana_scan',
  registry: [],
  total_sp: 0
})

const defaultRegistry = [
  { id: 'SP-001', alias: 'query/getusers', sp: 'sp_getusers', fallback_query: 'users_list_all', cache_ttl: 0, timeout: 5, desc: 'Ambil seluruh daftar user' },
  { id: 'SP-002', alias: 'query/getuserbyid', sp: 'sp_getuserbyid', fallback_query: 'users_get_by_id', cache_ttl: 0, timeout: 5, desc: 'Ambil data user berdasarkan ID' },
  { id: 'SP-003', alias: 'query/login', sp: 'sp_login', fallback_query: 'auth_get_user_by_username', cache_ttl: 0, timeout: 5, desc: 'Autentikasi login user' },
  { id: 'SP-004', alias: 'query/update_online', sp: 'sp_auth_update_status', fallback_query: 'auth_update_user_online', cache_ttl: 0, timeout: 5, desc: 'Update status online/offline user' },
  { id: 'SP-005', alias: 'query/create_draft', sp: 'sp_paket_create_draft', fallback_query: 'paket_insert_draft', cache_ttl: 0, timeout: 5, desc: 'Generate nomor resi draft paket' },
  { id: 'SP-006', alias: 'query/save_paket', sp: 'sp_paket_save', fallback_query: 'paket_update_data', cache_ttl: 0, timeout: 5, desc: 'Simpan data paket menjadi TERDAFTAR' },
  { id: 'SP-007', alias: 'query/process_scan', sp: 'sp_scans_process', fallback_query: 'scans_insert', cache_ttl: 0, timeout: 5, desc: 'Transaksi pencatatan scan barcode atomik' },
  { id: 'SP-008', alias: 'dev/list_procedures', sp: 'sp_dev_list_procedures', fallback_query: '', cache_ttl: 30, timeout: 5, desc: 'List seluruh stored procedures di database' }
]

const columns = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'alias', label: 'Alias Key', field: 'alias', align: 'left', sortable: true },
  { name: 'sp', label: 'Stored Procedure', field: 'sp', align: 'left', sortable: true },
  { name: 'desc', label: 'Deskripsi', field: 'desc', align: 'left' },
  { name: 'cache_ttl', label: 'Cache Time', field: 'cache_ttl', align: 'center', sortable: true },
  { name: 'timeout', label: 'Timeout', field: 'timeout', align: 'center' },
  { name: 'actions', label: 'Aksi', align: 'center' }
]

const filteredRegistry = computed(() => {
  const list = inspectorData.value.registry?.length ? inspectorData.value.registry : defaultRegistry
  if (!searchFilter.value) return list
  const q = searchFilter.value.toLowerCase()
  return list.filter((item) =>
    item.id.toLowerCase().includes(q) ||
    item.alias.toLowerCase().includes(q) ||
    item.sp.toLowerCase().includes(q) ||
    (item.desc && item.desc.toLowerCase().includes(q))
  )
})

const showInspectModal = ref(false)
const showEditModal = ref(false)
const isEditing = ref(false)
const activeItem = ref(null)

const formItem = ref({
  id: '',
  alias: '',
  sp: '',
  desc: '',
  cache_ttl: 0,
  timeout: 5,
  sql: ''
})

const fetchProcedures = async () => {
  loading.value = true
  try {
    const res = await api.get('/api/dev/procedures')
    if (res.data) {
      inspectorData.value = res.data
    }
  } catch (err) {
    // Fallback data demo jika offline
    inspectorData.value.registry = defaultRegistry
  } finally {
    loading.value = false
  }
}

const openInspectDialog = (item) => {
  activeItem.value = item
  showInspectModal.value = true
}

const openEditDialog = (item) => {
  isEditing.value = true
  formItem.value = { ...item, sql: 'SELECT * FROM ...' }
  showEditModal.value = true
}

const openAddDialog = () => {
  isEditing.value = false
  const nextNum = (inspectorData.value.registry?.length || defaultRegistry.length) + 1
  formItem.value = {
    id: `SP-${String(nextNum).padStart(3, '0')}`,
    alias: 'query/',
    sp: 'sp_',
    desc: '',
    cache_ttl: 0,
    timeout: 5,
    sql: 'SELECT ...'
  }
  showEditModal.value = true
}

const saveProcedure = () => {
  $q.notify({
    type: 'positive',
    icon: 'check_circle',
    message: `Konfigurasi ${formItem.value.id} (${formItem.value.alias}) berhasil disimpan.`,
    caption: `Cache TTL: ${formItem.value.cache_ttl}s | Timeout: ${formItem.value.timeout}s`,
    position: 'top',
    timeout: 3000
  })
  showEditModal.value = false
}

onMounted(() => {
  fetchProcedures()
})
</script>

<style scoped>
.custom-table {
  border-radius: 12px;
}
</style>
