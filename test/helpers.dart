import 'dart:io';

import 'package:arb_guard/arb_guard.dart';

/// Checks one message of a translation against a template message.
List<Finding> check(
  String templateMessage,
  String translationMessage, {
  String locale = 'es',
  Map<String, Object?>? templateMeta,
  Map<String, Object?>? translationMeta,
  ParseOptions parse = const ParseOptions(),
  String lang = 'en',
}) {
  return checkMessages(
    locale: locale,
    lang: lang,
    parse: parse,
    template: {
      '@@locale': 'en',
      'msg': templateMessage,
      if (templateMeta != null) '@msg': templateMeta,
    },
    translation: {
      '@@locale': locale,
      'msg': translationMessage,
      if (translationMeta != null) '@msg': translationMeta,
    },
  );
}

/// Rule ids of [findings] in order.
List<String> ids(List<Finding> findings) => [
  for (final f in findings) f.ruleId,
];

/// Creates a temporary folder with the given files; the caller deletes it.
Directory tempProject(Map<String, String> files) {
  final dir = Directory.systemTemp.createTempSync('arb_guard_test_');
  files.forEach((name, content) {
    final file = File('${dir.path}/$name');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  });
  return dir;
}
