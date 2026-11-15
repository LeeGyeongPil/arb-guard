import 'dart:convert';
import 'package:arb_guard/src/arb_file.dart';
import 'dart:io';

import 'package:arb_guard/arb_guard.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('tags (AG009)', () {
    test('missing closing tag', () {
      final f = check('Welcome <b>{name}</b>', 'Bienvenido <b>{name}');
      expect(ids(f), ['AG009']);
      expect(f.single.data['missing'], ['</b>']);
    });

    test('tags may move as long as they stay paired', () {
      expect(
        check('<b>{a}</b> and <i>{b}</i>', '<i>{b}</i> y <b>{a}</b>'),
        isEmpty,
      );
    });

    test('closing before opening is a nesting error', () {
      final f = check('<b>{a}</b>', '</b>{a}<b>');
      expect(ids(f), ['AG009']);
      expect(f.single.data.containsKey('tags'), isTrue);
    });

    test('unexpected extra tag', () {
      final f = check('Hello {a}', 'Hola <b>{a}</b>');
      expect(ids(f), ['AG009']);
      expect(f.single.data['unexpected'], ['<b>', '</b>']);
    });

    test('attributes may differ and self-closing tags are ignored', () {
      expect(
        check(
          '<a href="{url}">go</a><br/>',
          '<a href="{url}" class="x">ir</a>',
        ),
        isEmpty,
      );
    });

    test('comparison sign is not a tag', () {
      expect(check('a < b > c {x}', 'a < b > d {x}'), isEmpty);
    });
  });

  group('hash literal (AG010)', () {
    test('new # inside a plural branch is a warning', () {
      final f = check(
        '{years, plural, one{1 year} other{{years} years}}',
        '{years, plural, one{1 año} other{# años}}',
      );
      expect(ids(f), ['AG010']);
      expect(f.single.severity, Severity.warning);
      expect(f.single.message, contains('{years}'));
    });

    test('# that the template also has is fine', () {
      expect(
        check(
          '{n, plural, one{One} other{Item # of {n}}}',
          '{n, plural, one{Uno} other{Elemento # de {n}}}',
        ),
        isEmpty,
      );
    });

    test('# outside plural branches is not reported', () {
      expect(check('Hello {a}', 'Hola #{a}'), isEmpty);
    });
  });

  group('metadata (AG012)', () {
    test('type int against String', () {
      final f = check(
        'Hello, {name}!',
        'Hola, {name}!',
        templateMeta: {
          'placeholders': {
            'name': {'type': 'String'},
          },
        },
        translationMeta: {
          'placeholders': {
            'name': {'type': 'int'},
          },
        },
      );
      expect(ids(f), ['AG012']);
      expect(f.single.data['field'], 'type');
    });

    test('format mismatch', () {
      final f = check(
        '{d}',
        '{d}',
        templateMeta: {
          'placeholders': {
            'd': {'type': 'DateTime', 'format': 'yMd'},
          },
        },
        translationMeta: {
          'placeholders': {
            'd': {'type': 'DateTime', 'format': 'yMMMd'},
          },
        },
      );
      expect(ids(f), ['AG012']);
      expect(f.single.data['field'], 'format');
    });

    test('missing translation metadata is fine', () {
      expect(
        check(
          'Hello, {name}!',
          'Hola, {name}!',
          templateMeta: {
            'placeholders': {
              'name': {'type': 'String'},
            },
          },
        ),
        isEmpty,
      );
    });
  });

  group('untranslated (AG013)', () {
    test('identical text is info', () {
      final f = check('Save', 'Save', locale: 'ko');
      expect(ids(f), ['AG013']);
      expect(f.single.severity, Severity.info);
    });

    test('same language variant is skipped', () {
      expect(check('Save', 'Save', locale: 'en_GB'), isEmpty);
    });

    test('messages without letters are skipped', () {
      expect(check('{count}', '{count}', locale: 'ko'), isEmpty);
      expect(check('...', '...', locale: 'ko'), isEmpty);
    });
  });

  group('file level (AG014)', () {
    test('translation key that is not in the template', () {
      final f = checkMessages(
        locale: 'es',
        template: {'a': 'A'},
        translation: {'a': 'Á', 'extra': 'X'},
      );
      expect(ids(f), ['AG014']);
      expect(f.single.key, 'extra');
    });

    test('non-string message value', () {
      final f = checkMessages(
        locale: 'es',
        template: {'a': 'A'},
        translation: {'a': 5},
      );
      expect(ids(f), ['AG014']);
      expect(f.single.message, contains('number'));
    });

    test('invalid JSON file is AG014 with line and column', () async {
      final dir = tempProject({
        'app_en.arb': '{"a": "A"}',
        'app_es.arb': '{\n  "a": "A",\n  "b": \n}',
      });
      addTearDown(() => dir.deleteSync(recursive: true));
      final result = await checkProject(CheckOptions(arbDir: dir.path));
      final f = result.findings.single;
      expect(f.ruleId, 'AG014');
      expect(f.file, endsWith('app_es.arb'));
      expect(f.line, 4);
      expect(File(f.file!).existsSync(), isTrue);
    });

    test('translation that is not UTF-8 is AG014 invalid_encoding', () async {
      final dir = tempProject({'app_en.arb': '{"a": "A"}'});
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/app_es.arb').writeAsBytesSync([
        ...utf8.encode('{"a":"'),
        0xff,
        0xfe,
        ...utf8.encode(' bad"}'),
      ]);
      for (final lang in ['en', 'ko']) {
        final result = await checkProject(
          CheckOptions(arbDir: dir.path, lang: lang),
        );
        final f = result.findings.single;
        expect(f.ruleId, 'AG014');
        expect(f.data['reason'], 'invalid_encoding');
        expect(f.message, contains('UTF-8'));
        expect(result.filesChecked, 2);
      }
    });

    test('template that is not UTF-8 is a usage error', () async {
      final dir = tempProject({'app_es.arb': '{"a": "A"}'});
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/app_en.arb').writeAsBytesSync([0x7b, 0xff, 0x7d]);
      expect(
        () => checkProject(CheckOptions(arbDir: dir.path)),
        throwsA(isA<ArbGuardUsageException>()),
      );
    });

    test('file names are taken with either path separator', () {
      expect(ArbFile.localeFromFileName(r'lib\l10n\app_es.arb'), 'es');
    });
  });
}
