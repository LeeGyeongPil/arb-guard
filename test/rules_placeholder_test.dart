import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('renames (AG003)', () {
    test('{name} -> {nombre} is exactly one AG003', () {
      final f = check('Hello, {name}!', '¡Hola, {nombre}!');
      expect(ids(f), ['AG003']);
      expect(f.single.data, {'from': 'name', 'to': 'nombre'});
      expect(f.single.message, contains('{name} was translated to {nombre}'));
    });

    test('plural variable renamed in every place is one AG003', () {
      final f = check(
        '{count, plural, one{{count} item in {store}} other{{count} items in {store}}}',
        '{n, plural, one{{n} artículo en {store}} other{{n} artículos en {store}}}',
      );
      expect(ids(f), ['AG003']);
    });

    test('two simultaneous renames give two AG003', () {
      final f = check('{a} and {b}', '{x} y {z}');
      expect(ids(f), ['AG003', 'AG003']);
      expect(f.map((x) => x.data['to']), ['x', 'z']);
    });

    test('uneven change falls back to AG001 + AG002', () {
      final f = check('{a} and {b}', '{x}');
      expect(ids(f), ['AG001', 'AG001', 'AG002']);
    });
  });

  group('missing and extra (AG001, AG002)', () {
    test('missing placeholder is AG001', () {
      final f = check('Hi {name}, you have {n} mails', 'Hola {name}');
      expect(ids(f), ['AG001']);
      expect(f.single.data['placeholder'], 'n');
    });

    test('extra placeholder is AG002 and explains the signature change', () {
      final f = check('Hello, {name}!', '안녕하세요, {name}님! {user}', locale: 'ko');
      expect(ids(f), ['AG002']);
      expect(f.single.message, contains("Object user"));
      expect(f.single.message, contains('signature'));
    });

    test('identical placeholders in a different order are fine', () {
      expect(check('{a} then {b}', '{b} luego {a}'), isEmpty);
    });
  });

  group('kind changes (AG008)', () {
    test('plural -> plain placeholder', () {
      final f = check('{count, plural, one{a} other{b}}', '{count} things');
      expect(ids(f), ['AG008']);
      expect(f.single.data, {
        'name': 'count',
        'template': 'plural',
        'translation': 'placeholder',
      });
    });

    test('select -> plural', () {
      final f = check(
        '{g, select, male{a} other{b}}',
        '{g, plural, one{a} other{b}}',
      );
      expect(ids(f), contains('AG008'));
    });

    test('same kind reports nothing', () {
      expect(
        check('{g, select, male{a} other{b}}', '{g, select, male{x} other{y}}'),
        isEmpty,
      );
    });
  });

  group('syntax errors (AG011)', () {
    test('broken translation is AG011 with the offset', () {
      final f = check('Hi {name}', 'Hola {name');
      expect(ids(f), ['AG011']);
      expect(f.single.data['offset'], 5);
    });
  });
}
