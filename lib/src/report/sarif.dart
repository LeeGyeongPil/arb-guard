/// SARIF 2.1.0 report for code scanning uploads.
library;

import 'dart:convert';

import '../checker.dart';
import '../finding.dart';
import '../i18n/messages.dart';
import '../version.dart';

const String sarifSchema = 'https://json.schemastore.org/sarif-2.1.0.json';

String _level(Severity s) => switch (s) {
  Severity.error => 'error',
  Severity.warning => 'warning',
  Severity.info => 'note',
};

/// SARIF log with every rule in `tool.driver.rules` and one result per finding.
String renderSarif(CheckResult result, {required String lang}) {
  final rules = [
    for (final r in ruleCatalog)
      {
        'id': r.id,
        'name': r.name,
        'shortDescription': {'text': tr(lang, 'rule.${r.id}.desc')},
        'defaultConfiguration': {'level': _level(r.severity)},
      },
  ];
  final results = [
    for (final f in result.findings)
      {
        'ruleId': f.ruleId,
        'ruleIndex': ruleCatalog.indexWhere((r) => r.id == f.ruleId),
        'level': _level(f.severity),
        'message': {
          'text': f.key.isEmpty ? f.message : '${f.key}: ${f.message}',
        },
        if (f.file != null)
          'locations': [
            {
              'physicalLocation': {
                'artifactLocation': {'uri': f.file!.replaceAll(r'\', '/')},
                if (f.line != null)
                  'region': {'startLine': f.line, 'startColumn': f.column ?? 1},
              },
            },
          ],
      },
  ];
  final log = {
    r'$schema': sarifSchema,
    'version': '2.1.0',
    'runs': [
      {
        'tool': {
          'driver': {
            'name': 'arb_guard',
            'version': packageVersion,
            'informationUri': 'https://github.com/LeeGyeongPil/arb-guard',
            'rules': rules,
          },
        },
        'results': results,
      },
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(log)}\n';
}
