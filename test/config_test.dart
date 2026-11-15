import 'package:arb_guard/arb_guard.dart';
import 'package:arb_guard/src/arb_file.dart';
import 'package:arb_guard/src/cli.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('flat YAML', () {
    test('reads keys, quotes and comments', () {
      final map = parseFlatYaml('''
# comment
arb-dir: lib/i18n   # trailing comment
template-arb-file: "app_ko.arb"
use-escaping: true
nested:
  ignored: yes
- item
''');
      expect(map['arb-dir'], 'lib/i18n');
      expect(map['template-arb-file'], 'app_ko.arb');
      expect(map['use-escaping'], 'true');
      expect(map.containsKey('ignored'), isFalse);
    });
  });

  group('merging', () {
    test('l10n.yaml values are used', () {
      final dir = tempProject({
        'l10n.yaml':
            'arb-dir: arbs\ntemplate-arb-file: app_de.arb\n'
            'use-escaping: true\nrelax-syntax: true\n',
      });
      addTearDown(() => dir.deleteSync(recursive: true));
      final config = loadConfig(configPath: '${dir.path}/l10n.yaml');
      expect(config.arbDir, '${dir.path}/arbs');
      expect(config.templateFile, 'app_de.arb');
      expect(config.parse.useEscaping, isTrue);
      expect(config.parse.relaxSyntax, isTrue);
    });

    test('CLI arguments win over l10n.yaml', () {
      final dir = tempProject({
        'l10n.yaml': 'arb-dir: arbs\ntemplate-arb-file: app_de.arb\n',
      });
      addTearDown(() => dir.deleteSync(recursive: true));
      final config = loadConfig(
        configPath: '${dir.path}/l10n.yaml',
        arbDir: 'other',
        templateFile: 'app_fr.arb',
      );
      expect(config.arbDir, 'other');
      expect(config.templateFile, 'app_fr.arb');
    });

    test('without config and arguments gen-l10n defaults apply', () {
      final config = loadConfig();
      expect(config.arbDir, 'lib/l10n');
      expect(config.templateFile, 'app_en.arb');
      expect(config.parse.useEscaping, isFalse);
    });

    test('an explicit missing config file is a usage error', () {
      expect(
        () => loadConfig(configPath: 'nope/l10n.yaml'),
        throwsA(isA<ArbGuardUsageException>()),
      );
    });
  });

  group('locale detection', () {
    test('file name is used without @@locale', () {
      expect(ArbFile.localeFromFileName('lib/l10n/app_es.arb'), 'es');
      expect(ArbFile.localeFromFileName('app_zh_Hant.arb'), 'zh_Hant');
      final file = ArbFile.parse('x/app_pt_BR.arb', '{"a": "b"}');
      expect(file.locale, 'pt_BR');
    });

    test('@@locale wins over the file name', () {
      final file = ArbFile.parse(
        'x/app_es.arb',
        '{"@@locale": "gl", "a": "b"}',
      );
      expect(file.locale, 'gl');
    });

    test('key positions are 1-based line and column', () {
      final file = ArbFile.parse(
        'a.arb',
        '{\n  "a": "x, \\" y",\n  "b": {"c": 1},\n  "d": 2\n}',
      );
      expect(file.positions['a']!.toString(), '2:3');
      expect(file.positions['b']!.toString(), '3:3');
      expect(file.positions['d']!.toString(), '4:3');
      expect(file.positions.containsKey('c'), isFalse);
    });
  });

  group('project errors', () {
    test('missing template file is a usage error with the cause', () async {
      final dir = tempProject({'app_es.arb': '{}'});
      addTearDown(() => dir.deleteSync(recursive: true));
      await expectLater(
        checkProject(CheckOptions(arbDir: dir.path)),
        throwsA(
          isA<ArbGuardUsageException>().having(
            (e) => e.message,
            'message',
            contains('app_en.arb'),
          ),
        ),
      );
    });

    test('CLI turns it into exit code 2 and a readable message', () async {
      final dir = tempProject({'app_es.arb': '{}'});
      addTearDown(() => dir.deleteSync(recursive: true));
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runCli(
        ['check', '--arb-dir', dir.path, '--lang', 'en'],
        env: const {},
        out: out,
        err: err,
      );
      expect(code, 2);
      expect(err.toString(), contains('template file not found'));
      expect(out.toString(), isEmpty);
    });

    test('the project config is applied by the CLI', () async {
      final dir = tempProject({
        'l10n.yaml': 'arb-dir: arbs\ntemplate-arb-file: app_de.arb\n',
        'arbs/app_de.arb': '{"@@locale": "de", "a": "Hallo {x}"}',
        'arbs/app_ko.arb': '{"@@locale": "ko", "a": "안녕 {y}"}',
      });
      addTearDown(() => dir.deleteSync(recursive: true));
      final out = StringBuffer();
      final code = await runCli(
        ['check', '--config', '${dir.path}/l10n.yaml', '--format', 'json'],
        env: const {},
        out: out,
        err: StringBuffer(),
      );
      expect(code, 1);
      expect(out.toString(), contains('AG003'));
    });

    test('use-escaping changes how apostrophes are read', () async {
      final files = {
        'app_en.arb': '{"a": "It\'s {name}"}',
        'app_es.arb': '{"a": "Es {name}"}',
      };
      final dir = tempProject(files);
      addTearDown(() => dir.deleteSync(recursive: true));
      final plain = await checkProject(CheckOptions(arbDir: dir.path));
      expect(plain.findings, isEmpty);
      final escaped = await checkProject(
        CheckOptions(
          arbDir: dir.path,
          parse: const ParseOptions(useEscaping: true),
        ),
      );
      expect(escaped.findings.map((f) => f.ruleId), ['AG002']);
    });
  });
}
