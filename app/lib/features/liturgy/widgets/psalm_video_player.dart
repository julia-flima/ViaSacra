import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme.dart';
import '../../../data/models/liturgy.dart';
import '../../../widgets/common.dart';
import 'psalm_video_embed_stub.dart' if (dart.library.js_interop) 'psalm_video_embed_web.dart';

/// Player incorporado do Salmo Responsorial cantado via embed oficial
/// `youtube-nocookie.com` (100% FOSS / F-Droid — sem SDK proprietário).
///
/// - **Android / iOS**: `webview_flutter` com `baseUrl` HTTPS e
///   `referrerpolicy="strict-origin-when-cross-origin"` (evita o Erro 153 do YouTube).
/// - **Web**: `<iframe>` nativo via `HtmlElementView.fromTagName`.
/// - **Desktop**: atalho direto para abrir o vídeo oficial no navegador.
class PsalmVideoPlayer extends StatefulWidget {
  const PsalmVideoPlayer({super.key, required this.videoId, this.title, this.credit});

  final String videoId;
  final String? title;
  final AudioCredit? credit;

  @override
  State<PsalmVideoPlayer> createState() => _PsalmVideoPlayerState();
}

class _PsalmVideoPlayerState extends State<PsalmVideoPlayer> {
  static const _origin = 'https://julia-flima.github.io';
  WebViewController? _controller;
  bool _loading = true;

  bool get _isMobileWebView =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  String get _watchUrl => 'https://www.youtube.com/watch?v=${widget.videoId}';

  @override
  void initState() {
    super.initState();
    if (_isMobileWebView) {
      _initMobileWebView();
    } else {
      _loading = false;
    }
  }

  void _initMobileWebView() {
    final safeId = widget.videoId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final html =
        '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #12100E; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: 0; display: block; }
  </style>
</head>
<body>
  <iframe
    src="https://www.youtube-nocookie.com/embed/$safeId?rel=0&playsinline=1&origin=$_origin"
    title="Salmo Responsorial Cantado"
    referrerpolicy="strict-origin-when-cross-origin"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen>
  </iframe>
</body>
</html>
''';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF12100E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            if (uri == null) return NavigationDecision.prevent;
            final host = uri.host.toLowerCase();
            final allowed =
                host.endsWith('youtube-nocookie.com') ||
                host.endsWith('youtube.com') ||
                host.endsWith('googlevideo.com') ||
                host == 'julia-flima.github.io';
            if (!allowed) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: '$_origin/ViaSacra/');
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(_watchUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final webEmbed = kIsWeb ? buildWebYoutubeEmbed(widget.videoId, widget.title) : null;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (webEmbed != null)
            AspectRatio(aspectRatio: 16 / 9, child: webEmbed)
          else if (_controller != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller!),
                  if (_loading)
                    const ColoredBox(
                      color: Color(0xFF12100E),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(VsSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title ?? 'Salmo Responsorial Cantado',
                      style: t.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _openExternal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Abrir'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(VsSpacing.md, 6, VsSpacing.sm, 8),
            child: Row(
              children: [
                Expanded(
                  child: SourceAttribution(
                    source: [widget.credit?.channel ?? widget.credit?.performer ?? 'YouTube']
                        .whereType<String>()
                        .join(' · '),
                    url: widget.credit?.sourceUrl ?? _watchUrl,
                    license: widget.credit?.license ?? 'YouTube Embed Oficial',
                  ),
                ),
                TextButton.icon(
                  onPressed: _openExternal,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('YouTube'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
