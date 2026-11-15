/// Shared state handed to every rule while one message is checked.
library;

import '../arb_file.dart';
import '../finding.dart';
import '../i18n/messages.dart';
import '../icu/nodes.dart';
import '../signature.dart';

/// Everything a rule needs to compare one translated message.
class MessageContext {
  MessageContext({
    required this.lang,
    required this.locale,
    required this.templateLocale,
    required this.key,
    required this.templateText,
    required this.translationText,
    required this.templateNodes,
    required this.translationNodes,
    required this.templateMeta,
    required this.translationMeta,
    this.file,
    this.position,
  }) : templateArgs = collectArgs(templateNodes),
       translationArgs = collectArgs(translationNodes),
       pairs = pairStructure(templateNodes, translationNodes);

  final String lang;
  final String locale;
  final String templateLocale;
  final String key;
  final String templateText;
  final String translationText;
  final List<IcuNode> templateNodes;
  final List<IcuNode> translationNodes;
  final Map<String, ArgInfo> templateArgs;
  final Map<String, ArgInfo> translationArgs;
  final StructurePairs pairs;

  /// `@key` metadata maps (empty when absent).
  final Map<String, Object?> templateMeta;
  final Map<String, Object?> translationMeta;

  final String? file;
  final Position? position;
  final List<Finding> findings = [];

  /// Names of placeholders that were renamed (reported once by AG003).
  final Set<String> renamedFrom = {};
  final Set<String> renamedTo = {};

  String t(String msgKey, [List<String> params = const []]) =>
      tr(lang, msgKey, params);

  /// Records a finding. [severity] defaults to the rule's catalog severity.
  void add(
    String ruleId,
    String message, {
    Severity? severity,
    Map<String, Object?> data = const {},
  }) {
    findings.add(
      Finding(
        ruleId: ruleId,
        severity: severity ?? ruleInfo(ruleId).severity,
        locale: locale,
        key: key,
        message: message,
        file: file,
        line: position?.line,
        column: position?.column,
        data: data,
      ),
    );
  }
}

/// Formats a placeholder name for messages: `name` -> `{name}`.
String braces(String name) => '{$name}';
