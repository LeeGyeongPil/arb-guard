/// Public entry points: [checkMessages] and [checkProject].
library;

import 'dart:convert';
import 'dart:io';

import 'arb_file.dart';
import 'config.dart';
import 'finding.dart';
import 'i18n/messages.dart';
import 'icu/nodes.dart';
import 'icu/parser.dart';
import 'plural_rules.dart';
import 'rules/branches.dart';
import 'rules/context.dart';
import 'rules/markup.dart';
import 'rules/metadata.dart';
import 'rules/placeholder.dart';

/// Options of [checkProject].
class CheckOptions {
  const CheckOptions({
    this.arbDir = defaultArbDir,
    this.templateFile = defaultTemplateFile,
    this.locales = const {},
    this.parse = const ParseOptions(),
    this.lang = 'en',
  });

  /// Folder with the `.arb` files.
  final String arbDir;

  /// File name of the template inside [arbDir].
  final String templateFile;

  /// Only check these locales (language or full locale); empty means all.
  final Set<String> locales;
  final ParseOptions parse;

  /// Language of finding messages, `en` or `ko`.
  final String lang;
}

/// Result of [checkProject].
class CheckResult {
  const CheckResult({
    required this.findings,
    required this.filesChecked,
    required this.missingKeys,
  });

  final List<Finding> findings;

  /// Number of ARB files read (template included).
  final int filesChecked;

  /// Template keys without a translation, per locale (not reported as findings).
  final Map<String, List<String>> missingKeys;

  int count(Severity s) => findings.where((f) => f.severity == s).length;
}

/// Checks one translation map against the template map, in memory.
///
/// Both maps use the ARB layout (`key`, `@key`, `@@locale`). Returns findings
/// for the translation only; syntax problems of the template are skipped (use
/// [checkProject] to see them). Intended for translators that want to validate
/// their output before writing a file.
List<Finding> checkMessages({
  required String locale,
  required Map<String, Object?> template,
  required Map<String, Object?> translation,
  ParseOptions parse = const ParseOptions(),
  String lang = 'en',
}) {
  final templateLocale =
      template['@@locale'] is String ? template['@@locale']! as String : 'en';
  return _checkTranslation(
    lang: lang,
    locale: locale,
    templateLocale: templateLocale,
    template: template,
    translation: translation,
    parse: parse,
  );
}

Map<String, Object?> _meta(Map<String, Object?> arb, String key) {
  final m = arb['@$key'];
  return m is Map<String, Object?> ? m : const {};
}

List<Finding> _checkTranslation({
  required String lang,
  required String locale,
  required String templateLocale,
  required Map<String, Object?> template,
  required Map<String, Object?> translation,
  required ParseOptions parse,
  String? file,
  Map<String, Position> positions = const {},
}) {
  final out = <Finding>[];
  for (final key in translation.keys) {
    if (key.startsWith('@')) continue;
    final position = positions[key];
    Finding file14(
      String messageKey,
      List<String> params,
      Map<String, Object?> data,
    ) => Finding(
      ruleId: 'AG014',
      severity: Severity.error,
      locale: locale,
      key: key,
      message: tr(lang, messageKey, params),
      file: file,
      line: position?.line,
      column: position?.column,
      data: data,
    );
    final value = translation[key];
    if (!template.containsKey(key)) {
      out.add(file14('ag014.extra', const [], const {'reason': 'unknown_key'}));
      continue;
    }
    if (value is! String) {
      out.add(
        file14(
          'ag014.type',
          [_describeType(value)],
          {'reason': 'not_a_string'},
        ),
      );
      continue;
    }
    final templateValue = template[key];
    if (templateValue is! String) continue;

    List<IcuNode> templateNodes;
    try {
      templateNodes = parseIcu(templateValue, options: parse);
    } on IcuSyntaxError {
      continue; // reported once by checkProject for the template file
    }
    List<IcuNode> translationNodes;
    try {
      translationNodes = parseIcu(value, options: parse);
    } on IcuSyntaxError catch (e) {
      out.add(
        Finding(
          ruleId: 'AG011',
          severity: Severity.error,
          locale: locale,
          key: key,
          message: tr(lang, 'ag011', [
            '${e.offset}',
            tr(lang, 'icu.${e.code.name}'),
          ]),
          file: file,
          line: position?.line,
          column: position?.column,
          data: {'offset': e.offset, 'code': e.code.name},
        ),
      );
      continue;
    }

    final c = MessageContext(
      lang: lang,
      locale: locale,
      templateLocale: templateLocale,
      key: key,
      templateText: templateValue,
      translationText: value,
      templateNodes: templateNodes,
      translationNodes: translationNodes,
      templateMeta: _meta(template, key),
      translationMeta: _meta(translation, key),
      file: file,
      position: position,
    );
    checkPlaceholders(c);
    checkSelectKeys(c);
    checkPluralCategories(c);
    checkExactBranches(c);
    checkBranchPlaceholders(c);
    checkTags(c);
    checkHashLiteral(c);
    checkMetadata(c);
    checkUntranslated(c);
    out.addAll(c.findings);
  }
  return out;
}

String _describeType(Object? value) {
  if (value == null) return 'null';
  if (value is Map) return 'object';
  if (value is List) return 'array';
  if (value is bool) return 'boolean';
  if (value is num) return 'number';
  return value.runtimeType.toString();
}

/// Reads [path] as UTF-8. Returns the text, or a failure reason:
/// `'encoding'` for bad UTF-8, or the OS error message.
({String? text, String? error, bool encoding}) _readUtf8(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    return (text: utf8.decode(bytes), error: null, encoding: false);
  } on FormatException {
    return (text: null, error: null, encoding: true);
  } on FileSystemException catch (e) {
    final detail = e.osError?.message ?? e.message;
    return (text: null, error: detail, encoding: false);
  }
}

String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

String _joinPath(String dir, String name) {
  final clean =
      dir.length > 1 && (dir.endsWith('/') || dir.endsWith('\\'))
          ? dir.substring(0, dir.length - 1)
          : dir;
  return clean == '.' ? name : '$clean/$name';
}

String _parseErrorText(String lang, ArbFile arb) =>
    arb.parseErrorKey != null ? tr(lang, arb.parseErrorKey!) : arb.parseError!;

bool _wanted(Set<String> locales, String locale) {
  if (locales.isEmpty) return true;
  return locales.contains(locale) || locales.contains(languageOf(locale));
}

/// Checks every `.arb` file in [CheckOptions.arbDir] against the template.
///
/// Throws [ArbGuardUsageException] when the folder or template is missing or
/// the template is not valid JSON.
Future<CheckResult> checkProject(CheckOptions options) async {
  final lang = options.lang;
  final dir = Directory(options.arbDir);
  if (!dir.existsSync()) {
    throw ArbGuardUsageException(
      tr(lang, 'cli.err.dir_missing', [options.arbDir]),
    );
  }
  final templatePath = _joinPath(options.arbDir, options.templateFile);
  final templateIo = File(templatePath);
  if (!templateIo.existsSync()) {
    throw ArbGuardUsageException(
      tr(lang, 'cli.err.template_missing', [templatePath]),
    );
  }
  final templateRead = _readUtf8(templatePath);
  if (templateRead.encoding) {
    throw ArbGuardUsageException(
      tr(lang, 'cli.err.template_encoding', [templatePath]),
    );
  }
  if (templateRead.text == null) {
    throw ArbGuardUsageException(
      tr(lang, 'cli.err.read_failed', [templatePath, templateRead.error!]),
    );
  }
  final template = ArbFile.parse(templatePath, templateRead.text!);
  if (template.parseError != null) {
    throw ArbGuardUsageException(
      tr(lang, 'cli.err.template_invalid', [
        templatePath,
        _parseErrorText(lang, template),
      ]),
    );
  }

  final findings = <Finding>[];
  // Template-only checks: ICU syntax and message types.
  for (final key in template.messageKeys) {
    final value = template.entries[key];
    final pos = template.positions[key];
    if (value is! String) {
      findings.add(
        Finding(
          ruleId: 'AG014',
          severity: Severity.error,
          locale: template.locale,
          key: key,
          message: tr(lang, 'ag014.type', [_describeType(value)]),
          file: templatePath,
          line: pos?.line,
          column: pos?.column,
          data: const {'reason': 'not_a_string'},
        ),
      );
      continue;
    }
    try {
      parseIcu(value, options: options.parse);
    } on IcuSyntaxError catch (e) {
      findings.add(
        Finding(
          ruleId: 'AG011',
          severity: Severity.error,
          locale: template.locale,
          key: key,
          message: tr(lang, 'ag011', [
            '${e.offset}',
            tr(lang, 'icu.${e.code.name}'),
          ]),
          file: templatePath,
          line: pos?.line,
          column: pos?.column,
          data: {'offset': e.offset, 'code': e.code.name},
        ),
      );
    }
  }

  final names =
      dir
          .listSync()
          .whereType<File>()
          .map((f) => _fileName(f.path))
          .where((n) => n.endsWith('.arb') && n != options.templateFile)
          .toList()
        ..sort();

  final missing = <String, List<String>>{};
  var files = 1;
  for (final name in names) {
    final path = _joinPath(options.arbDir, name);
    final read = _readUtf8(path);
    final fileLocale = ArbFile.localeFromFileName(path);
    final ArbFile arb;
    if (read.text == null) {
      // Unreadable or not UTF-8: report it as AG014 instead of crashing.
      if (!_wanted(options.locales, fileLocale)) continue;
      files++;
      findings.add(
        Finding(
          ruleId: 'AG014',
          severity: Severity.error,
          locale: fileLocale,
          key: '',
          message:
              read.encoding
                  ? tr(lang, 'ag014.encoding')
                  : tr(lang, 'cli.err.read_failed', [path, read.error!]),
          file: path,
          data: {'reason': read.encoding ? 'invalid_encoding' : 'read_failed'},
        ),
      );
      continue;
    }
    arb = ArbFile.parse(path, read.text!);
    if (!_wanted(options.locales, arb.locale)) continue;
    files++;
    final part = <Finding>[];
    if (arb.parseError != null) {
      part.add(
        Finding(
          ruleId: 'AG014',
          severity: Severity.error,
          locale: arb.locale,
          key: '',
          message: tr(lang, 'ag014.json', [_parseErrorText(lang, arb)]),
          file: path,
          line: arb.errorPosition?.line,
          column: arb.errorPosition?.column,
          data: const {'reason': 'invalid_json'},
        ),
      );
    } else {
      part.addAll(
        _checkTranslation(
          lang: lang,
          locale: arb.locale,
          templateLocale: template.locale,
          template: template.entries,
          translation: arb.entries,
          parse: options.parse,
          file: path,
          positions: arb.positions,
        ),
      );
      final absent = [
        for (final k in template.messageKeys)
          if (!arb.entries.containsKey(k)) k,
      ];
      if (absent.isNotEmpty) missing[arb.locale] = absent;
    }
    part.sort((a, b) {
      final byLine = (a.line ?? 0).compareTo(b.line ?? 0);
      if (byLine != 0) return byLine;
      final byCol = (a.column ?? 0).compareTo(b.column ?? 0);
      return byCol != 0 ? byCol : a.ruleId.compareTo(b.ruleId);
    });
    findings.addAll(part);
  }

  return CheckResult(
    findings: findings,
    filesChecked: files,
    missingKeys: missing,
  );
}
