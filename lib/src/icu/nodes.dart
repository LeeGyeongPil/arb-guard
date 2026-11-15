/// Node types of the ICU message subset understood by Flutter's `gen-l10n`.
library;

/// Base class of all parsed message nodes.
sealed class IcuNode {
  const IcuNode();
}

/// Literal text (escapes already resolved).
final class TextNode extends IcuNode {
  const TextNode(this.text);
  final String text;
}

/// A simple argument such as `{name}` or `{count, number}`.
final class PlaceholderNode extends IcuNode {
  const PlaceholderNode(this.name, {this.type, this.format, this.offset = 0});
  final String name;

  /// Format type for `{x, number}` / `{x, date, yMd}` style arguments.
  final String? type;
  final String? format;
  final int offset;
}

/// One branch of a plural or select (`one{...}`, `=0{...}`, `male{...}`).
final class Branch {
  const Branch(this.key, this.nodes);
  final String key;
  final List<IcuNode> nodes;
}

/// Kind of a message argument.
enum ArgKind { placeholder, plural, ordinal, select }

/// `plural` / `selectordinal` / `select` argument with its branches.
final class ArgNode extends IcuNode {
  const ArgNode(this.name, this.kind, this.branches, {this.offset = 0});
  final String name;
  final ArgKind kind;
  final List<Branch> branches;
  final int offset;

  Branch? branch(String key) {
    for (final b in branches) {
      if (b.key == key) return b;
    }
    return null;
  }
}
