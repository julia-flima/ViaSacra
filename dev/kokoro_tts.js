// Ponte principal do Kokoro-82M para Flutter Web: gerencia Worker dedicado,
// pré-síntese (lookahead) do bloco N+1 e reprodução sem lacunas via Web Audio API.
(function () {
  let worker = null;
  let audioCtx = null;
  let activeToken = 0;
  let nextId = 1;
  let currentStopPlayback = null;
  let prefetched = null; // { key, promise }
  const pending = new Map();
  const statusListeners = new Set();

  let currentStatus = {
    state: 'idle',
    progress: null,
    label: null,
    device: null,
    cached: false,
    cacheBytes: 0,
    error: null,
  };

  function emitStatus(patch) {
    currentStatus = { ...currentStatus, ...patch };
    if (patch.state !== 'error' && !('error' in patch)) {
      currentStatus.error = null;
    }
    for (const fn of statusListeners) {
      try {
        fn(currentStatus);
      } catch (_) {}
    }
  }

  function ensureWorker() {
    if (worker) return worker;
    const workerUrl = new URL('kokoro_worker.js', document.baseURI);
    const w = new Worker(workerUrl, { type: 'module' });
    w.onmessage = (event) => {
      const msg = event.data || {};
      if (msg.type === 'status') {
        const nextState = msg.state === 'ready' && currentStopPlayback ? 'speaking' : msg.state;
        emitStatus({
          state: nextState,
          progress: msg.progress ?? null,
          label: msg.label ?? null,
          device: msg.device ?? currentStatus.device,
          cached: msg.cached ?? currentStatus.cached,
          cacheBytes: msg.cacheBytes ?? currentStatus.cacheBytes,
          error: msg.error ?? null,
        });
        return;
      }

      if (msg.type === 'synthPart') {
        pending.get(msg.id)?.part(msg);
        return;
      }

      if (msg.type === 'synthResult') {
        const entry = pending.get(msg.id);
        if (!entry) return;
        pending.delete(msg.id);
        if (msg.error) entry.reject(new Error(msg.error));
        else entry.resolve(msg);
        return;
      }

      if (msg.type === 'statusResult') {
        const entry = pending.get(msg.reqId);
        if (!entry) return;
        pending.delete(msg.reqId);
        emitStatus(msg.status);
        entry.resolve(currentStatus);
        return;
      }

      if (msg.type === 'preloadResult' || msg.type === 'clearResult') {
        const entry = pending.get(msg.reqId);
        if (!entry) return;
        pending.delete(msg.reqId);
        entry.resolve(Boolean(msg.ok));
      }
    };

    w.onerror = (err) => {
      const msg = err?.message || 'Erro no Web Worker do Kokoro TTS';
      emitStatus({ state: 'error', progress: null, label: null, error: msg });
      for (const [, entry] of pending) {
        entry.reject(new Error(msg));
      }
      pending.clear();
      prefetched = null;
      worker = null;
    };

    worker = w;
    return w;
  }

  function unlockAudio() {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    if (!audioCtx) audioCtx = new Ctx();
    if (audioCtx.state === 'suspended') {
      audioCtx.resume().catch(() => {});
    }
    try {
      const silent = audioCtx.createBuffer(1, 1, 22050);
      const src = audioCtx.createBufferSource();
      src.buffer = silent;
      src.connect(audioCtx.destination);
      src.start(0);
    } catch (_) {}
    return audioCtx;
  }

  function makeKey(text, speed, voice, language) {
    return `${voice || 'pf_dora'}|${language || 'pt-BR'}|${Number(speed) || 1}|${text}`;
  }

  // Uma síntese em andamento: as sentenças chegam em `parts` à medida que ficam prontas.
  function requestSynthesize(text, speed, voice, language) {
    const id = nextId++;
    const w = ensureWorker();
    const startedAt = performance.now();
    const job = { parts: [], done: false, failed: false, waiters: [] };
    const wake = () => job.waiters.splice(0).forEach((fn) => fn());
    pending.set(id, {
      part(msg) {
        if (job.parts.length === 0) {
          console.debug(`VS-TTS web: 1ª sentença em ${Math.round(performance.now() - startedAt)} ms (${text.length} chars)`);
        }
        job.parts.push(msg);
        wake();
      },
      resolve() {
        job.done = true;
        wake();
      },
      reject() {
        job.done = true;
        job.failed = true;
        wake();
      },
    });
    w.postMessage({ type: 'synthesize', id, text, speed, voice, language });
    // Sentença [i], ou null quando a síntese acabou antes dela.
    job.part = async (i) => {
      while (i >= job.parts.length && !job.done) await new Promise((r) => job.waiters.push(r));
      return i < job.parts.length ? job.parts[i] : null;
    };
    return job;
  }

  function playPcm(pcm, sampleRate, token) {
    const ctx = unlockAudio();
    if (!ctx) return Promise.reject(new Error('AudioContext indisponível'));
    if (token !== activeToken) return Promise.resolve(true);

    return new Promise((resolve, reject) => {
      let finished = false;
      const source = ctx.createBufferSource();
      const buffer = ctx.createBuffer(1, pcm.length, sampleRate);
      buffer.getChannelData(0).set(pcm);
      source.buffer = buffer;
      source.connect(ctx.destination);

      const finish = (ok) => {
        if (finished) return;
        finished = true;
        if (currentStopPlayback === cancelPlayback) currentStopPlayback = null;
        try {
          source.disconnect();
        } catch (_) {}
        emitStatus({
          state: currentStatus.cached ? 'ready' : 'idle',
          progress: null,
          label: null,
        });
        resolve(ok);
      };

      const cancelPlayback = () => {
        try {
          source.onended = null;
          source.stop(0);
        } catch (_) {}
        finish(true);
      };

      currentStopPlayback = cancelPlayback;
      source.onended = () => finish(true);
      emitStatus({ state: 'speaking', progress: null, label: null });

      try {
        source.start(0);
      } catch (err) {
        if (currentStopPlayback === cancelPlayback) currentStopPlayback = null;
        reject(err);
      }
    });
  }

  window.viaSacraKokoro = {
    stop() {
      activeToken++;
      prefetched = null;
      if (currentStopPlayback) {
        currentStopPlayback();
      }
      if (worker) {
        worker.postMessage({ type: 'cancel', minId: nextId });
      }
    },

    async speak(text, speed, voice, language, nextText) {
      const token = ++activeToken;
      if (currentStopPlayback) currentStopPlayback();
      unlockAudio();

      const trimmed = String(text || '').trim();
      if (!trimmed) return true;

      const selectedVoice = voice || 'pf_dora';
      const selectedLang = language || 'pt-BR';
      const key = makeKey(trimmed, speed, selectedVoice, selectedLang);

      let job;
      if (prefetched && prefetched.key === key) {
        job = prefetched.job;
        prefetched = null;
      } else {
        prefetched = null;
        if (worker) worker.postMessage({ type: 'cancel', minId: nextId });
        job = requestSynthesize(trimmed, speed, selectedVoice, selectedLang);
      }

      // O próximo trecho entra na fila do worker já, para ele não ficar parado enquanto este toca.
      const nextTrimmed = nextText ? String(nextText).trim() : '';
      if (nextTrimmed) {
        const nextKey = makeKey(nextTrimmed, speed, selectedVoice, selectedLang);
        prefetched = { key: nextKey, job: requestSynthesize(nextTrimmed, speed, selectedVoice, selectedLang) };
      }

      try {
        let played = 0;
        for (let i = 0; ; i++) {
          const part = await job.part(i);
          if (token !== activeToken) return true;
          if (!part || !part.pcm || part.pcm.length === 0) break;
          await playPcm(part.pcm, part.sampleRate || 24000, token);
          if (token !== activeToken) return true;
          played++;
        }
        return played > 0 || !job.failed;
      } catch (_) {
        prefetched = null;
        return false;
      }
    },

    preload(voice) {
      const reqId = nextId++;
      const w = ensureWorker();
      return new Promise((resolve) => {
        pending.set(reqId, {
          resolve,
          reject: () => resolve(false),
        });
        w.postMessage({ type: 'preload', reqId, voice: voice || 'pf_dora' });
      });
    },

    clearCache() {
      activeToken++;
      prefetched = null;
      if (currentStopPlayback) currentStopPlayback();
      const reqId = nextId++;
      const w = ensureWorker();
      return new Promise((resolve) => {
        pending.set(reqId, {
          resolve,
          reject: () => resolve(false),
        });
        w.postMessage({ type: 'clearCache', reqId, minId: nextId });
      });
    },

    getStatus() {
      const reqId = nextId++;
      const w = ensureWorker();
      return new Promise((resolve) => {
        pending.set(reqId, {
          resolve,
          reject: () => resolve(currentStatus),
        });
        w.postMessage({ type: 'status', reqId });
      });
    },

    onStatus(callback) {
      if (typeof callback !== 'function') return;
      statusListeners.add(callback);
      try {
        callback(currentStatus);
      } catch (_) {}
    },
  };
})();
