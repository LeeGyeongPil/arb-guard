/// AG009 (markup tags) and AG010 (literal `#` in plural branches).
library;

import '../signature.dart';
import 'context.dart';

/// AG009: tags may move around but must stay the same set and stay paired.
void checkTags(MessageContext c) {
  final reported = <String>{};
  for (final ctx in c.pairs.contexts) {
    final want = ctx.template.tags;
    final got = ctx.translation.tags;
    if (want.isEmpty && got.isEmpty) continue;
    final missing = _minus(want, got);
    final extra = _minus(got, want);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      if (!reported.add('${ctx.path}|diff')) continue;
      c.add(
        'AG009',
        c.t('ag009.diff', [_join(c, missing), _join(c, extra)]),
        data: {
          'path': ctx.path,
          'missing': missing.map((t) => t.toString()).toList(),
          'unexpected': extra.map((t) => t.toString()).toList(),
        },
      );
    } else if (tagsBalanced(want) && !tagsBalanced(got)) {
      if (!reported.add('${ctx.path}|nesting')) continue;
      c.add(
        'AG009',
        c.t('ag009.nesting', [got.join(' ')]),
        data: {'path': ctx.path, 'tags': got.map((t) => t.toString()).toList()},
      );
    }
  }
}

String _join(MessageContext c, List<TagToken> tokens) =>
    tokens.isEmpty ? c.t('none') : tokens.join(' ');

/// Multiset difference `a - b`.
List<TagToken> _minus(List<TagToken> a, List<TagToken> b) {
  final remaining = [...b];
  final out = <TagToken>[];
  for (final t in a) {
    final i = remaining.indexOf(t);
    if (i >= 0) {
      remaining.removeAt(i);
    } else {
      out.add(t);
    }
  }
  return out;
}

/// AG010: Flutter does not turn `#` into the number, so a new `#` shows up
/// on screen as a literal character.
void checkHashLiteral(MessageContext c) {
  for (final ctx in c.pairs.contexts) {
    if (!ctx.inPlural || ctx.branchKey == null) continue;
    if (!ctx.translation.hasHash || ctx.template.hasHash) continue;
    final variable = ctx.enclosingPlural ?? 'count';
    c.add(
      'AG010',
      c.t('ag010', [ctx.branchKey!, braces(variable)]),
      data: {'branch': ctx.branchKey, 'path': ctx.path},
    );
  }
}
