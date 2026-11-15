/// AG001, AG002, AG003 (renames) and AG008 (argument kind changes).
library;

import '../icu/nodes.dart';
import 'context.dart';

/// Compares the sets of argument names of template and translation.
///
/// Missing and extra names that line up in document order are reported as one
/// rename (AG003) instead of an AG001 + AG002 pair.
void checkPlaceholders(MessageContext c) {
  final missing = [
    for (final n in c.templateArgs.keys)
      if (!c.translationArgs.containsKey(n)) n,
  ];
  final extra = [
    for (final n in c.translationArgs.keys)
      if (!c.templateArgs.containsKey(n)) n,
  ];

  if (missing.isNotEmpty && missing.length == extra.length) {
    for (var i = 0; i < missing.length; i++) {
      c.renamedFrom.add(missing[i]);
      c.renamedTo.add(extra[i]);
      c.add(
        'AG003',
        c.t('ag003', [braces(missing[i]), braces(extra[i]), extra[i], c.key]),
        data: {'from': missing[i], 'to': extra[i]},
      );
    }
  } else {
    for (final n in missing) {
      c.add('AG001', c.t('ag001', [braces(n)]), data: {'placeholder': n});
    }
    for (final n in extra) {
      c.add(
        'AG002',
        c.t('ag002', [braces(n), n, c.key]),
        data: {'placeholder': n},
      );
    }
  }

  // AG008: same name, different kind.
  for (final entry in c.templateArgs.entries) {
    final other = c.translationArgs[entry.key];
    if (other == null) continue;
    if (other.kind != entry.value.kind) {
      c.add(
        'AG008',
        c.t('ag008', [
          entry.key,
          c.t('kind.${_kindName(entry.value.kind)}'),
          c.t('kind.${_kindName(other.kind)}'),
        ]),
        data: {
          'name': entry.key,
          'template': _kindName(entry.value.kind),
          'translation': _kindName(other.kind),
        },
      );
    }
  }
}

String _kindName(ArgKind kind) => kind.name;
