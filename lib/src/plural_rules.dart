/// Integer plural categories per language.
///
/// Source: CLDR language plural rules,
/// https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
/// (checked 2026-11-15). Categories that only appear for decimals or for
/// millions (`many` in es/fr/it/pt/ca, `many` in cs/sk/lt, `many` in he) are
/// treated as optional: translators may leave them out without harm.
library;

/// Required and optional plural categories of one language.
class PluralCategories {
  const PluralCategories(this.required, [this.optional = const {}]);

  /// Categories a translation must provide (`other` is always required).
  final Set<String> required;

  /// Categories that are allowed but may be left out.
  final Set<String> optional;

  Set<String> get allowed => {...required, ...optional};
}

const PluralCategories _otherOnly = PluralCategories({'other'});
const PluralCategories _oneOther = PluralCategories({'one', 'other'});
const PluralCategories _romance = PluralCategories({'one', 'other'}, {'many'});
const PluralCategories _slavicEast = PluralCategories({
  'one',
  'few',
  'many',
  'other',
});
const PluralCategories _slavicWest = PluralCategories(
  {'one', 'few', 'other'},
  {'many'},
);
const PluralCategories _southSlavic = PluralCategories({'one', 'few', 'other'});

/// Language code -> categories. Languages missing here are unknown.
const Map<String, PluralCategories> pluralTable = {
  // other only
  'ja': _otherOnly, 'ko': _otherOnly, 'zh': _otherOnly, 'vi': _otherOnly,
  'th': _otherOnly, 'id': _otherOnly, 'ms': _otherOnly, 'my': _otherOnly,
  'km': _otherOnly, 'lo': _otherOnly,
  // one / other
  'en': _oneOther, 'de': _oneOther, 'nl': _oneOther, 'sv': _oneOther,
  'da': _oneOther, 'nb': _oneOther, 'no': _oneOther, 'fi': _oneOther,
  'et': _oneOther, 'el': _oneOther, 'hu': _oneOther, 'tr': _oneOther,
  'bg': _oneOther, 'hi': _oneOther, 'bn': _oneOther, 'fa': _oneOther,
  'sw': _oneOther, 'af': _oneOther, 'ur': _oneOther, 'ta': _oneOther,
  'te': _oneOther,
  // one / many(optional) / other
  'es': _romance, 'fr': _romance, 'it': _romance, 'pt': _romance,
  'ca': _romance,
  // Slavic and Baltic
  'pl': _slavicEast, 'ru': _slavicEast, 'uk': _slavicEast, 'be': _slavicEast,
  'cs': _slavicWest, 'sk': _slavicWest, 'lt': _slavicWest,
  'hr': _southSlavic, 'sr': _southSlavic, 'bs': _southSlavic,
  'ro': _southSlavic,
  'sl': PluralCategories({'one', 'two', 'few', 'other'}),
  'lv': PluralCategories({'zero', 'one', 'other'}),
  'he': PluralCategories({'one', 'two', 'other'}, {'many'}),
  'ar': PluralCategories({'zero', 'one', 'two', 'few', 'many', 'other'}),
};

/// Extracts the language part of a locale such as `pt_BR` or `zh-Hant`.
String languageOf(String locale) {
  final m = RegExp(r'^[A-Za-z]+').firstMatch(locale);
  return (m?.group(0) ?? locale).toLowerCase();
}

/// Categories for [locale], or null when the language is not in the table.
PluralCategories? pluralCategoriesFor(String locale) =>
    pluralTable[languageOf(locale)];

/// The plural keywords a branch key can be.
const Set<String> pluralKeywords = {
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
};
