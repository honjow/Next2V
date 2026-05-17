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

export function highlightCodeLine(code: string, lang: string): CodeToken[] {
  const normalized = normalizeCodeLanguage(lang);
  if (normalized === 'xml' || normalized === 'html') {
    return highlightXmlLine(code);
  }
  if (normalized === 'json') {
    return highlightJsonLine(code);
  }
  if (normalized === 'shell') {
    return highlightShellLine(code);
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
