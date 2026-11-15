/// ICU subset parser modelled on Flutter's `gen-l10n` message parser.
library;

import 'nodes.dart';

/// How the parser treats quotes and unbalanced braces (`l10n.yaml` flags).
class ParseOptions {
  const ParseOptions({this.useEscaping = false, this.relaxSyntax = false});

  /// `use-escaping`: single quotes quote literal text, `''` is an apostrophe.
  final bool useEscaping;

  /// `relax-syntax`: braces that do not start a valid argument are plain text.
  final bool relaxSyntax;
}

/// Error codes of [IcuSyntaxError]; localized by the report layer.
enum IcuErrorCode {
  unterminatedBrace,
  unexpectedClosingBrace,
  expectedIdentifier,
  expectedBranchBrace,
  expectedComma,
  missingOther,
  duplicateBranch,
  unknownType,
}

/// Thrown by [parseIcu] for malformed messages.
class IcuSyntaxError implements Exception {
  IcuSyntaxError(this.code, this.offset, this.message);
  final IcuErrorCode code;

  /// Zero-based offset into the message string (of the offending character or
  /// of the opening brace that was never closed).
  final int offset;
  final String message;

  @override
  String toString() => 'IcuSyntaxError at $offset: $message';
}

/// Parses [source] into nodes. Throws [IcuSyntaxError].
List<IcuNode> parseIcu(
  String source, {
  ParseOptions options = const ParseOptions(),
}) {
  return _Parser(source, options).parseNodes(inBranch: false);
}

final RegExp _identStart = RegExp(r'[A-Za-z_]');
final RegExp _identPart = RegExp(r'[A-Za-z0-9_]');

class _Parser {
  _Parser(this.s, this.options);
  final String s;
  final ParseOptions options;
  int i = 0;

  bool get _eof => i >= s.length;

  void _skipWs() {
    while (!_eof &&
        (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) {
      i++;
    }
  }

  String _ident() {
    final start = i;
    if (!_eof && _identStart.hasMatch(s[i])) {
      i++;
      while (!_eof && _identPart.hasMatch(s[i])) {
        i++;
      }
    }
    return s.substring(start, i);
  }

  IcuSyntaxError _unterminated(int start) => IcuSyntaxError(
    IcuErrorCode.unterminatedBrace,
    start,
    "'{' at offset $start is never closed",
  );

  /// True when a `{` at [at] starts a valid argument (used by relax-syntax).
  bool _looksLikeArgument(int at) {
    var j = at + 1;
    while (j < s.length && (s[j] == ' ' || s[j] == '\t')) {
      j++;
    }
    if (j >= s.length || !_identStart.hasMatch(s[j])) return false;
    while (j < s.length && _identPart.hasMatch(s[j])) {
      j++;
    }
    while (j < s.length && (s[j] == ' ' || s[j] == '\t')) {
      j++;
    }
    return j < s.length && (s[j] == '}' || s[j] == ',');
  }

  List<IcuNode> parseNodes({required bool inBranch}) {
    final nodes = <IcuNode>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        nodes.add(TextNode(buf.toString()));
        buf.clear();
      }
    }

    while (!_eof) {
      final c = s[i];
      if (options.useEscaping && c == "'") {
        if (i + 1 < s.length && s[i + 1] == "'") {
          buf.write("'");
          i += 2;
          continue;
        }
        // Quoted section: everything up to the next quote is literal.
        i++;
        while (!_eof && s[i] != "'") {
          buf.write(s[i]);
          i++;
        }
        if (!_eof) i++;
        continue;
      }
      if (c == '{') {
        if (options.relaxSyntax && !_looksLikeArgument(i)) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        nodes.add(_parseArgument());
        continue;
      }
      if (c == '}') {
        if (inBranch) break;
        if (options.relaxSyntax) {
          buf.write(c);
          i++;
          continue;
        }
        throw IcuSyntaxError(
          IcuErrorCode.unexpectedClosingBrace,
          i,
          "unexpected '}' without a matching '{'",
        );
      }
      buf.write(c);
      i++;
    }
    flush();
    return nodes;
  }

  IcuNode _parseArgument() {
    final start = i;
    i++; // {
    _skipWs();
    final name = _ident();
    if (name.isEmpty) {
      if (_eof) throw _unterminated(start);
      throw IcuSyntaxError(
        IcuErrorCode.expectedIdentifier,
        i,
        'expected an argument name after {',
      );
    }
    _skipWs();
    if (_eof) throw _unterminated(start);
    if (s[i] == '}') {
      i++;
      return PlaceholderNode(name, offset: start);
    }
    if (s[i] != ',') {
      throw IcuSyntaxError(
        IcuErrorCode.expectedComma,
        i,
        "expected ',' or '}' after the argument name",
      );
    }
    i++;
    _skipWs();
    final typeOffset = i;
    final type = _ident();
    _skipWs();
    if (type == 'plural' || type == 'selectordinal' || type == 'select') {
      if (_eof) throw _unterminated(start);
      if (s[i] != ',') {
        throw IcuSyntaxError(
          IcuErrorCode.expectedComma,
          i,
          "expected ',' after '$type'",
        );
      }
      i++;
      final kind =
          type == 'plural'
              ? ArgKind.plural
              : type == 'select'
              ? ArgKind.select
              : ArgKind.ordinal;
      return _parseBranches(name, kind, start);
    }
    if (type.isEmpty) {
      if (_eof) throw _unterminated(start);
      throw IcuSyntaxError(
        IcuErrorCode.unknownType,
        typeOffset,
        'expected an argument type after the comma',
      );
    }
    // Format argument such as {n, number, compact}: only the name matters.
    String? format;
    if (!_eof && s[i] == ',') {
      i++;
      final fs = i;
      while (!_eof && s[i] != '}' && s[i] != '{') {
        i++;
      }
      format = s.substring(fs, i).trim();
    }
    if (_eof || s[i] != '}') throw _unterminated(start);
    i++;
    return PlaceholderNode(name, type: type, format: format, offset: start);
  }

  ArgNode _parseBranches(String name, ArgKind kind, int start) {
    final branches = <Branch>[];
    while (true) {
      _skipWs();
      if (_eof) throw _unterminated(start);
      if (s[i] == '}') {
        i++;
        break;
      }
      final keyStart = i;
      while (!_eof &&
          s[i] != '{' &&
          s[i] != '}' &&
          s[i] != ' ' &&
          s[i] != '\t' &&
          s[i] != '\n' &&
          s[i] != '\r') {
        i++;
      }
      final key = s.substring(keyStart, i);
      if (key.isEmpty) {
        throw IcuSyntaxError(
          IcuErrorCode.expectedBranchBrace,
          i,
          'expected a branch name',
        );
      }
      if (kind != ArgKind.select && key.startsWith('offset:')) {
        continue; // plural offset: ignored, only the branches matter here
      }
      _skipWs();
      if (_eof) throw _unterminated(start);
      if (s[i] != '{') {
        throw IcuSyntaxError(
          IcuErrorCode.expectedBranchBrace,
          i,
          "expected '{' after branch name '$key'",
        );
      }
      final branchStart = i;
      i++;
      final nodes = parseNodes(inBranch: true);
      if (_eof) throw _unterminated(branchStart);
      i++; // closing }
      if (branches.any((b) => b.key == key)) {
        throw IcuSyntaxError(
          IcuErrorCode.duplicateBranch,
          keyStart,
          "branch '$key' is defined twice",
        );
      }
      branches.add(Branch(key, nodes));
    }
    if (!branches.any((b) => b.key == 'other')) {
      throw IcuSyntaxError(
        IcuErrorCode.missingOther,
        start,
        "the '$name' argument has no 'other' branch",
      );
    }
    return ArgNode(name, kind, branches, offset: start);
  }
}
