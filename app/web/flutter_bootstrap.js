{{flutter_js}}
{{flutter_build_config}}

// Via Sacra: sem o service worker legado do Flutter (usamos o nosso, sw.js) e
// sem buscar nada em CDNs do Google — CanvasKit é servido daqui mesmo
// (build com --no-web-resources-cdn) e todas as fontes estão embutidas no app.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
    // Fontes de fallback ficariam em fonts.gstatic.com; apontamos para um caminho
    // local inexistente: se faltar algum glifo, nada é requisitado a terceiros.
    fontFallbackBaseUrl: 'assets/fonts/sem-fallback-externo/',
  },
});
