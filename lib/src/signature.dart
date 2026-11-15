/// Structural signature of a message: arguments, branches, tags, `#`.
library;

import 'icu/nodes.dart';

/// An argument name with its (strongest) kind in one message.
class ArgInfo {
  ArgInfo(this.name, this.kind, {this.type, this.format});
  final String name;
  ArgKind kind;
  final String? type;
  final String? format;
}

/// Collects arguments in document order. A name used as plural/select anywhere
/// counts as plural/select even if it also appears inline as `{count}`.
Map<String, ArgInfo> collectArgs(List<IcuNode> nodes) {
  final out = <String, ArgInfo>{};
  void walk(List<IcuNode> ns) {
    for (final n in ns) {
      switch (n) {
        case TextNode():
          break;
        case PlaceholderNode():
          out.putIfAbsent(
            n.name,
            () => ArgInfo(
              n.name,
              ArgKind.placeholder,
              type: n.type,
              format: n.format,
            ),
          );
        case ArgNode():
          final existing = out[n.name];
          if (existing == null) {
            out[n.name] = ArgInfo(n.name, n.kind);
          } else {
            existing.kind = n.kind;
          }
          for (final b in n.branches) {
            walk(b.nodes);
          }
      }
    }
  }

  walk(nodes);
  return out;
}

/// A markup tag token such as `<b>` (open), `</b>` (close).
class TagToken {
  const TagToken(this.name, this.closing);
  final String name;
  final bool closing;

  @override
  String toString() => closing ? '</$name>' : '<$name>';

  @override
  bool operator ==(Object other) =>
      other is TagToken && other.name == name && other.closing == closing;

  @override
  int get hashCode => Object.hash(name, closing);
}

final RegExp _tagPattern = RegExp(
  r'<(/?)([A-Za-z][A-Za-z0-9-]*)((?:\s[^<>]*)?)(/?)>',
);

/// Marker that replaces arguments inside the flattened text of a context.
const String _argMarker = '\u0000';

/// Direct content of one message part (top level or one branch).
class Context {
  Context(this.nodes);
  final List<IcuNode> nodes;

  /// Names of `{name}` placeholders written directly in this part.
  late final List<String> placeholders = [
    for (final n in nodes)
      if (n is PlaceholderNode) n.name,
  ];

  /// Text of this part with arguments replaced by a marker.
  late final String flatText =
      nodes.map((n) => n is TextNode ? n.text : _argMarker).join();

  /// Markup tags in this part (self-closing tags are ignored).
  late final List<TagToken> tags = [
    for (final m in _tagPattern.allMatches(flatText))
      if (m.group(4) != '/') TagToken(m.group(2)!, m.group(1) == '/'),
  ];

  late final bool hasHash = flatText.contains('#');
}

/// A template part paired with the translation part at the same place.
class ContextPair {
  ContextPair({
    required this.path,
    required this.template,
    required this.translation,
    this.branchKey,
    this.enclosingPlural,
    this.inPlural = false,
  });

  /// Readable path such as `` (top level) or `count=few`.
  final String path;
  final Context template;
  final Context translation;

  /// Key of the translation branch (null at top level).
  final String? branchKey;

  /// Variable of the plural this part is a direct branch of, if any.
  final String? enclosingPlural;

  /// True when this part is inside any plural branch.
  final bool inPlural;
}

/// A template argument paired with the translation argument of the same name
/// and kind at the same place.
class ArgPair {
  ArgPair(this.path, this.template, this.translation);
  final String path;
  final ArgNode template;
  final ArgNode translation;
}

/// Result of [pairStructure].
class StructurePairs {
  final List<ContextPair> contexts = [];
  final List<ArgPair> args = [];
}

/// Finds the template branch a translation branch should be compared with.
///
/// Same key first; a translation `one` falls back to the template `=1`; a
/// category the template does not use (for example Polish `few`) falls back to
/// the template `other`.
Branch? referenceBranch(ArgNode template, String key) {
  final same = template.branch(key);
  if (same != null) return same;
  if (template.kind == ArgKind.select) return null;
  if (key == 'one') {
    final exact = template.branch('=1');
    if (exact != null) return exact;
  }
  if (key == 'zero') {
    final exact = template.branch('=0');
    if (exact != null) return exact;
  }
  if (key.startsWith('=')) return null;
  return template.branch('other');
}

/// Walks both trees in parallel and pairs matching parts and arguments.
StructurePairs pairStructure(
  List<IcuNode> template,
  List<IcuNode> translation,
) {
  final out = StructurePairs();

  void walk(
    List<IcuNode> t,
    List<IcuNode> r,
    String path,
    String? branchKey,
    String? enclosingPlural,
    bool inPlural,
  ) {
    out.contexts.add(
      ContextPair(
        path: path,
        template: Context(t),
        translation: Context(r),
        branchKey: branchKey,
        enclosingPlural: enclosingPlural,
        inPlural: inPlural,
      ),
    );
    final candidates = t.whereType<ArgNode>().toList();
    final used = <ArgNode>{};
    for (final ra in r.whereType<ArgNode>()) {
      ArgNode? ta;
      for (final c in candidates) {
        if (!used.contains(c) && c.name == ra.name && c.kind == ra.kind) {
          ta = c;
          break;
        }
      }
      if (ta == null) continue;
      used.add(ta);
      final here = path.isEmpty ? ra.name : '$path/${ra.name}';
      out.args.add(ArgPair(here, ta, ra));
      for (final rb in ra.branches) {
        final tb = referenceBranch(ta, rb.key);
        if (tb == null) continue;
        walk(
          tb.nodes,
          rb.nodes,
          '$here=${rb.key}',
          rb.key,
          ra.kind == ArgKind.plural || ra.kind == ArgKind.ordinal
              ? ra.name
              : null,
          inPlural || ra.kind == ArgKind.plural || ra.kind == ArgKind.ordinal,
        );
      }
    }
  }

  walk(template, translation, '', null, null, false);
  return out;
}

/// All plural arguments (including nested ones), in document order.
List<ArgNode> allPlurals(List<IcuNode> nodes) {
  final out = <ArgNode>[];
  void walk(List<IcuNode> ns) {
    for (final n in ns) {
      if (n is ArgNode) {
        if (n.kind == ArgKind.plural) out.add(n);
        for (final b in n.branches) {
          walk(b.nodes);
        }
      }
    }
  }

  walk(nodes);
  return out;
}

/// True when [tokens] open and close in proper nesting.
bool tagsBalanced(List<TagToken> tokens) {
  final stack = <String>[];
  for (final t in tokens) {
    if (!t.closing) {
      stack.add(t.name);
    } else {
      if (stack.isEmpty || stack.last != t.name) return false;
      stack.removeLast();
    }
  }
  return stack.isEmpty;
}

/// Plain text of a message (for "has letters" checks).
String plainText(List<IcuNode> nodes) {
  final buf = StringBuffer();
  void walk(List<IcuNode> ns) {
    for (final n in ns) {
      switch (n) {
        case TextNode():
          buf.write(n.text);
        case PlaceholderNode():
          break;
        case ArgNode():
          for (final b in n.branches) {
            walk(b.nodes);
          }
      }
    }
  }

  walk(nodes);
  return buf.toString();
}
