import 'package:arb_guard/arb_guard.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const _template = '{g, select, male{He} female{She} other{They}}';

void main() {
  test('translated keys give one AG004 error with pairs', () {
    final f = check(
      _template,
      '{g, select, masculino{Él} femenino{Ella} other{Elle}}',
    );
    expect(ids(f), ['AG004']);
    expect(f.single.severity, Severity.error);
    expect(f.single.message, contains('male → masculino, female → femenino'));
    expect(f.single.data['pairs'], ['male → masculino', 'female → femenino']);
  });

  test('case change is AG004 too', () {
    final f = check(
      _template,
      '{g, select, Male{Él} female{Ella} other{Elle}}',
    );
    expect(ids(f), ['AG004']);
    expect(f.single.data['added'], ['Male']);
    expect(f.single.data['missing'], ['male']);
  });

  test('only missing template keys is a warning', () {
    final f = check(_template, '{g, select, male{Él} other{Elle}}');
    expect(ids(f), ['AG004']);
    expect(f.single.severity, Severity.warning);
    expect(f.single.data['missing'], ['female']);
  });

  test('extra key without a missing one is an error', () {
    final f = check(
      _template,
      '{g, select, male{a} female{b} neutral{c} other{d}}',
    );
    expect(ids(f), ['AG004']);
    expect(f.single.severity, Severity.error);
    expect(f.single.data['added'], ['neutral']);
  });

  test('uneven add and miss is reported as mixed', () {
    final f = check(_template, '{g, select, hombre{a} other{c}}');
    expect(ids(f), ['AG004']);
    expect(f.single.message, contains('added hombre'));
    expect(f.single.message, contains('missing male, female'));
  });

  test('same keys in another order are fine', () {
    expect(
      check(_template, '{g, select, other{x} female{y} male{z}}'),
      isEmpty,
    );
  });

  test('nested select inside plural is compared too', () {
    final f = check(
      '{n, plural, one{{g, select, male{a} other{b}}} other{{n} x}}',
      '{n, plural, one{{g, select, hombre{a} other{b}}} other{{n} x}}',
    );
    expect(ids(f), ['AG004']);
  });
}
