/// Static checks that translated ARB files keep the template's structure.
///
/// Use [checkProject] for a folder of `.arb` files or [checkMessages] for
/// in-memory maps (for example, the output of a translation tool).
library;

export 'src/checker.dart'
    show CheckOptions, CheckResult, checkMessages, checkProject;
export 'src/config.dart'
    show ArbGuardUsageException, ProjectConfig, loadConfig, parseFlatYaml;
export 'src/finding.dart' show Finding, RuleInfo, Severity, ruleCatalog;
export 'src/i18n/messages.dart' show resolveLanguage, supportedLanguages;
export 'src/icu/parser.dart' show IcuSyntaxError, ParseOptions;
export 'src/version.dart' show packageVersion;
