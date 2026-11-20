// A versão exibida no app (Sobre) acompanha a do pubspec.yaml e da receita do F-Droid.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:via_sacra/core/constants.dart';

void main() {
  test('AppInfo.version, pubspec.yaml e receita do F-Droid estão sincronizados', () {
    final pubspec = RegExp(
      r'^version:\s*(\S+)\+(\d+)',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    final (name, code) = (pubspec.group(1)!, pubspec.group(2)!);
    expect(AppInfo.version, name, reason: 'atualize AppInfo.version em lib/core/constants.dart');

    final fdroid = File('../fdroid/io.github.juliaflima.via_sacra.yml').readAsStringSync();
    expect(fdroid, contains('CurrentVersion: $name'), reason: 'atualize fdroid/io.github.juliaflima.via_sacra.yml');
    expect(fdroid, contains('CurrentVersionCode: $code'));
    expect(fdroid, contains('commit: v$name'));
  });
}
