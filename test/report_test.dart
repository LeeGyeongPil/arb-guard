import 'dart:convert';
import 'dart:io';

import 'package:arb_guard/arb_guard.dart';
import 'package:arb_guard/src/report/github.dart';
import 'package:arb_guard/src/report/json.dart';
import 'package:arb_guard/src/report/sarif.dart';
import 'package:arb_guard/src/report/text.dart';
import 'package:test/test.dart';

Future<CheckResult> example() =>
    checkProject(const CheckOptions(arbDir: 'example/l10n'));

void main() {
  test('json report has stable keys', () async {
    final data =
        jsonDecode(renderJson(await example())) as Map<String, Object?>;
    expect(data['version'], 1);
    final findings = data['findings']! as List<Object?>;
    final first = findings.first! as Map<String, Object?>;
    for (final key in [
      'ruleId',
      'severity',
      'locale',
      'key',
      'file',
      'line',
      'column',
      'message',
    ]) {
      expect(first.containsKey(key), isTrue, reason: key);
    }
    expect(first['ruleId'], 'AG003');
    expect(first['line'], 3);
    final summary = data['summary']! as Map<String, Object?>;
    expect(summary['errors'], 9);
    expect(summary['warnings'], 1);
    expect(summary['infos'], 1);
    expect(summary['filesChecked'], 4);
  });

  test('sarif report follows 2.1.0 and points at the key lines', () async {
    final result = await example();
    final sarif =
        jsonDecode(renderSarif(result, lang: 'en')) as Map<String, Object?>;
    expect(sarif['version'], '2.1.0');
    expect(sarif[r'$schema'], contains('sarif-2.1.0'));
    final run =
        (sarif['runs']! as List<Object?>).first! as Map<String, Object?>;
    final driver =
        (run['tool']! as Map<String, Object?>)['driver']!
            as Map<String, Object?>;
    final ruleIds = [
      for (final r in driver['rules']! as List<Object?>)
        (r! as Map<String, Object?>)['id'],
    ];
    expect(ruleIds, [
      for (var i = 1; i <= 14; i++) 'AG${i.toString().padLeft(3, '0')}',
    ]);

    final results = run['results']! as List<Object?>;
    expect(results, hasLength(result.findings.length));
    for (final r in results) {
      final m = r! as Map<String, Object?>;
      final location =
          ((m['locations']! as List<Object?>).first!
                  as Map<String, Object?>)['physicalLocation']!
              as Map<String, Object?>;
      final uri =
          (location['artifactLocation']! as Map<String, Object?>)['uri']!
              as String;
      final line =
          (location['region']! as Map<String, Object?>)['startLine']! as int;
      final key =
          ((m['message']! as Map<String, Object?>)['text']! as String)
              .split(':')
              .first;
      final lines = File(uri).readAsLinesSync();
      expect(
        lines[line - 1].trimLeft(),
        startsWith('"$key"'),
        reason: '$uri:$line should hold key $key',
      );
    }
  });

  test(
    'sarif levels map error, warning, info to error, warning, note',
    () async {
      final text = renderSarif(await example(), lang: 'en');
      expect(text, contains('"level": "note"'));
      expect(text, contains('"level": "warning"'));
      expect(text, contains('"level": "error"'));
    },
  );

  test('github format emits workflow commands', () async {
    final lines = renderGithub(await example()).trim().split('\n');
    expect(
      lines.first,
      startsWith(
        '::error file=example/l10n/app_es.arb,line=3,col=3,title=AG003::',
      ),
    );
    expect(
      lines.any((l) => l.startsWith('::warning ') && l.contains('title=AG010')),
      isTrue,
    );
    expect(
      lines.any((l) => l.startsWith('::notice ') && l.contains('title=AG013')),
      isTrue,
    );
  });

  test('github format escapes newlines and percent signs', () {
    final result = CheckResult(
      findings: const [
        Finding(
          ruleId: 'AG013',
          severity: Severity.info,
          locale: 'es',
          key: 'k',
          message: '100%\nsure',
          file: 'a,b.arb',
          line: 1,
          column: 1,
        ),
      ],
      filesChecked: 1,
      missingKeys: const {},
    );
    final line = renderGithub(result);
    expect(line, contains('100%25%0Asure'));
    expect(line, contains('file=a%2Cb.arb'));
  });

  test('text report colors only when asked', () async {
    final result = await example();
    expect(renderText(result, lang: 'en'), isNot(contains('\x1B[')));
    expect(renderText(result, lang: 'en', color: true), contains('\x1B[31m'));
  });

  test('text summary lists untranslated keys by count', () async {
    final result = await checkProject(
      CheckOptions(arbDir: _missingKeyDir.path),
    );
    expect(
      renderText(result, lang: 'en'),
      contains('1 template key(s) have no translation'),
    );
  });

  test('messages follow the chosen language, rule ids do not', () async {
    final result = await checkProject(
      const CheckOptions(arbDir: 'example/l10n', lang: 'ko'),
    );
    final first = result.findings.first;
    expect(first.ruleId, 'AG003');
    expect(first.message, contains('번역되었습니다'));
    final json = jsonDecode(renderJson(result)) as Map<String, Object?>;
    expect(
      ((json['findings']! as List<Object?>).first!
          as Map<String, Object?>)['ruleId'],
      'AG003',
    );
  });
}

final Directory _missingKeyDir = () {
  final dir = Directory.systemTemp.createTempSync('arb_guard_missing_');
  File('${dir.path}/app_en.arb').writeAsStringSync('{"a": "A", "b": "B"}');
  File('${dir.path}/app_es.arb').writeAsStringSync('{"a": "Á"}');
  return dir;
}();
