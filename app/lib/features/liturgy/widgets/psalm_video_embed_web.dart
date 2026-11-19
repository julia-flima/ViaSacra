import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Incorpora o player oficial `youtube-nocookie.com` via `<iframe>` na Web.
Widget? buildWebYoutubeEmbed(String videoId, String? title) {
  final origin = Uri.base.origin;
  final embedUrl =
      'https://www.youtube-nocookie.com/embed/$videoId'
      '?rel=0&playsinline=1&origin=${Uri.encodeComponent(origin)}';
  return HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (Object element) {
      final iframe = element as web.HTMLIFrameElement;
      iframe.src = embedUrl;
      iframe.title = title ?? 'Salmo Responsorial Cantado';
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
      iframe.allowFullscreen = true;
      iframe.referrerPolicy = 'strict-origin-when-cross-origin';
    },
  );
}
