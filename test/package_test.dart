import 'dart:io';

import 'package:arb_guard/arb_guard.dart';
import 'package:test/test.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('packageVersion matches pubspec.yaml', () {
    final version = RegExp(
      r'^version: (\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(packageVersion, version);
  });

  test('version is 0.1.4', () {
    expect(packageVersion, '0.1.4');
    final r = Process.runSync('dart', [
      'run',
      'bin/arb_guard.dart',
      '--version',
    ]);
    expect((r.stdout as String).trim(), 'arb_guard 0.1.4');
  });

  test('the only runtime dependency is args', () {
    final block =
        RegExp(
          r'^dependencies:\r?\n((?:  .*\r?\n)+)',
          multiLine: true,
        ).firstMatch(pubspec)!.group(1)!;
    final names =
        block
            .split(RegExp(r'\r?\n'))
            .where((l) => l.trim().isNotEmpty)
            .map((l) => l.trim().split(':').first)
            .toList();
    expect(names, ['args']);
  });

  test('the executable is declared', () {
    expect(pubspec, matches(RegExp(r'executables:\r?\n  arb_guard:')));
    expect(File('bin/arb_guard.dart').existsSync(), isTrue);
  });

  test('the rule catalog has AG001 to AG014 in order', () {
    expect(ruleCatalog.map((r) => r.id).toList(), [
      for (var i = 1; i <= 14; i++) 'AG${i.toString().padLeft(3, '0')}',
    ]);
  });

  test('both example folders hold four ARB files', () {
    for (final dir in ['example/clean', 'example/l10n']) {
      final files = Directory(
        dir,
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.arb'));
      expect(files, hasLength(4), reason: dir);
    }
  });
}
