/// AG004 (select keys), AG005 (plural categories), AG006 (exact branches) and
/// AG007 (placeholders dropped from a branch).
library;

import '../finding.dart';
import '../icu/nodes.dart';
import '../plural_rules.dart';
import '../signature.dart';
import 'context.dart';

/// AG004: select keys are values the app passes in, so they must not change.
void checkSelectKeys(MessageContext c) {
  for (final pair in c.pairs.args) {
    if (pair.template.kind != ArgKind.select) continue;
    final templateKeys = pair.template.branches.map((b) => b.key).toList();
    final translationKeys =
        pair.translation.branches.map((b) => b.key).toList();
    final added = [
      for (final k in translationKeys)
        if (!templateKeys.contains(k)) k,
    ];
    final missing = [
      for (final k in templateKeys)
        if (!translationKeys.contains(k)) k,
    ];
    if (added.isEmpty && missing.isEmpty) continue;
    final data = <String, Object?>{
      'select': pair.translation.name,
      'added': added,
      'missing': missing,
    };
    if (added.isEmpty) {
      c.add(
        'AG004',
        c.t('ag004.missing', [missing.join(', ')]),
        severity: Severity.warning,
        data: data,
      );
    } else if (added.length == missing.length) {
      final pairs = [
        for (var i = 0; i < added.length; i++) '${missing[i]} → ${added[i]}',
      ];
      data['pairs'] = pairs;
      c.add('AG004', c.t('ag004.changed', [pairs.join(', ')]), data: data);
    } else if (missing.isEmpty) {
      c.add('AG004', c.t('ag004.added', [added.join(', ')]), data: data);
    } else {
      c.add(
        'AG004',
        c.t('ag004.mixed', [added.join(', '), missing.join(', ')]),
        data: data,
      );
    }
  }
}

/// AG005: plural categories of the translation must fit the locale.
void checkPluralCategories(MessageContext c) {
  final rules = pluralCategoriesFor(c.locale);
  if (rules == null) return;
  for (final plural in allPlurals(c.translationNodes)) {
    final keys = plural.branches.map((b) => b.key).toSet();
    final missing = <String>[];
    for (final category in const [
      'zero',
      'one',
      'two',
      'few',
      'many',
      'other',
    ]) {
      if (!rules.required.contains(category)) continue;
      if (keys.contains(category)) continue;
      // An exact branch covers a category that only holds one number.
      final exact = switch (category) {
        'zero' => '=0',
        'one' => '=1',
        'two' => '=2',
        _ => null,
      };
      if (exact != null && keys.contains(exact)) continue;
      missing.add(category);
    }
    if (missing.isNotEmpty) {
      c.add(
        'AG005',
        c.t('ag005.missing', [c.locale, missing.join(', ')]),
        data: {'plural': plural.name, 'missing': missing},
      );
    }
    final unused = [
      for (final k in plural.branches.map((b) => b.key))
        if (pluralKeywords.contains(k) && !rules.allowed.contains(k)) k,
    ];
    if (unused.isNotEmpty) {
      c.add(
        'AG005',
        c.t('ag005.unused', [c.locale, unused.join(', ')]),
        severity: Severity.warning,
        data: {'plural': plural.name, 'unused': unused},
      );
    }
  }
}

/// AG006: the template's `=0` / `=1` style branches should survive.
void checkExactBranches(MessageContext c) {
  for (final pair in c.pairs.args) {
    if (pair.template.kind != ArgKind.plural) continue;
    for (final b in pair.template.branches) {
      if (!b.key.startsWith('=')) continue;
      if (pair.translation.branch(b.key) == null) {
        c.add(
          'AG006',
          c.t('ag006', [b.key]),
          data: {'plural': pair.translation.name, 'branch': b.key},
        );
      }
    }
  }
}

/// AG007: a branch must keep the placeholders of the template branch.
void checkBranchPlaceholders(MessageContext c) {
  final reported = <String>{};
  for (final ctx in c.pairs.contexts) {
    if (ctx.branchKey == null) continue;
    final have = ctx.translation.placeholders.toSet();
    for (final name in ctx.template.placeholders) {
      if (have.contains(name)) continue;
      // Dropping the counted number from `one{One item}` is idiomatic.
      if (name == ctx.enclosingPlural) continue;
      // Missing in the whole message: AG001 / AG003 already reports it.
      if (!c.translationArgs.containsKey(name)) continue;
      if (!reported.add('${ctx.path}|$name')) continue;
      c.add(
        'AG007',
        c.t('ag007', [ctx.branchKey!, braces(name)]),
        data: {'branch': ctx.branchKey, 'placeholder': name, 'path': ctx.path},
      );
    }
  }
}
