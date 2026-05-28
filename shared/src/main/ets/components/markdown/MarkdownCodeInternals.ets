// Internal shared code-highlighting primitives extracted from MarkdownContent.ets.
// Consumed by MarkdownContent.ets and ./MarkdownCodeBlock.ets. Not part of any
// public surface beyond these two files.

export const RENDER_CODE_FONT_SIZE = 12;
export const RENDER_CODE_LINE_HEIGHT = 18;

type CodeHighLight = "string" | "text" | "keyword" | "type" | "symbol" | "number" | "boolean" | "comment" | "tag" | "attr" | "key" | "punctuation" | "flag";

export interface CodeToken {
  type: CodeHighLight;
  text: string;
}

// ---------- Code syntax highlighting ----------
// V2Next-owned simple code highlighter used by the fallback Markdown renderer.
// Simple regex-based tokenizer: splits each line into typed spans for coloring.
const _stringRegex = /(["'])(?:(?=(\\?))\2.)*?\1/g;
const _commonRegex = /([(\s=){}.[\]",;:<>+\-*\/])/gi;

const _keywords: Set<string> = new Set([
  "public",
  "private",
  "protect",
  "default",
  "new",
  "throw",
  "throws",
  "let",
  "var",
  "const",
  "if",
  "else",
  "switch",
  "case",
  "for",
  "continue",
  "break",
  "return",
  "import",
  "from",
  "static",
  "function",
  "class",
  "interface",
  "extends",
  "implements",
  "type",
  "export",
  "async",
  "await",
  "try",
  "catch",
  "finally",
  "while",
  "do",
  "in",
  "of",
  "yield",
  "@param",
  "this",
  "super",
  "enum",
  "abstract",
  "readonly",
  "override",
  "func",
  "package",
  "fn",
  "mut",
]);

const _types: Set<string> = new Set([
  "void",
  "bool",
  "boolean",
  "byte",
  "short",
  "int",
  "integer",
  "long",
  "float",
  "double",
  "char",
  "character",
  "number",
  "string",
  "array",
  "object",
  "null",
  "undefined",
]);

const _symbols: Set<string> = new Set([
  "=",
  "(",
  ")",
  "{",
  "}",
  "<",
  ">",
  "|",
  "&",
  "!",
  ";",
  ":",
  ".",
  "^",
  "$",
  "@",
  "%",
  "+",
  "-",
  "*",
  "/",
]);

function _splitOne(code: CodeToken, token: CodeToken): CodeToken[] {
  if (!code) {
    return [];
  } else if (code.type !== "text") {
    return [code];
  }
  let res: CodeToken[] = [];
  let parts = code.text.split(token.text);
  parts.forEach((v: string, index: number) => {
    if (index < parts.length - 1) {
      if (v.length > 0) {
        res.push({ type: "text", text: v });
      }
      res.push({ type: token.type, text: token.text });
    } else if (v.length > 0) {
      res.push({ type: "text", text: v });
    }
  });
  return res;
}

function _splitAll(codes: CodeToken[], token: CodeToken): CodeToken[] {
  let res: CodeToken[] = [];
  codes.forEach((code: CodeToken) => {
    res = res.concat(_splitOne(code, token));
  });
  return res;
}

function _buildToken(text: string): CodeToken {
  let trimmed = text.trim();
  if (trimmed.length > 0 && !isNaN(parseFloat(trimmed)) && isFinite(Number(trimmed))) {
    return { type: "number", text: text };
  } else if (trimmed === "true" || trimmed === "false") {
    return { type: "boolean", text: text };
  } else if (_keywords.has(trimmed.toLowerCase())) {
    return { type: "keyword", text: text };
  } else if (_types.has(trimmed.toLowerCase())) {
    return { type: "type", text: text };
  } else if (_symbols.has(trimmed)) {
    return { type: "symbol", text: text };
  }
  return { type: "text", text: text };
}

export function normalizeCodeLanguage(lang: string): string {
  const raw = (lang || '').trim().toLowerCase();
  if (!raw) {
    return '';
  }
  const first = raw.split(/[\s,;]+/)[0].replace(/^language-/, '').replace(/^lang-/, '');
  if (first === 'js' || first === 'javascript' || first === 'jsx') {
    return 'javascript';
  }
  if (first === 'ts' || first === 'typescript' || first === 'tsx' || first === 'ets' || first === 'arkts') {
    return 'typescript';
  }
  if (first === 'xml' || first === 'html' || first === 'xhtml' || first === 'svg') {
    return first === 'xml' ? 'xml' : 'html';
  }
  if (first === 'json' || first === 'jsonc') {
    return 'json';
  }
  if (first === 'shell' || first === 'bash' || first === 'sh' || first === 'zsh') {
    return 'shell';
  }
  if (first === 'py' || first === 'python') {
    return 'python';
  }
  if (first === 'go' || first === 'golang') {
    return 'go';
  }
  if (first === 'rs' || first === 'rust') {
    return 'rust';
  }
  if (first === 'java') {
    return 'java';
  }
  if (first === 'kt' || first === 'kotlin') {
    return 'kotlin';
  }
  if (first === 'swift') {
    return 'swift';
  }
  if (first === 'sql') {
    return 'sql';
  }
  if (first === 'diff' || first === 'patch') {
    return 'diff';
  }
  if (first === 'yaml' || first === 'yml') {
    return 'yaml';
  }
  if (first === 'css') {
    return 'css';
  }
  return first || 'generic';
}

function _pushCodeToken(tokens: CodeToken[], type: CodeHighLight, text: string): void {
  if (!text) {
    return;
  }
  const last = tokens.length > 0 ? tokens[tokens.length - 1] : null;
  if (last && last.type === type) {
    last.text += text;
  } else {
    tokens.push({ type: type, text: text } as CodeToken);
  }
}

function _lineCommentIndex(code: string): number {
  let quote = '';
  let escaped = false;
  for (let i = 0; i < code.length - 1; i++) {
    const ch = code.charAt(i);
    if (escaped) {
      escaped = false;
      continue;
    }
    if (ch === '\\') {
      escaped = true;
      continue;
    }
    if (quote) {
      if (ch === quote) {
        quote = '';
      }
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      quote = ch;
      continue;
    }
    if (ch === '/' && code.charAt(i + 1) === '/') {
      return i;
    }
  }
  return -1;
}

// Two-pass generic tokenizer: first extract string literals, then split the rest by
// common delimiters and classify each piece (keyword, type, number, etc.).
function highlightLine(code: string): CodeToken[] {
  const commentIndex = _lineCommentIndex(code || '');
  if (commentIndex >= 0) {
    const before = highlightLine((code || '').slice(0, commentIndex));
    before.push({ type: 'comment', text: (code || '').slice(commentIndex) } as CodeToken);
    return before;
  }
  let tokens: CodeToken[] = [{ type: "text", text: code } as CodeToken];

  let blockCommentMatch: RegExpExecArray | null = /\/\*[\s\S]*?\*\//.exec(code || '');
  if (blockCommentMatch) {
    tokens = _splitAll(tokens, { type: 'comment', text: blockCommentMatch[0] } as CodeToken);
  }

  // Pass 1: pull out quoted strings so they're not further split
  let strings = code.match(_stringRegex);
  if (strings && strings.length > 0) {
    for (let i = 0; i < strings.length; i++) {
      tokens = _splitAll(tokens, { type: "string", text: strings[i] });
    }
  }

  // Pass 2: split remaining 'text' tokens by symbols/whitespace and classify
  let result: CodeToken[] = [];
  for (let i = 0; i < tokens.length; i++) {
    let t = tokens[i];
    if (t.type === "text") {
      let parts = t.text.split(_commonRegex);
      parts.forEach((s: string) => {
        if (s.length > 0) {
          result.push(_buildToken(s));
        }
      });
    } else {
      result.push(t);
    }
  }
  return result;
}

function highlightJsonLine(code: string): CodeToken[] {
  const tokens: CodeToken[] = [];
  const source = code || '';
  const re = /"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\],:]/g;
  let last = 0;
  let match: RegExpExecArray | null = re.exec(source);
  while (match) {
    if (match.index > last) {
      _pushCodeToken(tokens, 'text', source.slice(last, match.index));
    }
    const value = match[0];
    const after = source.slice(re.lastIndex).replace(/^\s+/, '');
    if (value.startsWith('"')) {
      _pushCodeToken(tokens, after.startsWith(':') ? 'key' : 'string', value);
    } else if (/^-?\d/.test(value)) {
      _pushCodeToken(tokens, 'number', value);
    } else if (value === 'true' || value === 'false' || value === 'null') {
      _pushCodeToken(tokens, 'boolean', value);
    } else {
      _pushCodeToken(tokens, 'punctuation', value);
    }
    last = re.lastIndex;
    match = re.exec(source);
  }
  if (last < source.length) {
    _pushCodeToken(tokens, 'text', source.slice(last));
  }
  return tokens;
}

function highlightXmlLine(code: string): CodeToken[] {
  const tokens: CodeToken[] = [];
  const source = code || '';
  const tagRe = /<!--[\s\S]*?-->|<\/?[A-Za-z][^>]*?\/?>/g;
  let last = 0;
  let match: RegExpExecArray | null = tagRe.exec(source);
  while (match) {
    if (match.index > last) {
      _pushCodeToken(tokens, 'text', source.slice(last, match.index));
    }
    const tag = match[0];
    if (tag.startsWith('<!--')) {
      _pushCodeToken(tokens, 'comment', tag);
    } else {
      const tagTokens = tokenizeXmlTag(tag);
      for (const token of tagTokens) {
        _pushCodeToken(tokens, token.type, token.text);
      }
    }
    last = tagRe.lastIndex;
    match = tagRe.exec(source);
  }
  if (last < source.length) {
    _pushCodeToken(tokens, 'text', source.slice(last));
  }
  return tokens;
}

function tokenizeXmlTag(tag: string): CodeToken[] {
  const tokens: CodeToken[] = [];
  let index = 0;
  const open = /^<\/?/.exec(tag || '');
  if (open) {
    _pushCodeToken(tokens, 'punctuation', open[0]);
    index = open[0].length;
  }
  const name = /^[A-Za-z_:\-][\w:.\-]*/.exec(tag.slice(index));
  if (name) {
    _pushCodeToken(tokens, 'tag', name[0]);
    index += name[0].length;
  }
  while (index < tag.length) {
    const rest = tag.slice(index);
    const close = /^\s*\/?>$/.exec(rest);
    if (close) {
      const spaces = rest.slice(0, rest.length - (rest.endsWith('/>') ? 2 : 1));
      _pushCodeToken(tokens, 'text', spaces);
      _pushCodeToken(tokens, 'punctuation', rest.endsWith('/>') ? '/>' : '>');
      break;
    }
    const attr = /^(\s+)([A-Za-z_:\-][\w:.\-]*)(\s*=\s*)?((?:"[^"]*"|'[^']*'))?/.exec(rest);
    if (!attr || attr[0].length === 0) {
      _pushCodeToken(tokens, 'text', rest.charAt(0));
      index += 1;
      continue;
    }
    _pushCodeToken(tokens, 'text', attr[1] || '');
    _pushCodeToken(tokens, 'attr', attr[2] || '');
    _pushCodeToken(tokens, 'punctuation', attr[3] || '');
    _pushCodeToken(tokens, 'string', attr[4] || '');
    index += attr[0].length;
  }
  return tokens;
}

function highlightShellLine(code: string): CodeToken[] {
  const source = code || '';
  const hash = source.indexOf('#');
  const body = hash >= 0 ? source.slice(0, hash) : source;
  const result: CodeToken[] = [];
  const re = /"(?:\\.|[^"\\])*"|'[^']*'|--?[A-Za-z0-9][\w-]*|\b(?:cd|echo|export|grep|sed|awk|cat|ls|rm|cp|mv|mkdir|curl|git|node|npm|pnpm|yarn|bash|sh|if|then|else|fi|for|do|done|case|esac|while|function)\b/g;
  let last = 0;
  let match: RegExpExecArray | null = re.exec(body);
  while (match) {
    if (match.index > last) {
      _pushCodeToken(result, 'text', body.slice(last, match.index));
    }
    const value = match[0];
    if (value.startsWith('"') || value.startsWith("'")) {
      _pushCodeToken(result, 'string', value);
    } else if (value.startsWith('-')) {
      _pushCodeToken(result, 'flag', value);
    } else {
      _pushCodeToken(result, 'keyword', value);
    }
    last = re.lastIndex;
    match = re.exec(body);
  }
  if (last < body.length) {
    _pushCodeToken(result, 'text', body.slice(last));
  }
  if (hash >= 0) {
    _pushCodeToken(result, 'comment', source.slice(hash));
  }
  return result;
}

const _tsJsKeywords: Set<string> = new Set([
  'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'constructor', 'continue',
  'debugger', 'default', 'delete', 'do', 'else', 'enum', 'export', 'extends', 'finally', 'for',
  'from', 'function', 'get', 'if', 'implements', 'import', 'in', 'instanceof', 'interface', 'let',
  'new', 'of', 'override', 'private', 'protected', 'public', 'readonly', 'return', 'set', 'static',
  'super', 'switch', 'this', 'throw', 'try', 'type', 'typeof', 'var', 'void', 'while', 'yield',
]);
const _tsJsTypes: Set<string> = new Set(['Array', 'Boolean', 'Error', 'Map', 'Number', 'Object', 'Promise', 'Record', 'Set', 'String', 'any', 'boolean', 'never', 'null', 'number', 'object', 'string', 'undefined', 'unknown', 'void']);
const _pythonKeywords: Set<string> = new Set(['False', 'None', 'True', 'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try', 'while', 'with', 'yield']);
const _cssKeywords: Set<string> = new Set(['@container', '@font-face', '@import', '@keyframes', '@media', '@supports', 'display', 'flex', 'grid', 'none', 'relative', 'absolute', 'fixed', 'sticky', 'block', 'inline', 'center', 'solid', 'transparent', 'var']);
const _sqlKeywords: Set<string> = new Set(['ADD', 'ALTER', 'AND', 'AS', 'ASC', 'BY', 'CREATE', 'DELETE', 'DESC', 'DISTINCT', 'DROP', 'FROM', 'GROUP', 'HAVING', 'IN', 'INSERT', 'INTO', 'JOIN', 'LEFT', 'LIKE', 'LIMIT', 'NOT', 'NULL', 'ON', 'OR', 'ORDER', 'RIGHT', 'SELECT', 'SET', 'TABLE', 'UPDATE', 'VALUES', 'WHERE']);

function _highlightRegexLine(source: string, re: RegExp, classifier: (value: string) => CodeHighLight): CodeToken[] {
  const tokens: CodeToken[] = [];
  let last = 0;
  let match: RegExpExecArray | null = re.exec(source || '');
  while (match) {
    if (match.index > last) {
      _pushCodeToken(tokens, 'text', (source || '').slice(last, match.index));
    }
    const value = match[0];
    _pushCodeToken(tokens, classifier(value), value);
    last = re.lastIndex;
    match = re.exec(source || '');
  }
  if (last < (source || '').length) {
    _pushCodeToken(tokens, 'text', (source || '').slice(last));
  }
  return tokens;
}

function highlightTsJsLine(code: string): CodeToken[] {
  const source = code || '';
  const commentIndex = _lineCommentIndex(source);
  if (commentIndex >= 0) {
    const before = highlightTsJsLine(source.slice(0, commentIndex));
    before.push({ type: 'comment', text: source.slice(commentIndex) } as CodeToken);
    return before;
  }
  const re = /`(?:\\.|[^`\\])*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|=>|\b\d+(?:\.\d+)?\b|\b[A-Za-z_$][\w$]*\b|[{}()[\].,;:?<>+\-*\/%=!&|]+/g;
  return _highlightRegexLine(source, re, (value: string): CodeHighLight => {
    if (value.startsWith('"') || value.startsWith("'") || value.startsWith('`')) {
      return 'string';
    }
    if (/^\d/.test(value)) {
      return 'number';
    }
    if (value === 'true' || value === 'false') {
      return 'boolean';
    }
    if (_tsJsKeywords.has(value)) {
      return 'keyword';
    }
    if (_tsJsTypes.has(value)) {
      return 'type';
    }
    if (/^[{}()[\].,;:?<>+\-*\/%=!&|]+$/.test(value)) {
      return 'punctuation';
    }
    return 'text';
  });
}

function highlightPythonLine(code: string): CodeToken[] {
  const source = code || '';
  const hash = source.indexOf('#');
  const body = hash >= 0 ? source.slice(0, hash) : source;
  const result = _highlightRegexLine(body, /"""[\s\S]*?"""|'''[\s\S]*?'''|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b\d+(?:\.\d+)?\b|\b[A-Za-z_]\w*\b|[{}()[\].,;:@<>+\-*\/%=!&|]+/g, (value: string): CodeHighLight => {
    if (value.startsWith('"') || value.startsWith("'")) {
      return 'string';
    }
    if (/^\d/.test(value)) {
      return 'number';
    }
    if (_pythonKeywords.has(value)) {
      return value === 'True' || value === 'False' ? 'boolean' : 'keyword';
    }
    if (/^[{}()[\].,;:@<>+\-*\/%=!&|]+$/.test(value)) {
      return 'punctuation';
    }
    return 'text';
  });
  if (hash >= 0) {
    _pushCodeToken(result, 'comment', source.slice(hash));
  }
  return result;
}

function highlightCssLine(code: string): CodeToken[] {
  const source = code || '';
  return _highlightRegexLine(source, /\/\*[\s\S]*?\*\/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|#[0-9A-Fa-f]{3,8}\b|@[A-Za-z-]+|--[A-Za-z0-9_-]+|\b\d+(?:\.\d+)?(?:px|vp|em|rem|%|s|ms)?\b|\b[A-Za-z-]+\b|[{}()[\].,;:#<>+\-*\/%=!]+/g, (value: string): CodeHighLight => {
    if (value.startsWith('/*')) {
      return 'comment';
    }
    if (value.startsWith('"') || value.startsWith("'")) {
      return 'string';
    }
    if (value.startsWith('@') || _cssKeywords.has(value)) {
      return 'keyword';
    }
    if (value.startsWith('#') || /^\d/.test(value)) {
      return 'number';
    }
    if (value.startsWith('--')) {
      return 'attr';
    }
    if (/^[{}()[\].,;:#<>+\-*\/%=!]+$/.test(value)) {
      return 'punctuation';
    }
    return 'text';
  });
}

function highlightSqlLine(code: string): CodeToken[] {
  const source = code || '';
  const comment = source.indexOf('--');
  const body = comment >= 0 ? source.slice(0, comment) : source;
  const result = _highlightRegexLine(body, /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b\d+(?:\.\d+)?\b|\b[A-Za-z_]\w*\b|[(),.;=*<>+\-/]+/g, (value: string): CodeHighLight => {
    if (value.startsWith('"') || value.startsWith("'")) {
      return 'string';
    }
    if (/^\d/.test(value)) {
      return 'number';
    }
    if (_sqlKeywords.has(value.toUpperCase())) {
      return 'keyword';
    }
    if (/^[(),.;=*<>+\-/]+$/.test(value)) {
      return 'punctuation';
    }
    return 'text';
  });
  if (comment >= 0) {
    _pushCodeToken(result, 'comment', source.slice(comment));
  }
  return result;
}

function highlightDiffLine(code: string): CodeToken[] {
  const source = code || '';
  if (source.startsWith('+++') || source.startsWith('---')) {
    return [{ type: 'keyword', text: source } as CodeToken];
  }
  if (source.startsWith('+')) {
    return [{ type: 'string', text: source } as CodeToken];
  }
  if (source.startsWith('-')) {
    return [{ type: 'comment', text: source } as CodeToken];
  }
  if (source.startsWith('@@')) {
    return [{ type: 'number', text: source } as CodeToken];
  }
  return [{ type: 'text', text: source } as CodeToken];
}

function yamlCommentIndex(code: string): number {
  let quote = '';
  let escaped = false;
  for (let i = 0; i < (code || '').length; i++) {
    const ch = code.charAt(i);
    if (escaped) {
      escaped = false;
      continue;
    }
    if (ch === '\\') {
      escaped = true;
      continue;
    }
    if (quote) {
      if (ch === quote) {
        quote = '';
      }
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
      continue;
    }
    if (ch === '#') {
      return i;
    }
  }
  return -1;
}

function pushYamlScalar(tokens: CodeToken[], scalar: string): void {
  const re = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:true|false|null|yes|no|on|off)\b|-?\b\d+(?:\.\d+)?\b|[{}[\],]|[^\s{}[\],]+|\s+/gi;
  let match: RegExpExecArray | null = re.exec(scalar || '');
  while (match) {
    const value = match[0];
    if (/^\s+$/.test(value)) {
      _pushCodeToken(tokens, 'text', value);
    } else if (value.startsWith('"') || value.startsWith("'")) {
      _pushCodeToken(tokens, 'string', value);
    } else if (/^(?:true|false|null|yes|no|on|off)$/i.test(value)) {
      _pushCodeToken(tokens, 'boolean', value);
    } else if (/^-?\d/.test(value)) {
      _pushCodeToken(tokens, 'number', value);
    } else if (/^[{}[\],]$/.test(value)) {
      _pushCodeToken(tokens, 'punctuation', value);
    } else {
      _pushCodeToken(tokens, 'string', value);
    }
    match = re.exec(scalar || '');
  }
}

function highlightYamlLine(code: string): CodeToken[] {
  const source = code || '';
  const commentIndex = yamlCommentIndex(source);
  const body = commentIndex >= 0 ? source.slice(0, commentIndex) : source;
  const tokens: CodeToken[] = [];
  const yamlKey = /^(\s*)(-\s+)?([A-Za-z_][\w.-]*)(\s*:\s*)(.*)$/.exec(body);
  if (yamlKey) {
    _pushCodeToken(tokens, 'text', yamlKey[1] || '');
    const yamlListPrefix = yamlKey[2] || '';
    _pushCodeToken(tokens, 'punctuation', yamlListPrefix);
    _pushCodeToken(tokens, 'key', yamlKey[3] || '');
    _pushCodeToken(tokens, 'punctuation', yamlKey[4] || '');
    pushYamlScalar(tokens, yamlKey[5] || '');
  } else {
    const yamlList = /^(\s*)(-\s+)(.*)$/.exec(body);
    if (yamlList) {
      _pushCodeToken(tokens, 'text', yamlList[1] || '');
      const yamlListPrefix = yamlList[2] || '';
      _pushCodeToken(tokens, 'punctuation', yamlListPrefix);
      pushYamlScalar(tokens, yamlList[3] || '');
    } else {
      pushYamlScalar(tokens, body);
    }
  }
  if (commentIndex >= 0) {
    _pushCodeToken(tokens, 'comment', source.slice(commentIndex));
  }
  return tokens;
}

function looksLikeJson(source: string): boolean {
  return /^\s*[\[{]/.test(source) && /"[^"\n]+"\s*:|\[\s*("|-?\d|true|false|null|\{|\[)/.test(source);
}

function looksLikeHtml(source: string): boolean {
  return /<[A-Za-z][\w:-]*(?:\s+[A-Za-z_:][\w:.-]*(?:\s*=\s*(?:"[^"]*"|'[^']*'))?)*\s*\/?>/.test(source);
}

function looksLikeShell(source: string): boolean {
  const lines = source.split(/\r?\n/).filter((line: string): boolean => line.trim().length > 0);
  if (lines.length === 0) {
    return false;
  }
  let shellLike = 0;
  for (const line of lines) {
    if (/^\s*(?:\$\s*)?(?:sudo|apt|brew|git|curl|wget|npm|pnpm|yarn|node|bash|sh|cd|ls|mkdir|rm|cp|mv)\b/.test(line)) {
      shellLike += 1;
    }
  }
  return shellLike >= Math.min(2, lines.length);
}

function looksLikePython(source: string): boolean {
  return /^\s*(?:def|class)\s+[A-Za-z_]\w*.*:\s*$/m.test(source) ||
    /^\s*(?:from\s+[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*\s+import|import\s+[A-Za-z_]\w*|print\s*\()/m.test(source);
}

function looksLikeGo(source: string): boolean {
  return /^\s*package\s+main\b/m.test(source) || /^\s*func\s+main\s*\(\s*\)/m.test(source);
}

function looksLikeRust(source: string): boolean {
  return /^\s*fn\s+main\s*\(\s*\)/m.test(source) || /\blet\s+mut\b/.test(source);
}

function looksLikeSql(source: string): boolean {
  return /\bSELECT\b[\s\S]+\bFROM\b/i.test(source) || /^\s*(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\b/i.test(source);
}

function looksLikeDiff(source: string): boolean {
  return /^diff --git\b/m.test(source) || /^@@\s+-\d+/m.test(source) || /^(?:\+\+\+|---)\s+/m.test(source);
}

function sniffCodeLanguage(code: string): string {
  const source = (code || '').trim();
  if (!source) {
    return '';
  }
  if (looksLikeDiff(source)) {
    return 'diff';
  }
  if (looksLikeJson(source)) {
    return 'json';
  }
  if (looksLikeHtml(source)) {
    return 'html';
  }
  if (looksLikeShell(source)) {
    return 'shell';
  }
  if (looksLikePython(source)) {
    return 'python';
  }
  if (looksLikeGo(source)) {
    return 'go';
  }
  if (looksLikeRust(source)) {
    return 'rust';
  }
  if (looksLikeSql(source)) {
    return 'sql';
  }
  return '';
}

export function highlightCodeLine(code: string, lang: string): CodeToken[] {
  const explicit = normalizeCodeLanguage(lang);
  const normalized = explicit ? explicit : sniffCodeLanguage(code);
  if (normalized === 'xml' || normalized === 'html') {
    return highlightXmlLine(code);
  }
  if (normalized === 'json') {
    return highlightJsonLine(code);
  }
  if (normalized === 'shell') {
    return highlightShellLine(code);
  }
  if (normalized === 'typescript' || normalized === 'javascript') {
    return highlightTsJsLine(code);
  }
  if (normalized === 'python') {
    return highlightPythonLine(code);
  }
  if (normalized === 'css') {
    return highlightCssLine(code);
  }
  if (normalized === 'sql') {
    return highlightSqlLine(code);
  }
  if (normalized === 'diff') {
    return highlightDiffLine(code);
  }
  if (normalized === 'yaml') {
    return highlightYamlLine(code);
  }
  return highlightLine(code);
}

export interface CodeColorPalette {
  text: ResourceColor;
  string: ResourceColor;
  keyword: ResourceColor;
  type: ResourceColor;
  symbol: ResourceColor;
  number: ResourceColor;
  boolean: ResourceColor;
  comment: ResourceColor;
  tag: ResourceColor;
  attr: ResourceColor;
  key: ResourceColor;
  punctuation: ResourceColor;
  flag: ResourceColor;
}

const _darkCodeColors: CodeColorPalette = {
  "text": "#F8F8F2",
  "string": "#E6DB74",
  "keyword": "#66D9EF",
  "type": "#A6E22E",
  "symbol": "#F8F8F2",
  "number": "#AE81FF",
  "boolean": "#AE81FF",
  "comment": "#8B949E",
  "tag": "#7EE787",
  "attr": "#D2A8FF",
  "key": "#79C0FF",
  "punctuation": "#F8F8F2",
  "flag": "#FFA657",
};

const _lightCodeColors: CodeColorPalette = {
  "text": "#24292F",
  "string": "#0A3069",
  "keyword": "#CF222E",
  "type": "#8250DF",
  "symbol": "#24292F",
  "number": "#0550AE",
  "boolean": "#0550AE",
  "comment": "#6E7781",
  "tag": "#116329",
  "attr": "#8250DF",
  "key": "#0550AE",
  "punctuation": "#24292F",
  "flag": "#953800",
};

export function _codeColors(isDark: boolean): CodeColorPalette {
  return isDark ? _darkCodeColors : _lightCodeColors;
}

export function _codeColor(isDark: boolean, tokenType: CodeHighLight): ResourceColor {
  const palette = _codeColors(isDark);
  if (tokenType === 'string') {
    return palette.string;
  }
  if (tokenType === 'keyword') {
    return palette.keyword;
  }
  if (tokenType === 'type') {
    return palette.type;
  }
  if (tokenType === 'symbol') {
    return palette.symbol;
  }
  if (tokenType === 'number') {
    return palette.number;
  }
  if (tokenType === 'boolean') {
    return palette.boolean;
  }
  if (tokenType === 'comment') {
    return palette.comment;
  }
  if (tokenType === 'tag') {
    return palette.tag;
  }
  if (tokenType === 'attr') {
    return palette.attr;
  }
  if (tokenType === 'key') {
    return palette.key;
  }
  if (tokenType === 'punctuation') {
    return palette.punctuation;
  }
  if (tokenType === 'flag') {
    return palette.flag;
  }
  return palette.text;
}

export function _codeBackground(isDark: boolean): ResourceColor {
  return isDark ? "#1E1F22" : "#F6F8FA";
}

export function _codeHeaderBackground(isDark: boolean): ResourceColor {
  return isDark ? "#2B2D31" : "#EAEEF3";
}

export function _codeMetaColor(isDark: boolean): ResourceColor {
  return isDark ? "#C9D1D9" : "#57606A";
}

export function _codePressedOverlay(isDark: boolean): ResourceColor {
  return isDark ? "#40FFFFFF" : "#18000000";
}
