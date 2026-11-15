import 'dart:io';

import 'package:arb_guard/arb_guard.dart';
import 'package:arb_guard/src/cli.dart';
import 'package:arb_guard/src/i18n/messages.dart';
import 'package:test/test.dart';

Future<String> out(
  List<String> args, {
  Map<String, String> env = const {},
}) async {
  final buffer = StringBuffer();
  await runCli(args, env: env, out: buffer, err: StringBuffer());
  return buffer.toString();
}

final RegExp _hangul = RegExp(r'[가-힣]');

void main() {
  group('language choice', () {
    test('--lang beats every environment variable', () {
      final env = {
        'ARB_GUARD_LANG': 'en',
        'LC_ALL': 'en_US.UTF-8',
        'LANG': 'en_US.UTF-8',
      };
      expect(resolveLanguage(cliLang: 'ko', env: env), 'ko');
      expect(
        resolveLanguage(cliLang: 'en', env: {'ARB_GUARD_LANG': 'ko'}),
        'en',
      );
    });

    test('ARB_GUARD_LANG > LC_ALL > LC_MESSAGES > LANG', () {
      expect(
        resolveLanguage(
          env: {'ARB_GUARD_LANG': 'ko', 'LC_ALL': 'en_US', 'LANG': 'en_US'},
        ),
        'ko',
      );
      expect(
        resolveLanguage(env: {'LC_ALL': 'ko_KR.UTF-8', 'LC_MESSAGES': 'en_US'}),
        'ko',
      );
      expect(
        resolveLanguage(env: {'LC_MESSAGES': 'ko_KR', 'LANG': 'en_US'}),
        'ko',
      );
      expect(resolveLanguage(env: {'LC_ALL': 'en_US', 'LANG': 'ko_KR'}), 'en');
      expect(resolveLanguage(env: {'LANG': 'ko_KR.UTF-8'}), 'ko');
    });

    test('anything that is not Korean is English', () {
      expect(resolveLanguage(env: {'LANG': 'fr_FR.UTF-8'}), 'en');
      expect(resolveLanguage(env: {'LANG': 'C'}), 'en');
      expect(resolveLanguage(), 'en');
    });
  });

  group('message tables', () {
    test('English and Korean have exactly the same keys', () {
      expect(messages['ko']!.keys.toSet(), messages['en']!.keys.toSet());
    });

    test('both languages use the same {n} slots in every message', () {
      final slot = RegExp(r'\{\d\}');
      for (final key in messages['en']!.keys) {
        final en =
            slot
                .allMatches(messages['en']![key]!)
                .map((m) => m.group(0))
                .toSet();
        final ko =
            slot
                .allMatches(messages['ko']![key]!)
                .map((m) => m.group(0))
                .toSet();
        expect(ko, en, reason: key);
      }
    });

    test('every rule has a description in both languages', () {
      for (final rule in ruleCatalog) {
        expect(messages['en']!['rule.${rule.id}.desc'], isNotNull);
        expect(messages['ko']!['rule.${rule.id}.desc'], isNotNull);
      }
    });
  });

  group('screens switch language', () {
    test('rules', () async {
      final ko = await out(['rules', '--lang', 'ko']);
      final en = await out(['rules', '--lang', 'en']);
      expect(ko, contains('규칙'));
      expect(ko, contains('AG004'));
      expect(en, contains('Rules'));
      expect(en, contains('AG004'));
      expect(en, isNot(matches(_hangul)));
    });

    test('help', () async {
      expect(await out(['--help', '--lang', 'ko']), contains('사용법'));
      final en = await out(['--help', '--lang', 'en']);
      expect(en, contains('Usage: arb_guard'));
      expect(en, isNot(matches(_hangul)));
      expect(
        await out(['check', '--help', '--lang', 'ko']),
        contains('ARB 파일 폴더'),
      );
      expect(
        await out(['check', '--help', '--lang', 'en']),
        contains('Folder with the ARB files'),
      );
    });

    test('check', () async {
      final ko = await out([
        'check',
        '--arb-dir',
        'example/l10n',
        '--lang',
        'ko',
      ]);
      final en = await out([
        'check',
        '--arb-dir',
        'example/l10n',
        '--lang',
        'en',
      ]);
      expect(ko, contains('번역되었습니다'));
      expect(ko, contains('개 오류'));
      expect(en, contains('was translated to'));
      expect(en, contains('9 errors'));
      expect(en, isNot(matches(_hangul)));
      expect(ko, contains('AG003'));
    });

    test(
      'environment variable picks the language when --lang is absent',
      () async {
        final ko = await out(['rules'], env: {'ARB_GUARD_LANG': 'ko'});
        expect(ko, contains('규칙'));
        final lcAll = await out(['rules'], env: {'LC_ALL': 'ko_KR.UTF-8'});
        expect(lcAll, contains('규칙'));
      },
    );

    test('--lang before the command works', () async {
      expect(await out(['--lang', 'ko', 'rules']), contains('규칙'));
    });

    test('usage errors are localized', () async {
      final err = StringBuffer();
      await runCli(
        ['nope', '--lang', 'ko'],
        env: const {},
        out: StringBuffer(),
        err: err,
      );
      expect(err.toString(), contains('알 수 없는 명령'));
    });

    test('tool-made error texts are Korean with --lang ko', () async {
      final dir = Directory.systemTemp.createTempSync('arb_guard_i18n');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/app_en.arb').writeAsStringSync('{"a":"A"}');
      File('${dir.path}/app_es.arb').writeAsStringSync('[1,2]');
      final text = await out(['check', '--arb-dir', dir.path, '--lang', 'ko']);
      expect(text, contains('최상위 값은 JSON 객체여야 합니다'));
      expect(text, isNot(contains('top level')));

      final buffer = StringBuffer();
      final err = StringBuffer();
      await runCli(['check', '--bogus', '--lang', 'ko'], out: buffer, err: err);
      expect(err.toString(), matches(_hangul));
    });
  });
}
