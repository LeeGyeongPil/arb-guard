/// `l10n.yaml` handling (flat key/value subset) and option merging.
library;

import 'dart:io';

import 'i18n/messages.dart';
import 'icu/parser.dart';

/// Thrown for usage and configuration problems (CLI exit code 2).
class ArbGuardUsageException implements Exception {
  ArbGuardUsageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads flat `key: value` lines (the only shape `l10n.yaml` uses here).
///
/// Comments, blank lines, indented lines and list items are ignored; quotes
/// around values are removed.
Map<String, String> parseFlatYaml(String source) {
  final out = <String, String>{};
  for (final raw in source.split(RegExp(r'\r?\n'))) {
    if (raw.isEmpty ||
        raw.startsWith('#') ||
        raw.startsWith(' ') ||
        raw.startsWith('\t') ||
        raw.startsWith('-')) {
      continue;
    }
    final colon = raw.indexOf(':');
    if (colon <= 0) continue;
    final key = raw.substring(0, colon).trim();
    var value = raw.substring(colon + 1).trim();
    if (value.startsWith('"') || value.startsWith("'")) {
      final quote = value[0];
      final end = value.indexOf(quote, 1);
      value = end > 0 ? value.substring(1, end) : value.substring(1);
    } else {
      final hash = value.indexOf(' #');
      if (hash >= 0) value = value.substring(0, hash).trim();
    }
    out[key] = value;
  }
  return out;
}

/// Effective project settings after merging `l10n.yaml` and CLI arguments.
class ProjectConfig {
  const ProjectConfig({
    required this.arbDir,
    required this.templateFile,
    required this.parse,
    this.configPath,
  });

  final String arbDir;
  final String templateFile;
  final ParseOptions parse;

  /// The `l10n.yaml` that was read, if any.
  final String? configPath;
}

/// Built-in defaults of `flutter gen-l10n`.
const String defaultArbDir = 'lib/l10n';
const String defaultTemplateFile = 'app_en.arb';

String _dirname(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  if (cut < 0) return '.';
  return cut == 0 ? '/' : path.substring(0, cut);
}

String _resolveAgainst(String base, String path) {
  final absolute =
      path.startsWith('/') ||
      path.startsWith('\\') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
  if (absolute || base == '.') return path;
  return '$base/$path';
}

bool _bool(String? value) => value != null && value.toLowerCase() == 'true';

/// Merges settings. Priority: CLI arguments > `l10n.yaml` > gen-l10n defaults.
///
/// [configPath] is an explicit `--config` (must exist). When it is null,
/// `./l10n.yaml` is used if present.
ProjectConfig loadConfig({
  String? configPath,
  String? arbDir,
  String? templateFile,
  bool useEscaping = false,
  bool relaxSyntax = false,
  String lang = 'en',
}) {
  var path = configPath;
  if (path == null && File('l10n.yaml').existsSync()) path = 'l10n.yaml';
  var yaml = const <String, String>{};
  if (path != null) {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArbGuardUsageException(tr(lang, 'cli.err.config_missing', [path]));
    }
    try {
      yaml = parseFlatYaml(file.readAsStringSync());
    } on FileSystemException catch (e) {
      throw ArbGuardUsageException(
        tr(lang, 'cli.err.config_bad', [path, e.message]),
      );
    }
  }
  final base = path == null ? '.' : _dirname(path);
  final yamlDir = yaml['arb-dir'];
  return ProjectConfig(
    arbDir:
        arbDir ??
        (yamlDir != null ? _resolveAgainst(base, yamlDir) : defaultArbDir),
    templateFile:
        templateFile ?? yaml['template-arb-file'] ?? defaultTemplateFile,
    parse: ParseOptions(
      useEscaping: useEscaping || _bool(yaml['use-escaping']),
      relaxSyntax: relaxSyntax || _bool(yaml['relax-syntax']),
    ),
    configPath: path,
  );
}
