import 'package:arb_guard/arb_guard.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const _template = '{count, plural, one{{count} item} other{{count} items}}';

void main() {
  group('CLDR categories (AG005)', () {
    test('Korean with only other: no findings', () {
      expect(
        check(_template, '{count, plural, other{{count}개}}', locale: 'ko'),
        isEmpty,
      );
    });

    test('Spanish without many: no findings', () {
      expect(
        check(
          _template,
          '{count, plural, one{{count} artículo} other{{count} artículos}}',
        ),
        isEmpty,
      );
    });

    test('Spanish with many is allowed too', () {
      expect(
        check(
          _template,
          '{count, plural, one{{count} a} many{{count} de b} other{{count} c}}',
        ),
        isEmpty,
      );
    });

    test('Polish without few and many is an error', () {
      final f = check(
        _template,
        '{count, plural, one{{count} plik} other{{count} plików}}',
        locale: 'pl',
      );
      expect(ids(f), ['AG005']);
      expect(f.single.severity, Severity.error);
      expect(f.single.data['missing'], ['few', 'many']);
    });

    test('English using few is a warning', () {
      final f = check(
        _template,
        '{count, plural, one{{count} item} few{{count} items} other{{count} items}}',
        locale: 'en_GB',
      );
      expect(ids(f), ['AG005']);
      expect(f.single.severity, Severity.warning);
      expect(f.single.data['unused'], ['few']);
    });

    test('exact =1 branch satisfies one', () {
      expect(
        check(_template, '{count, plural, =1{uno} other{{count} otros}}'),
        isEmpty,
      );
    });

    test('unknown language only needs other', () {
      expect(
        check(_template, '{count, plural, other{{count} xx}}', locale: 'xx'),
        isEmpty,
      );
    });
  });

  group('exact branches (AG006)', () {
    test('dropping =0 is a warning', () {
      final f = check(
        '{count, plural, =0{No files} one{1 file} other{{count} files}}',
        '{count, plural, one{1 archivo} other{{count} archivos}}',
      );
      expect(ids(f), ['AG006']);
      expect(f.single.severity, Severity.warning);
      expect(f.single.data['branch'], '=0');
    });

    test('keeping =0 is fine', () {
      expect(
        check(
          '{count, plural, =0{No files} one{1 file} other{{count} files}}',
          '{count, plural, =0{Sin archivos} one{1 archivo} other{{count} archivos}}',
        ),
        isEmpty,
      );
    });
  });

  group('branch placeholders (AG007)', () {
    const store =
        '{count, plural, one{{count} item in {store}} other{{count} items in {store}}}';

    test('Polish few branch that drops {store}', () {
      final f = check(
        store,
        '{count, plural, one{{count} produkt w {store}} few{{count} produkty} '
        'many{{count} produktów w {store}} other{{count} produktu w {store}}}',
        locale: 'pl',
      );
      expect(ids(f), ['AG007']);
      expect(f.single.data['branch'], 'few');
      expect(f.single.data['placeholder'], 'store');
    });

    test('dropping the counted number in one is idiomatic', () {
      expect(
        check(
          '{count, plural, one{{count} file} other{{count} files}}',
          '{count, plural, one{Un archivo} other{{count} archivos}}',
        ),
        isEmpty,
      );
    });

    test('dropping another placeholder from a select branch is reported', () {
      final f = check(
        '{g, select, male{{name} came} other{{name} came}}',
        '{g, select, male{Vino} other{{name} vino}}',
      );
      expect(ids(f), ['AG007']);
    });

    test('dropping the plural count inside a nested select is idiomatic', () {
      expect(
        check(
          '{count, plural, one{{g, select, male{{count} he} other{{count} they}}} other{{count} x}}',
          '{count, plural, one{{g, select, male{Él} other{Elle}}} other{{count} x}}',
        ),
        isEmpty,
      );
    });

    test('nested select drop of another placeholder shows the path', () {
      final f = check(
        '{count, plural, one{{g, select, male{{name} he} other{{name} they}}} other{{count} x}}',
        '{count, plural, one{{g, select, male{Él} other{{name} elle}}} other{{count} x}}',
      );
      expect(ids(f), ['AG007']);
      expect(f.single.data['path'], 'count=one/g=male');
      expect(f.single.message, contains('count=one/g=male'));
    });

    test('a placeholder missing everywhere is not repeated per branch', () {
      final f = check(
        '{g, select, male{{name} came} other{{name} came}}',
        '{g, select, male{Vino} other{Vino}}',
      );
      expect(ids(f), ['AG001']);
    });
  });
}
