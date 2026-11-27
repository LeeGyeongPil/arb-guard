/// All user-visible text lives here, in one table per language.
///
/// Placeholders in message templates are `{0}`, `{1}`, ... and are replaced in a
/// single pass, so substituted values may safely contain braces.
library;

/// Supported UI languages.
const List<String> supportedLanguages = ['en', 'ko'];

/// Resolves the UI language.
///
/// Order: [cliLang] > `ARB_GUARD_LANG` > `LC_ALL` > `LC_MESSAGES` > `LANG`.
/// Anything that does not start with `ko` falls back to English.
String resolveLanguage({String? cliLang, Map<String, String> env = const {}}) {
  if (cliLang != null && cliLang.isNotEmpty) {
    return cliLang.toLowerCase().startsWith('ko') ? 'ko' : 'en';
  }
  for (final name in const [
    'ARB_GUARD_LANG',
    'LC_ALL',
    'LC_MESSAGES',
    'LANG',
  ]) {
    final v = env[name];
    if (v != null && v.isNotEmpty) {
      return v.toLowerCase().startsWith('ko') ? 'ko' : 'en';
    }
  }
  return 'en';
}

final RegExp _slot = RegExp(r'\{(\d)\}');

/// Looks up [key] in [lang] and fills `{n}` slots with [params].
String tr(String lang, String key, [List<String> params = const []]) {
  final table = messages[lang] ?? messages['en']!;
  final template = table[key] ?? messages['en']![key] ?? key;
  return template.replaceAllMapped(_slot, (m) {
    final index = int.parse(m.group(1)!);
    return index < params.length ? params[index] : m.group(0)!;
  });
}

/// Message tables. Both languages must have exactly the same keys.
const Map<String, Map<String, String>> messages = {'en': _en, 'ko': _ko};

const Map<String, String> _en = {
  // Rule descriptions (arb_guard rules, SARIF).
  'rule.AG001.desc': 'A template placeholder is missing in the translation',
  'rule.AG002.desc':
      'The translation uses a placeholder the template does not have',
  'rule.AG003.desc':
      'A placeholder was renamed (translated) in the translation',
  'rule.AG004.desc': 'Select keys differ from the template',
  'rule.AG005.desc': 'Plural categories do not match the locale\'s CLDR rules',
  'rule.AG006.desc':
      'An exact plural branch (=0, =1) of the template was dropped',
  'rule.AG007.desc':
      'A plural/select branch dropped a placeholder its template branch has',
  'rule.AG008.desc': 'An argument changed kind (plural, select, placeholder)',
  'rule.AG009.desc': 'Markup tags differ from the template',
  'rule.AG010.desc':
      'A literal # inside a plural branch (Flutter does not substitute it)',
  'rule.AG011.desc': 'ICU message syntax error',
  'rule.AG012.desc':
      'Placeholder metadata (type, format) differs from the template',
  'rule.AG013.desc': 'The translation is identical to the template text',
  'rule.AG014.desc':
      'The ARB file is invalid (JSON, value type, unknown or duplicate key)',

  // Finding messages.
  'ag001': 'placeholder {0} from the template is missing in the translation',
  'ag002':
      "placeholder {0} does not exist in the template - gen-l10n would add 'Object {1}' to every locale's {2}() signature",
  'ag003':
      "placeholder {0} was translated to {1} - gen-l10n would add 'Object {2}' to every locale's {3}() signature",
  'ag004.changed':
      "select keys were changed: {0} (runtime always falls to 'other')",
  'ag004.added':
      "select keys that are not in the template: {0} (they never match at runtime)",
  'ag004.mixed': 'select keys differ from the template: added {0}; missing {1}',
  'ag004.missing': 'select keys from the template are missing: {0}',
  'ag005.missing':
      'locale {0} needs the plural categories {1}, but they are missing',
  'ag005.unused': 'locale {0} has no plural category {1}; it is never selected',
  'ag006': 'exact plural branch {0} from the template was dropped',
  'ag007': "branch '{0}' drops placeholder {1} that the template branch has",
  'ag008': "'{0}' is a {1} in the template but a {2} in the translation",
  'ag009.diff':
      'markup tags differ from the template (missing: {0}; unexpected: {1})',
  'ag009.nesting': 'markup tags are not properly paired or nested: {0}',
  'ag010':
      "literal '#' in plural branch '{0}' - Flutter does not replace it with the number; use {1} instead",
  'ag011': 'ICU syntax error at offset {0}: {1}',
  'ag012':
      "metadata of placeholder {0}: {1} is '{2}' in the template but '{3}' here",
  'ag013': 'translation is identical to the template text',
  'ag014.json': 'invalid JSON: {0}',
  'arb.top_not_object': 'the top level must be a JSON object',
  'ag014.encoding':
      'the file is not valid UTF-8 - re-save it as UTF-8 (without conversion tools that change quotes)',
  'cli.err.read_failed': 'cannot read {0}: {1}',
  'cli.err.template_encoding':
      'the template file {0} is not valid UTF-8 - re-save it as UTF-8',
  'ag014.type': 'message value must be a string, found {0}',
  'ag014.extra': 'key does not exist in the template file',
  'ag014.duplicate':
      'key appears more than once (first at {0}); only the last value is used',
  'icu.unterminatedBrace': "an opening '{' is never closed",
  'icu.unexpectedClosingBrace': "unexpected '}' without a matching '{'",
  'icu.expectedIdentifier': 'expected an argument name after {',
  'icu.expectedBranchBrace': "expected a branch name followed by '{'",
  'icu.expectedComma': "expected ',' in the argument",
  'icu.missingOther': "plural/select has no 'other' branch",
  'icu.duplicateBranch': 'the same branch is defined twice',
  'icu.unknownType': 'expected an argument type after the comma',
  'kind.placeholder': 'placeholder',
  'kind.plural': 'plural',
  'kind.ordinal': 'ordinal plural',
  'kind.select': 'select',
  'none': '-',

  // Report text.
  'summary': 'Checked {0} file(s): {1} errors, {2} warnings, {3} infos',
  'summary.missing':
      '{0} template key(s) have no translation (not listed; gen-l10n reports them)',
  'summary.none': 'No findings.',

  // CLI.
  'cli.usage': 'Usage: arb_guard <command> [options]',
  'cli.description':
      'Checks that translated ARB files keep the template\'s placeholders, select keys, plural branches and markup tags.',
  'cli.commands': 'Commands:',
  'cli.cmd.check': 'Check translated ARB files against the template',
  'cli.cmd.rules': 'List all rules with their default severity',
  'cli.help_hint':
      "Run 'arb_guard <command> --help' for the options of a command.",
  'cli.global.options': 'Global options:',
  'cli.opt.help': 'Show this help',
  'cli.opt.version': 'Print the version',
  'cli.opt.lang': 'Language of the output (en or ko)',
  'cli.opt.arb_dir':
      'Folder with the ARB files (default: arb-dir of l10n.yaml or lib/l10n)',
  'cli.opt.template':
      'Template ARB file name (default: template-arb-file of l10n.yaml or app_en.arb)',
  'cli.opt.config': 'Path of l10n.yaml (default: ./l10n.yaml if it exists)',
  'cli.opt.locale': 'Only check these locales (comma separated)',
  'cli.opt.format': 'Output format',
  'cli.opt.output': 'Write the report to this file instead of stdout',
  'cli.opt.fail_on': 'Lowest severity that makes the exit code 1',
  'cli.opt.use_escaping':
      'Treat single quotes as escapes (like use-escaping: true)',
  'cli.opt.relax_syntax':
      'Treat stray braces as text (like relax-syntax: true)',
  'cli.opt.no_color': 'Do not colorize text output',
  'cli.rules.title': 'Rules',
  'cli.rules.header': 'ID       Severity  Name / description',
  'cli.err.unknown_command': "unknown command '{0}'",
  'cli.err.bad_option': 'invalid option: {0} - see arb_guard check --help',
  'cli.err.bad_value': "invalid value '{1}' for --{0}",
  'cli.err.dir_missing':
      'ARB folder not found: {0} - pass --arb-dir or set arb-dir in l10n.yaml',
  'cli.err.template_missing':
      'template file not found: {0} - pass --template or set template-arb-file in l10n.yaml',
  'cli.err.config_missing': 'config file not found: {0}',
  'cli.err.config_bad': 'cannot read {0}: {1}',
  'cli.err.template_invalid': 'the template file {0} is not valid JSON: {1}',
  'cli.err.output_write': 'cannot write {0}: {1}',
  'cli.err.no_translations': 'no translation files found next to {0}',
};

const Map<String, String> _ko = {
  'rule.AG001.desc': '템플릿의 자리표시자가 번역에서 빠졌습니다',
  'rule.AG002.desc': '템플릿에 없는 자리표시자가 번역에 들어갔습니다',
  'rule.AG003.desc': '자리표시자 이름이 번역(개명)되었습니다',
  'rule.AG004.desc': 'select 키가 템플릿과 다릅니다',
  'rule.AG005.desc': '복수형 범주가 로케일의 CLDR 규칙과 맞지 않습니다',
  'rule.AG006.desc': '템플릿의 명시 복수형 가지(=0, =1)가 사라졌습니다',
  'rule.AG007.desc': '복수형/select 가지가 템플릿 가지에 있던 자리표시자를 잃었습니다',
  'rule.AG008.desc': '인자의 종류(plural, select, 자리표시자)가 바뀌었습니다',
  'rule.AG009.desc': '마크업 태그가 템플릿과 다릅니다',
  'rule.AG010.desc': 'plural 가지 안의 # 리터럴(Flutter 는 치환하지 않습니다)',
  'rule.AG011.desc': 'ICU 메시지 문법 오류',
  'rule.AG012.desc': '자리표시자 메타데이터(type, format)가 템플릿과 다릅니다',
  'rule.AG013.desc': '번역이 템플릿 문장과 글자 그대로 같습니다',
  'rule.AG014.desc': 'ARB 파일이 올바르지 않습니다(JSON, 값 형식, 모르는 키, 중복 키)',

  'ag001': '템플릿의 자리표시자 {0} 이(가) 번역에 없습니다',
  'ag002':
      "자리표시자 {0} 은(는) 템플릿에 없습니다 - gen-l10n 이 모든 로케일의 {2}() 시그니처에 'Object {1}' 을 추가합니다",
  'ag003':
      "자리표시자 {0} 이(가) {1} 로 번역되었습니다 - gen-l10n 이 모든 로케일의 {3}() 시그니처에 'Object {2}' 을 추가합니다",
  'ag004.changed': "select 키가 바뀌었습니다: {0} (실행하면 항상 'other' 로 떨어집니다)",
  'ag004.added': '템플릿에 없는 select 키: {0} (실행 중 절대 일치하지 않습니다)',
  'ag004.mixed': 'select 키가 템플릿과 다릅니다: 추가 {0}; 누락 {1}',
  'ag004.missing': '템플릿의 select 키가 빠졌습니다: {0}',
  'ag005.missing': '로케일 {0} 은(는) 복수형 범주 {1} 이(가) 필요한데 없습니다',
  'ag005.unused': '로케일 {0} 에는 복수형 범주 {1} 이(가) 없어 선택되지 않습니다',
  'ag006': '템플릿의 명시 복수형 가지 {0} 이(가) 사라졌습니다',
  'ag007': "'{0}' 가지에서 템플릿 가지에 있던 자리표시자 {1} 이(가) 빠졌습니다",
  'ag008': "'{0}' 은(는) 템플릿에서 {1}, 번역에서 {2} 입니다",
  'ag009.diff': '마크업 태그가 템플릿과 다릅니다 (누락: {0}; 예상 밖: {1})',
  'ag009.nesting': '마크업 태그의 짝이나 중첩이 맞지 않습니다: {0}',
  'ag010':
      "plural 가지 '{0}' 안의 '#' 리터럴 - Flutter 는 숫자로 바꾸지 않습니다. 대신 {1} 을(를) 쓰세요",
  'ag011': 'ICU 문법 오류 (오프셋 {0}): {1}',
  'ag012': "자리표시자 {0} 의 메타데이터: {1} 이(가) 템플릿에서는 '{2}', 여기서는 '{3}' 입니다",
  'ag013': '번역이 템플릿 문장과 글자 그대로 같습니다',
  'ag014.json': 'JSON 이 올바르지 않습니다: {0}',
  'arb.top_not_object': '최상위 값은 JSON 객체여야 합니다',
  'ag014.encoding': '파일이 올바른 UTF-8 이 아닙니다 - UTF-8 로 다시 저장하세요',
  'cli.err.read_failed': '{0} 을(를) 읽을 수 없습니다: {1}',
  'cli.err.template_encoding':
      '템플릿 파일 {0} 이(가) 올바른 UTF-8 이 아닙니다 - UTF-8 로 다시 저장하세요',
  'ag014.type': '메시지 값은 문자열이어야 합니다 (현재 {0})',
  'ag014.extra': '템플릿 파일에 없는 키입니다',
  'ag014.duplicate': '같은 키가 두 번 이상 나옵니다(처음 위치 {0}) - 마지막 값만 쓰입니다',
  'icu.unterminatedBrace': "여는 '{' 가 닫히지 않았습니다",
  'icu.unexpectedClosingBrace': "짝이 없는 '}' 가 있습니다",
  'icu.expectedIdentifier': '{ 뒤에 인자 이름이 필요합니다',
  'icu.expectedBranchBrace': "가지 이름 뒤에 '{' 가 필요합니다",
  'icu.expectedComma': "인자에 ',' 가 필요합니다",
  'icu.missingOther': "plural/select 에 'other' 가지가 없습니다",
  'icu.duplicateBranch': '같은 가지가 두 번 정의되었습니다',
  'icu.unknownType': '쉼표 뒤에 인자 종류가 필요합니다',
  'kind.placeholder': '자리표시자',
  'kind.plural': 'plural',
  'kind.ordinal': 'ordinal plural',
  'kind.select': 'select',
  'none': '-',

  'summary': '파일 {0}개 검사: {1}개 오류, {2}개 경고, {3}개 정보',
  'summary.missing': '템플릿 키 {0}개에 번역이 없습니다 (목록에는 없음; gen-l10n 이 알려 줍니다)',
  'summary.none': '발견 사항이 없습니다.',

  'cli.usage': '사용법: arb_guard <명령> [옵션]',
  'cli.description':
      '번역된 ARB 파일이 템플릿의 자리표시자, select 키, 복수형 가지, 마크업 태그를 지켰는지 검사합니다.',
  'cli.commands': '명령:',
  'cli.cmd.check': '번역된 ARB 파일을 템플릿과 비교해 검사합니다',
  'cli.cmd.rules': '모든 규칙과 기본 심각도를 보여 줍니다',
  'cli.help_hint': "명령별 옵션은 'arb_guard <명령> --help' 로 확인하세요.",
  'cli.global.options': '공통 옵션:',
  'cli.opt.help': '이 도움말을 보여 줍니다',
  'cli.opt.version': '버전을 출력합니다',
  'cli.opt.lang': '출력 언어 (en 또는 ko)',
  'cli.opt.arb_dir': 'ARB 파일 폴더 (기본: l10n.yaml 의 arb-dir 또는 lib/l10n)',
  'cli.opt.template':
      '템플릿 ARB 파일 이름 (기본: l10n.yaml 의 template-arb-file 또는 app_en.arb)',
  'cli.opt.config': 'l10n.yaml 경로 (기본: 있으면 ./l10n.yaml)',
  'cli.opt.locale': '이 로케일만 검사합니다 (쉼표로 구분)',
  'cli.opt.format': '출력 형식',
  'cli.opt.output': '표준 출력 대신 이 파일에 보고서를 씁니다',
  'cli.opt.fail_on': '종료 코드를 1 로 만드는 가장 낮은 심각도',
  'cli.opt.use_escaping': '작은따옴표를 이스케이프로 취급 (use-escaping: true 와 같음)',
  'cli.opt.relax_syntax': '짝 없는 중괄호를 글자로 취급 (relax-syntax: true 와 같음)',
  'cli.opt.no_color': '텍스트 출력에 색을 쓰지 않습니다',
  'cli.rules.title': '규칙',
  'cli.rules.header': 'ID       심각도  이름 / 설명',
  'cli.err.unknown_command': "알 수 없는 명령 '{0}'",
  'cli.err.bad_option': '옵션이 올바르지 않습니다: {0} - arb_guard check --help 로 확인하세요',
  'cli.err.bad_value': "--{0} 의 값 '{1}' 이(가) 올바르지 않습니다",
  'cli.err.dir_missing':
      'ARB 폴더를 찾을 수 없습니다: {0} - --arb-dir 를 주거나 l10n.yaml 에 arb-dir 를 적으세요',
  'cli.err.template_missing':
      '템플릿 파일을 찾을 수 없습니다: {0} - --template 를 주거나 l10n.yaml 에 template-arb-file 를 적으세요',
  'cli.err.config_missing': '설정 파일을 찾을 수 없습니다: {0}',
  'cli.err.config_bad': '{0} 을(를) 읽을 수 없습니다: {1}',
  'cli.err.template_invalid': '템플릿 파일 {0} 이(가) 올바른 JSON 이 아닙니다: {1}',
  'cli.err.output_write': '{0} 에 쓸 수 없습니다: {1}',
  'cli.err.no_translations': '{0} 옆에서 번역 파일을 찾지 못했습니다',
};
