// Ponte leve para Piper TTS neural em WebAssembly (@diffusionstudio/vits-web).
// O modelo pt_BR-cadu-medium (~60 MB) só é baixado sob demanda quando o usuário
// toca em "Ouvir" em textos em português (Bíblia, Homilia ou Liturgia offline),
// ficando armazenado permanentemente no OPFS do navegador.
(function () {
  const VOICE_ID = 'pt_BR-cadu-medium';
  const VITS_URL = 'https://cdn.jsdelivr.net/npm/@diffusionstudio/vits-web/+esm';

  let vitsPromise = null;
  let currentAudio = null;
  let currentUrl = null;
  let activeToken = 0;

  function loadVits() {
    if (!vitsPromise) {
      vitsPromise = import(VITS_URL);
    }
    return vitsPromise;
  }

  function cleanupAudio() {
    if (currentAudio) {
      try {
        currentAudio.pause();
        currentAudio.src = '';
      } catch (_) {}
      currentAudio = null;
    }
    if (currentUrl) {
      try {
        URL.revokeObjectURL(currentUrl);
      } catch (_) {}
      currentUrl = null;
    }
  }

  window.viaSacraPiper = {
    stop() {
      activeToken++;
      cleanupAudio();
    },

    async speak(text, speed) {
      const token = ++activeToken;
      cleanupAudio();
      const tts = await loadVits();
      if (token !== activeToken) return true;

      const wav = await tts.predict({ text: String(text || ''), voiceId: VOICE_ID });
      if (token !== activeToken) return true;

      return await new Promise((resolve, reject) => {
        const url = URL.createObjectURL(wav);
        const audio = new Audio(url);
        audio.playbackRate = Math.max(0.5, Math.min(2.0, Number(speed) || 1.0));
        currentAudio = audio;
        currentUrl = url;

        const finish = () => {
          if (currentAudio === audio) cleanupAudio();
          resolve(true);
        };
        audio.onended = finish;
        audio.onpause = () => {
          if (token !== activeToken) finish();
        };
        audio.onerror = (e) => {
          if (currentAudio === audio) cleanupAudio();
          reject(e);
        };
        audio.play().catch((err) => {
          if (currentAudio === audio) cleanupAudio();
          reject(err);
        });
      });
    },
  };
})();
