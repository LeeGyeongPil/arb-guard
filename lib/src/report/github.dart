/// GitHub Actions workflow commands (`::error file=...::message`).
library;

import '../checker.dart';
import '../finding.dart';

String _escapeData(String s) =>
    s.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');

String _escapeProperty(String s) =>
    _escapeData(s).replaceAll(':', '%3A').replaceAll(',', '%2C');

String _command(Severity s) => switch (s) {
  Severity.error => 'error',
  Severity.warning => 'warning',
  Severity.info => 'notice',
};

/// One workflow command per finding.
String renderGithub(CheckResult result) {
  final out = StringBuffer();
  for (final f in result.findings) {
    final props = <String>[
      if (f.file != null) 'file=${_escapeProperty(f.file!)}',
      if (f.line != null) 'line=${f.line}',
      if (f.column != null) 'col=${f.column}',
      'title=${f.ruleId}',
    ];
    final text = f.key.isEmpty ? f.message : '${f.key}: ${f.message}';
    out.writeln(
      '::${_command(f.severity)} ${props.join(',')}::${_escapeData(text)}',
    );
  }
  return out.toString();
}
