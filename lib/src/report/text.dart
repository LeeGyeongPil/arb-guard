/// Human readable report.
library;

import '../checker.dart';
import '../finding.dart';
import '../i18n/messages.dart';

const _reset = '\x1B[0m';
const _dim = '\x1B[2m';

String _paint(Severity s) => switch (s) {
  Severity.error => '\x1B[31m',
  Severity.warning => '\x1B[33m',
  Severity.info => '\x1B[36m',
};

/// `file:line:col severity RULE key: message` lines plus a summary.
String renderText(
  CheckResult result, {
  required String lang,
  bool color = false,
}) {
  final out = StringBuffer();
  String paint(String code, String text) => color ? '$code$text$_reset' : text;

  for (final f in result.findings) {
    final where =
        f.file == null
            ? f.locale
            : f.line == null
            ? f.file!
            : '${f.file}:${f.line}:${f.column ?? 1}';
    final key = f.key.isEmpty ? '' : '${f.key}: ';
    out.writeln(
      '${paint(_dim, where)} '
      '${paint(_paint(f.severity), f.severity.name)} '
      '${paint(_paint(f.severity), f.ruleId)} $key${f.message}',
    );
  }
  if (result.findings.isEmpty) {
    out.writeln(tr(lang, 'summary.none'));
  }
  out.writeln();
  out.writeln(
    tr(lang, 'summary', [
      '${result.filesChecked}',
      '${result.count(Severity.error)}',
      '${result.count(Severity.warning)}',
      '${result.count(Severity.info)}',
    ]),
  );
  final missing = result.missingKeys.values.fold<int>(
    0,
    (sum, keys) => sum + keys.length,
  );
  if (missing > 0) {
    out.writeln(tr(lang, 'summary.missing', ['$missing']));
  }
  return out.toString();
}
