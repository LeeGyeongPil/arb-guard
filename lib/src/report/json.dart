/// Machine readable report with stable keys.
library;

import 'dart:convert';

import '../checker.dart';
import '../finding.dart';
import '../version.dart';

/// JSON report: `version`, `tool`, `findings[]`, `summary`.
String renderJson(CheckResult result) {
  final data = <String, Object?>{
    'version': 1,
    'tool': {'name': 'arb_guard', 'version': packageVersion},
    'findings': [for (final f in result.findings) f.toJson()],
    'summary': {
      'errors': result.count(Severity.error),
      'warnings': result.count(Severity.warning),
      'infos': result.count(Severity.info),
      'filesChecked': result.filesChecked,
      'missingKeys': {
        for (final e in result.missingKeys.entries) e.key: e.value.length,
      },
    },
  };
  return '${const JsonEncoder.withIndent('  ').convert(data)}\n';
}
