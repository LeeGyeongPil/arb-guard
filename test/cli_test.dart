import 'dart:convert';
import 'dart:io';

import 'package:arb_guard/src/cli.dart';
import 'package:test/test.dart';

import 'helpers.dart';

class _Run {
  _Run(this.code, this.out, this.err);
  final int code;
  final String out;
  final String err;
}

Future<_Run> run(
  List<String> args, {
  Map<String, String> env = const {},
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(args, env: env, out: out, err: err);
  return _Run(code, out.toString(), err.toString());
}

void main() {
  test(
    'example/l10n fails with exactly the expected findings per rule',
    () async {
      final r = await run([
        'check',
        '--arb-dir',
        'example/l10n',
        '--format',
        'json',
      ]);
      expect(r.code, 1);
      final findings =
          (jsonDecode(r.out) as Map<String, Object?>)['findings']!
              as List<Object?>;
      final counts = <String, int>{};
      for (final f in findings) {
        final id = (f! as Map<String, Object?>)['ruleId']! as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      final expected =
          jsonDecode(
                File('test/fixtures/expected_example.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(counts, expected);
    },
  );

  test('example/clean has no findings and exits 0', () async {
    final r = await run([
      'check',
      '--arb-dir',
      'example/clean',
      '--lang',
      'en',
    ]);
    expect(r.code, 0);
    expect(r.out, contains('No findings.'));
    expect(r.out, contains('0 errors, 0 warnings'));
  });

  test('text output has file:line:col and the rule id', () async {
    final r = await run(['check', '--arb-dir', 'example/l10n', '--lang', 'en']);
    expect(
      r.out,
      contains('example/l10n/app_es.arb:3:3 error AG003 greeting:'),
    );
    expect(r.out, contains('example/l10n/app_es.arb:5:3 error AG004 invite:'));
  });

  test('missing folder exits 2', () async {
    final r = await run([
      'check',
      '--arb-dir',
      'does/not/exist',
      '--lang',
      'en',
    ]);
    expect(r.code, 2);
    expect(r.err, contains('ARB folder not found'));
  });

  test('--fail-on never exits 0 even with errors', () async {
    final r = await run([
      'check',
      '--arb-dir',
      'example/l10n',
      '--fail-on',
      'never',
    ]);
    expect(r.code, 0);
  });

  group('--fail-on warning', () {
    late Directory dir;
    setUp(() {
      dir = tempProject({
        'app_en.arb': '{"y": "{n, plural, one{1 year} other{{n} years}}"}',
        'app_es.arb': '{"y": "{n, plural, one{1 año} other{# años}}"}',
      });
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('warnings alone pass by default', () async {
      expect((await run(['check', '--arb-dir', dir.path])).code, 0);
    });

    test('warnings fail with --fail-on warning', () async {
      expect(
        (await run([
          'check',
          '--arb-dir',
          dir.path,
          '--fail-on',
          'warning',
        ])).code,
        1,
      );
    });
  });

  test('--locale restricts the files that are checked', () async {
    final r = await run([
      'check',
      '--arb-dir',
      'example/l10n',
      '--locale',
      'ko',
      '--format',
      'json',
    ]);
    final data = jsonDecode(r.out) as Map<String, Object?>;
    final findings = data['findings']! as List<Object?>;
    expect(
      findings.every((f) => (f! as Map<String, Object?>)['locale'] == 'ko'),
      isTrue,
    );
    expect((data['summary']! as Map<String, Object?>)['filesChecked'], 2);
  });

  test('--output writes the report to a file and keeps stdout empty', () async {
    final dir = tempProject({});
    addTearDown(() => dir.deleteSync(recursive: true));
    final target = '${dir.path}/report.txt';
    final r = await run([
      'check',
      '--arb-dir',
      'example/clean',
      '--output',
      target,
    ]);
    expect(r.out, isEmpty);
    expect(File(target).readAsStringSync(), contains('Checked 4 file(s)'));
  });

  test('--version prints the version', () async {
    final r = await run(['--version']);
    expect(r.code, 0);
    expect(r.out, matches(RegExp(r'^arb_guard \d+\.\d+\.\d+')));
  });

  test('unknown command and unknown option exit 2', () async {
    expect((await run(['frobnicate'])).code, 2);
    expect((await run(['check', '--nope'])).code, 2);
    expect((await run(['check', '--fail-on', 'sometimes'])).code, 2);
    expect((await run([])).code, 2);
  });

  test('non-UTF-8 ARB file gives exit 1 and no crash', () async {
    final dir = tempProject({'app_en.arb': '{"a": "A"}'});
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/app_es.arb').writeAsBytesSync([0x7b, 0xff, 0xfe, 0x7d]);
    for (final format in ['text', 'json', 'sarif']) {
      final r = await run(['check', '--arb-dir', dir.path, '--format', format]);
      expect(r.code, 1, reason: format);
    }
  });

  test('non-UTF-8 template gives exit 2', () async {
    final dir = tempProject({'app_es.arb': '{"a": "A"}'});
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/app_en.arb').writeAsBytesSync([0x7b, 0xff, 0x7d]);
    final r = await run(['check', '--arb-dir', dir.path, '--lang', 'ko']);
    expect(r.code, 2);
    expect(r.err, contains('UTF-8'));
  });
}
