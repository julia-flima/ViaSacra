import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/url_safety.dart';
import '../../widgets/common.dart';

/// Abre um documento oficial do `vatican.va`:
/// - No Android e iOS: abre no [VaticanReaderScreen] integrado com CSS do Via Sacra
///   (sem copiar nem hospedar o texto protegido — 100% compatível com o F-Droid).
/// - Na Web/Desktop (onde `vatican.va` envia `X-Frame-Options: SAMEORIGIN`): abre a
///   seção oficial diretamente em uma nova aba.
Future<void> openVaticanDocument(BuildContext context, {required String title, required String url}) async {
  final nativeWebView =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (!nativeWebView) {
    await openExternal(context, url);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VaticanReaderScreen(title: title, url: url),
    ),
  );
}

/// Leitor integrado para páginas oficiais do portal `vatican.va` (CIC 1992 e
/// Compêndio 2005), com injeção leve de CSS para adaptar cores (Pergaminho /
/// Modo Igreja), tipografia e margens ao visual do Via Sacra.
class VaticanReaderScreen extends StatefulWidget {
  const VaticanReaderScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<VaticanReaderScreen> createState() => _VaticanReaderScreenState();
}

class _VaticanReaderScreenState extends State<VaticanReaderScreen> {
  static const _allowedDomains = ['vatican.va'];

  late final WebViewController _controller;
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _error = null);
          },
          onPageFinished: (_) async {
            await _injectViaSacraCss();
            await _syncHistory();
          },
          // Só páginas do vatican.va abrem aqui (com JS e o CSS do app);
          // qualquer outro link vai para o navegador do aparelho.
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            if (uri == null) return NavigationDecision.prevent;
            if (UrlSafety.isHttpsIn(uri, _allowedDomains)) return NavigationDecision.navigate;
            if (uri.scheme == 'http' && _allowedDomains.any((d) => UrlSafety.isHostOf(uri.host, d))) {
              unawaited(_controller.loadRequest(uri.replace(scheme: 'https')));
              return NavigationDecision.prevent;
            }
            if (req.isMainFrame && (uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'mailto')) {
              unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (err) {
            if (mounted && (err.isForMainFrame ?? true)) {
              setState(() => _error = err.description);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _syncHistory() async {
    final back = await _controller.canGoBack();
    final fwd = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = fwd;
      });
    }
  }

  String _hex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  Future<void> _injectViaSacraCss() async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final bg = _hex(cs.surface);
    final fg = _hex(cs.onSurface);
    final accent = _hex(cs.primary);
    final muted = _hex(cs.onSurfaceVariant);

    final css =
        '''
      html, body {
        background: $bg !important;
        color: $fg !important;
        font-family: Georgia, "Times New Roman", serif !important;
        font-size: 17px !important;
        line-height: 1.75 !important;
        max-width: 740px !important;
        margin: 0 auto !important;
        padding: 12px 18px 48px 18px !important;
        box-sizing: border-box !important;
      }
      body * {
        background-color: transparent !important;
        color: inherit !important;
        max-width: 100% !important;
      }
      a, a * { color: $accent !important; text-decoration-thickness: 1px; }
      h1, h2, h3, h4, b, strong { color: $fg !important; }
      hr { border: none; border-top: 1px solid $muted; opacity: 0.25; margin: 20px 0; }
      img[src*="top"], img[src*="logo"], img[src*="ind"], table[width="100%"] img { display: none !important; }
      table { width: 100% !important; border-collapse: collapse !important; }
      td { padding: 4px !important; }
    ''';

    final js =
        '''
      (function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          document.head.appendChild(meta);
        }
        meta.content = 'width=device-width, initial-scale=1.0';
        var id = 'viasacra-reader-css';
        var el = document.getElementById(id);
        if (!el) {
          el = document.createElement('style');
          el.id = id;
          document.head.appendChild(el);
        }
        el.textContent = ${jsonEncode(css)};
      })();
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Ignora falhas transitórias se a página navegar antes da injeção.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_canGoBack)
            IconButton(
              tooltip: 'Voltar página',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _controller.goBack(),
            ),
          if (_canGoForward)
            IconButton(
              tooltip: 'Avançar página',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _controller.goForward(),
            ),
          IconButton(tooltip: 'Recarregar', icon: const Icon(Icons.refresh), onPressed: () => _controller.reload()),
          IconButton(
            tooltip: 'Abrir no navegador',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openExternal(context, widget.url),
          ),
        ],
        bottom: _progress > 0 && _progress < 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress),
              )
            : null,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Não foi possível carregar o portal do Vaticano.', style: t.titleMedium),
                    const SizedBox(height: 8),
                    Text(_error!, style: t.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _controller.reload(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => openExternal(context, widget.url),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Abrir no navegador'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
