/// Command line interface: `check`, `rules`, `--help`, `--version`.
library;

import 'dart:io';

import 'package:args/args.dart';

import 'checker.dart';
import 'config.dart';
import 'finding.dart';
import 'i18n/messages.dart';
import 'report/github.dart';
import 'report/json.dart';
import 'report/sarif.dart';
import 'report/text.dart';
import 'version.dart';

/// Exit codes.
const int exitOk = 0;
const int exitFindings = 1;
const int exitUsage = 2;

ArgParser _buildCheckParser(String lang) {
  String t(String key) => tr(lang, key);
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: t('cli.opt.help'))
    ..addOption('lang', help: t('cli.opt.lang'), allowed: supportedLanguages)
    ..addOption('arb-dir', help: t('cli.opt.arb_dir'), valueHelp: 'DIR')
    ..addOption('template', help: t('cli.opt.template'), valueHelp: 'FILE')
    ..addOption('config', help: t('cli.opt.config'), valueHelp: 'FILE')
    ..addOption('locale', help: t('cli.opt.locale'), valueHelp: 'es,ko')
    ..addOption(
      'format',
      help: t('cli.opt.format'),
      allowed: ['text', 'json', 'sarif', 'github'],
      defaultsTo: 'text',
    )
    ..addOption('output', help: t('cli.opt.output'), valueHelp: 'FILE')
    ..addOption(
      'fail-on',
      help: t('cli.opt.fail_on'),
      allowed: ['error', 'warning', 'never'],
      defaultsTo: 'error',
    )
    ..addFlag('use-escaping', negatable: false, help: t('cli.opt.use_escaping'))
    ..addFlag('relax-syntax', negatable: false, help: t('cli.opt.relax_syntax'))
    ..addFlag('no-color', negatable: false, help: t('cli.opt.no_color'));
}

ArgParser _buildRulesParser(String lang) =>
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: tr(lang, 'cli.opt.help'),
      )
      ..addOption(
        'lang',
        help: tr(lang, 'cli.opt.lang'),
        allowed: supportedLanguages,
      );

ArgParser _buildTopParser(String lang) =>
    ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: tr(lang, 'cli.opt.help'),
      )
      ..addFlag('version', negatable: false, help: tr(lang, 'cli.opt.version'))
      ..addOption(
        'lang',
        help: tr(lang, 'cli.opt.lang'),
        allowed: supportedLanguages,
      );

String _topHelp(String lang) {
  final b =
      StringBuffer()
        ..writeln(tr(lang, 'cli.description'))
        ..writeln()
        ..writeln(tr(lang, 'cli.usage'))
        ..writeln()
        ..writeln(tr(lang, 'cli.commands'))
        ..writeln('  check   ${tr(lang, 'cli.cmd.check')}')
        ..writeln('  rules   ${tr(lang, 'cli.cmd.rules')}')
        ..writeln()
        ..writeln(tr(lang, 'cli.global.options'))
        ..writeln(_buildTopParser(lang).usage)
        ..writeln()
        ..writeln(tr(lang, 'cli.help_hint'));
  return b.toString();
}

String _commandHelp(String lang, String command, ArgParser parser) {
  return 'arb_guard $command - ${tr(lang, 'cli.cmd.$command')}\n\n${parser.usage}\n';
}

/// Finds `--lang` before full parsing so that even usage errors are localized.
String? _prescanLang(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--lang' && i + 1 < args.length) return args[i + 1];
    if (a.startsWith('--lang=')) return a.substring(7);
  }
  return null;
}

/// Runs the CLI and returns the process exit code.
///
/// [env], [out] and [err] can be replaced in tests.
Future<int> runCli(
  List<String> args, {
  Map<String, String>? env,
  StringSink? out,
  StringSink? err,
}) async {
  final environment = env ?? Platform.environment;
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  final pre = _prescanLang(args);
  final lang = resolveLanguage(
    cliLang: supportedLanguages.contains(pre) ? pre : null,
    env: environment,
  );

  int usageError(String message) {
    stderrSink.writeln('arb_guard: $message');
    return exitUsage;
  }

  // Options before the command (`--lang ko check`, `--help`, `--version`).
  var commandIndex = -1;
  final leading = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('-')) {
      commandIndex = i;
      break;
    }
    leading.add(a);
    if (a == '--lang' && i + 1 < args.length) {
      leading.add(args[++i]);
    }
  }
  ArgResults top;
  try {
    top = _buildTopParser(lang).parse(leading);
  } on FormatException catch (e) {
    return usageError(tr(lang, 'cli.err.bad_option', [e.message]));
  }
  if (top['version'] == true) {
    stdoutSink.writeln('arb_guard $packageVersion');
    return exitOk;
  }
  if (top['help'] == true) {
    stdoutSink.write(_topHelp(lang));
    return exitOk;
  }
  if (commandIndex < 0) {
    stderrSink.write(_topHelp(lang));
    return exitUsage;
  }
  final command = args[commandIndex];
  final commandArgs = args.sublist(commandIndex + 1);

  switch (command) {
    case 'check':
      return _runCheck(commandArgs, lang, environment, stdoutSink, usageError);
    case 'rules':
      ArgResults r;
      try {
        r = _buildRulesParser(lang).parse(commandArgs);
      } on FormatException catch (e) {
        return usageError(tr(lang, 'cli.err.bad_option', [e.message]));
      }
      if (r['help'] == true) {
        stdoutSink.write(_commandHelp(lang, 'rules', _buildRulesParser(lang)));
        return exitOk;
      }
      stdoutSink.write(renderRules(lang));
      return exitOk;
    default:
      return usageError(tr(lang, 'cli.err.unknown_command', [command]));
  }
}

/// The `rules` table.
String renderRules(String lang) {
  final b =
      StringBuffer()
        ..writeln(tr(lang, 'cli.rules.title'))
        ..writeln(tr(lang, 'cli.rules.header'));
  for (final r in ruleCatalog) {
    b.writeln(
      '${r.id.padRight(8)} ${r.severity.name.padRight(8)}  '
      '${r.name} - ${tr(lang, 'rule.${r.id}.desc')}',
    );
  }
  return b.toString();
}

Future<int> _runCheck(
  List<String> args,
  String initialLang,
  Map<String, String> env,
  StringSink out,
  int Function(String) usageError,
) async {
  final lang = initialLang;
  ArgResults r;
  try {
    r = _buildCheckParser(lang).parse(args);
  } on FormatException catch (e) {
    return usageError(tr(lang, 'cli.err.bad_option', [e.message]));
  }
  if (r['help'] == true) {
    out.write(_commandHelp(lang, 'check', _buildCheckParser(lang)));
    return exitOk;
  }
  if (r.rest.isNotEmpty) {
    return usageError(tr(lang, 'cli.err.unknown_command', [r.rest.first]));
  }

  final localeText = r['locale'] as String?;
  final format = r['format'] as String;
  final failOn = r['fail-on'] as String;
  final outputPath = r['output'] as String?;

  try {
    final config = loadConfig(
      configPath: r['config'] as String?,
      arbDir: r['arb-dir'] as String?,
      templateFile: r['template'] as String?,
      useEscaping: r['use-escaping'] == true,
      relaxSyntax: r['relax-syntax'] == true,
      lang: lang,
    );
    final result = await checkProject(
      CheckOptions(
        arbDir: config.arbDir,
        templateFile: config.templateFile,
        locales: {
          if (localeText != null)
            for (final l in localeText.split(','))
              if (l.trim().isNotEmpty) l.trim(),
        },
        parse: config.parse,
        lang: lang,
      ),
    );

    final useColor =
        outputPath == null &&
        r['no-color'] != true &&
        env['NO_COLOR'] == null &&
        _isTerminal(out);
    final report = switch (format) {
      'json' => renderJson(result),
      'sarif' => renderSarif(result, lang: lang),
      'github' => renderGithub(result),
      _ => renderText(result, lang: lang, color: useColor),
    };
    if (outputPath != null) {
      try {
        File(outputPath).writeAsStringSync(report);
      } on FileSystemException catch (e) {
        return usageError(
          tr(lang, 'cli.err.output_write', [outputPath, e.message]),
        );
      }
    } else {
      out.write(report);
    }

    final failing = switch (failOn) {
      'never' => 0,
      'warning' =>
        result.count(Severity.error) + result.count(Severity.warning),
      _ => result.count(Severity.error),
    };
    return failing > 0 ? exitFindings : exitOk;
  } on ArbGuardUsageException catch (e) {
    return usageError(e.message);
  }
}

bool _isTerminal(StringSink sink) =>
    identical(sink, stdout) && stdout.hasTerminal;
