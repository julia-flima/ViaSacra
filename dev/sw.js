/* Via Sacra — service worker (offline-first).
 *
 * • App (HTML/JS/WASM/fontes/assets): "stale-while-revalidate" — abre na hora a
 *   partir do cache e atualiza em segundo plano para a próxima visita.
 * • Liturgia (JSON do jsDelivr / GitHub): "network-first" com fallback ao cache.
 * • Nada de terceiros além dessas fontes de dados; nenhuma telemetria.
 *
 * VERSION é substituída no deploy (deploy-web.yml) para invalidar caches antigos.
 */
const VERSION = 'preview-431de9df8260';
const APP_CACHE = `via-sacra-dev-app-${VERSION}`;
const DATA_CACHE = 'via-sacra-dev-dados';
const KOKORO_CACHE = 'via-sacra-kokoro-v1';

const PRECACHE = [
  './',
  'index.html',
  'manifest.json',
  'kokoro_tts.js',
  'kokoro_worker.js',
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
      Promise.all(
        keys
          .filter((k) => (k.startsWith('via-sacra-dev-app-') && k !== APP_CACHE) || k === DATA_CACHE)
          .map((k) => caches.delete(k)),
      ),
    ).then(() => self.clients.claim()),
  );
});

function isLiturgyData(url) {
  const isDataHost = url.hostname === 'cdn.jsdelivr.net' || url.hostname === 'raw.githubusercontent.com';
  return isDataHost && /\/liturgia\/[^/]+\.json$/.test(url.pathname);
}

function isKokoroRuntime(url) {
  return (
    url.hostname === 'cdn.jsdelivr.net' &&
    /^\/npm\/(ephone@1\.0\.2|onnxruntime-web@1\.22\.0)\//.test(url.pathname)
  );
}

function isAppShell(req, url) {
  if (req.mode === 'navigate') return true;
  return /\/(index\.html|flutter_bootstrap\.js|main\.dart\.js|manifest\.json|kokoro_tts\.js|kokoro_worker\.js)$/.test(
    url.pathname,
  );
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  if (isKokoroRuntime(url)) {
    event.respondWith(
      caches.open(KOKORO_CACHE).then((cache) =>
        cache.match(req).then((cached) => {
          if (cached) return cached;
          return fetch(req).then((resp) => {
            if (resp.ok) cache.put(req, resp.clone());
            return resp;
          });
        }),
      ),
    );
    return;
  }

  if (isLiturgyData(url)) {
    event.respondWith(
      fetch(req, { cache: 'no-store' })
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

  // App shell (HTML/JS principal): network-first para refletir novos deploys na hora,
  // mantendo funcionamento 100% offline via fallback do cache.
  if (isAppShell(req, url)) {
    event.respondWith(
      fetch(req, { cache: 'no-cache' })
        .then((resp) => {
          if (resp.ok && resp.type === 'basic') {
            const copy = resp.clone();
            caches.open(APP_CACHE).then((c) => c.put(req, copy));
          }
          return resp;
        })
        .catch(() =>
          caches.open(APP_CACHE).then((cache) =>
            cache.match(req, { ignoreSearch: req.mode === 'navigate' }).then(
              (cached) => cached || (req.mode === 'navigate' ? cache.match('index.html') : Response.error()),
            ),
          ),
        ),
    );
    return;
  }

  // Assets estáticos (fontes, arte sacra, WASM, módulos): stale-while-revalidate.
  event.respondWith(
    caches.open(APP_CACHE).then((cache) =>
      cache.match(req).then((cached) => {
        const network = fetch(req)
          .then((resp) => {
            if (resp.ok && resp.type === 'basic') cache.put(req, resp.clone());
            return resp;
          })
          .catch(() => cached || Response.error());
        return cached || network;
      }),
    ),
  );
});
