/// AG012 (placeholder metadata) and AG013 (untranslated text).
library;

import '../plural_rules.dart';
import '../signature.dart';
import 'context.dart';

/// AG012: `@key.placeholders.<name>.type|format` must agree with the template.
void checkMetadata(MessageContext c) {
  final want = _placeholders(c.templateMeta);
  final got = _placeholders(c.translationMeta);
  for (final entry in got.entries) {
    final template = want[entry.key];
    if (template == null) continue;
    for (final field in const ['type', 'format']) {
      final a = template[field];
      final b = entry.value[field];
      if (a == null || b == null || a == b) continue;
      c.add(
        'AG012',
        c.t('ag012', [braces(entry.key), field, '$a', '$b']),
        data: {
          'placeholder': entry.key,
          'field': field,
          'template': '$a',
          'translation': '$b',
        },
      );
    }
  }
}

Map<String, Map<String, Object?>> _placeholders(Map<String, Object?> meta) {
  final raw = meta['placeholders'];
  if (raw is! Map<String, Object?>) return const {};
  return {
    for (final e in raw.entries)
      if (e.value is Map<String, Object?>)
        e.key: e.value! as Map<String, Object?>,
  };
}

final RegExp _letter = RegExp(r'\p{L}', unicode: true);

/// AG013: info when the translation is the template text, unchanged.
void checkUntranslated(MessageContext c) {
  if (c.translationText != c.templateText) return;
  if (languageOf(c.locale) == languageOf(c.templateLocale)) return;
  if (!_letter.hasMatch(plainText(c.templateNodes))) return;
  c.add('AG013', c.t('ag013'));
}
