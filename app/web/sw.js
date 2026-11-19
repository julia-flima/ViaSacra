/* Via Sacra — service worker (offline-first).
 *
 * • App (HTML/JS/WASM/fontes/assets): "stale-while-revalidate" — abre na hora a
 *   partir do cache e atualiza em segundo plano para a próxima visita.
 * • Liturgia (JSON do jsDelivr / GitHub): "network-first" com fallback ao cache.
 * • Nada de terceiros além dessas fontes de dados; nenhuma telemetria.
 *
 * VERSION é substituída no deploy (deploy-web.yml) para invalidar caches antigos.
 */
const VERSION = 'dev';
const APP_CACHE = `via-sacra-app-${VERSION}`;
const DATA_CACHE = 'via-sacra-dados';

const PRECACHE = [
  './',
  'index.html',
  'manifest.json',
  'flutter_bootstrap.js',
  'main.dart.js',
  'sqlite3.wasm',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/apple-touch-icon.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(APP_CACHE).then((cache) =>
      // Falha de um item não impede a instalação.
      Promise.all(PRECACHE.map((url) => cache.add(url).catch(() => null))),
    ),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k.startsWith('via-sacra-app-') && k !== APP_CACHE).map((k) => caches.delete(k))),
    ).then(() => self.clients.claim()),
  );
});

function isLiturgyData(url) {
  return url.hostname === 'cdn.jsdelivr.net' || url.hostname === 'raw.githubusercontent.com';
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (isLiturgyData(url)) {
    event.respondWith(
      fetch(req)
        .then((resp) => {
          if (resp.ok) {
            const copy = resp.clone();
            caches.open(DATA_CACHE).then((c) => c.put(req, copy));
          }
          return resp;
        })
        .catch(() => caches.match(req).then((r) => r || Response.error())),
    );
    return;
  }

  if (url.origin !== self.location.origin) return; // áudios externos etc.: direto da rede

  event.respondWith(
    caches.open(APP_CACHE).then((cache) =>
      cache.match(req, { ignoreSearch: req.mode === 'navigate' }).then((cached) => {
        const network = fetch(req)
          .then((resp) => {
            if (resp.ok && resp.type === 'basic') cache.put(req, resp.clone());
            return resp;
          })
          .catch(() => cached || (req.mode === 'navigate' ? cache.match('index.html') : Response.error()));
        return cached || network;
      }),
    ),
  );
});
