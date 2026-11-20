/// Checagens de URL usadas pelas WebViews e pelos embeds (issue #14).
abstract final class UrlSafety {
  /// [host] é [domain] ou um subdomínio dele: "www.vatican.va" passa para
  /// "vatican.va"; "evilvatican.va" e "vatican.va.evil.com" não passam.
  static bool isHostOf(String host, String domain) {
    final h = host.toLowerCase();
    final d = domain.toLowerCase();
    return h == d || h.endsWith('.$d');
  }

  /// URL HTTPS cujo host pertence a um dos [domains].
  static bool isHttpsIn(Uri uri, Iterable<String> domains) =>
      uri.scheme == 'https' && domains.any((d) => isHostOf(uri.host, d));

  static final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// IDs de vídeo do YouTube têm 11 caracteres de [A-Za-z0-9_-].
  static bool isYoutubeId(String id) => _youtubeId.hasMatch(id);
}
