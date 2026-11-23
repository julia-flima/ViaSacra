/* Via Sacra — service worker (offline-first).
 *
 * • App (HTML/JS/WASM/fontes/assets): "stale-while-revalidate" — abre na hora a
 *   partir do cache e atualiza em segundo plano para a próxima visita.
 * • Liturgia (JSON do jsDelivr / GitHub): "network-first" com fallback ao cache.
 * • Nada de terceiros além dessas fontes de dados; nenhuma telemetria.
 *
 * VERSION é substituída no deploy (deploy-web.yml) para invalidar caches antigos.
 */
const VERSION = 'dd1ba391c008';
const APP_CACHE = `via-sacra-app-${VERSION}`;
const DATA_CACHE = 'via-sacra-dados';
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
          .filter((k) => (k.startsWith('via-sacra-app-') && k !== APP_CACHE) || k === DATA_CACHE)
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

/* Lembretes (issue #59), sem servidor. O app manda a lista dos próximos 14 dias
 * ({tag, at, title, body, payload}); aqui ela fica guardada e cada lembrete é
 * mostrado uma única vez quando a hora chega:
 * • com o app aberto (mesmo em segundo plano), na hora certa: o app pede "verificar";
 * • com o PWA instalado no Chrome, quando o navegador acorda este service worker
 *   (Periodic Background Sync: horário aproximado, o navegador decide).
 * Toque na notificação: abre (ou traz à frente) o app na aba do lembrete.
 */
const REMINDERS_CACHE = 'via-sacra-lembretes';
const REMINDERS_KEY = 'lembretes.json';

async function readReminders() {
  const resp = await (await caches.open(REMINDERS_CACHE)).match(REMINDERS_KEY);
  return resp ? resp.json() : { itens: [], mostrados: [] };
}

async function writeReminders(state) {
  await (await caches.open(REMINDERS_CACHE)).put(REMINDERS_KEY, new Response(JSON.stringify(state)));
}

// Mostra os lembretes vencidos há no máximo `atrasoMax` ms e ainda não mostrados.
async function showDueReminders(atrasoMax) {
  const state = await readReminders();
  const agora = Date.now();
  const vencidos = state.itens.filter(
    (r) => r.at <= agora && agora - r.at <= atrasoMax && !state.mostrados.includes(r.tag),
  );
  for (const r of vencidos) {
    await self.registration.showNotification(r.title, {
      body: r.body,
      tag: r.tag,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { payload: r.payload },
    });
    state.mostrados.push(r.tag);
  }
  if (vencidos.length) {
    state.mostrados = state.mostrados.slice(-60);
    await writeReminders(state);
  }
}

self.addEventListener('message', (event) => {
  const msg = event.data || {};
  if (msg.tipo === 'lembretes') {
    event.waitUntil(
      readReminders().then(async (state) => {
        await writeReminders({ itens: msg.itens || [], mostrados: state.mostrados });
        // Só no Chrome com o PWA instalado; nos demais casos a chamada falha e tudo bem.
        const sync = self.registration.periodicSync;
        if (!sync) return;
        if ((msg.itens || []).length) {
          await sync.register('lembretes', { minInterval: 12 * 60 * 60 * 1000 }).catch(() => {});
        } else {
          await sync.unregister('lembretes').catch(() => {});
        }
      }),
    );
  } else if (msg.tipo === 'verificar') {
    event.waitUntil(showDueReminders(5 * 60 * 1000));
  }
});

// O navegador decide quando acordar: aceita um atraso de até 12 h (melhor tarde que nunca).
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'lembretes') event.waitUntil(showDueReminders(12 * 60 * 60 * 1000));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const payload = (event.notification.data && event.notification.data.payload) || 'liturgia';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clients) => {
      const aberto = clients[0];
      if (aberto) {
        aberto.postMessage({ tipo: 'abrir', payload });
        return aberto.focus();
      }
      return self.clients.openWindow(`./?abrir=${encodeURIComponent(payload)}`);
    }),
  );
});
