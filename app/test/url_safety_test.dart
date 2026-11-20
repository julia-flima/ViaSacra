// Checagens de URL das WebViews e embeds (issue #14).
import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/core/url_safety.dart';

void main() {
  test('isHostOf aceita o domínio e subdomínios, nunca imitações', () {
    expect(UrlSafety.isHostOf('vatican.va', 'vatican.va'), isTrue);
    expect(UrlSafety.isHostOf('www.vatican.va', 'vatican.va'), isTrue);
    expect(UrlSafety.isHostOf('WWW.Vatican.VA', 'vatican.va'), isTrue);
    expect(UrlSafety.isHostOf('evilvatican.va', 'vatican.va'), isFalse);
    expect(UrlSafety.isHostOf('vatican.va.evil.com', 'vatican.va'), isFalse);
    expect(UrlSafety.isHostOf('evil-youtube.com', 'youtube.com'), isFalse);
    expect(UrlSafety.isHostOf('m.youtube.com', 'youtube.com'), isTrue);
  });

  test('isHttpsIn exige HTTPS e domínio permitido', () {
    const domains = ['vatican.va'];
    expect(UrlSafety.isHttpsIn(Uri.parse('https://www.vatican.va/archive/x.html'), domains), isTrue);
    expect(UrlSafety.isHttpsIn(Uri.parse('http://www.vatican.va/archive/x.html'), domains), isFalse);
    expect(UrlSafety.isHttpsIn(Uri.parse('https://exemplo.com/?u=vatican.va'), domains), isFalse);
    expect(UrlSafety.isHttpsIn(Uri.parse('javascript:alert(1)'), domains), isFalse);
  });

  test('isYoutubeId aceita só ids de 11 caracteres seguros', () {
    expect(UrlSafety.isYoutubeId('NHUXSd2fdhI'), isTrue);
    expect(UrlSafety.isYoutubeId('a-b_C123xyZ'), isTrue);
    expect(UrlSafety.isYoutubeId('curto'), isFalse);
    expect(UrlSafety.isYoutubeId('NHUXSd2fdhI?autoplay=1'), isFalse);
    expect(UrlSafety.isYoutubeId('"><script>x'), isFalse);
    expect(UrlSafety.isYoutubeId(''), isFalse);
  });
}
