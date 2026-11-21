// Web Worker dedicado do motor Kokoro-82M (WebGPU com fallback WASM) e eSpeak-NG (WASM).
// Versões de dependências e revisão do modelo são fixadas para reprodutibilidade e cache offline.

const CACHE_NAME = 'via-sacra-kokoro-v1';
const ORT_BASE = 'https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/';
const EPHONE_URL = 'https://cdn.jsdelivr.net/npm/ephone@1.0.2/ephone.js';
const HF_REV = '1939ad2a8e416c0acfeecc08a694d14ef25f2231';
const HF_BASE = `https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/${HF_REV}`;
const MODEL_URL = `${HF_BASE}/onnx/model_quantized.onnx`;
const TOKENIZER_URL = `${HF_BASE}/tokenizer.json`;
const SAMPLE_RATE = 24000;
const MAX_PHONEME_TOKENS = 490;
const SILENCE_SAMPLES = Math.round(SAMPLE_RATE * 0.12);

const voiceUrl = (id) => `${HF_BASE}/voices/${id}.bin`;

let ort = null;
let ephone = null;
let vocab = null;
let session = null;
let activeDevice = null; // 'webgpu' | 'wasm'
let initPromise = null;
const voiceCache = new Map();

let queue = Promise.resolve();
let minValidId = 0;

function postStatus(payload) {
  self.postMessage({ type: 'status', ...payload });
}

async function openKokoroCache() {
  if (typeof caches === 'undefined') return null;
  try {
    return await caches.open(CACHE_NAME);
  } catch (_) {
    return null;
  }
}

async function computeCacheStats() {
  const cache = await openKokoroCache();
  if (!cache) return { cached: Boolean(session), cacheBytes: 0 };
  try {
    const reqs = await cache.keys();
    let hasModel = false;
    let total = 0;
    for (const req of reqs) {
      if (req.url === MODEL_URL) hasModel = true;
      const resp = await cache.match(req);
      if (!resp) continue;
      const lenHeader = Number(resp.headers.get('content-length'));
      if (Number.isFinite(lenHeader) && lenHeader > 0) {
        total += lenHeader;
      } else {
        const buf = await resp.clone().arrayBuffer();
        total += buf.byteLength;
      }
    }
    return { cached: hasModel, cacheBytes: total };
  } catch (_) {
    return { cached: Boolean(session), cacheBytes: 0 };
  }
}

async function fetchCachedBytes(url, label, onProgress) {
  const cache = await openKokoroCache();
  if (cache) {
    try {
      const hit = await cache.match(url);
      if (hit && hit.ok) {
        return new Uint8Array(await hit.arrayBuffer());
      }
    } catch (_) {}
  }

  const resp = await fetch(url, { mode: 'cors' });
  if (!resp.ok) {
    throw new Error(`HTTP ${resp.status} ao baixar ${label}`);
  }

  const contentType = resp.headers.get('content-type') || 'application/octet-stream';
  const total = Number(resp.headers.get('content-length')) || 0;
  let bytes;

  if (resp.body && onProgress) {
    const reader = resp.body.getReader();
    const chunks = [];
    let loaded = 0;
    let lastReport = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      loaded += value.byteLength;
      const now = performance.now();
      if (now - lastReport >= 100) {
        lastReport = now;
        onProgress(total > 0 ? Math.min(loaded / total, 0.99) : null, loaded, total);
      }
    }
    bytes = new Uint8Array(loaded);
    let offset = 0;
    for (const c of chunks) {
      bytes.set(c, offset);
      offset += c.byteLength;
    }
    onProgress(1, loaded, total || loaded);
  } else {
    bytes = new Uint8Array(await resp.arrayBuffer());
  }

  if (cache) {
    try {
      await cache.put(
        url,
        new Response(bytes, {
          status: 200,
          headers: {
            'Content-Type': contentType,
            'Content-Length': String(bytes.byteLength),
          },
        }),
      );
    } catch (_) {}
  }

  return bytes;
}

async function detectWebGpu() {
  try {
    if (typeof navigator === 'undefined' || !navigator.gpu) return false;
    const adapter = await navigator.gpu.requestAdapter();
    return Boolean(adapter);
  } catch (_) {
    return false;
  }
}

async function createSession(modelBytes, preferWebGpu) {
  if (preferWebGpu) {
    try {
      const s = await ort.InferenceSession.create(modelBytes, { executionProviders: ['webgpu', 'wasm'] });
      activeDevice = 'webgpu';
      return s;
    } catch (_) {}
  }
  const s = await ort.InferenceSession.create(modelBytes, { executionProviders: ['wasm'] });
  activeDevice = 'wasm';
  return s;
}

async function runInit() {
  postStatus({ state: 'downloading', progress: 0.02, label: 'Carregando fonemizador pt-BR…' });
  const [{ default: createEphone, roa, en_us }, tokBytes, hasWebGpu] = await Promise.all([
    import(EPHONE_URL),
    fetchCachedBytes(TOKENIZER_URL, 'tokenizer'),
    detectWebGpu(),
  ]);

  ephone = await createEphone([roa, en_us]);
  const tokenizer = JSON.parse(new TextDecoder().decode(tokBytes));
  vocab = tokenizer.model.vocab;

  postStatus({ state: 'downloading', progress: 0.08, label: 'Carregando motor ONNX…' });
  ort = await import(hasWebGpu ? `${ORT_BASE}ort.webgpu.min.mjs` : `${ORT_BASE}ort.wasm.min.mjs`);
  ort.env.wasm.wasmPaths = ORT_BASE;
  ort.env.wasm.proxy = false;
  ort.env.wasm.numThreads = self.crossOriginIsolated ? Math.min(navigator.hardwareConcurrency || 4, 4) : 1;

  const modelBytes = await fetchCachedBytes(
    MODEL_URL,
    'Baixando voz neural Kokoro (~92 MB)…',
    (ratio) => {
      postStatus({
        state: 'downloading',
        progress: ratio == null ? null : 0.1 + ratio * 0.82,
        label:
          ratio == null
            ? 'Baixando voz neural Kokoro…'
            : `Baixando voz neural Kokoro (${Math.round(ratio * 100)}%)…`,
      });
    },
  );

  postStatus({ state: 'loading', progress: 0.95, label: 'Inicializando modelo de voz…', device: hasWebGpu ? 'webgpu' : 'wasm' });
  session = await createSession(modelBytes, hasWebGpu);
}

async function ensureReady() {
  if (session) return;
  if (!initPromise) {
    initPromise = runInit().catch((err) => {
      initPromise = null;
      throw err;
    });
  }
  await initPromise;
}

async function ensureVoice(voiceId) {
  if (voiceCache.has(voiceId)) return voiceCache.get(voiceId);
  const bytes = await fetchCachedBytes(voiceUrl(voiceId), `voz ${voiceId}`);
  const floats = new Float32Array(bytes.buffer, bytes.byteOffset, Math.floor(bytes.byteLength / 4));
  voiceCache.set(voiceId, floats);
  return floats;
}

function resolveVoiceSpec(language, preferredVoice) {
  const prefMale = preferredVoice === 'pm_alex';
  const lang = String(language || 'pt-BR').toLowerCase();
  if (lang.startsWith('en')) {
    return { kokoroVoice: prefMale ? 'am_michael' : 'af_heart', ephoneVoice: 'en-US' };
  }
  if (lang.startsWith('la') || lang.startsWith('it')) {
    return { kokoroVoice: prefMale ? 'im_nicola' : 'if_sara', ephoneVoice: 'it' };
  }
  if (lang.startsWith('es')) {
    return { kokoroVoice: prefMale ? 'em_alex' : 'ef_dora', ephoneVoice: 'es' };
  }
  return { kokoroVoice: prefMale ? 'pm_alex' : 'pf_dora', ephoneVoice: 'pt-BR' };
}

function normalizeTextForSpeech(raw) {
  return String(raw || '')
    .replace(/[«»“”]/g, '"')
    .replace(/[‘’]/g, "'")
    .replace(/[—–]/g, ', ')
    .replace(/§\s*/g, 'parágrafo ')
    .replace(/\s+/g, ' ')
    .trim();
}

function mapIpaToKokoro(ipa, ephoneVoice) {
  let s = ipa
    .normalize('NFD')
    .replaceAll('dʒ', 'ʤ')
    .replaceAll('tʃ', 'ʧ')
    .replaceAll('dz', 'ʣ')
    .replaceAll('ts', 'ʦ')
    .replaceAll('aɪ', 'I')
    .replaceAll('aʊ', 'W')
    .replaceAll('eɪ', 'A')
    .replaceAll('oʊ', 'O')
    .replaceAll('əʊ', 'Q')
    .replaceAll('ɔɪ', 'Y')
    .replaceAll('g', 'ɡ')
    .replace(/(\S)\u0329/g, 'ᵊ$1')
    .replaceAll('\u0329', '')
    .replaceAll('-', '');
  if (ephoneVoice === 'en-US') {
    s = s
      .replaceAll('ʲ', 'j')
      .replaceAll('r', 'ɹ')
      .replaceAll('x', 'k')
      .replaceAll('ɬ', 'l')
      .replaceAll('ʔ', 't')
      .replaceAll('ɾ', 'T');
  }
  return s;
}

function tokenizePhonemes(phonemes) {
  const ids = [];
  for (const ch of phonemes) {
    const id = vocab[ch];
    if (typeof id === 'number') ids.push(id);
  }
  return ids;
}

// Divide em sentenças (. ! ? ; :) e as longas nas vírgulas; junta pedaços muito curtos.
// Pedaços menores = o som começa antes. No navegador a síntese roda em uma só thread
// (~2× o tempo da fala, medido em 2026-11), então esperar a frase inteira atrasava muito.
function splitSentences(text) {
  const out = [];
  let buf = '';
  const push = (piece) => {
    buf = buf ? `${buf} ${piece}` : piece;
    if (buf.length >= 24) {
      out.push(buf);
      buf = '';
    }
  };
  for (const m of text.matchAll(/[^.!?;:]+[.!?;:]*/g)) {
    const sentence = m[0].trim();
    if (!sentence) continue;
    if (sentence.length <= 90) {
      push(sentence);
      continue;
    }
    for (const c of sentence.matchAll(/[^,]+,?/g)) push(c[0].trim());
  }
  if (buf) out.push(buf);
  return out;
}

function splitTokenChunks(tokenIds) {
  if (tokenIds.length <= MAX_PHONEME_TOKENS) return [tokenIds];
  const breakIds = new Set(
    ['.', '!', '?', ',', ':', ';', ' '].map((c) => vocab[c]).filter((v) => typeof v === 'number'),
  );
  const chunks = [];
  let start = 0;
  while (start < tokenIds.length) {
    if (tokenIds.length - start <= MAX_PHONEME_TOKENS) {
      chunks.push(tokenIds.slice(start));
      break;
    }
    let split = -1;
    const min = start + Math.floor(MAX_PHONEME_TOKENS * 0.4);
    for (let i = start + MAX_PHONEME_TOKENS - 1; i >= min; i--) {
      if (breakIds.has(tokenIds[i])) {
        split = i + 1;
        break;
      }
    }
    if (split <= start) split = start + MAX_PHONEME_TOKENS;
    chunks.push(tokenIds.slice(start, split));
    start = split;
  }
  return chunks;
}

function isValidWaveform(arr) {
  if (!arr || arr.length === 0) return false;
  const step = Math.max(1, Math.floor(arr.length / 256));
  for (let i = 0; i < arr.length; i += step) {
    const v = arr[i];
    if (!Number.isFinite(v) || Math.abs(v) > 10.0) return false;
  }
  return true;
}

async function fallbackToWasmSession() {
  try {
    await session?.release?.();
  } catch (_) {}
  const modelBytes = await fetchCachedBytes(MODEL_URL, 'Baixando voz neural Kokoro…');
  session = await ort.InferenceSession.create(modelBytes, { executionProviders: ['wasm'] });
  activeDevice = 'wasm';
}

async function runChunkInference(tokenIds, styleFloats, speedVal) {
  const padded = new BigInt64Array(tokenIds.length + 2);
  padded[0] = 0n;
  for (let i = 0; i < tokenIds.length; i++) padded[i + 1] = BigInt(tokenIds[i]);
  padded[padded.length - 1] = 0n;

  const styleOffset = Math.min(Math.max(tokenIds.length, 0), 509) * 256;
  const styleSlice = styleFloats.subarray(styleOffset, styleOffset + 256);

  const inputs = {
    input_ids: new ort.Tensor('int64', padded, [1, padded.length]),
    style: new ort.Tensor('float32', styleSlice, [1, 256]),
    speed: new ort.Tensor('float32', Float32Array.from([speedVal]), [1]),
  };

  let outputs;
  try {
    outputs = await session.run(inputs);
  } catch (err) {
    if (activeDevice === 'webgpu') {
      await fallbackToWasmSession();
      outputs = await session.run(inputs);
    } else {
      throw err;
    }
  }

  let data = outputs.waveform.data;
  if (activeDevice === 'webgpu' && !isValidWaveform(data)) {
    await fallbackToWasmSession();
    outputs = await session.run(inputs);
    data = outputs.waveform.data;
  }
  return data instanceof Float32Array ? new Float32Array(data) : Float32Array.from(data);
}

function concatWaveforms(parts) {
  if (parts.length === 1) return parts[0];
  const totalLen = parts.reduce((acc, p) => acc + p.length, 0) + (parts.length - 1) * SILENCE_SAMPLES;
  const out = new Float32Array(totalLen);
  let offset = 0;
  for (let i = 0; i < parts.length; i++) {
    out.set(parts[i], offset);
    offset += parts[i].length;
    if (i < parts.length - 1) offset += SILENCE_SAMPLES;
  }
  return out;
}

function enqueue(fn) {
  const next = queue.then(fn, fn);
  queue = next.catch(() => {});
  return next;
}

self.onmessage = (event) => {
  const msg = event.data || {};
  if (msg.type === 'cancel') {
    minValidId = Math.max(minValidId, msg.minId || 0);
    return;
  }

  if (msg.type === 'status') {
    computeCacheStats().then((stats) => {
      self.postMessage({
        type: 'statusResult',
        reqId: msg.reqId,
        status: {
          state: session ? 'ready' : 'idle',
          device: activeDevice,
          ...stats,
        },
      });
    });
    return;
  }

  if (msg.type === 'preload') {
    enqueue(async () => {
      try {
        await ensureReady();
        const spec = resolveVoiceSpec('pt-BR', msg.voice);
        await ensureVoice(spec.kokoroVoice);
        const stats = await computeCacheStats();
        postStatus({ state: 'ready', device: activeDevice, ...stats });
        self.postMessage({ type: 'preloadResult', reqId: msg.reqId, ok: true });
      } catch (err) {
        const stats = await computeCacheStats();
        postStatus({ state: 'error', error: String(err?.message || err), ...stats });
        self.postMessage({ type: 'preloadResult', reqId: msg.reqId, ok: false, error: String(err?.message || err) });
      }
    });
    return;
  }

  if (msg.type === 'clearCache') {
    const clearThreshold = Number(msg.minId) || 0;
    minValidId = Math.max(minValidId, clearThreshold);
    enqueue(async () => {
      try {
        try {
          await session?.release?.();
        } catch (_) {}
        session = null;
        initPromise = null;
        activeDevice = null;
        voiceCache.clear();
        if (typeof caches !== 'undefined') {
          await caches.delete(CACHE_NAME);
        }
        postStatus({ state: 'idle', device: null, cached: false, cacheBytes: 0 });
        self.postMessage({ type: 'clearResult', reqId: msg.reqId, ok: true });
      } catch (err) {
        self.postMessage({ type: 'clearResult', reqId: msg.reqId, ok: false, error: String(err?.message || err) });
      }
    });
    return;
  }

  if (msg.type === 'synthesize') {
    enqueue(async () => {
      if (msg.id < minValidId) {
        self.postMessage({ type: 'synthResult', id: msg.id, cancelled: true });
        return;
      }
      try {
        await ensureReady();
        if (msg.id < minValidId) {
          self.postMessage({ type: 'synthResult', id: msg.id, cancelled: true });
          return;
        }
        const { kokoroVoice, ephoneVoice } = resolveVoiceSpec(msg.language, msg.voice);
        const styleFloats = await ensureVoice(kokoroVoice);
        const cleanText = normalizeTextForSpeech(msg.text);
        if (!cleanText) {
          self.postMessage({ type: 'synthResult', id: msg.id, empty: true });
          return;
        }

        ephone.setVoice(ephoneVoice);
        const rawIpa = ephone.textToIpa(cleanText);
        const kokoroPhonemes = mapIpaToKokoro(rawIpa, ephoneVoice);
        const tokenIds = tokenizePhonemes(kokoroPhonemes);
        if (tokenIds.length === 0) {
          self.postMessage({ type: 'synthResult', id: msg.id, empty: true });
          return;
        }

        const speed = Math.max(0.5, Math.min(2.0, Number(msg.speed) || 1.0));
        // Uma sentença por vez: cada uma é enviada assim que fica pronta e já pode tocar,
        // em vez de esperar o trecho inteiro (era a espera longa no Salmo).
        // Tempo de síntese e duração do áudio: a página mede se o Kokoro acompanha a fala aqui.
        let synthMs = 0;
        let audioMs = 0;
        for (const sentence of splitSentences(cleanText)) {
          const ids = tokenizePhonemes(mapIpaToKokoro(ephone.textToIpa(sentence), ephoneVoice));
          for (const chunk of ids.length ? splitTokenChunks(ids) : []) {
            if (msg.id < minValidId) {
              self.postMessage({ type: 'synthResult', id: msg.id, cancelled: true });
              return;
            }
            const t0 = performance.now();
            const pcm = await runChunkInference(chunk, styleFloats, speed);
            synthMs += performance.now() - t0;
            audioMs += (pcm.length * 1000) / SAMPLE_RATE;
            self.postMessage({ type: 'synthPart', id: msg.id, pcm, sampleRate: SAMPLE_RATE }, [pcm.buffer]);
          }
        }

        const stats = await computeCacheStats();
        postStatus({ state: 'ready', device: activeDevice, ...stats });
        self.postMessage({ type: 'synthResult', id: msg.id, done: true, synthMs, audioMs });
      } catch (err) {
        const stats = await computeCacheStats();
        postStatus({ state: 'error', error: String(err?.message || err), ...stats });
        self.postMessage({ type: 'synthResult', id: msg.id, error: String(err?.message || err) });
      }
    });
  }
};
