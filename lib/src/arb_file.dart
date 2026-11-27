/// Reading ARB files with line/column positions of the top-level keys.
library;

import 'dart:convert';

/// 1-based line and column in a text file.
class Position {
  const Position(this.line, this.column);
  final int line;
  final int column;

  @override
  String toString() => '$line:$column';
}

/// A top-level key written more than once in the same file.
///
/// JSON parsers keep only the last value, so the earlier ones are lost.
class DuplicateKey {
  const DuplicateKey(this.key, this.first, this.position);

  final String key;

  /// Where the key first appears.
  final Position first;

  /// Where it appears again (one entry per repeat).
  final Position position;
}

/// A parsed `.arb` file.
class ArbFile {
  ArbFile._({
    required this.path,
    required this.locale,
    required this.entries,
    required this.positions,
    this.duplicates = const [],
    this.parseError,
    this.parseErrorKey,
    this.errorPosition,
  });

  /// Path as it should be shown in reports.
  final String path;

  /// `@@locale`, or the locale taken from the file name.
  final String locale;

  /// All top-level entries (messages, `@key` metadata, `@@` globals).
  final Map<String, Object?> entries;

  /// Position of the opening quote of each top-level key.
  final Map<String, Position> positions;

  /// Top-level keys that appear more than once, in file order.
  final List<DuplicateKey> duplicates;

  /// Set when the file is not valid JSON (then [entries] is empty).
  final String? parseError;

  /// Message-table key for [parseError] when the tool, not the JSON parser,
  /// produced it (so reports can translate it); null otherwise.
  final String? parseErrorKey;
  final Position? errorPosition;

  /// Message keys: everything that does not start with `@`.
  Iterable<String> get messageKeys =>
      entries.keys.where((k) => !k.startsWith('@'));

  /// Parses [source]. Never throws: problems end up in [parseError].
  static ArbFile parse(String path, String source) {
    final fallbackLocale = localeFromFileName(path);
    final index = _LineIndex(source);
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      final offset = e.offset ?? 0;
      return ArbFile._(
        path: path,
        locale: fallbackLocale,
        entries: const {},
        positions: const {},
        parseError: e.message,
        errorPosition: index.positionOf(offset),
      );
    }
    if (decoded is! Map<String, Object?>) {
      return ArbFile._(
        path: path,
        locale: fallbackLocale,
        entries: const {},
        positions: const {},
        parseError: 'the top level must be a JSON object',
        parseErrorKey: 'arb.top_not_object',
        errorPosition: const Position(1, 1),
      );
    }
    final locale = decoded['@@locale'];
    final duplicates = <DuplicateKey>[];
    return ArbFile._(
      path: path,
      locale: locale is String && locale.isNotEmpty ? locale : fallbackLocale,
      entries: decoded,
      positions: _scanKeyPositions(source, index, duplicates),
      duplicates: duplicates,
    );
  }

  /// `lib/l10n/app_zh_Hant.arb` -> `zh_Hant`; `app.arb` -> `app`.
  static String localeFromFileName(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final base =
        name.endsWith('.arb') ? name.substring(0, name.length - 4) : name;
    final cut = base.indexOf('_');
    return cut < 0 ? base : base.substring(cut + 1);
  }
}

class _LineIndex {
  _LineIndex(this.source) {
    _starts.add(0);
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 10) _starts.add(i + 1);
    }
  }
  final String source;
  final List<int> _starts = [];

  Position positionOf(int offset) {
    var lo = 0;
    var hi = _starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return Position(lo + 1, offset - _starts[lo] + 1);
  }
}

/// Finds the position of every key of the top-level object.
///
/// A repeated key keeps its last position (the value JSON decoding keeps);
/// each repeat is added to [duplicates].
Map<String, Position> _scanKeyPositions(
  String source,
  _LineIndex index,
  List<DuplicateKey> duplicates,
) {
  final result = <String, Position>{};
  final first = <String, Position>{};
  var depth = 0;
  var expectKey = false;
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == '"') {
      final start = i;
      i++;
      while (i < source.length && source[i] != '"') {
        if (source[i] == r'\') i++;
        i++;
      }
      if (depth == 1 && expectKey && i < source.length) {
        final raw = source.substring(start, i + 1);
        final key = jsonDecode(raw);
        if (key is String) {
          final at = index.positionOf(start);
          final seen = first[key];
          if (seen == null) {
            first[key] = at;
          } else {
            duplicates.add(DuplicateKey(key, seen, at));
          }
          result[key] = at;
        }
        expectKey = false;
      }
      i++;
      continue;
    }
    if (c == '{' || c == '[') {
      depth++;
      if (depth == 1 && c == '{') expectKey = true;
    } else if (c == '}' || c == ']') {
      depth--;
    } else if (c == ',' && depth == 1) {
      expectKey = true;
    }
    i++;
  }
  return result;
}
