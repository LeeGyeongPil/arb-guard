# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2]

### Fixed
- AG007 no longer flags a dropped plural count variable inside a select nested in a plural branch, and its message now shows the full branch path (e.g. `count=one/gender=male`).

## [0.1.1]

### Fixed
- Config path resolution now normalizes Windows path separators.
- Tests tolerate CRLF checkouts, and `.gitattributes` pins LF line endings.
- CI workflow uses the correct executable name.

## [0.1.0]

### Added
- `arb_guard check` compares every `.arb` file in a folder with the template and
  reports structural damage with file, line and column.
- Fourteen rules, `AG001` to `AG014`: placeholder missing, unknown or renamed,
  select keys changed, plural categories (per-locale CLDR table), dropped exact
  plural branches, placeholders dropped from a branch, argument kind changes,
  markup tag mismatches, literal `#` in plural branches, ICU syntax errors,
  placeholder metadata mismatches, untranslated text and invalid ARB files.
- ICU subset parser that follows `use-escaping` and `relax-syntax`.
- `l10n.yaml` support (`arb-dir`, `template-arb-file`, `use-escaping`,
  `relax-syntax`); command line arguments take priority.
- Output formats `text`, `json`, `sarif` (2.1.0) and `github` (Actions
  annotations), `--output`, `--fail-on` and exit codes 0, 1 and 2.
- English and Korean output: `--lang`, `ARB_GUARD_LANG`, `LC_ALL`,
  `LC_MESSAGES`, `LANG`.
- `arb_guard rules` command and the library API `checkProject` / `checkMessages`.
- `example/l10n` (defective translations) and `example/clean` (no findings).

[Unreleased]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/LeeGyeongPil/arb-guard/releases/tag/v0.1.0
