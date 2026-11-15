/// Findings and the rule catalog.
library;

/// How serious a finding is.
enum Severity {
  error,
  warning,
  info;

  /// Parses `error|warning|info`; returns null for anything else.
  static Severity? tryParse(String value) {
    for (final s in Severity.values) {
      if (s.name == value) return s;
    }
    return null;
  }
}

/// One problem found in a translation.
class Finding {
  const Finding({
    required this.ruleId,
    required this.severity,
    required this.locale,
    required this.key,
    required this.message,
    this.file,
    this.line,
    this.column,
    this.data = const {},
  });

  /// Stable rule id, `AG001` ... `AG014`.
  final String ruleId;
  final Severity severity;
  final String locale;

  /// ARB message key (empty for file-level problems).
  final String key;

  /// Localized, human readable explanation.
  final String message;

  /// Path of the ARB file, when known.
  final String? file;

  /// 1-based line and column of the message key in [file], when known.
  final int? line;
  final int? column;

  /// Machine readable details (rule specific, language independent).
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'ruleId': ruleId,
    'severity': severity.name,
    'locale': locale,
    'key': key,
    'file': file,
    'line': line,
    'column': column,
    'message': message,
    'data': data,
  };

  @override
  String toString() => '$ruleId $locale/$key: $message';
}

/// Static description of a rule.
class RuleInfo {
  const RuleInfo(this.id, this.name, this.severity);
  final String id;
  final String name;
  final Severity severity;
}

/// All rules in id order.
const List<RuleInfo> ruleCatalog = [
  RuleInfo('AG001', 'placeholder_missing', Severity.error),
  RuleInfo('AG002', 'placeholder_unknown', Severity.error),
  RuleInfo('AG003', 'placeholder_renamed', Severity.error),
  RuleInfo('AG004', 'select_keys_changed', Severity.error),
  RuleInfo('AG005', 'plural_categories', Severity.error),
  RuleInfo('AG006', 'plural_exact_dropped', Severity.warning),
  RuleInfo('AG007', 'branch_placeholder_dropped', Severity.error),
  RuleInfo('AG008', 'argument_kind_changed', Severity.error),
  RuleInfo('AG009', 'tags_mismatch', Severity.error),
  RuleInfo('AG010', 'hash_literal', Severity.warning),
  RuleInfo('AG011', 'icu_syntax', Severity.error),
  RuleInfo('AG012', 'metadata_mismatch', Severity.error),
  RuleInfo('AG013', 'untranslated', Severity.info),
  RuleInfo('AG014', 'arb_invalid', Severity.error),
];

/// Returns the catalog entry for [id].
RuleInfo ruleInfo(String id) => ruleCatalog.firstWhere((r) => r.id == id);
