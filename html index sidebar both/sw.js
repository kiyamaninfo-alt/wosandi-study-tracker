const CACHE_NAME = 'al-study-tracker-v11';
const PRECACHE_ASSETS = [
  './',
  './app-logo.svg',
  './study-analytics',
  './study-analytics.html',
  './sidebar.html',
  './wosandi/index.html',
  './wosandi/app.js',
  './wosandi/dataService.js',
  './wosandi/gradeController.js',
  './wosandi/subjectDrawer.js',
  './wosandi/subjectManager.js',
  './wosandi/todayPriorities.js',
  './wosandi/unitAnalytics.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      for (const asset of PRECACHE_ASSETS) {
        try {
          const res = await fetch(asset, { redirect: 'follow' });
          if (res && (res.status === 200 || res.type === 'opaque')) {
            await cache.put(asset, res);
          }
        } catch (_) {}
      }
    }).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  // Don't intercept Supabase REST or Realtime websocket requests
  const url = new URL(req.url);
  if (url.hostname.includes('supabase.co')) return;

  // For top-level document navigations, use Network-First strategy directly
  // This allows Cloudflare clean-URL redirects (307 .html -> clean URL) to be resolved natively by the browser
  // without triggering Chromium's ERR_FAILED redirect error.
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseToCache = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(req, responseToCache);
          });
        }
        return networkResponse;
      }).catch(async () => {
        const cache = await caches.open(CACHE_NAME);
        const urlStr = req.url.toLowerCase();
        if (urlStr.includes('study-analytics')) {
          return (await cache.match('./study-analytics')) || (await cache.match('./study-analytics.html'));
        }
        return (await cache.match('./')) || (await cache.match('./index.html'));
      })
    );
    return;
  }

  // Cache-First for static assets
  event.respondWith(
    caches.match(req).then((cachedResponse) => {
      const fetchPromise = fetch(req).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseToCache = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(req, responseToCache);
          });
        }
        return networkResponse;
      }).catch(() => {
        return cachedResponse;
      });

      return cachedResponse || fetchPromise;
    })
  );
});
