<template>
  <q-page class="q-pa-md q-pa-lg-xl text-black">
    <!-- Header Section -->
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="row items-center q-gutter-sm">
          <h4 class="page-title text-black text-weight-bolder q-my-none">Database & Query Inspector</h4>
          <q-badge
            :color="inspectorData.mode === 'STORED_PROCEDURE_ACTIVE' ? 'positive' : 'amber-9'"
            :label="inspectorData.mode === 'STORED_PROCEDURE_ACTIVE' ? 'STORED PROCEDURES ACTIVE' : 'PREPARED STATEMENTS ACTIVE'"
            class="text-weight-bold q-py-xs q-px-sm"
            style="border-radius: 6px;"
          />
        </div>
        <div class="text-subtitle2 text-black text-weight-medium q-mt-xs">
          Katalog Query Database MariaDB (<span class="font-mono text-weight-bold text-primary">sys_queries</span>), Parameter Binding, Definisi SQL, dan Caching.
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
            <div class="overline-label text-black text-weight-bold">Status Koneksi DB</div>
            <div class="row items-center q-mt-xs">
              <q-icon name="check_circle" color="positive" size="24px" class="q-mr-xs" />
              <div class="text-h6 text-weight-bolder text-black font-mono">ONLINE</div>
            </div>
            <div class="text-caption text-black text-weight-bold font-mono">Database: {{ inspectorData.database || 'wahana_scan' }}</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="scan-card q-pa-sm">
          <q-card-section>
            <div class="overline-label text-black text-weight-bold">Engine Mode</div>
            <div class="text-h6 text-weight-bolder text-primary font-mono q-mt-xs">
              MariaDB Stored Procedures
            </div>
            <div class="text-caption text-black text-weight-bold font-mono">Prepared Statements: Active</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="scan-card q-pa-sm">
          <q-card-section>
            <div class="overline-label text-black text-weight-bold">Total Catalog Queries</div>
            <div class="text-h6 text-weight-bolder text-black font-mono q-mt-xs">
              {{ (inspectorData.registry || []).length }} Query
            </div>
            <div class="text-caption text-black text-weight-bold font-mono">Tabel: sys_queries</div>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-sm-6 col-md-3">
        <q-card class="scan-card q-pa-sm">
          <q-card-section>
            <div class="overline-label text-black text-weight-bold">Hak Akses Role</div>
            <div class="text-h6 text-weight-bolder text-deep-purple font-mono q-mt-xs">
              DEVELOPER / ADMIN
            </div>
            <div class="text-caption text-black text-weight-bold font-mono">RBAC Security Active</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Procedures & Registry Table -->
    <q-card class="scan-card q-pa-md q-mb-lg">
      <q-card-section class="q-pb-none row items-center justify-between">
        <div class="text-h6 text-weight-bolder text-black">
          <q-icon name="dns" color="primary" class="q-mr-xs" />
          Katalog Query & Stored Procedures (<span class="font-mono text-primary">sys_queries</span>)
        </div>
        <q-input
          v-model="searchFilter"
          dense
          outlined
          placeholder="Cari ID, Code, atau SP..."
          class="bg-white text-black"
          style="min-width: 280px;"
        >
          <template #append>
            <q-icon name="search" color="black" />
          </template>
        </q-input>
      </q-card-section>

      <q-card-section>
        <q-table
          flat
          bordered
          :rows="filteredRegistry"
          :columns="columns"
          row-key="query_id"
          :pagination="{ rowsPerPage: 10 }"
          class="custom-table text-black"
        >
          <template #body-cell-query_id="props">
            <q-td :props="props">
              <q-badge color="black" text-color="white" :label="props.row.query_id" class="font-mono text-weight-bold q-pa-xs" />
            </q-td>
          </template>

          <template #body-cell-query_code="props">
            <q-td :props="props">
              <span class="font-mono text-weight-bolder text-primary text-body2">{{ props.row.query_code }}</span>
            </q-td>
          </template>

          <template #body-cell-sp_name="props">
            <q-td :props="props">
              <span class="font-mono text-weight-bold text-black">{{ props.row.sp_name }}()</span>
            </q-td>
          </template>

          <template #body-cell-query_type="props">
            <q-td :props="props">
              <q-badge
                :color="props.row.query_type === 'SELECT_ALL' ? 'blue-9' : (props.row.query_type === 'SELECT_ROW' ? 'teal-9' : 'purple-9')"
                :label="props.row.query_type || 'SELECT_ROW'"
                class="font-mono text-weight-bold"
              />
            </q-td>
          </template>

          <template #body-cell-required_role="props">
            <q-td :props="props">
              <q-badge
                :color="props.row.required_role === 'ADMIN' ? 'red-9' : (props.row.required_role === 'DEVELOPER' ? 'deep-purple-9' : 'grey-9')"
                :label="props.row.required_role || 'PUBLIC'"
                class="text-weight-bold"
              />
            </q-td>
          </template>

          <template #body-cell-deskripsi="props">
            <q-td :props="props">
              <span class="text-black text-weight-medium">{{ props.row.deskripsi || '-' }}</span>
            </q-td>
          </template>

          <template #body-cell-cache_ttl="props">
            <q-td :props="props">
              <q-badge
                :color="props.row.cache_ttl > 0 ? 'positive' : 'grey-8'"
                :label="props.row.cache_ttl > 0 ? `${props.row.cache_ttl}s (Cached)` : '0s (Real-Time)'"
                class="font-mono text-weight-bold"
              />
            </q-td>
          </template>

          <template #body-cell-actions="props">
            <q-td :props="props" align="center">
              <q-btn
                flat
                dense
                round
                color="primary"
                icon="code"
                @click="openInspectDialog(props.row)"
              >
                <q-tooltip>Lihat Query SQL</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                color="secondary"
                icon="edit"
                @click="openEditDialog(props.row)"
              >
                <q-tooltip>Edit Query</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                color="negative"
                icon="delete"
                @click="deleteProcedure(props.row)"
              >
                <q-tooltip>Hapus Query</q-tooltip>
              </q-btn>
            </q-td>
          </template>
        </q-table>
      </q-card-section>
    </q-card>

    <!-- Dialog Pratinjau Definisi Query SQL (Inspect Modal) -->
    <q-dialog v-model="showInspectModal">
      <q-card style="min-width: 580px; max-width: 800px; border-radius: 16px;" class="text-black">
        <q-card-section class="row items-center justify-between q-pb-none bg-slate-100">
          <div class="text-h6 text-weight-bolder text-black font-mono">
            <q-icon name="code" color="primary" class="q-mr-xs" />
            {{ activeItem?.query_id }} : {{ activeItem?.query_code }}
          </div>
          <q-btn icon="close" flat round dense v-close-popup color="black" />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-pt-md">
          <!-- Info Ringkas -->
          <div class="row q-col-gutter-sm q-mb-md">
            <div class="col-6">
              <div class="bg-grey-2 q-pa-sm rounded-borders text-black">
                <div class="text-caption text-weight-bold">Stored Procedure:</div>
                <div class="font-mono text-weight-bolder text-primary text-body2">{{ activeItem?.sp_name }}()</div>
              </div>
            </div>
            <div class="col-3">
              <div class="bg-grey-2 q-pa-sm rounded-borders text-black">
                <div class="text-caption text-weight-bold">Query Type:</div>
                <div class="font-mono text-weight-bolder text-black">{{ activeItem?.query_type }}</div>
              </div>
            </div>
            <div class="col-3">
              <div class="bg-grey-2 q-pa-sm rounded-borders text-black">
                <div class="text-caption text-weight-bold">Role:</div>
                <div class="font-mono text-weight-bolder text-black">{{ activeItem?.required_role }}</div>
              </div>
            </div>
          </div>

          <div class="text-caption text-black text-weight-bold q-mb-md bg-blue-1 q-pa-sm rounded-borders border-blue">
            <q-icon name="info" color="primary" class="q-mr-xs" />
            <strong>Fungsi:</strong> {{ activeItem?.deskripsi || '-' }}
          </div>

          <!-- Parameter Binding -->
          <div class="text-weight-bolder text-black q-mb-xs">Parameter Input:</div>
          <div class="bg-grey-2 q-pa-sm rounded-borders font-mono text-black text-weight-bold q-mb-md">
            {{ activeItem?.param_keys || '[]' }}
          </div>

          <!-- 1. Definisi Query SQL MariaDB (Teks Hitam Jelas) -->
          <div class="text-weight-bolder text-black q-mb-xs">
            <q-icon name="storage" color="primary" class="q-mr-xs" />
            Definisi Query SQL (Di MariaDB):
          </div>
          <pre class="code-box-sql q-pa-md rounded-borders font-mono text-weight-bold q-mb-md" style="overflow-x: auto;">{{ getSqlQuery(activeItem?.query_code, activeItem?.sp_name) }}</pre>

          <!-- 2. Sintaks Pemanggilan CALL di Database -->
          <div class="text-weight-bolder text-black q-mb-xs">
            <q-icon name="play_arrow" color="positive" class="q-mr-xs" />
            Sintaks Eksekusi Stored Procedure:
          </div>
          <pre class="code-box-call q-pa-sm rounded-borders font-mono text-weight-bolder text-black q-mb-none" style="overflow-x: auto;">CALL {{ activeItem?.sp_name }}({{ getCallPlaceholders(activeItem?.param_keys) }});</pre>
        </q-card-section>

        <q-card-actions align="right" class="bg-grey-1 q-pa-md">
          <q-btn flat label="Tutup" color="black" v-close-popup no-caps class="text-weight-bold" />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Dialog Tambah / Edit Query (sys_queries) -->
    <q-dialog v-model="showEditModal">
      <q-card style="min-width: 520px; max-width: 700px; border-radius: 16px;" class="text-black">
        <q-card-section class="row items-center justify-between q-pb-none bg-slate-100">
          <div class="text-h6 text-weight-bolder text-black">
            <q-icon :name="isEditing ? 'edit' : 'add_circle'" color="primary" class="q-mr-xs" />
            {{ isEditing ? 'Edit Query Catalog' : 'Tambah Query Baru (sys_queries)' }}
          </div>
          <q-btn icon="close" flat round dense v-close-popup color="black" />
        </q-card-section>

        <q-separator />

        <q-card-section class="q-pt-md">
          <q-form @submit.prevent="saveProcedure" class="q-gutter-y-md">
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input v-model="formItem.query_id" label="Query ID" dense outlined :readonly="isEditing" required hint="Contoh: QRY-001" class="text-black" />
              </div>
              <div class="col-6">
                <q-input v-model="formItem.query_code" label="Query Code" dense outlined required hint="Contoh: CustInsert, AuthLogin" class="text-black" />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input v-model="formItem.sp_name" label="Nama Stored Procedure MariaDB" dense outlined required hint="Contoh: sp_paket_save" class="text-black" />
              </div>
              <div class="col-6">
                <q-select
                  v-model="formItem.query_type"
                  :options="['SELECT_ROW', 'SELECT_ALL', 'EXECUTE']"
                  label="Query Type"
                  dense
                  outlined
                  class="text-black"
                />
              </div>
            </div>

            <q-input
              v-model="formItem.param_keys_str"
              label="Parameter Keys (Array JSON / Koma Terpisah)"
              dense
              outlined
              hint='Contoh: ["resi", "nama_barang"] atau resi, nama_barang'
              class="text-black"
            />

            <div class="row q-col-gutter-sm">
              <div class="col-4">
                <q-select
                  v-model="formItem.required_role"
                  :options="['PUBLIC', 'PETUGAS_SCAN', 'ADMIN', 'DEVELOPER']"
                  label="Required Role"
                  dense
                  outlined
                  class="text-black"
                />
              </div>
              <div class="col-4">
                <q-input
                  v-model.number="formItem.cache_ttl"
                  type="number"
                  label="Cache TTL (Detik)"
                  dense
                  outlined
                  hint="0 = Real-Time"
                  class="text-black"
                />
              </div>
              <div class="col-4">
                <q-input
                  v-model.number="formItem.timeout_sec"
                  type="number"
                  label="Timeout (Detik)"
                  dense
                  outlined
                  class="text-black"
                />
              </div>
            </div>

            <q-input v-model="formItem.deskripsi" label="Deskripsi / Fungsi Query" dense outlined rows="2" type="textarea" class="text-black" />

            <q-card-actions align="right" class="q-px-none q-pt-md">
              <q-btn flat label="Batal" color="black" v-close-popup no-caps class="text-weight-bold" />
              <q-btn type="submit" label="Simpan ke Database" color="primary" unelevated no-caps class="text-weight-bolder" :loading="saving" />
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
import api from '../../services/api'

const $q = useQuasar()
const loading = ref(false)
const saving = ref(false)
const searchFilter = ref('')

const inspectorData = ref({
  mode: 'STORED_PROCEDURE_ACTIVE',
  db_online: true,
  database: 'wahana_scan',
  registry: [],
  total_sp: 0
})

// Kamus Definisi Query SQL Murni untuk Setiap Stored Procedure
const SQL_DEFINITIONS = {
  'UsersListAll': `SELECT id, name, username, role, status, last_login 
FROM users 
ORDER BY id ASC;`,

  'UsersGetById': `SELECT * 
FROM users 
WHERE id = p_id;`,

  'AuthLogin': `SELECT * 
FROM users 
WHERE LOWER(username) = LOWER(p_username) 
LIMIT 1;`,

  'AuthUpdateStatus': `IF p_status = 'ONLINE' THEN
  UPDATE users SET status = 'ONLINE', last_login = NOW() WHERE id = p_user_id;
ELSE
  UPDATE users SET status = 'OFFLINE' WHERE id = p_user_id;
END IF;`,

  'UsersInsert': `INSERT INTO users (id, name, username, password_hash, role, status)
VALUES (p_id, p_name, p_username, p_pass, p_role, p_status);`,

  'UsersUpdate': `IF p_pass IS NOT NULL AND p_pass != '' THEN
  UPDATE users SET name = p_name, username = p_username, role = p_role, password_hash = p_pass WHERE id = p_id;
ELSE
  UPDATE users SET name = p_name, username = p_username, role = p_role WHERE id = p_id;
END IF;`,

  'UsersDelete': `DELETE FROM users 
WHERE id = p_id;`,

  'UsersToggleStatus': `UPDATE users 
SET status = p_status 
WHERE id = p_id;`,

  'PaketCreateDraft': `INSERT INTO paket (nomor_resi, status, created_by, telepon_pengirim, telepon_penerima, created_at)
VALUES (p_resi, 'DRAFT', p_created_by, '', '', NOW());

SELECT p.*, u.name AS creator_name 
FROM paket p LEFT JOIN users u ON u.id = p.created_by 
WHERE p.nomor_resi = p_resi;`,

  'CustInsert': `UPDATE paket
   SET nama_barang = p_nama, pengirim = p_pengirim, alamat_pengirim = p_alamat_p, telepon_pengirim = p_telp_p,
       penerima = p_penerima, alamat_tujuan = p_alamat_t, telepon_penerima = p_telp_t,
       berat_kg = p_berat, jenis_layanan = p_layanan, status = 'TERDAFTAR', created_at = NOW()
 WHERE nomor_resi = p_resi;

SELECT p.*, u.name AS creator_name 
FROM paket p LEFT JOIN users u ON u.id = p.created_by 
WHERE p.nomor_resi = p_resi;`,

  'PaketListAll': `SELECT p.*, u.name AS creator_name 
FROM paket p LEFT JOIN users u ON u.id = p.created_by 
ORDER BY p.created_at DESC;`,

  'PaketGetDetail': `SELECT p.*, u.name AS creator_name 
FROM paket p LEFT JOIN users u ON u.id = p.created_by 
WHERE p.nomor_resi = p_resi;`,

  'TasksListAll': `SELECT t.*, u.name AS user_name 
FROM tasks t JOIN users u ON u.id = t.user_id 
ORDER BY t.tanggal DESC, t.task_id DESC;`,

  'TasksGetById': `SELECT t.*, u.name AS user_name 
FROM tasks t JOIN users u ON u.id = t.user_id 
WHERE t.task_id = p_task_id;`,

  'TasksInsert': `INSERT INTO tasks (task_id, user_id, shift, tanggal, target, progress, status, lokasi)
VALUES (p_id, p_user_id, p_shift, p_tanggal, p_target, 0, 'PROSES_SCAN', p_lokasi);`,

  'TasksProgress': `UPDATE tasks 
SET progress = progress + p_increment 
WHERE task_id = p_task_id;`,

  'TasksComplete': `UPDATE tasks 
SET status = 'SELESAI' 
WHERE task_id = p_task_id;`,

  'ScansProcess': `-- Transaksi Atomik (InnoDB Row Lock):
-- 1. Validasi keberadaan resi & status (Bukan DRAFT).
-- 2. Kunci baris task (SELECT ... FOR UPDATE).
-- 3. Cek duplikasi nomor resi pada task.
-- 4. INSERT ke scan_events (SUCCESS / DUPLICATE).
-- 5. Jika SUCCESS -> Increment progress task (+1).
-- 6. Return result_code: 'SUCCESS' / 'DUPLICATE' / 'UNKNOWN_RESI' / 'DRAFT'.`,

  'ScansListAll': `SELECT s.*, u.name AS user_name 
FROM scan_events s JOIN users u ON u.id = s.user_id 
ORDER BY s.waktu_scan DESC;`,

  'ScansStats': `SELECT 
  COALESCE(SUM(CASE WHEN status_scan = 'SUCCESS' THEN 1 ELSE 0 END), 0) AS total_success,
  COALESCE(SUM(CASE WHEN status_scan = 'DUPLICATE' THEN 1 ELSE 0 END), 0) AS total_duplicate,
  MAX(waktu_scan) AS last_scan
FROM scan_events 
WHERE user_id = p_user_id;`,

  'AuditInsert': `INSERT INTO audit_logs (user_id, action, details, ip_address, created_at)
VALUES (p_user_id, p_action, p_details, p_ip, NOW());`,

  'AuditListAll': `SELECT a.*, u.name AS user_name 
FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id 
ORDER BY a.created_at DESC;`,

  'DevListQueries': `SELECT query_id, query_code, sp_name, param_keys, query_type, required_role, cache_ttl, timeout_sec, deskripsi, status, created_at, updated_at 
FROM sys_queries 
ORDER BY query_id ASC;`
}

const defaultRegistry = [
  { query_id: 'QRY-001', query_code: 'UsersListAll', sp_name: 'sp_getusers', param_keys: '[]', query_type: 'SELECT_ALL', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil seluruh daftar user' },
  { query_id: 'QRY-002', query_code: 'UsersGetById', sp_name: 'sp_getuserbyid', param_keys: '["id"]', query_type: 'SELECT_ROW', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil data user berdasarkan ID' },
  { query_id: 'QRY-003', query_code: 'AuthLogin', sp_name: 'sp_login', param_keys: '["username"]', query_type: 'SELECT_ROW', required_role: 'PUBLIC', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Autentikasi login user' },
  { query_id: 'QRY-004', query_code: 'AuthUpdateStatus', sp_name: 'sp_auth_update_status', param_keys: '["user_id","status"]', query_type: 'EXECUTE', required_role: 'PUBLIC', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Update status online/offline user' },
  { query_id: 'QRY-005', query_code: 'UsersInsert', sp_name: 'sp_users_insert', param_keys: '["id","name","username","password_hash","role","status"]', query_type: 'EXECUTE', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Tambah user baru oleh admin' },
  { query_id: 'QRY-006', query_code: 'UsersUpdate', sp_name: 'sp_users_update', param_keys: '["id","name","username","role","password_hash"]', query_type: 'EXECUTE', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Update profil & password user' },
  { query_id: 'QRY-007', query_code: 'UsersDelete', sp_name: 'sp_users_delete', param_keys: '["id"]', query_type: 'EXECUTE', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Hapus user dari database' },
  { query_id: 'QRY-008', query_code: 'UsersToggleStatus', sp_name: 'sp_users_toggle_status', param_keys: '["id","status"]', query_type: 'EXECUTE', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Aktifkan/Nonaktifkan status akun user' },
  { query_id: 'QRY-009', query_code: 'PaketCreateDraft', sp_name: 'sp_paket_create_draft', param_keys: '["resi","created_by"]', query_type: 'SELECT_ROW', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Generate nomor resi draft paket' },
  { query_id: 'QRY-010', query_code: 'CustInsert', sp_name: 'sp_paket_save', param_keys: '["resi","nama_barang","pengirim","alamat_pengirim","telepon_pengirim","penerima","alamat_tujuan","telepon_penerima","berat_kg","jenis_layanan"]', query_type: 'SELECT_ROW', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Simpan data paket customer menjadi TERDAFTAR' },
  { query_id: 'QRY-011', query_code: 'PaketListAll', sp_name: 'sp_paket_list', param_keys: '[]', query_type: 'SELECT_ALL', required_role: 'PUBLIC', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil seluruh daftar paket' },
  { query_id: 'QRY-012', query_code: 'PaketGetDetail', sp_name: 'sp_paket_get_detail', param_keys: '["resi"]', query_type: 'SELECT_ROW', required_role: 'PUBLIC', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil detail paket berdasarkan resi' },
  { query_id: 'QRY-013', query_code: 'TasksListAll', sp_name: 'sp_tasks_list', param_keys: '[]', query_type: 'SELECT_ALL', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil seluruh daftar tugas scan' },
  { query_id: 'QRY-014', query_code: 'TasksGetById', sp_name: 'sp_tasks_get_by_id', param_keys: '["task_id"]', query_type: 'SELECT_ROW', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil detail tugas scan by ID' },
  { query_id: 'QRY-015', query_code: 'TasksInsert', sp_name: 'sp_tasks_insert', param_keys: '["task_id","user_id","shift","tanggal","target","lokasi"]', query_type: 'EXECUTE', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Buat penugasan scan baru' },
  { query_id: 'QRY-016', query_code: 'TasksProgress', sp_name: 'sp_tasks_progress', param_keys: '["task_id","increment"]', query_type: 'EXECUTE', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Tambah progress scan pada tugas' },
  { query_id: 'QRY-017', query_code: 'TasksComplete', sp_name: 'sp_tasks_complete', param_keys: '["task_id"]', query_type: 'EXECUTE', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Selesaikan tugas scan' },
  { query_id: 'QRY-018', query_code: 'ScansProcess', sp_name: 'sp_scans_process', param_keys: '["scan_id","nomor_resi","user_id","task_id","lokasi","device_id","jenis_scan"]', query_type: 'SELECT_ROW', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Transaksi scan barcode atomik & anti duplikasi' },
  { query_id: 'QRY-019', query_code: 'ScansListAll', sp_name: 'sp_scans_list', param_keys: '[]', query_type: 'SELECT_ALL', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil riwayat scan barcode' },
  { query_id: 'QRY-020', query_code: 'ScansStats', sp_name: 'sp_scans_stats', param_keys: '["user_id"]', query_type: 'SELECT_ROW', required_role: 'PETUGAS_SCAN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil rekap statistik scan petugas' },
  { query_id: 'QRY-021', query_code: 'AuditInsert', sp_name: 'sp_audit_insert', param_keys: '["user_id","action","details","ip_address"]', query_type: 'EXECUTE', required_role: 'PUBLIC', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Catat aktivitas sistem ke audit logs' },
  { query_id: 'QRY-022', query_code: 'AuditListAll', sp_name: 'sp_audit_list', param_keys: '[]', query_type: 'SELECT_ALL', required_role: 'ADMIN', cache_ttl: 0, timeout_sec: 5, deskripsi: 'Ambil seluruh riwayat log audit' },
  { query_id: 'QRY-023', query_code: 'DevListQueries', sp_name: 'sp_sys_get_queries', param_keys: '[]', query_type: 'SELECT_ALL', required_role: 'DEVELOPER', cache_ttl: 0, timeout_sec: 5, deskripsi: 'List seluruh registry query sistem' }
]

const columns = [
  { name: 'query_id', label: 'Query ID', field: 'query_id', align: 'left', sortable: true },
  { name: 'query_code', label: 'Query Code', field: 'query_code', align: 'left', sortable: true },
  { name: 'sp_name', label: 'Stored Procedure', field: 'sp_name', align: 'left', sortable: true },
  { name: 'query_type', label: 'Type', field: 'query_type', align: 'center', sortable: true },
  { name: 'required_role', label: 'Role', field: 'required_role', align: 'center', sortable: true },
  { name: 'deskripsi', label: 'Deskripsi', field: 'deskripsi', align: 'left' },
  { name: 'cache_ttl', label: 'Cache TTL', field: 'cache_ttl', align: 'center', sortable: true },
  { name: 'actions', label: 'Aksi', align: 'center' }
]

const filteredRegistry = computed(() => {
  const list = inspectorData.value.registry?.length ? inspectorData.value.registry : defaultRegistry
  if (!searchFilter.value) return list
  const q = searchFilter.value.toLowerCase()
  return list.filter((item) =>
    (item.query_id && item.query_id.toLowerCase().includes(q)) ||
    (item.query_code && item.query_code.toLowerCase().includes(q)) ||
    (item.sp_name && item.sp_name.toLowerCase().includes(q)) ||
    (item.deskripsi && item.deskripsi.toLowerCase().includes(q))
  )
})

const showInspectModal = ref(false)
const showEditModal = ref(false)
const isEditing = ref(false)
const activeItem = ref(null)

const formItem = ref({
  query_id: '',
  query_code: '',
  sp_name: '',
  param_keys_str: '',
  query_type: 'SELECT_ROW',
  required_role: 'PUBLIC',
  cache_ttl: 0,
  timeout_sec: 5,
  deskripsi: ''
})

const getSqlQuery = (code, sp) => {
  if (code && SQL_DEFINITIONS[code]) return SQL_DEFINITIONS[code]
  return `-- Definisi Stored Procedure: ${sp || code || 'sp_unknown'}\nSELECT * FROM sys_queries;`
}

const getCallPlaceholders = (paramKeys) => {
  let count = 0
  if (paramKeys) {
    if (typeof paramKeys === 'string') {
      try { count = JSON.parse(paramKeys).length } catch (e) { count = paramKeys.split(',').length }
    } else if (Array.isArray(paramKeys)) {
      count = paramKeys.length
    }
  }
  return count > 0 ? Array(count).fill('?').join(', ') : ''
}

const fetchProcedures = async () => {
  loading.value = true
  try {
    const [procRes, qryRes] = await Promise.allSettled([
      api.get('/api/dev/procedures'),
      api.get('/api/dev/queries')
    ])

    if (procRes.status === 'fulfilled' && procRes.value.data) {
      inspectorData.value = procRes.value.data
    }

    if (qryRes.status === 'fulfilled' && qryRes.value.data?.data) {
      inspectorData.value.registry = qryRes.value.data.data
    }
  } catch (err) {
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
  let paramsStr = item.param_keys || '[]'
  formItem.value = {
    ...item,
    param_keys_str: typeof paramsStr === 'string' ? paramsStr : JSON.stringify(paramsStr)
  }
  showEditModal.value = true
}

const openAddDialog = () => {
  isEditing.value = false
  const count = (inspectorData.value.registry?.length || defaultRegistry.length) + 1
  formItem.value = {
    query_id: `QRY-${String(count).padStart(3, '0')}`,
    query_code: '',
    sp_name: 'sp_',
    param_keys_str: '[]',
    query_type: 'SELECT_ROW',
    required_role: 'PUBLIC',
    cache_ttl: 0,
    timeout_sec: 5,
    deskripsi: ''
  }
  showEditModal.value = true
}

const saveProcedure = async () => {
  saving.value = true
  try {
    let parsedParams = []
    const raw = formItem.value.param_keys_str.trim()
    if (raw.startsWith('[') && raw.endsWith(']')) {
      try { parsedParams = JSON.parse(raw) } catch (e) { parsedParams = [] }
    } else if (raw) {
      parsedParams = raw.split(',').map(s => s.trim()).filter(Boolean)
    }

    const payload = {
      query_id: formItem.value.query_id,
      query_code: formItem.value.query_code,
      sp_name: formItem.value.sp_name,
      param_keys: parsedParams,
      query_type: formItem.value.query_type,
      required_role: formItem.value.required_role,
      cache_ttl: Number(formItem.value.cache_ttl) || 0,
      timeout_sec: Number(formItem.value.timeout_sec) || 5,
      deskripsi: formItem.value.deskripsi
    }

    if (isEditing.value) {
      await api.put(`/api/dev/queries/${payload.query_id}`, payload)
    } else {
      await api.post('/api/dev/queries', payload)
    }

    $q.notify({
      type: 'positive',
      icon: 'check_circle',
      message: `Query ${payload.query_code} (${payload.query_id}) berhasil disimpan ke database.`,
      position: 'top'
    })

    showEditModal.value = false
    await fetchProcedures()
  } catch (err) {
    $q.notify({
      type: 'negative',
      message: err.response?.data?.message || 'Gagal menyimpan query ke database.',
      position: 'top'
    })
  } finally {
    saving.value = false
  }
}

const deleteProcedure = (row) => {
  $q.dialog({
    title: 'Konfirmasi Hapus Query',
    message: `Apakah Anda yakin ingin menghapus query ${row.query_code} (${row.query_id}) dari database sys_queries?`,
    cancel: { label: 'Batal', flat: true, noCaps: true },
    ok: { label: 'Hapus', color: 'negative', unelevated: true, noCaps: true }
  }).onOk(async () => {
    try {
      await api.delete(`/api/dev/queries/${row.query_id}`)
      $q.notify({
        type: 'positive',
        icon: 'check_circle',
        message: `Query ${row.query_id} berhasil dihapus.`,
        position: 'top'
      })
      await fetchProcedures()
    } catch (err) {
      $q.notify({
        type: 'negative',
        message: err.response?.data?.message || 'Gagal menghapus query.',
        position: 'top'
      })
    }
  })
}

onMounted(() => {
  fetchProcedures()
})
</script>

<style scoped>
.custom-table {
  border-radius: 12px;
}

.code-box-sql {
  background-color: #f8fafc;
  color: #0f172a;
  border: 1px solid #cbd5e1;
  font-size: 0.85rem;
  line-height: 1.45;
}

.code-box-call {
  background-color: #f1f5f9;
  color: #0f172a;
  border: 1px solid #94a3b8;
  font-size: 0.9rem;
}

.border-blue {
  border: 1px solid #bfdbfe;
}
</style>
