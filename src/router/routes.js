const routes = [
  {
    path: '/',
    component: () => import('../layouts/MainLayout.vue'),
    children: [
      { path: '', component: () => import('../pages/IndexPage.vue') },
      { path: 'scan', component: () => import('../pages/ScanPage.vue') },
      { path: 'hasil', component: () => import('../pages/HasilScanPage.vue') },
      { path: 'riwayat', component: () => import('../pages/RiwayatPage.vue') }
    ]
  },

  {
    path: '/:catchAll(.*)*',
    component: () => import('../pages/ErrorNotFound.vue')
  }
]

export default routes
