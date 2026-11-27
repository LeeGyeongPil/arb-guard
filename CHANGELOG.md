# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

### Added
- `AG014` now reports a key that appears more than once in the same ARB file (template or translation), with `data.reason` `duplicate_key`. The finding points at the repeated key and gives the first position (`data.first_line`, `data.first_column`). JSON keeps only the last value, so the earlier text was lost without a warning.

### Changed
- A file with a repeated key used to pass and now fails with an `AG014` error. Remove the extra entry to fix it.

## [0.1.4]

### Changed
- Documentation: added the 0.1.3 compare link to the changelog.

## [0.1.3]

### Changed
- The `args` dependency is now `^2.7.0` instead of pinned `2.7.0`, so projects that depend on arb_guard can resolve other `args` versions. CI also runs analyze and tests against the lowest allowed version of `args`, the runtime dependency.

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

[Unreleased]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.4...v0.2.0
[0.1.4]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/LeeGyeongPil/arb-guard/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/LeeGyeongPil/arb-guard/releases/tag/v0.1.0
