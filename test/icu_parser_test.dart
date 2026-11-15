import 'package:arb_guard/src/icu/nodes.dart';
import 'package:arb_guard/src/icu/parser.dart';
import 'package:test/test.dart';

void main() {
  group('arguments and branches', () {
    test('parses a plain placeholder between text', () {
      final nodes = parseIcu('Hello, {name}!');
      expect(nodes, hasLength(3));
      expect((nodes[0] as TextNode).text, 'Hello, ');
      expect((nodes[1] as PlaceholderNode).name, 'name');
      expect((nodes[2] as TextNode).text, '!');
    });

    test('nested braces inside a plural branch', () {
      final nodes = parseIcu(
        '{count, plural, =0{none} one{1 item} other{{count} items}}',
      );
      final plural = nodes.single as ArgNode;
      expect(plural.kind, ArgKind.plural);
      expect(plural.branches.map((b) => b.key), ['=0', 'one', 'other']);
      final other = plural.branch('other')!;
      expect((other.nodes.first as PlaceholderNode).name, 'count');
    });

    test('select nested in plural', () {
      final nodes = parseIcu(
        '{n, plural, one{{g, select, male{He} other{They}} left} other{{n} left}}',
      );
      final plural = nodes.single as ArgNode;
      final inner = plural.branch('one')!.nodes.first as ArgNode;
      expect(inner.kind, ArgKind.select);
      expect(inner.name, 'g');
      expect(inner.branches.map((b) => b.key), ['male', 'other']);
    });

    test('select keys may be non-ASCII', () {
      final nodes = parseIcu('{g, select, 남성{그} other{그들}}');
      expect((nodes.single as ArgNode).branch('남성'), isNotNull);
    });

    test('format arguments keep their name and type', () {
      final node = parseIcu('{n, number, compact}').single as PlaceholderNode;
      expect(node.name, 'n');
      expect(node.type, 'number');
      expect(node.format, 'compact');
    });
  });

  group('use-escaping', () {
    test('default mode: apostrophe is plain text, one placeholder', () {
      final nodes = parseIcu("It's {name}");
      expect(nodes.whereType<PlaceholderNode>(), hasLength(1));
      expect((nodes.first as TextNode).text, "It's ");
    });

    test('escaping on: a lone quote starts a quoted section', () {
      final nodes = parseIcu(
        "It's {name}",
        options: const ParseOptions(useEscaping: true),
      );
      expect(nodes.whereType<PlaceholderNode>(), isEmpty);
    });

    test('escaping on: doubled quote is an apostrophe', () {
      final nodes = parseIcu(
        "It''s {name}",
        options: const ParseOptions(useEscaping: true),
      );
      expect(nodes.whereType<PlaceholderNode>(), hasLength(1));
      expect((nodes.first as TextNode).text, "It's ");
    });

    test('escaping on: quoted braces are literal', () {
      final nodes = parseIcu(
        "'{'name'}'",
        options: const ParseOptions(useEscaping: true),
      );
      expect(nodes.single, isA<TextNode>());
      expect((nodes.single as TextNode).text, '{name}');
    });
  });

  group('relax-syntax', () {
    test('strict mode rejects a brace that is not an argument', () {
      expect(
        () => parseIcu('{ not an argument }'),
        throwsA(isA<IcuSyntaxError>()),
      );
    });

    test('relax mode keeps it as text', () {
      final nodes = parseIcu(
        '{ not an argument }',
        options: const ParseOptions(relaxSyntax: true),
      );
      expect((nodes.single as TextNode).text, '{ not an argument }');
    });

    test('stray closing brace: error offset in strict, text in relax', () {
      expect(
        () => parseIcu('a } b'),
        throwsA(
          isA<IcuSyntaxError>()
              .having((e) => e.offset, 'offset', 2)
              .having(
                (e) => e.code,
                'code',
                IcuErrorCode.unexpectedClosingBrace,
              ),
        ),
      );
      final nodes = parseIcu(
        'a } b',
        options: const ParseOptions(relaxSyntax: true),
      );
      expect((nodes.single as TextNode).text, 'a } b');
    });
  });

  group('syntax errors report offsets', () {
    IcuSyntaxError errorOf(String source) {
      try {
        parseIcu(source);
      } on IcuSyntaxError catch (e) {
        return e;
      }
      fail('expected a syntax error for: $source');
    }

    test('plural without closing brace points at its opening brace', () {
      final e = errorOf('{count, plural, one{x} other{y}');
      expect(e.code, IcuErrorCode.unterminatedBrace);
      expect(e.offset, 0);
    });

    test('placeholder without closing brace', () {
      final e = errorOf('Hello {name');
      expect(e.code, IcuErrorCode.unterminatedBrace);
      expect(e.offset, 6);
    });

    test('branch without closing brace points at the branch brace', () {
      final e = errorOf('{c, plural, other{x');
      expect(e.code, IcuErrorCode.unterminatedBrace);
      expect(e.offset, 17);
    });

    test('plural without other branch', () {
      final e = errorOf('{c, plural, one{x}}');
      expect(e.code, IcuErrorCode.missingOther);
      expect(e.offset, 0);
    });

    test('duplicate branch', () {
      final e = errorOf('{c, select, a{x} a{y} other{z}}');
      expect(e.code, IcuErrorCode.duplicateBranch);
      expect(e.offset, 17);
    });

    test('missing argument name', () {
      final e = errorOf('Hi {}');
      expect(e.code, IcuErrorCode.expectedIdentifier);
      expect(e.offset, 4);
    });
  });
}
