import { MarkdownOptions, Token, Tokens, lexer } from "@lidary/markdown";
import { common, Want } from "@kit.AbilityKit";
import { pasteboard } from "@kit.BasicServicesKit";
import { connection } from "@kit.NetworkKit";
import { promptAction } from "@kit.ArkUI";
import { StorageKeys } from "../constants/StorageKeys";
import { ReadingSettings } from "../settings/ReadingSettings";
import { ThemeConstants } from "../theme/ThemeConstants";
import { MediaUrlUtils } from "../utils/MediaUrlUtils";
import { HtmlEntityUtils } from "../utils/HtmlEntityUtils";
import { Base64DecodeUtils } from "../utils/Base64DecodeUtils";

// @lidary/markdown is intentionally quarantined here.
// Allowed uses:
//   1. lexer() may parse real Markdown fallback sources only.
//   2. exported Token/Tokens/MarkdownOptions types may be used as temporary
//      compatibility shapes while this component is migrated to V2Next-owned
//      Render Tokens.
// Do NOT route V2EX content_rendered HTML through HTML -> Markdown -> lexer(),
// and do NOT rely on @lidary/markdown's renderer/custom builders for ordered
// V2EX content layout. Mixed text/image/link order and inline-vs-block image
// placement are source-structure semantics owned by V2Next, not by the library.
//
// The custom token types below are legacy compatibility shims: they keep the
// current UI working while preventing the library from taking over blocks whose
// layout/order V2Next must control. Do not expand this pattern; replace it with
// explicit V2Next Render Tokens when touching this area.
const CODE_MONO = "customCode";
const LIST_MONO = "customList";
const PARAGRAPH_MONO = "customParagraph";
const IMAGE_BLOCK_MONO = "customImageBlock";
const IMAGE_TABLE_MONO = "customImageTable";
const IMAGE_TABLE_START = "@@V2NEXT_IMAGE_TABLE_START@@";
const IMAGE_TABLE_END = "@@V2NEXT_IMAGE_TABLE_END@@";
// Neutral load sentinel for inline images whose intrinsic dimensions are not known yet.
// This is only to start ImageSpan loading/onComplete; it is not an icon/small-image fallback
// and must not reserve content-width space before the real image size is recorded.
const INLINE_IMAGE_PENDING_SIZE = 1;
const INLINE_IMAGE_VIEWPORT_SAFE_MAX_HEIGHT = 1200;
const INLINE_IMAGE_SIZE_RECORD_LIMIT = 64;

const RENDER_BODY_FONT_SIZE = 14;
const RENDER_BODY_LINE_HEIGHT = 20;
const RENDER_CODE_FONT_SIZE = 12;
const RENDER_CODE_LINE_HEIGHT = 18;
const RENDER_H1_FONT_SIZE = 22;
const RENDER_H1_LINE_HEIGHT = 28;
const RENDER_H2_FONT_SIZE = 20;
const RENDER_H2_LINE_HEIGHT = 26;
const RENDER_H3_FONT_SIZE = 18;
const RENDER_H3_LINE_HEIGHT = 24;
const RENDER_H4_FONT_SIZE = 16;
const RENDER_H4_LINE_HEIGHT = 22;
const RENDER_H5_FONT_SIZE = 15;
const RENDER_H5_LINE_HEIGHT = 21;
const RENDER_H6_FONT_SIZE = 14;
const RENDER_H6_LINE_HEIGHT = 20;
// Minimum width that keeps ordinary header words and short numeric cells readable;
// if every column cannot keep this width, the table scrolls horizontally instead of hard-squeezing text.
const TABLE_READABLE_MIN_CELL_WIDTH = 112;
const TABLE_CELL_HORIZONTAL_PADDING = ThemeConstants.SPACE_SM * 2;
// Content-width units used for ordinary table natural-width estimates. These stay close to glyph
// proportions so prose-heavy cells do not dominate responsive compression.
const TABLE_ASCII_DISPLAY_UNIT = 0.56;
const TABLE_NUMERIC_DISPLAY_UNIT = 0.48;
const TABLE_SYMBOL_DISPLAY_UNIT = 0.56;
const TABLE_SPACE_DISPLAY_UNIT = 0.33;
const TABLE_WIDE_DISPLAY_UNIT = 1.0;
// Conservative no-wrap estimate used only for protected short tokens (short ASCII headers and
// percent/fraction cells). Values are ArkUI vp text-width estimates, not physical-pixel dump
// bounds; they must preserve protected tokens without making a 230-class viewport scroll when
// the protected minima can fit.
const TABLE_PROTECTED_ASCII_DISPLAY_UNIT = 1.65;
const TABLE_PROTECTED_NUMERIC_DISPLAY_UNIT = 1.1;
const TABLE_PROTECTED_SYMBOL_DISPLAY_UNIT = 0.9;
const TABLE_PROTECTED_SPACE_DISPLAY_UNIT = 0.55;
const TABLE_PROTECTED_WIDE_DISPLAY_UNIT = 1.08;
const TABLE_BORDER_COLOR = "#1A000000";

type TokenValue = Object | string | number | boolean | null | undefined;
type TokenRecord = Record<string, TokenValue>;

type RenderSourceKind = "markdown" | "renderedHtml";
type RenderBlockKind = "paragraph" | "heading" | "list" | "blockquote" | "code" | "imageBlock" | "imageTable" | "table";
type RenderInlineKind = "text" | "link" | "strong" | "em" | "codespan" | "image" | "break" | "base64Decode";
type RenderToken = Token;

interface Base64DecodeToken {
  type: string;
  raw: string;
  text: string;
  original: string;
  decoded: string;
}

interface RenderContractStyleRow {
  name: string;
  semanticKind: RenderBlockKind | RenderInlineKind;
  fontSize: string;
  lineHeight?: string;
  color?: string;
  weight?: string;
  style?: string;
  background?: string;
  roleDecision?: string;
}

// Explicit V2Next rendering contract table. These rows are intentionally string
// formulas rather than computed values so adapter tests can assert the semantic
// contract without requiring ArkUI runtime objects. The actual builders below
// must stay aligned with this table.
const RENDER_STYLE_CONTRACT_TABLE: RenderContractStyleRow[] = [
  { name: "paragraph", semanticKind: "paragraph", fontSize: "fixed base 14 * readingTextScale", lineHeight: "fixed base 20 * readingTextScale", color: "TEXT_PRIMARY" },
  { name: "h1", semanticKind: "heading", fontSize: "fixed base 22 * readingTextScale", lineHeight: "fixed base 28 * readingTextScale", weight: "Bold", color: "TEXT_PRIMARY" },
  { name: "h2", semanticKind: "heading", fontSize: "fixed base 20 * readingTextScale", lineHeight: "fixed base 26 * readingTextScale", weight: "Bold", color: "TEXT_PRIMARY" },
  { name: "h3", semanticKind: "heading", fontSize: "fixed base 18 * readingTextScale", lineHeight: "fixed base 24 * readingTextScale", weight: "Medium", color: "TEXT_PRIMARY" },
  { name: "h4", semanticKind: "heading", fontSize: "fixed base 16 * readingTextScale", lineHeight: "fixed base 22 * readingTextScale", weight: "Medium", color: "TEXT_PRIMARY" },
  { name: "h5", semanticKind: "heading", fontSize: "fixed base 15 * readingTextScale", lineHeight: "fixed base 21 * readingTextScale", weight: "Medium", color: "TEXT_PRIMARY" },
  { name: "h6", semanticKind: "heading", fontSize: "fixed base 14 * readingTextScale", lineHeight: "fixed base 20 * readingTextScale", weight: "Medium", color: "TEXT_PRIMARY" },
  { name: "list", semanticKind: "list", fontSize: "fixed base 14 * readingTextScale", lineHeight: "fixed base 20 * readingTextScale", color: "TEXT_PRIMARY" },
  { name: "blockquote", semanticKind: "blockquote", fontSize: "fixed base 14 * readingTextScale", lineHeight: "fixed base 20 * readingTextScale", color: "TEXT_PRIMARY", background: "_quoteBackground(...)" },
  { name: "code/pre", semanticKind: "code", fontSize: "fixed base 12 * readingTextScale", lineHeight: "fixed base 18 * readingTextScale", color: "CODE_TEXT", background: "_codeBackground(...)" },
  { name: "link", semanticKind: "link", fontSize: "inherited/body", color: "TEXT_LINK", style: "underline except member links" },
  { name: "strong", semanticKind: "strong", fontSize: "inherited/body", weight: "Bold", color: "TEXT_PRIMARY" },
  { name: "em", semanticKind: "em", fontSize: "inherited/body", style: "Italic", color: "TEXT_PRIMARY" },
  { name: "codespan", semanticKind: "codespan", fontSize: "inherited/body", color: "TEXT_PRIMARY", background: "BG_SUB" },
  { name: "base64Decode", semanticKind: "base64Decode", fontSize: "inherited/body", color: "TEXT_LINK", roleDecision: "ordinary text enhancement only; original token text remains visible and decoded text is badge-gated by default" },
  { name: "imageBlock", semanticKind: "imageBlock", fontSize: "n/a", roleDecision: "source structure / Markdown block semantics; never intrinsic big/small" },
  { name: "inlineImage", semanticKind: "image", fontSize: "n/a", roleDecision: "source structure / Markdown inline semantics; rendered dimensions come from actual image size + content container max constraint" },
  { name: "imageTable", semanticKind: "imageTable", fontSize: "caption labels", color: "TEXT_SECONDARY" },
  { name: "table", semanticKind: "table", fontSize: "fixed base 14 * readingTextScale", lineHeight: "fixed base 20 * readingTextScale", weight: "header Medium/Bold; body Regular", color: "TEXT_PRIMARY", background: "header BG_SUB; divider #1A000000" },
];

interface InlineImageToken extends Tokens.Image {
  inlineImage?: boolean;
}

interface InlineImageSizeRecord {
  url: string;
  widthPx: number;
  heightPx: number;
}

interface InlineImageRenderSize {
  width: number;
  height: number;
}

interface ImageTableToken {
  type: string;
  raw?: string;
  imageUrls?: string[];
  imageLabels?: string[];
}

interface RenderTableCell {
  raw?: string;
  text: string;
  tokens: Token[];
  align?: string;
  header?: boolean;
}

interface RenderTableToken {
  type: string;
  raw?: string;
  headers: RenderTableCell[];
  rows: RenderTableCell[][];
}

type InlineImageCompleteReporter = (url: string, event?: MarkdownImageCompleteEvent) => void;
type InlineImageErrorReporter = (url: string, event?: MarkdownImageErrorEvent) => void;

interface MarkdownRenderOptions extends MarkdownOptions {
  inlineImageSizeRecords?: InlineImageSizeRecord[];
  reportInlineImageComplete?: InlineImageCompleteReporter;
  reportInlineImageError?: InlineImageErrorReporter;
}

function _isInlineImageToken(token: Token): boolean {
  const image = token as InlineImageToken;
  return token && token.type === "image" && image.inlineImage === true;
}

function _findInlineImageSizeRecord(records: InlineImageSizeRecord[], url: string): InlineImageSizeRecord | null {
  if (!url || !records || records.length === 0) {
    return null;
  }
  for (const record of records) {
    if (record.url === url) {
      return record;
    }
  }
  return null;
}

function _inlineImageRenderUrl(token: Token): string {
  if (!token || token.type !== "image") {
    return "";
  }
  return MediaUrlUtils.imageUrlForRender((token as Tokens.Image).href);
}

function _areaWidth(value: Area): number {
  if (typeof value.width === 'number') {
    return value.width;
  }
  if (typeof value.width === 'string') {
    const parsed = Number.parseFloat(value.width);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

function _inlineImageRenderSize(token: Token, sizeRecords: InlineImageSizeRecord[], availableWidth: number): InlineImageRenderSize {
  const contentMaxWidth = Math.max(0, availableWidth);
  const url = _inlineImageRenderUrl(token);
  const record = _findInlineImageSizeRecord(sizeRecords, url);
  const widthPx = record?.widthPx ?? 0;
  const heightPx = record?.heightPx ?? 0;
  if (widthPx <= 0 || heightPx <= 0 || contentMaxWidth <= 0) {
    return {
      width: INLINE_IMAGE_PENDING_SIZE,
      height: INLINE_IMAGE_PENDING_SIZE,
    };
  }
  const scale = Math.min(1, contentMaxWidth / widthPx, INLINE_IMAGE_VIEWPORT_SAFE_MAX_HEIGHT / heightPx);
  return {
    width: Math.max(1, Math.round(widthPx * scale)),
    height: Math.max(1, Math.round(heightPx * scale)),
  };
}

function _isMixedInlineImageCandidate(token: Token): boolean {
  if (!token || token.type !== "image") {
    return false;
  }
  if (_isInlineImageToken(token)) {
    return true;
  }
  if ((token as InlineImageToken).inlineImage === false) {
    return false;
  }
  const raw = (token.raw ?? "").trim().toLowerCase();
  return raw.startsWith("<img");
}

function _appendCacheBust(url: string, nonce: number): string {
  if (!url) {
    return "";
  }
  if (nonce <= 0) {
    return url;
  }
  const sep = url.indexOf("?") >= 0 ? "&" : "?";
  return `${url}${sep}_r=${nonce}`;
}

type CodeHighLight = "string" | "text" | "keyword" | "type" | "symbol" | "number" | "boolean" | "comment" | "tag" | "attr" | "key" | "punctuation" | "flag";

interface CodeToken {
  type: CodeHighLight;
  text: string;
}

// ---------- Code syntax highlighting ----------
// Ported from @lidary/markdown's internal HighlightAnalyzer (not exported).
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

function normalizeCodeLanguage(lang: string): string {
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

function highlightCodeLine(code: string, lang: string): CodeToken[] {
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

const _darkCodeColors: Record<string, ResourceColor> = {
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

const _lightCodeColors: Record<string, ResourceColor> = {
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

function _codeColors(isDark: boolean): Record<string, ResourceColor> {
  return isDark ? _darkCodeColors : _lightCodeColors;
}

function _codeBackground(isDark: boolean): ResourceColor {
  return isDark ? "#1E1F22" : "#F6F8FA";
}

function _codeHeaderBackground(isDark: boolean): ResourceColor {
  return isDark ? "#2B2D31" : "#EAEEF3";
}

function _codeMetaColor(isDark: boolean): ResourceColor {
  return isDark ? "#C9D1D9" : "#57606A";
}

function _codePressedOverlay(isDark: boolean): ResourceColor {
  return isDark ? "#40FFFFFF" : "#18000000";
}

function _quoteBackground(isDark: boolean): ResourceColor {
  return isDark ? "#22262D" : "#F6F8FA";
}

function _quoteDriveColor(isDark: boolean): ResourceColor {
  return isDark ? "#636E7B" : "#D0D7DE";
}

// Signature required by @lidary/markdown's customInlineBuilder callback
interface CustomInlineParams {
  token: Token[];
  options: MarkdownOptions;
  uiContext: UIContext;
  inlineTextStyle?: MutableStyledString;
  isLink?: boolean;
  fontWeight?: FontWeight;
  onSpanClick?: () => void;
}

interface MarkdownImageCompleteEvent {
  loadingStatus: number;
  width?: number;
  height?: number;
  componentWidth?: number;
  componentHeight?: number;
}

interface MarkdownImageErrorEvent {
  message?: string;
}

type MentionClick = (username: string) => void;

// ---------- Custom block rendering ----------
// Handles token types we've hijacked from the library (code blocks, lists).
@Builder
function CustomBlockBuilder(token: Token, options: MarkdownOptions) {
  if (token.type === CODE_MONO) {
    MarkdownCodeBlock({ codeToken: token as Tokens.Code, options: options });
  } else if (token.type === LIST_MONO) {
    CustomList({
      listToken: token as Tokens.List,
      options: options,
      inlineImageSizeRecords: (options as MarkdownRenderOptions).inlineImageSizeRecords ?? [],
      reportImageComplete: (options as MarkdownRenderOptions).reportInlineImageComplete,
      reportImageError: (options as MarkdownRenderOptions).reportInlineImageError,
    });
  } else if (token.type === PARAGRAPH_MONO) {
    MarkdownParagraph({
      paragraphToken: token as Tokens.Paragraph,
      options: options,
      inlineImageSizeRecords: (options as MarkdownRenderOptions).inlineImageSizeRecords ?? [],
      reportImageComplete: (options as MarkdownRenderOptions).reportInlineImageComplete,
      reportImageError: (options as MarkdownRenderOptions).reportInlineImageError,
    });
  } else if (token.type === IMAGE_BLOCK_MONO) {
    MarkdownAutoImage({
      url: MediaUrlUtils.imageUrlForRender((token as Tokens.Image).href),
      options: options,
      reportImageComplete: (options as MarkdownRenderOptions).reportInlineImageComplete,
      reportImageError: (options as MarkdownRenderOptions).reportInlineImageError,
    });
  } else if (token.type === IMAGE_TABLE_MONO) {
    MarkdownImageTable({
      tableToken: token as ImageTableToken,
      options: options,
      reportImageComplete: (options as MarkdownRenderOptions).reportInlineImageComplete,
      reportImageError: (options as MarkdownRenderOptions).reportInlineImageError,
    });
  } else if (token.type === "table") {
    MarkdownTable({
      tableToken: token as RenderTableToken,
      options: options,
      inlineImageSizeRecords: (options as MarkdownRenderOptions).inlineImageSizeRecords ?? [],
      reportImageComplete: (options as MarkdownRenderOptions).reportInlineImageComplete,
      reportImageError: (options as MarkdownRenderOptions).reportInlineImageError,
    });
  }
}

function _openInlineLink(options: MarkdownOptions, url: string): void {
  const normalized = MediaUrlUtils.normalizeUrl(url);
  if (!normalized) {
    return;
  }
  const click = options?.linkClick as ((url?: string) => void) | undefined;
  if (click) {
    click(normalized);
  }
}

function _openMention(options: MarkdownOptions, username: string): void {
  const clean = (username || "").trim();
  if (!clean) {
    return;
  }
  const record = options as Record<string, Object>;
  const click = record["mentionClick"] as MentionClick | undefined;
  if (click) {
    click(clean);
  }
}

function _memberNameFromLink(token: Tokens.Link): string {
  const href = token.href || "";
  const match = /^https?:\/\/(?:www\.)?v2ex\.(?:com|co)\/member\/([^?#/]+)(?:[?#].*)?$/i.exec(MediaUrlUtils.normalizeUrl(href)) ||
    /^\/member\/([^?#/]+)(?:[?#].*)?$/i.exec(href);
  if (!match || !match[1]) {
    return "";
  }
  try {
    return decodeURIComponent(match[1]);
  } catch (_error) {
    return match[1];
  }
}

function _memberLinkText(token: Tokens.Link): string {
  const name = _memberNameFromLink(token);
  if (!name) {
    return "";
  }
  const text = (token.text || "").trim();
  if (text.startsWith("@")) {
    return text;
  }
  return `@${text || name}`;
}

function _copyDecodedBase64Text(decoded: string): void {
  try {
    let data = pasteboard.createData(
      pasteboard.MIMETYPE_TEXT_PLAIN,
      decoded,
    );
    pasteboard.getSystemPasteboard().setDataSync(data);
    promptAction.openToast({ message: "已复制解码文本" }).catch((_error: Error) => { });
  } catch (error) {
    promptAction.openToast({ message: (error as Error).message || "复制失败" }).catch((_error: Error) => { });
  }
}

function _base64PopupMessage(original: string, decoded: string): string {
  return `Base64 解码\n\n原文：${_base64OriginalSummary(original)}\n\n${decoded}`;
}

function _base64PopupKey(token: Base64DecodeToken, tokenIndex: number, scope: string): string {
  return `${scope}-${tokenIndex}-${token.original}`;
}

function _base64OriginalSummary(original: string): string {
  const value = original || "";
  if (value.length <= 32) {
    return value;
  }
  return `${value.slice(0, 16)}…${value.slice(value.length - 8)}`;
}

function _tokensContainBase64Decode(tokens: Token[]): boolean {
  if (!tokens || tokens.length === 0) {
    return false;
  }
  for (const token of tokens) {
    if (!token) {
      continue;
    }
    if (token.type === "base64Decode") {
      return true;
    }
    const children = (token as TokenRecord)["tokens"] as Token[] | undefined;
    if (Array.isArray(children) && _tokensContainBase64Decode(children)) {
      return true;
    }
  }
  return false;
}

@Component
struct Base64PopupBadge {
  @Prop token: Base64DecodeToken;
  @Prop tokenIndex: number = 0;
  @Prop fontSize: number = RENDER_BODY_FONT_SIZE;
  @Prop base64PopupScope: string = "inline";
  @State private isPopupVisible: boolean = false;

  build() {
    Button() {
      Text("Base64")
        .fontSize(Math.max(10, this.fontSize - 2))
        .fontColor(ThemeConstants.TEXT_LINK)
    }
    .type(ButtonType.Normal)
    .height(Math.max(18, this.fontSize + 6))
    .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
    .margin({ left: ThemeConstants.SPACE_XS })
    .borderRadius(ThemeConstants.RADIUS_SM)
    .backgroundColor(ThemeConstants.BG_SUB)
    .stateStyles({
      pressed: { .backgroundColor(ThemeConstants.BG_SUB) },
      normal: { .backgroundColor(ThemeConstants.BG_SUB) },
    })
    .onClick(() => {
      this.isPopupVisible = true;
    })
    .bindPopup(this.isPopupVisible, {
      message: _base64PopupMessage(this.token.original, this.token.decoded),
      placement: Placement.Bottom,
      primaryButton: {
        value: "复制",
        action: () => {
          _copyDecodedBase64Text(this.token.decoded);
        },
      },
      autoCancel: true,
      mask: false,
      enableArrow: true,
      onStateChange: (event: PopupStateChangeParam) => {
        this.isPopupVisible = event.isVisible;
      },
    });
  }
}

@Builder
function SelectableTextWithMentions(text: string, fontSize: number, options: MarkdownOptions) {
  ForEach(_splitMentionText(HtmlEntityUtils.decode(text)), (part: string) => {
    if (part.startsWith("@") && part.length > 1) {
      Span(part)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_LINK)
        .onClick(() => {
          _openMention(options, part.slice(1));
        });
    } else {
      Span(part)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_PRIMARY);
    }
  });
}

function _isMentionBoundaryChar(ch: string): boolean {
  if (!ch) {
    return true;
  }
  return !((ch >= 'a' && ch <= 'z') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= '0' && ch <= '9') ||
    ch === '_' || ch === '-' || ch === '.');
}

function _isValidMentionMatch(raw: string, atIndex: number, matchText: string): boolean {
  const before = atIndex > 0 ? raw.charAt(atIndex - 1) : '';
  const afterIndex = atIndex + matchText.length;
  const after = afterIndex < raw.length ? raw.charAt(afterIndex) : '';
  return _isMentionBoundaryChar(before) && _isMentionBoundaryChar(after);
}

function _splitMentionText(text: string): string[] {
  const raw = text || "";
  if (!raw) {
    return [""];
  }
  const parts: string[] = [];
  const re = /@([0-9A-Za-z_]{2,32})/g;
  let last = 0;
  let m: RegExpExecArray | null = re.exec(raw);
  while (m) {
    const matchText = m[0];
    if (!_isValidMentionMatch(raw, m.index, matchText)) {
      m = re.exec(raw);
      continue;
    }
    if (m.index > last) {
      parts.push(raw.slice(last, m.index));
    }
    parts.push(matchText);
    last = m.index + matchText.length;
    m = re.exec(raw);
  }
  if (last < raw.length) {
    parts.push(raw.slice(last));
  }
  return parts.length > 0 ? parts : [raw];
}

@Builder
function SelectableInlineTokenSpans(
  tokens: Token[],
  fontSize: number,
  options: MarkdownOptions,
  inlineImageSizeRecords: InlineImageSizeRecord[] = [],
  reportImageComplete?: InlineImageCompleteReporter,
  reportImageError?: InlineImageErrorReporter,
  availableWidth: number = 0,
  base64DecodeMode: string = ReadingSettings.BASE64_MODE_BADGE,
  activeBase64PopupKey: string = "",
  showBase64Popup?: (key: string) => void,
  hideBase64Popup?: (key: string) => void,
  base64PopupScope: string = "inline",
) {
  ForEach(tokens, (t: Token, tokenIndex: number) => {
    if (t.type === "strong") {
      Span((t as Tokens.Strong).text)
        .fontSize(fontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY);
    } else if (t.type === "em") {
      Span((t as Tokens.Em).text)
        .fontSize(fontSize)
        .fontStyle(FontStyle.Italic)
        .fontColor(ThemeConstants.TEXT_PRIMARY);
    } else if (t.type === "codespan") {
      Span(` ${(t as Tokens.Codespan).text} `)
        .fontSize(fontSize)
        .fontFamily("Noto Sans Mono")
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .textBackgroundStyle({
          color: ThemeConstants.BG_SUB,
          radius: ThemeConstants.RADIUS_SM,
        });
    } else if (t.type === "link") {
      if (_memberNameFromLink(t as Tokens.Link)) {
        Span(_memberLinkText(t as Tokens.Link))
          .fontSize(fontSize)
          .fontColor(ThemeConstants.TEXT_LINK)
          .onClick(() => {
            _openMention(options, _memberNameFromLink(t as Tokens.Link));
          });
      } else {
        Span((t as Tokens.Link).text)
          .fontSize(fontSize)
          .fontColor(ThemeConstants.TEXT_LINK)
          .decoration({ type: TextDecorationType.Underline, color: ThemeConstants.TEXT_LINK })
          .onClick(() => {
            _openInlineLink(options, (t as Tokens.Link).href);
          });
      }
    } else if (t.type === "base64Decode") {
      if (base64DecodeMode === ReadingSettings.BASE64_MODE_INLINE) {
        Span(` 解码：${(t as Base64DecodeToken).decoded}`)
          .fontSize(fontSize)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .textBackgroundStyle({
            color: ThemeConstants.BG_SUB,
            radius: ThemeConstants.RADIUS_SM,
          });
      } else if (base64DecodeMode === ReadingSettings.BASE64_MODE_BADGE) {
        Span(" Base64")
          .fontSize(Math.max(10, fontSize - 2))
          .fontColor(ThemeConstants.TEXT_LINK)
          .textBackgroundStyle({
            color: ThemeConstants.BG_SUB,
            radius: ThemeConstants.RADIUS_SM,
          });
      }
    } else if (t.type === "del") {
      Span((t as Tokens.Del).text)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .decoration({ type: TextDecorationType.LineThrough });
    } else if (_isInlineImageToken(t)) {
      ImageSpan(_inlineImageRenderUrl(t))
        .width(_inlineImageRenderSize(t, inlineImageSizeRecords, availableWidth).width)
        .height(_inlineImageRenderSize(t, inlineImageSizeRecords, availableWidth).height)
        .objectFit(ImageFit.Contain)
        .verticalAlign(ImageSpanAlignment.CENTER)
        .onComplete((event?: MarkdownImageCompleteEvent) => {
          if (reportImageComplete) {
            reportImageComplete(_inlineImageRenderUrl(t), event);
          }
        })
        .onError((event?: MarkdownImageErrorEvent) => {
          if (reportImageError) {
            reportImageError(_inlineImageRenderUrl(t), event);
          }
        });
    } else {
      SelectableTextWithMentions((t as Tokens.Text).text ?? t.raw ?? "", fontSize, options);
    }
  });
}

@Component
struct SelectableInlineTokenFlow {
  @Prop tokens: Token[] = [];
  @Prop fontSize: number = RENDER_BODY_FONT_SIZE;
  @Prop fontColor: ResourceColor = ThemeConstants.TEXT_PRIMARY;
  @Prop fontWeight: FontWeight = FontWeight.Regular;
  @Prop lineHeight: number = RENDER_BODY_LINE_HEIGHT;
  @Prop textAlign: TextAlign = TextAlign.Start;
  @Prop wordBreak: WordBreak = WordBreak.BREAK_WORD;
  @Prop copyOption: CopyOptions = CopyOptions.LocalDevice;
  @Prop textSelectable: TextSelectableMode = TextSelectableMode.SELECTABLE_FOCUSABLE;
  @Prop options: MarkdownOptions;
  @Prop inlineImageSizeRecords: InlineImageSizeRecord[] = [];
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @Prop availableWidth: number = 0;
  @Prop base64DecodeMode: string = ReadingSettings.BASE64_MODE_BADGE;
  @Prop activeBase64PopupKey: string = "";
  showBase64Popup?: (key: string) => void;
  hideBase64Popup?: (key: string) => void;
  @Prop base64PopupScope: string = "inline";

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.tokens, (t: Token, tokenIndex: number) => {
        if (t.type === "base64Decode" && this.base64DecodeMode === ReadingSettings.BASE64_MODE_BADGE) {
          Base64PopupBadge({
            token: t as Base64DecodeToken,
            tokenIndex: tokenIndex,
            fontSize: this.fontSize,
            base64PopupScope: this.base64PopupScope,
          });
        } else if (t.type === "base64Decode" && this.base64DecodeMode === ReadingSettings.BASE64_MODE_OFF) {
          Blank().width(0).height(0);
        } else {
          Text() {
            SelectableInlineTokenSpans(
              [t],
              this.fontSize,
              this.options,
              this.inlineImageSizeRecords,
              this.reportImageComplete,
              this.reportImageError,
              this.availableWidth,
              this.base64DecodeMode,
              this.activeBase64PopupKey,
              this.showBase64Popup,
              this.hideBase64Popup,
              `${this.base64PopupScope}-${tokenIndex}`,
            );
          }
          .fontSize(this.fontSize)
          .fontWeight(this.fontWeight)
          .fontColor(this.fontColor)
          .lineHeight(this.lineHeight)
          .textAlign(this.textAlign)
          .wordBreak(this.wordBreak)
          .copyOption(this.copyOption)
          .textSelectable(this.textSelectable)
        }
      }, (t: Token, tokenIndex: number) => `${String((t as TokenRecord)["type"] ?? "token")}-${String((t as TokenRecord)["raw"] ?? (t as TokenRecord)["text"] ?? tokenIndex)}-${tokenIndex}`)
    }
    .width("100%")
  }
}

@Component
struct MarkdownParagraph {
  @Prop paragraphToken: Tokens.Paragraph;
  @Prop options: MarkdownOptions;
  @Prop inlineImageSizeRecords: InlineImageSizeRecord[] = [];
  @Prop contentAvailableWidth: number = 0;
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ReadingSettings.TEXT_SCALE_DEFAULT;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;
  @StorageLink(StorageKeys.READING_BASE64_DECODE_MODE) base64DecodeMode: string = ReadingSettings.BASE64_MODE_BADGE;
  @State private paragraphAvailableWidth: number = 0;
  @State private activeBase64PopupKey: string = "";

  private showBase64Popup(key: string): void {
    this.activeBase64PopupKey = "";
    setTimeout(() => {
      this.activeBase64PopupKey = key;
    }, 20);
  }

  private hideBase64Popup(key: string): void {
    if (this.activeBase64PopupKey === key) {
      this.activeBase64PopupKey = "";
    }
  }

  private updateParagraphAvailableWidth(value: Area): void {
    this.paragraphAvailableWidth = _areaWidth(value);
  }

  private inlineContentMaxWidth(): number {
    if (this.paragraphAvailableWidth > 0) {
      return this.paragraphAvailableWidth;
    }
    return this.contentAvailableWidth;
  }

  private bodyFontSize(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_FONT_SIZE, this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_LINE_HEIGHT, this.readingFontSize);
  }

  private inlineTokens(): Token[] {
    const tokens = this.paragraphToken.tokens as Token[] | undefined;
    if (!Array.isArray(tokens) || tokens.length === 0) {
      return [];
    }
    return tokens;
  }

  private textTokens(): Token[] {
    return this.inlineTokens().filter((token: Token) => token && (token.type !== "image" || _isInlineImageToken(token)) && token.type !== "br");
  }

  private blockImageTokens(): Tokens.Image[] {
    return this.inlineTokens().filter((token: Token) => token && token.type === "image" && !_isInlineImageToken(token)) as Tokens.Image[];
  }

  private hasInlineImage(): boolean {
    return this.inlineTokens().some((token: Token) => _isInlineImageToken(token));
  }

  private hasBlockImage(): boolean {
    return this.blockImageTokens().length > 0;
  }

  build() {
    if (this.hasBlockImage()) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        ForEach(this.inlineTokens(), (token: Token, tokenIdx: number) => {
          if (token && token.type === "image" && !_isInlineImageToken(token)) {
            MarkdownAutoImage({
              url: MediaUrlUtils.imageUrlForRender((token as Tokens.Image).href),
              options: this.options,
              reportImageComplete: this.reportImageComplete,
              reportImageError: this.reportImageError,
            });
          } else if (token && token.type !== "br" && String((token as TokenRecord)["text"] ?? (token as TokenRecord)["raw"] ?? "").trim().length > 0) {
            if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_BADGE && _tokensContainBase64Decode([token])) {
              SelectableInlineTokenFlow({
                tokens: [token],
                fontSize: this.bodyFontSize(),
                fontColor: ThemeConstants.TEXT_PRIMARY,
                fontWeight: FontWeight.Regular,
                lineHeight: this.bodyLineHeight(),
                textAlign: TextAlign.Start,
                wordBreak: WordBreak.BREAK_WORD,
                copyOption: CopyOptions.LocalDevice,
                textSelectable: TextSelectableMode.SELECTABLE_FOCUSABLE,
                options: this.options,
                inlineImageSizeRecords: this.inlineImageSizeRecords,
                reportImageComplete: this.reportImageComplete,
                reportImageError: this.reportImageError,
                availableWidth: this.inlineContentMaxWidth(),
                base64DecodeMode: this.base64DecodeMode,
                activeBase64PopupKey: this.activeBase64PopupKey,
                showBase64Popup: (key: string) => { this.showBase64Popup(key); },
                hideBase64Popup: (key: string) => { this.hideBase64Popup(key); },
                base64PopupScope: `paragraph-block-${tokenIdx}`,
              })
              .onAreaChange((_oldValue: Area, newValue: Area) => {
                this.updateParagraphAvailableWidth(newValue);
              })
            } else {
              Text() {
                SelectableInlineTokenSpans(
                  [token],
                  this.bodyFontSize(),
                  this.options,
                  this.inlineImageSizeRecords,
                  this.reportImageComplete,
                  this.reportImageError,
                  this.inlineContentMaxWidth(),
                  this.base64DecodeMode,
                  this.activeBase64PopupKey,
                  (key: string) => { this.showBase64Popup(key); },
                  (key: string) => { this.hideBase64Popup(key); },
                  `paragraph-block-${tokenIdx}`,
                );
              }
              .fontSize(this.bodyFontSize())
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .lineHeight(this.bodyLineHeight())
              .textAlign(TextAlign.Start)
              .width("100%")
              .onAreaChange((_oldValue: Area, newValue: Area) => {
                this.updateParagraphAvailableWidth(newValue);
              })
              .copyOption(CopyOptions.LocalDevice)
              .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
            }
          }
        }, (token: Token, tokenIdx: number) => `${String((token as TokenRecord)["type"] ?? "token")}-${String((token as TokenRecord)["raw"] ?? (token as TokenRecord)["href"] ?? tokenIdx)}-${tokenIdx}`)
      }
      .width("100%")
      .alignItems(HorizontalAlign.Start)
    } else if (this.hasInlineImage()) {
      if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_BADGE && _tokensContainBase64Decode(this.inlineTokens())) {
        SelectableInlineTokenFlow({
          tokens: this.inlineTokens(),
          fontSize: this.bodyFontSize(),
          fontColor: ThemeConstants.TEXT_PRIMARY,
          fontWeight: FontWeight.Regular,
          lineHeight: this.bodyLineHeight(),
          textAlign: TextAlign.Start,
          wordBreak: WordBreak.BREAK_WORD,
          copyOption: CopyOptions.LocalDevice,
          textSelectable: TextSelectableMode.SELECTABLE_FOCUSABLE,
          options: this.options,
          inlineImageSizeRecords: this.inlineImageSizeRecords,
          reportImageComplete: this.reportImageComplete,
          reportImageError: this.reportImageError,
          availableWidth: this.inlineContentMaxWidth(),
          base64DecodeMode: this.base64DecodeMode,
          activeBase64PopupKey: this.activeBase64PopupKey,
          showBase64Popup: (key: string) => { this.showBase64Popup(key); },
          hideBase64Popup: (key: string) => { this.hideBase64Popup(key); },
          base64PopupScope: "paragraph-inline",
        })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updateParagraphAvailableWidth(newValue);
        })
      } else {
        Text() {
          SelectableInlineTokenSpans(
            this.inlineTokens(),
            this.bodyFontSize(),
            this.options,
            this.inlineImageSizeRecords,
            this.reportImageComplete,
            this.reportImageError,
            this.inlineContentMaxWidth(),
            this.base64DecodeMode,
            this.activeBase64PopupKey,
            (key: string) => { this.showBase64Popup(key); },
            (key: string) => { this.hideBase64Popup(key); },
            "paragraph-inline",
          );
        }
        .fontSize(this.bodyFontSize())
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .lineHeight(this.bodyLineHeight())
        .textAlign(TextAlign.Start)
        .width("100%")
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updateParagraphAvailableWidth(newValue);
        })
      }
    } else {
      if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_BADGE && _tokensContainBase64Decode(this.inlineTokens())) {
        SelectableInlineTokenFlow({
          tokens: this.inlineTokens(),
          fontSize: this.bodyFontSize(),
          fontColor: ThemeConstants.TEXT_PRIMARY,
          fontWeight: FontWeight.Regular,
          lineHeight: this.bodyLineHeight(),
          textAlign: TextAlign.Start,
          wordBreak: WordBreak.BREAK_WORD,
          copyOption: CopyOptions.LocalDevice,
          textSelectable: TextSelectableMode.SELECTABLE_FOCUSABLE,
          options: this.options,
          inlineImageSizeRecords: this.inlineImageSizeRecords,
          reportImageComplete: this.reportImageComplete,
          reportImageError: this.reportImageError,
          availableWidth: this.inlineContentMaxWidth(),
          base64DecodeMode: this.base64DecodeMode,
          activeBase64PopupKey: this.activeBase64PopupKey,
          showBase64Popup: (key: string) => { this.showBase64Popup(key); },
          hideBase64Popup: (key: string) => { this.hideBase64Popup(key); },
          base64PopupScope: "paragraph-text",
        })
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updateParagraphAvailableWidth(newValue);
        })
      } else {
        Text() {
          SelectableInlineTokenSpans(
            this.inlineTokens(),
            this.bodyFontSize(),
            this.options,
            this.inlineImageSizeRecords,
            this.reportImageComplete,
            this.reportImageError,
            this.inlineContentMaxWidth(),
            this.base64DecodeMode,
            this.activeBase64PopupKey,
            (key: string) => { this.showBase64Popup(key); },
            (key: string) => { this.hideBase64Popup(key); },
            "paragraph-text",
          );
        }
        .fontSize(this.bodyFontSize())
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .lineHeight(this.bodyLineHeight())
        .textAlign(TextAlign.Start)
        .width("100%")
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.updateParagraphAvailableWidth(newValue);
        })
        .copyOption(CopyOptions.LocalDevice)
        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
      }
    }
  }
}

@Component
struct MarkdownBlockquote {
  @Prop quoteToken: Token;
  @Prop options: MarkdownOptions;
  @Prop inlineImageSizeRecords: InlineImageSizeRecord[] = [];
  @Prop contentAvailableWidth: number = 0;
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ReadingSettings.TEXT_SCALE_DEFAULT;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;

  private bodyFontSize(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_FONT_SIZE, this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_LINE_HEIGHT, this.readingFontSize);
  }

  private quoteRailHeight(): number {
    return this.bodyLineHeight();
  }

  private quoteChildren(): Token[] {
    const children = (this.quoteToken as TokenRecord)["tokens"] as Token[] | undefined;
    return Array.isArray(children) ? children : [];
  }

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Blank()
        .width(3)
        .height(this.quoteRailHeight())
        .borderRadius(2)
        .backgroundColor(_quoteDriveColor(this.options.darkMode === true))
      Column({ space: ThemeConstants.SPACE_XS }) {
        ForEach(this.quoteChildren(), (child: Token) => {
          if (child.type === PARAGRAPH_MONO || child.type === "paragraph") {
            MarkdownParagraph({
              paragraphToken: child as Tokens.Paragraph,
              options: this.options,
              inlineImageSizeRecords: this.inlineImageSizeRecords,
              contentAvailableWidth: this.contentAvailableWidth,
              reportImageComplete: this.reportImageComplete,
              reportImageError: this.reportImageError,
            });
          } else if (child.type === LIST_MONO || child.type === "list") {
            CustomList({
              listToken: child as Tokens.List,
              options: this.options,
              inlineImageSizeRecords: this.inlineImageSizeRecords,
              contentAvailableWidth: this.contentAvailableWidth,
              reportImageComplete: this.reportImageComplete,
              reportImageError: this.reportImageError,
            });
          } else if (child.type === IMAGE_BLOCK_MONO || child.type === "image") {
            MarkdownAutoImage({
              url: MediaUrlUtils.imageUrlForRender((child as Tokens.Image).href),
              options: this.options,
              reportImageComplete: this.reportImageComplete,
              reportImageError: this.reportImageError,
            });
          } else if (child.type !== "space" && String((child as TokenRecord)["text"] ?? (child as TokenRecord)["raw"] ?? "").trim().length > 0) {
            Text(String((child as TokenRecord)["text"] ?? (child as TokenRecord)["raw"] ?? ""))
              .fontSize(this.bodyFontSize())
              .lineHeight(this.bodyLineHeight())
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .width("100%");
          }
        }, (child: Token, index: number) => `${String((child as TokenRecord)["type"] ?? "token")}-${String((child as TokenRecord)["raw"] ?? (child as TokenRecord)["text"] ?? index)}-${index}`)
      }
      .layoutWeight(1)
      .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
    }
    .width("100%")
    .padding({ left: ThemeConstants.SPACE_SM })
    .backgroundColor(_quoteBackground(this.options.darkMode === true))
    .borderRadius(ThemeConstants.RADIUS_SM)
    .alignItems(VerticalAlign.Top)
  }
}

@Component
struct MarkdownCodeBlock {
  @Prop codeToken: Tokens.Code;
  @Prop options: MarkdownOptions;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ReadingSettings.TEXT_SCALE_DEFAULT;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;
  @State private wrapLines: boolean = false;

  private codeText(): string {
    return this.codeToken.text || "";
  }

  private languageText(): string {
    const lang = normalizeCodeLanguage((this.codeToken.lang || "") as string);
    return lang || "code";
  }

  private copyCode(): void {
    try {
      let data = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN,
        this.codeText(),
      );
      pasteboard.getSystemPasteboard().setDataSync(data);
      promptAction.openToast({ message: "已复制代码" }).catch((error: Error) => {
        console.error(`openToast failed: ${error.message}`);
      });
    } catch (error) {
      promptAction.openToast({ message: (error as Error).message || "复制失败" }).catch((_error: Error) => { });
    }
  }

  private codeFontSize(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_CODE_FONT_SIZE, this.readingFontSize);
  }

  private codeLineHeight(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_CODE_LINE_HEIGHT, this.readingFontSize);
  }

  private isDarkMode(): boolean {
    return this.options.darkMode === true;
  }

  private codePalette(): Record<string, ResourceColor> {
    return _codeColors(this.isDarkMode());
  }

  @Builder CodeLineSpans(line: string) {
    ForEach(highlightCodeLine(line, this.languageText()), (ht: CodeToken) => {
      Span(ht.text)
        .fontColor(
          this.options.theme?.code?.fontColor?.[ht.type] ??
            this.codePalette()[ht.type] ??
            ThemeConstants.CODE_TEXT,
        )
        .fontSize(this.codeFontSize())
        .fontFamily("Noto Sans Mono");
    })
  }

  @Builder CodeLines(wrapLines: boolean) {
    Column() {
      ForEach(this.codeText().split("\n"), (line: string) => {
        if (wrapLines) {
          Text() {
            this.CodeLineSpans(line);
          }
          .width("100%")
          .lineHeight(this.codeLineHeight());
        } else {
          Text() {
            this.CodeLineSpans(line);
          }
          .lineHeight(this.codeLineHeight())
          .maxLines(1);
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ minWidth: "100%" })
    .padding({
      top: ThemeConstants.SPACE_SM,
      bottom: ThemeConstants.SPACE_MD,
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_SM,
    });
  }

  build() {
    Column() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.languageText())
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontColor(_codeMetaColor(this.isDarkMode()))
          .fontFamily("Noto Sans Mono")
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Blank();

        Button() {
          Text(this.wrapLines ? "滚动" : "换行")
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor(_codeMetaColor(this.isDarkMode()));
        }
        .type(ButtonType.Normal)
        .height(24)
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor(Color.Transparent)
        .stateStyles({
          pressed: { .backgroundColor(_codePressedOverlay(this.isDarkMode())) },
          normal: { .backgroundColor(Color.Transparent) },
        })
        .onClick(() => {
          this.wrapLines = !this.wrapLines;
        });

        Button() {
          Image($r("sys.media.ohos_ic_public_copy"))
            .width(ThemeConstants.ICON_SIZE_SM)
            .height(ThemeConstants.ICON_SIZE_SM)
            .fillColor(_codeMetaColor(this.isDarkMode()));
        }
        .type(ButtonType.Normal)
        .width(ThemeConstants.TOUCH_TARGET_SM - 4)
        .height(24)
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor(Color.Transparent)
        .stateStyles({
          pressed: { .backgroundColor(_codePressedOverlay(this.isDarkMode())) },
          normal: { .backgroundColor(Color.Transparent) },
        })
        .onClick(() => {
          this.copyCode();
        });
      }
      .width("100%")
      .padding({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS,
      })
      .backgroundColor(_codeHeaderBackground(this.isDarkMode()));

      if (this.wrapLines) {
        this.CodeLines(true);
      } else {
        Scroll() {
          this.CodeLines(false);
        }
        .width("100%")
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Auto);
      }
    }
    .width("100%")
    .borderRadius(this.options.theme?.code?.borderRadius ?? ThemeConstants.RADIUS_SM)
    .clip(true)
    .backgroundColor(this.options.theme?.code?.backgroundColor ?? _codeBackground(this.isDarkMode()));
  }
}

// Renders inline markdown tokens (bold, italic, code, link, etc.) as Span children.
// Used inside CustomList since the library's Inline component is not exported.
@Builder
function InlineTokenSpans(
  tokens: Token[],
  fontSize: number,
  inlineImageSizeRecords: InlineImageSizeRecord[] = [],
  reportImageComplete?: InlineImageCompleteReporter,
  reportImageError?: InlineImageErrorReporter,
  availableWidth: number = 0,
) {
  ForEach(tokens, (t: Token) => {
    if (t.type === "strong") {
      Span((t as Tokens.Strong).text)
        .fontSize(fontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY);
    } else if (t.type === "em") {
      Span((t as Tokens.Em).text)
        .fontSize(fontSize)
        .fontStyle(FontStyle.Italic)
        .fontColor(ThemeConstants.TEXT_PRIMARY);
    } else if (t.type === "codespan") {
      Span(` ${(t as Tokens.Codespan).text} `)
        .fontSize(fontSize)
        .fontFamily("Noto Sans Mono")
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .textBackgroundStyle({
          color: ThemeConstants.BG_SUB,
          radius: ThemeConstants.RADIUS_SM,
        });
    } else if (t.type === "link") {
      if (_memberNameFromLink(t as Tokens.Link)) {
        Span(_memberLinkText(t as Tokens.Link))
          .fontSize(fontSize)
          .fontColor(ThemeConstants.TEXT_LINK);
      } else {
        Span((t as Tokens.Link).text)
          .fontSize(fontSize)
          .fontColor(ThemeConstants.TEXT_LINK)
          .decoration({ type: TextDecorationType.Underline, color: ThemeConstants.TEXT_LINK });
      }
    } else if (t.type === "del") {
      Span((t as Tokens.Del).text)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .decoration({ type: TextDecorationType.LineThrough });
    } else if (_isInlineImageToken(t)) {
      ImageSpan(_inlineImageRenderUrl(t))
        .width(_inlineImageRenderSize(t, inlineImageSizeRecords, availableWidth).width)
        .height(_inlineImageRenderSize(t, inlineImageSizeRecords, availableWidth).height)
        .objectFit(ImageFit.Contain)
        .verticalAlign(ImageSpanAlignment.CENTER)
        .onComplete((event?: MarkdownImageCompleteEvent) => {
          if (reportImageComplete) {
            reportImageComplete(_inlineImageRenderUrl(t), event);
          }
        })
        .onError((event?: MarkdownImageErrorEvent) => {
          if (reportImageError) {
            reportImageError(_inlineImageRenderUrl(t), event);
          }
        });
    } else {
      // Token union includes Space which has no .text — cast needed
      Span((t as Tokens.Text).text ?? t.raw ?? "")
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_PRIMARY);
    }
  });
}

function buildPlainTextTokenForRender(text: string): Token {
  return {
    type: "text",
    raw: text,
    text: text,
  } as Token;
}

@Component
struct MarkdownTable {
  @Prop tableToken: RenderTableToken;
  @Prop options: MarkdownOptions;
  @Prop inlineImageSizeRecords: InlineImageSizeRecord[] = [];
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ReadingSettings.TEXT_SCALE_DEFAULT;
  @StorageLink(StorageKeys.READING_BASE64_DECODE_MODE) base64DecodeMode: string = ReadingSettings.BASE64_MODE_BADGE;
  @State private tableAvailableWidth: number = 0;
  @State private activeBase64PopupKey: string = "";

  private showBase64Popup(key: string): void {
    this.activeBase64PopupKey = "";
    setTimeout(() => {
      this.activeBase64PopupKey = key;
    }, 20);
  }

  private hideBase64Popup(key: string): void {
    if (this.activeBase64PopupKey === key) {
      this.activeBase64PopupKey = "";
    }
  }

  private updateTableAvailableWidth(value: Area): void {
    this.tableAvailableWidth = _areaWidth(value);
  }

  private bodyFontSize(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_FONT_SIZE, this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_LINE_HEIGHT, this.readingFontSize);
  }

  private columnCount(): number {
    let count = this.tableToken.headers.length;
    for (const row of this.tableToken.rows) {
      count = Math.max(count, row.length);
    }
    return Math.max(1, count);
  }

  private textDisplayUnits(text: string, protectedNoWrap: boolean = false): number {
    const asciiUnit = protectedNoWrap ? TABLE_PROTECTED_ASCII_DISPLAY_UNIT : TABLE_ASCII_DISPLAY_UNIT;
    const numericUnit = protectedNoWrap ? TABLE_PROTECTED_NUMERIC_DISPLAY_UNIT : TABLE_NUMERIC_DISPLAY_UNIT;
    const symbolUnit = protectedNoWrap ? TABLE_PROTECTED_SYMBOL_DISPLAY_UNIT : TABLE_SYMBOL_DISPLAY_UNIT;
    const spaceUnit = protectedNoWrap ? TABLE_PROTECTED_SPACE_DISPLAY_UNIT : TABLE_SPACE_DISPLAY_UNIT;
    const wideUnit = protectedNoWrap ? TABLE_PROTECTED_WIDE_DISPLAY_UNIT : TABLE_WIDE_DISPLAY_UNIT;
    let units = 0;
    for (const char of text) {
      const code = char.charCodeAt(0);
      if (char === " " || char === "\t") {
        units += spaceUnit;
      } else if (code >= 48 && code <= 57) {
        units += numericUnit;
      } else if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
        units += asciiUnit;
      } else if (code >= 0 && code <= 127) {
        units += symbolUnit;
      } else {
        units += wideUnit;
      }
    }
    return units;
  }

  private isProtectedNoWrapCell(cell: RenderTableCell | undefined): boolean {
    if (!cell) {
      return false;
    }
    const text = (cell.text ?? "").trim();
    return /^\d+(?:\.\d+)?%（\s*\d+\s*\/\s*\d+\s*）$/.test(text) ||
      (cell.header === true && /^(?=.{6,16}$)(?=.*[A-Za-z])[A-Za-z][A-Za-z0-9_-]*$/.test(text));
  }

  private shortUnbreakableIntrinsicMinWidth(cell: RenderTableCell | undefined): number {
    if (!cell) {
      return 0;
    }
    const text = (cell.text ?? "").trim();
    if (this.isProtectedNoWrapCell(cell)) {
      const noBreakDisplayText = text.replace(/\s+/g, "");
      return Math.ceil(this.textDisplayUnits(noBreakDisplayText, true) * this.bodyFontSize() + TABLE_CELL_HORIZONTAL_PADDING);
    }
    return 0;
  }

  private cellWidthText(cell: RenderTableCell): string {
    const text = cell.text ?? "";
    const trimmed = text.trim();
    if (/^\d+(?:\.\d+)?%（\s*\d+\s*\/\s*\d+\s*）$/.test(trimmed) ||
      (cell.header === true && /^(?=.{6,16}$)(?=.*[A-Za-z])[A-Za-z][A-Za-z0-9_-]*$/.test(trimmed))) {
      return trimmed.replace(/\s+/g, "");
    }
    return text;
  }

  private cellEstimatedWidth(cell: RenderTableCell | undefined): number {
    if (!cell) {
      return TABLE_CELL_HORIZONTAL_PADDING;
    }
    const text = this.cellWidthText(cell);
    const natural = Math.ceil(this.textDisplayUnits(text) * this.bodyFontSize() + TABLE_CELL_HORIZONTAL_PADDING);
    return Math.max(natural, this.shortUnbreakableIntrinsicMinWidth(cell));
  }

  private naturalColumnWidths(): number[] {
    const widths: number[] = [];
    const count = this.columnCount();
    for (let index = 0; index < count; index++) {
      let width = this.cellEstimatedWidth(this.tableToken.headers[index]);
      for (const row of this.tableToken.rows) {
        width = Math.max(width, this.cellEstimatedWidth(row[index]));
      }
      widths.push(width);
    }
    return widths;
  }

  private columnReadableMinWidths(): number[] {
    const widths: number[] = [];
    const count = this.columnCount();
    for (let index = 0; index < count; index++) {
      let minWidth = Math.max(TABLE_READABLE_MIN_CELL_WIDTH, this.shortUnbreakableIntrinsicMinWidth(this.tableToken.headers[index]));
      for (const row of this.tableToken.rows) {
        minWidth = Math.max(minWidth, this.shortUnbreakableIntrinsicMinWidth(row[index]));
      }
      widths.push(minWidth);
    }
    return widths;
  }

  private visibleCompactMinWidth(): number {
    return Math.ceil(this.bodyFontSize() * 4 + TABLE_CELL_HORIZONTAL_PADDING);
  }

  private longestUnbreakableSegment(text: string): string {
    const segments = (text ?? "").match(/[^\s\u3000]+/g) ?? [];
    let longest = "";
    for (const segment of segments) {
      if (segment.length > longest.length) {
        longest = segment;
      }
    }
    return longest;
  }

  private hardUnbreakableIntrinsicMinWidth(cell: RenderTableCell | undefined): number {
    if (!cell) {
      return 0;
    }
    const longestUnbreakableSegment = this.longestUnbreakableSegment(cell.text ?? "");
    if (longestUnbreakableSegment.length === 0) {
      return 0;
    }
    const isUrlLike = /^https?:\/\//i.test(longestUnbreakableSegment);
    const isHashLike = /^[A-Fa-f0-9]{32,}$/.test(longestUnbreakableSegment);
    const isLongCodeLike = /^[\x21-\x7E]+$/.test(longestUnbreakableSegment) && longestUnbreakableSegment.length >= 48;
    if (!isUrlLike && !isHashLike && !isLongCodeLike) {
      return 0;
    }
    return Math.ceil(this.textDisplayUnits(longestUnbreakableSegment) * this.bodyFontSize() + TABLE_CELL_HORIZONTAL_PADDING);
  }

  private hardUnbreakableColumnMinWidths(): number[] {
    const widths: number[] = [];
    const count = this.columnCount();
    for (let index = 0; index < count; index++) {
      let minWidth = this.hardUnbreakableIntrinsicMinWidth(this.tableToken.headers[index]);
      for (const row of this.tableToken.rows) {
        minWidth = Math.max(minWidth, this.hardUnbreakableIntrinsicMinWidth(row[index]));
      }
      widths.push(minWidth);
    }
    return widths;
  }

  private sumWidths(widths: number[]): number {
    let total = 0;
    for (const width of widths) {
      total += width;
    }
    return total;
  }

  private distributeColumnWidths(baseWidths: number[], targetWidths: number[], availableWidth: number): number[] {
    const allocated = baseWidths.map((width: number) => width);
    let remaining = availableWidth - this.sumWidths(allocated);
    while (remaining > 0) {
      const flexibleIndexes: number[] = [];
      for (let index = 0; index < allocated.length; index++) {
        if (allocated[index] < targetWidths[index]) {
          flexibleIndexes.push(index);
        }
      }
      if (flexibleIndexes.length === 0) {
        break;
      }
      const share = Math.max(1, Math.floor(remaining / flexibleIndexes.length));
      let consumed = 0;
      for (const index of flexibleIndexes) {
        if (remaining <= 0) {
          break;
        }
        const add = Math.min(share, remaining, targetWidths[index] - allocated[index]);
        allocated[index] += add;
        remaining -= add;
        consumed += add;
      }
      if (consumed === 0) {
        break;
      }
    }
    let index = 0;
    while (remaining > 0 && allocated.length > 0) {
      allocated[index] += 1;
      remaining -= 1;
      index = (index + 1) % allocated.length;
    }
    return allocated;
  }

  private allocatedColumnWidths(): number[] {
    const natural = this.naturalColumnWidths();
    const readableMin = this.columnReadableMinWidths();
    let naturalTotal = 0;
    for (const width of natural) {
      naturalTotal += width;
    }
    const availableWidth = this.tableAvailableWidth;
    if (availableWidth <= 0 || naturalTotal <= availableWidth) {
      return natural;
    }

    const readableTotal = this.sumWidths(readableMin);
    const hardUnbreakableColumnMinWidths = this.hardUnbreakableColumnMinWidths();
    const hardUnbreakableTotal = this.sumWidths(hardUnbreakableColumnMinWidths);
    if (hardUnbreakableTotal > availableWidth) {
      return hardUnbreakableColumnMinWidths.map((width: number, index: number) => {
        return Math.max(width, this.visibleCompactMinWidth(), Math.min(readableMin[index], this.visibleCompactMinWidth()));
      });
    }
    if (readableTotal > availableWidth) {
      const compactMin = natural.map((_width: number, index: number) => {
        return Math.max(hardUnbreakableColumnMinWidths[index], Math.min(readableMin[index], this.visibleCompactMinWidth()));
      });
      if (this.sumWidths(compactMin) > availableWidth) {
        return compactMin;
      }
      const compressionCap = Math.floor(availableWidth / Math.max(1, natural.length) * 1.5);
      const compactTargets = natural.map((width: number, index: number) => {
        return Math.max(compactMin[index], Math.min(width, compressionCap));
      });
      return this.distributeColumnWidths(compactMin, compactTargets, availableWidth);
    }

    const compressionCap = Math.floor(availableWidth / Math.max(1, natural.length) * 1.5);
    const cappedTargets = natural.map((width: number, index: number) => {
      if (width <= readableMin[index]) {
        return readableMin[index];
      }
      // Compression allocator cap: derive the waterline from measured available width and column
      // count so one prose-heavy natural column cannot absorb all spare width and hide following
      // protected columns. This is not a product width bucket; natural tables that fit still use
      // their exact content widths above.
      return Math.max(readableMin[index], Math.min(width, compressionCap));
    });
    return this.distributeColumnWidths(readableMin, cappedTargets, availableWidth);
  }

  private columnWidth(index: number): number {
    return this.allocatedColumnWidths()[index] ?? TABLE_READABLE_MIN_CELL_WIDTH;
  }

  private tableMinWidth(): number {
    let width = 0;
    const allocated = this.allocatedColumnWidths();
    for (let index = 0; index < allocated.length; index++) {
      width += allocated[index];
    }
    return width;
  }

  private tableContentWidth(): number {
    return this.tableMinWidth();
  }

  private emptyCell(): RenderTableCell {
    return {
      text: "",
      tokens: [],
    } as RenderTableCell;
  }

  private paddedRow(row: RenderTableCell[]): RenderTableCell[] {
    const cells: RenderTableCell[] = [];
    const count = this.columnCount();
    for (let index = 0; index < count; index++) {
      cells.push(row[index] ?? this.emptyCell());
    }
    return cells;
  }

  private normalizedRows(): RenderTableCell[][] {
    const rows: RenderTableCell[][] = [];
    if (this.tableToken.headers.length > 0) {
      rows.push(this.tableToken.headers);
    }
    for (const row of this.tableToken.rows) {
      rows.push(row);
    }
    return rows;
  }

  private isHeaderRow(index: number): boolean {
    return index === 0 && this.tableToken.headers.length > 0;
  }

  private formatTableCellTextForLayout(text: string): string {
    return (text ?? "").replace(/(\d+(?:\.\d+)?%)（\s*(\d+)\s*\/\s*(\d+)\s*）/g, (_match: string, percent: string, numerator: string, denominator: string): string => {
      return `${percent}\u2060（\u00A0${numerator}/${denominator}\u00A0）`;
    });
  }

  private formattedCellToken(token: Token): Token {
    const originalText = String((token as TokenRecord)["text"] ?? "");
    if (originalText.length === 0) {
      return token;
    }
    const formattedText = this.formatTableCellTextForLayout(originalText);
    if (formattedText === originalText) {
      return token;
    }
    const record = token as TokenRecord;
    const formattedRecord: TokenRecord = {};
    Object.keys(record).forEach((key: string) => {
      formattedRecord[key] = record[key];
    });
    formattedRecord["text"] = formattedText;
    return formattedRecord as Token;
  }

  private cellTokens(cell: RenderTableCell): Token[] {
    const tokens = Array.isArray(cell.tokens) && cell.tokens.length > 0 ? cell.tokens : [buildPlainTextTokenForRender(cell.text)];
    return tokens.map((token: Token) => this.formattedCellToken(token));
  }

  private cellTextAlign(cell: RenderTableCell): TextAlign {
    if (cell.align === "center") {
      return TextAlign.Center;
    }
    if (cell.align === "right") {
      return TextAlign.End;
    }
    return TextAlign.Start;
  }

  @Builder TableCell(cell: RenderTableCell, header: boolean, columnIndex: number, rowIndex: number) {
    if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_BADGE && _tokensContainBase64Decode(this.cellTokens(cell))) {
      SelectableInlineTokenFlow({
        tokens: this.cellTokens(cell),
        fontSize: this.bodyFontSize(),
        fontColor: ThemeConstants.TEXT_PRIMARY,
        fontWeight: header ? FontWeight.Medium : FontWeight.Regular,
        lineHeight: this.bodyLineHeight(),
        textAlign: this.cellTextAlign(cell),
        wordBreak: WordBreak.BREAK_WORD,
        copyOption: CopyOptions.LocalDevice,
        textSelectable: TextSelectableMode.SELECTABLE_FOCUSABLE,
        options: this.options,
        inlineImageSizeRecords: this.inlineImageSizeRecords,
        reportImageComplete: this.reportImageComplete,
        reportImageError: this.reportImageError,
        availableWidth: 0,
        base64DecodeMode: this.base64DecodeMode,
        activeBase64PopupKey: this.activeBase64PopupKey,
        showBase64Popup: (key: string) => { this.showBase64Popup(key); },
        hideBase64Popup: (key: string) => { this.hideBase64Popup(key); },
        base64PopupScope: `table-${rowIndex}-${columnIndex}`,
      })
      .width(this.columnWidth(columnIndex))
      .constraintSize({ minWidth: this.columnWidth(columnIndex), maxWidth: this.columnWidth(columnIndex) })
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS,
      })
      .border({
        width: { right: columnIndex < this.columnCount() - 1 ? 1 : 0 },
        color: TABLE_BORDER_COLOR,
      })
    } else {
      Text() {
        SelectableInlineTokenSpans(
          this.cellTokens(cell),
          this.bodyFontSize(),
          this.options,
          this.inlineImageSizeRecords,
          this.reportImageComplete,
          this.reportImageError,
          0,
          this.base64DecodeMode,
          this.activeBase64PopupKey,
          (key: string) => { this.showBase64Popup(key); },
          (key: string) => { this.hideBase64Popup(key); },
          `table-${rowIndex}-${columnIndex}`,
        );
      }
      .fontSize(this.bodyFontSize())
      .fontWeight(header ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(ThemeConstants.TEXT_PRIMARY)
      .lineHeight(this.bodyLineHeight())
      .textAlign(this.cellTextAlign(cell))
      .width(this.columnWidth(columnIndex))
      .constraintSize({ minWidth: this.columnWidth(columnIndex), maxWidth: this.columnWidth(columnIndex) })
      .wordBreak(WordBreak.BREAK_WORD)
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS,
      })
      .copyOption(CopyOptions.LocalDevice)
      .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
      .border({
        width: { right: columnIndex < this.columnCount() - 1 ? 1 : 0 },
        color: TABLE_BORDER_COLOR,
      });
    }
  }

  build() {
    Scroll() {
      Column() {
        ForEach(this.normalizedRows(), (row: RenderTableCell[], rowIndex: number) => {
          Row() {
            ForEach(this.paddedRow(row), (cell: RenderTableCell, cellIndex: number) => {
              this.TableCell(cell, this.isHeaderRow(rowIndex), cellIndex, rowIndex);
            }, (cell: RenderTableCell, cellIndex: number) => `${rowIndex}-${cellIndex}-${cell.text}`)
          }
          .width(this.tableContentWidth())
          .constraintSize({ minWidth: this.tableContentWidth(), maxWidth: this.tableContentWidth() })
          .alignItems(VerticalAlign.Top)
          .backgroundColor(this.isHeaderRow(rowIndex) ? ThemeConstants.BG_SUB : Color.Transparent)
          .border({
            width: { bottom: 1 },
            color: TABLE_BORDER_COLOR,
          });
        }, (row: RenderTableCell[], rowIndex: number) => `table-row-${rowIndex}-${row.length}`)
      }
      .width(this.tableContentWidth())
      .constraintSize({ minWidth: this.tableContentWidth(), maxWidth: this.tableContentWidth() })
      .border({ width: 1, color: TABLE_BORDER_COLOR })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .clip(true)
    }
    .width("100%")
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateTableAvailableWidth(newValue);
    });
  }
}

@Component
struct MarkdownImageTable {
  @Prop tableToken: ImageTableToken;
  @Prop options: MarkdownOptions;
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;

  private imageUrls(): string[] {
    return (this.tableToken.imageUrls ?? []).filter((url: string) => MediaUrlUtils.imageUrlForRender(url).length > 0);
  }

  private labels(): string[] {
    return this.tableToken.imageLabels ?? [];
  }

  private columnWidth(): string {
    const count = Math.max(1, this.imageUrls().length);
    return `${100 / count}%`;
  }

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.labels().some((label: string) => label.trim().length > 0)) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          ForEach(this.imageUrls(), (_url: string, index: number) => {
            Text(this.labels()[index] ?? "")
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .textAlign(TextAlign.Center)
              .width(this.columnWidth())
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }, (_url: string, index: number) => `label-${index}`)
        }
        .width("100%")
      }
      Row({ space: ThemeConstants.SPACE_SM }) {
        ForEach(this.imageUrls(), (url: string, index: number) => {
          Column() {
            MarkdownAutoImage({
              url: MediaUrlUtils.imageUrlForRender(url),
              options: this.options,
              reportImageComplete: this.reportImageComplete,
              reportImageError: this.reportImageError,
            });
          }
          .width(this.columnWidth())
          .alignItems(HorizontalAlign.Start)
        }, (url: string, index: number) => `${url}-${index}`)
      }
      .width("100%")
      .alignItems(VerticalAlign.Top)
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start)
  }
}

@Component
struct MarkdownAutoImage {
  @Prop url: string = "";
  @Prop options: MarkdownOptions;
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) @Watch('onImageLoadPolicyChanged') autoLoadImages: boolean = true
  @StorageLink(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI) @Watch('onImageLoadPolicyChanged') onlyLoadImagesOnWifi: boolean = false
  @State private loadState: number = 0 // 0: idle, 1: loading, 2: loaded, 3: error
  @State private reloadNonce: number = 0
  @State private networkChecked: boolean = false
  @State private isWifiNetwork: boolean = false
  @State private sourceWidth: number = 0
  @State private sourceHeight: number = 0
  @State private availableWidth: number = 0

  aboutToAppear() {
    this.refreshNetworkState();
    this.syncLoadState();
  }

  onImageLoadPolicyChanged(_propName: string): void {
    this.refreshNetworkState();
    this.syncLoadState();
  }

  private refreshNetworkState(): void {
    if (!this.autoLoadImages || !this.onlyLoadImagesOnWifi) {
      this.networkChecked = true;
      this.isWifiNetwork = false;
      return;
    }
    this.networkChecked = false;
    connection.getDefaultNet()
      .then((netHandle: connection.NetHandle) => connection.getNetCapabilities(netHandle))
      .then((capabilities: connection.NetCapabilities) => {
        const bearerTypes = capabilities.bearerTypes;
        this.isWifiNetwork = Array.isArray(bearerTypes) && bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0;
        this.networkChecked = true;
        this.syncLoadState();
      })
      .catch((_error: Error) => {
        this.isWifiNetwork = false;
        this.networkChecked = true;
        this.syncLoadState();
      });
  }

  private imageLoadingAllowed(): boolean {
    if (!this.autoLoadImages) {
      return false;
    }
    if (!this.onlyLoadImagesOnWifi) {
      return true;
    }
    return this.networkChecked && this.isWifiNetwork;
  }

  private imagePlaceholderText(): string {
    if (!this.autoLoadImages) {
      return "图片自动加载已关闭";
    }
    if (this.onlyLoadImagesOnWifi && !this.networkChecked) {
      return "正在检查网络";
    }
    return "仅 Wi-Fi 时自动加载图片";
  }

  private syncLoadState(): void {
    if (!this.url) {
      this.loadState = 0;
      return;
    }
    if (!this.imageLoadingAllowed()) {
      this.loadState = 0;
      return;
    }
    if (this.loadState === 0) {
      this.loadState = 1;
    }
  }

  private retryLoad(): void {
    if (!this.url || !this.imageLoadingAllowed()) {
      return;
    }
    this.reloadNonce += 1;
    this.loadState = 1;
  }

  private renderedWidth(): Length {
    if (this.sourceWidth > 0 && this.sourceWidth <= 240) {
      return this.sourceWidth;
    }
    return "100%";
  }

  private renderedHeight(): Length {
    if (this.sourceWidth > 0 && this.sourceHeight > 0) {
      if (this.sourceWidth <= 240) {
        return this.sourceHeight;
      }
      const width = this.availableWidth > 0 ? this.availableWidth : 360;
      return Math.max(80, Math.min(1200, width * this.sourceHeight / this.sourceWidth));
    }
    return 160;
  }

  private updateAvailableWidth(value: Area): void {
    if (typeof value.width === 'number') {
      this.availableWidth = value.width;
    } else if (typeof value.width === 'string') {
      const parsed = Number.parseFloat(value.width);
      this.availableWidth = Number.isNaN(parsed) ? 0 : parsed;
    }
  }

  build() {
    if (this.imageLoadingAllowed()) {
      Stack({ alignContent: Alignment.Start }) {
        Image(_appendCacheBust(this.url, this.reloadNonce))
          .width(this.renderedWidth())
          .height(this.renderedHeight())
          .objectFit(ImageFit.Contain)
          .borderRadius(ThemeConstants.RADIUS_SM)
          .onComplete((event?: MarkdownImageCompleteEvent) => {
            if ((event?.loadingStatus ?? 0) === 1) {
              this.sourceWidth = event?.width ?? 0;
              this.sourceHeight = event?.height ?? 0;
              this.loadState = 2;
              if (this.reportImageComplete) {
                this.reportImageComplete(this.url, event);
              }
            }
          })
          .onError((event?: MarkdownImageErrorEvent) => {
            this.loadState = 3;
            if (this.reportImageError) {
              this.reportImageError(this.url, event);
            }
          })
          .onClick(() => {
            const click = this.options?.imageClick as ((url?: string) => void) | undefined;
            if (click) {
              click(this.url);
            }
          });

        if (this.loadState === 1) {
          Row({ space: ThemeConstants.SPACE_SM }) {
            LoadingProgress()
              .width(ThemeConstants.LOADING_SIZE_SMALL)
              .height(ThemeConstants.LOADING_SIZE_SMALL)
            Text('加载中...')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .width('100%')
          .height(160)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor(ThemeConstants.BG_SUB)
          .hitTestBehavior(HitTestMode.Transparent)
        }

        if (this.loadState === 3) {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text('图片加载失败')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
            Text('点击重试')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_LINK)
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .width('100%')
          .height(160)
          .borderRadius(ThemeConstants.RADIUS_SM)
          .backgroundColor(ThemeConstants.BG_SUB)
          .onClick(() => {
            this.retryLoad();
          })
        }
      }
      .width('100%')
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.updateAvailableWidth(newValue);
      })
    } else {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.imagePlaceholderText())
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
        Text('点击预览')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_LINK)
      }
      .padding(ThemeConstants.SPACE_MD)
      .width('100%')
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor(ThemeConstants.BG_SUB)
      .onClick(() => {
        const click = this.options?.imageClick as ((url?: string) => void) | undefined;
        if (click) {
          click(this.url);
        }
      })
    }
  }
}

// Replaces the library's built-in MList which has broken bullet centering.
// Uses Text('•') as the bullet so it shares the same line metrics as the content,
// guaranteeing vertical alignment regardless of fontSize changes.
@Component
struct CustomList {
  @Prop listToken: Tokens.List;
  @Prop options: MarkdownOptions;
  @Prop inlineImageSizeRecords: InlineImageSizeRecord[] = [];
  @Prop contentAvailableWidth: number = 0;
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ReadingSettings.TEXT_SCALE_DEFAULT;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD;

  private bodyFontSize(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_FONT_SIZE, this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_LINE_HEIGHT, this.readingFontSize);
  }

  private blockSpace(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_XS;
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_MD;
    }
    return ThemeConstants.SPACE_SM;
  }

  build() {
    Column({ space: this.blockSpace() }) {
      ForEach(this.listToken.items, (item: Tokens.ListItem, index: number) => {
        Row({ space: ThemeConstants.SPACE_SM }) {
          if (this.listToken.ordered) {
            Text(`${(this.listToken.start as number) + index}.`)
              .fontSize(this.bodyFontSize())
              .lineHeight(this.bodyLineHeight())
              .fontColor(ThemeConstants.TEXT_PRIMARY);
          } else {
            Text("•")
              .fontSize(this.bodyFontSize())
              .lineHeight(this.bodyLineHeight())
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_SECONDARY);
          }
          Column({ space: this.blockSpace() }) {
            ForEach(item.tokens, (child: Token) => {
              if (child.type === "text" || child.type === "paragraph" || child.type === PARAGRAPH_MONO) {
                if (
                  (child as Tokens.Paragraph).tokens &&
                  (child as Tokens.Paragraph).tokens.length > 0
                ) {
                  MarkdownParagraph({
                    paragraphToken: child as Tokens.Paragraph,
                    options: this.options,
                    inlineImageSizeRecords: this.inlineImageSizeRecords,
                    contentAvailableWidth: this.contentAvailableWidth,
                    reportImageComplete: this.reportImageComplete,
                    reportImageError: this.reportImageError,
                  });
                } else {
                  Text(child.text)
                    .fontSize(this.bodyFontSize())
                    .lineHeight(this.bodyLineHeight())
                    .fontColor(ThemeConstants.TEXT_PRIMARY)
                    .width("100%");
                }
              } else if (child.type === LIST_MONO || child.type === "list") {
                CustomList({
                  listToken: child as Tokens.List,
                  options: this.options,
                  inlineImageSizeRecords: this.inlineImageSizeRecords,
                  contentAvailableWidth: this.contentAvailableWidth,
                  reportImageComplete: this.reportImageComplete,
                  reportImageError: this.reportImageError,
                }).padding({
                  left: ThemeConstants.SPACE_SM,
                });
              } else if (child.type === IMAGE_BLOCK_MONO || child.type === "image") {
                MarkdownAutoImage({ url: MediaUrlUtils.imageUrlForRender((child as Tokens.Image).href), options: this.options });
              } else if (child.type === "space") {
                Blank().height(0);
              }
            })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width("100%")
        .alignItems(VerticalAlign.Top);
      })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }
}

// customInlineBuilder callback: handles `codespan` tokens in normal paragraphs
// via StyledString API (the library's default uses plain Text, losing monospace).
function CodeSpanBuilder(tokenItem: Token, params: CustomInlineParams): void {
  if (tokenItem.type === "codespan") {
    let text = ` ${tokenItem.text} `;
    params.inlineTextStyle?.appendStyledString(
      new MutableStyledString(text, [
        {
          start: 0,
          length: text.length,
          styledKey: StyledStringKey.FONT,
          styledValue: new TextStyle({
            fontColor: params.options?.theme?.fontStyle?.fontColor ?? ThemeConstants.TEXT_PRIMARY,
            fontFamily: "Noto Sans Mono",
          }),
        },
        {
          start: 0,
          length: text.length,
          styledKey: StyledStringKey.BACKGROUND_COLOR,
          styledValue: new BackgroundColorStyle({
            color: params.options?.theme?.codeSpan?.backgroundColor ?? ThemeConstants.BG_SUB,
            radius: params.options?.theme?.codeSpan?.borderRadius ?? ThemeConstants.RADIUS_SM,
          }),
        },
      ]),
    );
  }
}
@Component
export struct MarkdownContent {
  @Prop @Watch('onSourceChanged') source: string = "";
  @Prop topMargin: number = ThemeConstants.SPACE_LG;
  onImageClick?: (url: string) => void
  onLinkClick?: (url: string) => void
  onMentionClick?: (username: string) => void
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ReadingSettings.TEXT_SCALE_DEFAULT;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD;
  @StorageLink(StorageKeys.READING_BASE64_DECODE_MODE) base64DecodeMode: string = ReadingSettings.BASE64_MODE_BADGE;
  @StorageLink(StorageKeys.THEME_EFFECTIVE_DARK) themeEffectiveDark: boolean = false;
  @State private tokens: Token[] = [];
  @State private inlineImageSizeRecords: InlineImageSizeRecord[] = [];
  @State private contentAvailableWidth: number = 0;
  @State private activeBase64PopupKey: string = "";

  private showBase64Popup(key: string): void {
    this.activeBase64PopupKey = "";
    setTimeout(() => {
      this.activeBase64PopupKey = key;
    }, 20);
  }

  private hideBase64Popup(key: string): void {
    if (this.activeBase64PopupKey === key) {
      this.activeBase64PopupKey = "";
    }
  }

  aboutToAppear() {
    this.refreshTokens();
  }

  onSourceChanged(_propName: string): void {
    this.inlineImageSizeRecords = [];
    this.refreshTokens();
  }

  private refreshTokens(): void {
    this.tokens = MarkdownContent.processTokens(this.source, this.inlineImageSizeRecords);
  }

  private updateContentAvailableWidth(value: Area): void {
    this.contentAvailableWidth = _areaWidth(value);
  }

  private reportInlineImageComplete(url: string, event?: MarkdownImageCompleteEvent): void {
    if (!url) {
      return;
    }
    const widthPx = event?.width ?? 0;
    const heightPx = event?.height ?? 0;
    this.upsertInlineImageSizeRecord({
      url: url,
      widthPx: widthPx,
      heightPx: heightPx,
    });
  }

  private reportInlineImageError(url: string, _event?: MarkdownImageErrorEvent): void {
    if (!url) {
      return;
    }
    this.upsertInlineImageSizeRecord({
      url: url,
      widthPx: 0,
      heightPx: 0,
    });
  }

  private upsertInlineImageSizeRecord(next: InlineImageSizeRecord): void {
    if (!next.url) {
      return;
    }
    const existing = _findInlineImageSizeRecord(this.inlineImageSizeRecords, next.url);
    if (existing && existing.widthPx === next.widthPx && existing.heightPx === next.heightPx) {
      return;
    }

    const records: InlineImageSizeRecord[] = [];
    for (const record of this.inlineImageSizeRecords) {
      if (record.url !== next.url) {
        records.push(record);
      }
    }
    records.push(next);
    while (records.length > INLINE_IMAGE_SIZE_RECORD_LIMIT) {
      records.shift();
    }
    this.inlineImageSizeRecords = records;
    this.tokens = MarkdownContent.processTokens(this.source, records);
  }

  private bodyFontSize(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_FONT_SIZE, this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_BODY_LINE_HEIGHT, this.readingFontSize);
  }


  private blockSpace(): number {
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return ThemeConstants.SPACE_XS;
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return ThemeConstants.SPACE_MD;
    }
    return ThemeConstants.SPACE_SM;
  }

  private effectiveTopMargin(): number {
    if (this.topMargin <= 0) {
      return 0;
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMPACT) {
      return this.topMargin > ThemeConstants.SPACE_XS ? this.topMargin - ThemeConstants.SPACE_XS : this.topMargin;
    }
    if (this.readingDensity === ReadingSettings.DENSITY_COMFORTABLE) {
      return this.topMargin + ThemeConstants.SPACE_XS;
    }
    return this.topMargin;
  }

  private openLink(url: string): void {
    const normalized = MediaUrlUtils.normalizeUrl(url);
    if (!normalized) {
      return;
    }
    if (this.onLinkClick) {
      this.onLinkClick(normalized);
      return;
    }

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = { action: "ohos.want.action.viewData", uri: normalized };
      context.startAbility(want)
        .catch((error: Error) => {
          promptAction.openToast({ message: error.message || "打开失败" }).catch((_error: Error) => { });
        });
    } catch (error) {
      promptAction.openToast({ message: (error as Error).message || "打开失败" }).catch((_error: Error) => { });
    }
  }

  // Boundary for @lidary/markdown:
  // - rendered HTML must be parsed directly by renderedHtmlToTokens(); never
  //   convert V2EX content_rendered into Markdown just to feed lexer(). That
  //   loses DOM structure and revives the inline/block image bugs this file is
  //   trying to remove.
  // - lexer() is only a fallback Markdown parser. Its output is immediately
  //   normalized into V2Next-controlled tokens before rendering decisions.
  // - layout decisions, especially image inline-vs-block placement, must follow
  //   the source structure / Markdown semantics, not image intrinsic size and
  //   not @lidary/markdown custom builder behavior.
  private static processTokens(md: string, sizeRecords: InlineImageSizeRecord[] = []): Token[] {
    let tokens: Token[];
    let sourceKind: RenderSourceKind;
    const decodedSource = HtmlEntityUtils.decode(md || '');
    if (MarkdownContent.looksLikeRenderedHtml(decodedSource)) {
      sourceKind = "renderedHtml";
      tokens = MarkdownContent.parseRenderedHtmlToRenderAst(decodedSource, sizeRecords);
    } else {
      sourceKind = "markdown";
      tokens = MarkdownContent.parseMarkdownToRenderAst(decodedSource, sizeRecords);
    }
    MarkdownContent.rewriteImageTableMarkers(tokens);
    MarkdownContent.rewriteBareImageLinks(tokens);
    MarkdownContent.rewriteInlineImageLinks(tokens);
    MarkdownContent.enhanceBase64TextTokens(tokens);
    MarkdownContent.splitResolvedWideInlineImages(tokens, sizeRecords);
    // Keep mixed text/image paragraphs as a single ordered token stream.
    // Splitting them into adjacent top-level custom blocks lets @lidary/markdown
    // reorder custom builders in practice (e.g. image rendered before preceding
    // text). MarkdownParagraph renders inline tokens itself and preserves order.
    MarkdownContent.promoteStandaloneImageParagraphs(tokens);
    MarkdownContent.rewriteStandaloneTextLinks(tokens);
    MarkdownContent.removeIgnorableLayoutTokens(tokens);
    MarkdownContent.mergeSelectableParagraphRuns(tokens);
    MarkdownContent.retypeBlockTokens(tokens);
    MarkdownContent.tagRenderSourceKind(tokens as RenderToken[], sourceKind);
    return tokens;
  }

  private static parseMarkdownToRenderAst(source: string, _sizeRecords: InlineImageSizeRecord[] = []): RenderToken[] {
    const tokens = lexer(MarkdownContent.normalizeMarkdownSource(source), { gfm: true, breaks: true }) as RenderToken[];
    MarkdownContent.normalizeMarkdownTableTokens(tokens);
    MarkdownContent.normalizeCodeBlockTokens(tokens);
    MarkdownContent.tagRenderSourceKind(tokens, "markdown");
    return tokens;
  }

  private static parseRenderedHtmlToRenderAst(contentRendered: string, sizeRecords: InlineImageSizeRecord[] = []): RenderToken[] {
    const tokens = MarkdownContent.renderedHtmlToTokens(contentRendered, sizeRecords) as RenderToken[];
    MarkdownContent.tagRenderSourceKind(tokens, "renderedHtml");
    return tokens;
  }

  private static tagRenderSourceKind(tokens: RenderToken[], sourceKind: RenderSourceKind): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (const token of tokens) {
      const record = token as TokenRecord;
      record["rawSourceKind"] = sourceKind;
      const childTokens = record["tokens"] as RenderToken[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.tagRenderSourceKind(childTokens, sourceKind);
      }
      const items = record["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          item["rawSourceKind"] = sourceKind;
          const itemTokens = item["tokens"] as RenderToken[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.tagRenderSourceKind(itemTokens, sourceKind);
          }
        }
      }
    }
  }

  private static renderedHtmlToTokens(html: string, sizeRecords: InlineImageSizeRecord[] = []): Token[] {
    const source = MarkdownContent.stripRenderedHtmlWrapper(html || '')
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n');
    const tokens: Token[] = [];
    const blockRe = /<(table|h[1-6]|p|ul|ol|blockquote|pre|div)\b[^>]*>([\s\S]*?)<\/\1>/gi;
    let last = 0;
    let match: RegExpExecArray | null = blockRe.exec(source);
    while (match) {
      if (match.index > last) {
        MarkdownContent.pushInlineParagraphToken(tokens, source.slice(last, match.index), sizeRecords);
      }
      tokens.push(...MarkdownContent.htmlBlockToTokens(match[1].toLowerCase(), match[0], match[2], sizeRecords));
      last = blockRe.lastIndex;
      match = blockRe.exec(source);
    }
    if (last < source.length) {
      MarkdownContent.pushInlineParagraphToken(tokens, source.slice(last), sizeRecords);
    }
    if (tokens.length === 0) {
      MarkdownContent.pushInlineParagraphToken(tokens, source, sizeRecords);
    }
    return tokens;
  }

  private static stripRenderedHtmlWrapper(html: string): string {
    let source = (html || '').trim();
    source = source.replace(/^<div\b[^>]*class=(["'])[^"']*markdown_body[^"']*\1[^>]*>/i, '');
    source = source.replace(/<\/div>\s*$/i, '');
    return source;
  }

  private static htmlBlockToTokens(tag: string, raw: string, body: string, sizeRecords: InlineImageSizeRecord[] = []): Token[] {
    if (tag === 'table') {
      const imageUrls = MarkdownContent.extractImageUrlsFromHtml(raw);
      if (imageUrls.length > 0) {
        const tableToken = MarkdownContent.parseImageTableMarker(MarkdownContent.buildImageTableMarker(imageUrls, MarkdownContent.extractTableHeaderLabels(raw)).trim());
        return tableToken ? [tableToken as Token] : [];
      }
      const tableToken = MarkdownContent.htmlTableToRenderTableToken(raw, sizeRecords);
      return tableToken ? [tableToken as Token] : [];
    }
    if (/^h[1-6]$/.test(tag)) {
      const depth = Number(tag.slice(1));
      return [{
        type: 'heading',
        raw: raw,
        depth: depth,
        text: MarkdownContent.stripHtmlTags(body),
        tokens: MarkdownContent.inlineHtmlToTokens(body, sizeRecords),
      } as Token];
    }
    if (tag === 'ul' || tag === 'ol') {
      return [MarkdownContent.htmlListToToken(raw, tag === 'ol', sizeRecords) as Token];
    }
    if (tag === 'blockquote') {
      return [{
        type: 'blockquote',
        raw: raw,
        text: MarkdownContent.stripHtmlTags(body),
        tokens: MarkdownContent.renderedHtmlToTokens(body, sizeRecords),
      } as Token];
    }
    if (tag === 'pre') {
      return [MarkdownContent.buildCodeBlockToken(
        MarkdownContent.extractPreCodeTextFromRenderedHtml(body),
        MarkdownContent.extractPreCodeLanguageFromRenderedHtml(raw, body),
        raw,
      ) as Token];
    }
    if (tag === 'div' && /<(?:table|h[1-6]|p|ul|ol|blockquote|pre)\b/i.test(body)) {
      return MarkdownContent.renderedHtmlToTokens(body, sizeRecords);
    }
    const paragraph = MarkdownContent.inlineHtmlToParagraph(body, raw, sizeRecords);
    return paragraph ? [paragraph as Token] : [];
  }

  private static htmlTableToRenderTableToken(raw: string, sizeRecords: InlineImageSizeRecord[] = []): RenderTableToken | null {
    const allRows: RenderTableCell[][] = [];
    const headerRows: RenderTableCell[][] = [];
    const bodyRows: RenderTableCell[][] = [];
    const rowRe = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
    let rowMatch: RegExpExecArray | null = rowRe.exec(raw || '');
    while (rowMatch) {
      const rowHtml = rowMatch[1] || '';
      const cells: RenderTableCell[] = [];
      let rowIsHeader = false;
      const cellRe = /<(th|td)\b([^>]*)>([\s\S]*?)<\/\1>/gi;
      let cellMatch: RegExpExecArray | null = cellRe.exec(rowHtml);
      while (cellMatch) {
        const tag = (cellMatch[1] || '').toLowerCase();
        const attrs = cellMatch[2] || '';
        const cellHtml = cellMatch[3] || '';
        const isHeader = tag === 'th';
        if (isHeader) {
          rowIsHeader = true;
        }
        cells.push(MarkdownContent.htmlTableCellToRenderCell(cellHtml, attrs, isHeader, sizeRecords));
        cellMatch = cellRe.exec(rowHtml);
      }
      if (cells.length > 0) {
        allRows.push(cells);
        const rowPrefix = (raw || '').slice(0, rowMatch.index);
        if (rowIsHeader || /<thead\b[^>]*>[\s\S]*$/i.test(rowPrefix) && !/<\/thead>[\s\S]*$/i.test(rowPrefix)) {
          headerRows.push(cells.map((cell: RenderTableCell): RenderTableCell => MarkdownContent.withTableCellHeader(cell, true)));
        } else {
          bodyRows.push(cells);
        }
      }
      rowMatch = rowRe.exec(raw || '');
    }
    if (allRows.length === 0) {
      return null;
    }
    let headers: RenderTableCell[] = headerRows.length > 0 ? headerRows[0] : [];
    let rows: RenderTableCell[][] = bodyRows;
    if (headers.length === 0 && allRows.length > 1 && allRows[0].some((cell: RenderTableCell): boolean => cell.header === true)) {
      headers = allRows[0].map((cell: RenderTableCell): RenderTableCell => MarkdownContent.withTableCellHeader(cell, true));
      rows = allRows.slice(1);
    } else if (headers.length === 0 && rows.length === 0) {
      rows = allRows;
    }
    return {
      type: 'table',
      raw: raw,
      headers: headers,
      rows: rows,
    } as RenderTableToken;
  }

  private static htmlTableCellToRenderCell(cellHtml: string, attrs: string, header: boolean, sizeRecords: InlineImageSizeRecord[] = []): RenderTableCell {
    const inlineTokens = MarkdownContent.inlineHtmlToTokens(cellHtml, sizeRecords);
    const text = inlineTokens.map((token: Token): string => String((token as TokenRecord)["text"] ?? (token as TokenRecord)["href"] ?? (token as TokenRecord)["raw"] ?? '')).join('');
    return {
      raw: cellHtml,
      text: text,
      tokens: inlineTokens,
      align: MarkdownContent.htmlTableCellAlign(attrs),
      header: header,
    } as RenderTableCell;
  }

  private static htmlTableCellAlign(attrs: string): string {
    const align = MarkdownContent.htmlAttr(attrs || '', 'align').toLowerCase();
    if (align === 'center' || align === 'right' || align === 'left') {
      return align;
    }
    return '';
  }

  private static withTableCellHeader(cell: RenderTableCell, header: boolean): RenderTableCell {
    return {
      raw: cell.raw,
      text: cell.text,
      tokens: cell.tokens,
      align: cell.align,
      header: header,
    } as RenderTableCell;
  }

  private static htmlListToToken(listHtml: string, ordered: boolean, sizeRecords: InlineImageSizeRecord[] = []): Tokens.List {
    const items: Tokens.ListItem[] = [];
    const itemRe = /<li\b[^>]*>([\s\S]*?)<\/li>/gi;
    let match: RegExpExecArray | null = itemRe.exec(listHtml || '');
    while (match) {
      const childBlocks = /<(?:ul|ol|p|div|table|h[1-6])\b/i.test(match[1])
        ? MarkdownContent.renderedHtmlToTokens(match[1], sizeRecords)
        : [];
      const paragraph = MarkdownContent.inlineHtmlToParagraph(match[1], match[0], sizeRecords);
      const itemTokens: Token[] = childBlocks.length > 0 ? childBlocks : (paragraph ? [paragraph as Token] : []);
      items.push({
        type: 'list_item',
        raw: match[0],
        task: false,
        checked: undefined,
        loose: false,
        text: MarkdownContent.stripHtmlTags(match[1]),
        tokens: itemTokens,
      } as Tokens.ListItem);
      match = itemRe.exec(listHtml || '');
    }
    return {
      type: 'list',
      raw: listHtml,
      ordered: ordered,
      start: 1,
      loose: false,
      items: items,
    } as Tokens.List;
  }

  private static pushInlineParagraphToken(tokens: Token[], html: string, sizeRecords: InlineImageSizeRecord[] = []): void {
    const paragraph = MarkdownContent.inlineHtmlToParagraph(html, html, sizeRecords);
    if (paragraph) {
      tokens.push(paragraph as Token);
    }
  }

  private static inlineHtmlToParagraph(html: string, raw: string, sizeRecords: InlineImageSizeRecord[] = []): Tokens.Paragraph | null {
    const inlineTokens = MarkdownContent.inlineHtmlToTokens(html, sizeRecords);
    if (inlineTokens.length === 0) {
      return null;
    }
    const text = inlineTokens.map((token: Token): string => String((token as TokenRecord)["text"] ?? (token as TokenRecord)["href"] ?? (token as TokenRecord)["raw"] ?? '')).join('');
    return {
      type: 'paragraph',
      raw: raw,
      text: text,
      tokens: inlineTokens,
    } as Tokens.Paragraph;
  }

  private static inlineHtmlToTokens(value: string, _sizeRecords: InlineImageSizeRecord[] = []): Token[] {
    const tokens: Token[] = [];
    const source = value || '';
    const inlineRe = /<a\b[^>]*>[\s\S]*?<\/a>|<img\b[^>]*>|<br\s*\/?>|<code\b[^>]*>[\s\S]*?<\/code>|<(strong|b|em|i)\b[^>]*>[\s\S]*?<\/\1>/gi;
    let last = 0;
    let match: RegExpExecArray | null = inlineRe.exec(source);
    while (match) {
      MarkdownContent.appendHtmlTextToken(tokens, source.slice(last, match.index));
      tokens.push(...MarkdownContent.htmlInlinePartToTokens(match[0]));
      last = inlineRe.lastIndex;
      match = inlineRe.exec(source);
    }
    MarkdownContent.appendHtmlTextToken(tokens, source.slice(last).replace(/<[^>]+>/g, ''));
    MarkdownContent.trimInlineTextEdges(tokens);
    MarkdownContent.markStandaloneInlineImages(tokens);
    return tokens;
  }

  private static htmlInlinePartToTokens(part: string): Token[] {
    if (/^<br/i.test(part)) {
      return [{ type: 'br', raw: part, text: '\n' } as Token];
    }
    if (/^<img/i.test(part)) {
      const src = MarkdownContent.htmlAttr(part, 'src');
      return src ? [MarkdownContent.buildImageToken(part, src, '', true) as Token] : [];
    }
    if (/^<a/i.test(part)) {
      const href = MarkdownContent.htmlAttr(part, 'href');
      const images: Token[] = [];
      const imageRe = /<img\b[^>]*>/gi;
      let imageMatch: RegExpExecArray | null = imageRe.exec(part);
      while (imageMatch) {
        const src = MarkdownContent.htmlAttr(imageMatch[0], 'src') || href;
        if (src) {
          images.push(MarkdownContent.buildImageToken(imageMatch[0], src, '', true) as Token);
        }
        imageMatch = imageRe.exec(part);
      }
      if (images.length > 0) {
        return images;
      }
      const label = MarkdownContent.stripHtmlTags(part);
      if (MarkdownContent.htmlClassContains(part, '__cf_email__')) {
        const decodedEmail = MarkdownContent.decodeCloudflareEmail(MarkdownContent.htmlAttr(part, 'data-cfemail'));
        const text = decodedEmail || label;
        return text ? [MarkdownContent.buildTextToken(text) as Token] : [];
      }
      if (!href) {
        return label ? [MarkdownContent.buildTextToken(label) as Token] : [];
      }
      return [{
        type: 'link',
        raw: part,
        href: href,
        title: null,
        text: label,
        tokens: [MarkdownContent.buildTextToken(label) as Token],
      } as Tokens.Link];
    }
    if (/^<code/i.test(part)) {
      return [{ type: 'codespan', raw: part, text: MarkdownContent.stripHtmlTags(part) } as Tokens.Codespan];
    }
    if (/^<(strong|b)/i.test(part)) {
      const text = MarkdownContent.stripHtmlTags(part);
      return [{ type: 'strong', raw: part, text: text, tokens: [MarkdownContent.buildTextToken(text) as Token] } as Tokens.Strong];
    }
    if (/^<(em|i)/i.test(part)) {
      const text = MarkdownContent.stripHtmlTags(part);
      return [{ type: 'em', raw: part, text: text, tokens: [MarkdownContent.buildTextToken(text) as Token] } as Tokens.Em];
    }
    return [];
  }

  private static appendHtmlTextToken(tokens: Token[], text: string): void {
    const clean = HtmlEntityUtils.decode(text || '').replace(/[ \t\f\v\r\n]+/g, ' ');
    if (!clean) {
      return;
    }
    const inlineTokens = MarkdownContent.parseMarkdownInlineTextTokens(clean);
    for (const token of inlineTokens) {
      const record = token as TokenRecord;
      const last = tokens.length > 0 ? tokens[tokens.length - 1] as TokenRecord : null;
      if (record["type"] === 'text' && last && last["type"] === 'text') {
        last["text"] = String(last["text"] ?? '') + String(record["text"] ?? '');
        last["raw"] = String(last["raw"] ?? '') + String(record["raw"] ?? record["text"] ?? '');
      } else {
        tokens.push(token);
      }
    }
  }

  private static parseMarkdownInlineTextTokens(text: string): Token[] {
    const result: Token[] = [];
    const source = text || '';
    const re = /\[([^\]\n]+)\]\(\s*(https?:\/\/[^\s)]+)\s*\)|\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`/g;
    let last = 0;
    let match: RegExpExecArray | null = re.exec(source);
    while (match) {
      if (match.index > last) {
        result.push(MarkdownContent.buildTextToken(source.slice(last, match.index)) as Token);
      }
      if (match[2]) {
        const label = match[1] || '';
        const href = match[2] || '';
        result.push({
          type: 'link',
          raw: match[0],
          href: href,
          title: null,
          text: label,
          tokens: [MarkdownContent.buildTextToken(label) as Token],
        } as Tokens.Link);
      } else if (match[3]) {
        const value = match[3] || '';
        result.push({ type: 'strong', raw: match[0], text: value, tokens: [MarkdownContent.buildTextToken(value) as Token] } as Tokens.Strong);
      } else if (match[4]) {
        const value = match[4] || '';
        result.push({ type: 'em', raw: match[0], text: value, tokens: [MarkdownContent.buildTextToken(value) as Token] } as Tokens.Em);
      } else if (match[5]) {
        result.push({ type: 'codespan', raw: match[0], text: match[5] || '' } as Tokens.Codespan);
      }
      last = match.index + match[0].length;
      match = re.exec(source);
    }
    if (last === 0) {
      return [MarkdownContent.buildTextToken(source) as Token];
    }
    if (last < source.length) {
      result.push(MarkdownContent.buildTextToken(source.slice(last)) as Token);
    }
    return result;
  }

  private static trimInlineTextEdges(tokens: Token[]): void {
    while (tokens.length > 0) {
      const first = tokens[0] as TokenRecord;
      if (first["type"] !== 'text' || String(first["text"] ?? '').trim().length > 0) {
        break;
      }
      tokens.shift();
    }
    while (tokens.length > 0) {
      const last = tokens[tokens.length - 1] as TokenRecord;
      if (last["type"] !== 'text' || String(last["text"] ?? '').trim().length > 0) {
        break;
      }
      tokens.pop();
    }
    if (tokens.length > 0 && (tokens[0] as TokenRecord)["type"] === 'text') {
      const first = tokens[0] as TokenRecord;
      const trimmed = String(first["text"] ?? '').replace(/^\s+/, '');
      first["text"] = trimmed;
      first["raw"] = trimmed;
    }
    if (tokens.length > 0 && (tokens[tokens.length - 1] as TokenRecord)["type"] === 'text') {
      const last = tokens[tokens.length - 1] as TokenRecord;
      const trimmed = String(last["text"] ?? '').replace(/\s+$/, '');
      last["text"] = trimmed;
      last["raw"] = trimmed;
    }
    MarkdownContent.removeLeadingMentionTextBeforeMemberLink(tokens);
  }

  private static removeLeadingMentionTextBeforeMemberLink(tokens: Token[]): void {
    for (let i = 1; i < tokens.length; i++) {
      const current = tokens[i] as TokenRecord;
      const previous = tokens[i - 1] as TokenRecord;
      if (current["type"] !== 'link' || previous["type"] !== 'text') {
        continue;
      }
      const href = String(current["href"] ?? '');
      if (!/^\/member\/[^?#/]+(?:[?#].*)?$/i.test(href) && !/^https?:\/\/(?:www\.)?v2ex\.(?:com|co)\/member\/[^?#/]+/i.test(href)) {
        continue;
      }
      const text = String(previous["text"] ?? '');
      const stripped = text.replace(/@\s*$/, '');
      if (stripped !== text) {
        previous["text"] = stripped;
        previous["raw"] = stripped;
      }
    }
    for (let i = tokens.length - 1; i >= 0; i--) {
      const token = tokens[i] as TokenRecord;
      if (token["type"] === 'text' && String(token["text"] ?? '').length === 0) {
        tokens.splice(i, 1);
      }
    }
  }

  private static normalizeMarkdownTableTokens(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      if (token["type"] === "table") {
        const tableToken = MarkdownContent.normalizeMarkdownTableToken(tokens[i]);
        if (tableToken) {
          tokens[i] = tableToken as Token;
        }
        continue;
      }
      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.normalizeMarkdownTableTokens(childTokens);
      }
    }
  }

  private static normalizeMarkdownTableToken(token: Token): RenderTableToken | null {
    const record = token as TokenRecord;
    const headers: RenderTableCell[] = [];
    const headerValues = record["header"] as TokenRecord[] | undefined;
    if (Array.isArray(headerValues)) {
      for (const cell of headerValues) {
        headers.push(MarkdownContent.markdownTableCellToRenderCell(cell, true));
      }
    }
    const rows: RenderTableCell[][] = [];
    const rowValues = record["rows"] as Array<TokenRecord[]> | undefined;
    if (Array.isArray(rowValues)) {
      for (const row of rowValues) {
        if (!Array.isArray(row)) {
          continue;
        }
        const cells: RenderTableCell[] = [];
        for (const cell of row) {
          cells.push(MarkdownContent.markdownTableCellToRenderCell(cell, false));
        }
        rows.push(cells);
      }
    }
    if (headers.length === 0 && rows.length === 0) {
      return MarkdownContent.markdownTableRawToRenderTableToken(String(record["raw"] ?? ''));
    }
    return {
      type: 'table',
      raw: String(record["raw"] ?? ''),
      headers: headers,
      rows: rows,
    } as RenderTableToken;
  }

  private static markdownTableCellToRenderCell(cell: TokenRecord, header: boolean): RenderTableCell {
    const text = String(cell["text"] ?? cell["raw"] ?? '');
    const tokens = cell["tokens"] as Token[] | undefined;
    return {
      raw: String(cell["raw"] ?? text),
      text: text,
      tokens: Array.isArray(tokens) && tokens.length > 0 ? tokens : MarkdownContent.parseMarkdownInlineTextTokens(text),
      align: String(cell["align"] ?? ''),
      header: header,
    } as RenderTableCell;
  }

  private static markdownTableRawToRenderTableToken(raw: string): RenderTableToken | null {
    const lines = (raw || '').split('\n').map((line: string): string => line.trim()).filter((line: string): boolean => line.length > 0);
    if (lines.length < 2 || !MarkdownContent.isMarkdownTableSeparator(lines[1])) {
      return null;
    }
    const headers = MarkdownContent.markdownTableCells(lines[0]).map((cell: string): RenderTableCell => MarkdownContent.markdownRawCellToRenderCell(cell, true));
    const rows: RenderTableCell[][] = [];
    for (let i = 2; i < lines.length; i++) {
      const cells = MarkdownContent.markdownTableCells(lines[i]);
      if (cells.length === 0) {
        continue;
      }
      rows.push(cells.map((cell: string): RenderTableCell => MarkdownContent.markdownRawCellToRenderCell(cell, false)));
    }
    return {
      type: 'table',
      raw: raw,
      headers: headers,
      rows: rows,
    } as RenderTableToken;
  }

  private static markdownRawCellToRenderCell(raw: string, header: boolean): RenderTableCell {
    const text = (raw || '').trim().replace(/\\\|/g, '|');
    return {
      raw: raw,
      text: text,
      tokens: MarkdownContent.parseMarkdownInlineTextTokens(text),
      align: '',
      header: header,
    } as RenderTableCell;
  }

  private static normalizeMarkdownSource(md: string): string {
    let source = md || '';
    if (MarkdownContent.looksLikeRenderedHtml(source)) {
      source = MarkdownContent.renderedHtmlToMarkdown(source);
    }
    source = source.replace(/<table\b[^>]*>[\s\S]*?<\/table>/gi, (table: string): string => {
      return MarkdownContent.convertImageTableToMarkdownImages(table);
    });
    source = source
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .replace(/<a\b[^>]*>\s*<img\b[^>]*\bsrc=(["'])(https?:\/\/[^"']+)\1[^>]*>\s*<\/a>/gi, '$2')
      .replace(/<img\b[^>]*\bsrc=(["'])(https?:\/\/[^"']+)\1[^>]*>/gi, '$2')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/(^|\n)[ \t]*(https?:\/\/[^\s<>()]+)[ \t]*(?=\n|$)/gi,
        (_all: string, prefix: string, url: string): string => {
          const renderUrl = MediaUrlUtils.imageUrlForRender(url);
          return renderUrl ? `${prefix}\n${renderUrl}\n` : `${prefix}${url}`;
        })
      .replace(/<\/?(?:table|tbody|thead|tr|td|th)\b[^>]*>/gi, '\n\n')
      .replace(/^[ \t]+(https?:\/\/[^\s<>()]+)[ \t]*$/gmi, '$1')
      .replace(/\n{3,}/g, '\n\n')
      .replace(/\]\(\s+(https?:\/\/[^\s)]+)\s*\)/gi, ']($1)');
    return MarkdownContent.convertMarkdownImageTables(source);
  }

  private static looksLikeRenderedHtml(source: string): boolean {
    const value = (source || '').trim();
    return /<(?:div|p|h[1-6]|ul|ol|li|table|img|a|pre|code)\b/i.test(value);
  }

  private static renderedHtmlToMarkdown(html: string): string {
    let md = (html || '')
      .replace(/\r\n/g, '\n')
      .replace(/<table\b[^>]*>[\s\S]*?<\/table>/gi, (table: string): string => {
        return MarkdownContent.convertHtmlTable(table);
      })
      .replace(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1>/gi, (_all: string, level: string, text: string): string => {
        return `\n\n${MarkdownContent.headingPrefix(Number(level))} ${MarkdownContent.stripHtmlTags(text)}\n\n`;
      })
      .replace(/<ol\b[^>]*>([\s\S]*?)<\/ol>/gi, (_all: string, body: string): string => {
        return MarkdownContent.convertHtmlList(body, true);
      })
      .replace(/<ul\b[^>]*>([\s\S]*?)<\/ul>/gi, (_all: string, body: string): string => {
        return MarkdownContent.convertHtmlList(body, false);
      })
      .replace(/<p\b[^>]*>([\s\S]*?)<\/p>/gi, (_all: string, text: string): string => {
        const inline = MarkdownContent.inlineHtmlToMarkdown(text).trim();
        return inline ? `\n\n${inline}\n\n` : '\n\n';
      })
      .replace(/<div\b[^>]*>/gi, '\n\n')
      .replace(/<\/div>/gi, '\n\n')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<img\b[^>]*>/gi, (tag: string): string => MarkdownContent.inlineHtmlToMarkdown(tag))
      .replace(/<[^>]+>/g, '');
    return HtmlEntityUtils.decode(md)
      .replace(/^[ \t]+(https?:\/\/[^\s<>()]+)[ \t]*$/gmi, '$1')
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  private static headingPrefix(level: number): string {
    let prefix = '';
    const count = Math.max(1, Math.min(6, level));
    for (let i = 0; i < count; i++) {
      prefix += '#';
    }
    return prefix;
  }

  private static convertMarkdownImageTables(source: string): string {
    const lines = (source || '').split('\n');
    const out: string[] = [];
    let i = 0;
    while (i < lines.length) {
      if (i + 2 < lines.length && MarkdownContent.isMarkdownTableSeparator(lines[i + 1])) {
        const labels = MarkdownContent.markdownTableCells(lines[i]).map((cell: string): string => cell.trim());
        const imageUrls: string[] = [];
        let end = i + 2;
        while (end < lines.length && MarkdownContent.markdownTableCells(lines[end]).length > 0) {
          const cells = MarkdownContent.markdownTableCells(lines[end]);
          for (const cell of cells) {
            const url = MarkdownContent.firstMarkdownImageUrl(cell);
            if (url) {
              imageUrls.push(url);
            }
          }
          end++;
        }
        if (imageUrls.length > 0) {
          out.push(MarkdownContent.buildImageTableMarker(imageUrls, labels));
          i = end;
          continue;
        }
      }
      out.push(lines[i]);
      i++;
    }
    return out.join('\n');
  }

  private static markdownTableCells(line: string): string[] {
    const value = (line || '').trim();
    if (!value.startsWith('|') || !value.endsWith('|')) {
      return [];
    }
    const inner = value.substring(1, value.length - 1);
    return inner.split('|');
  }

  private static isMarkdownTableSeparator(line: string): boolean {
    const cells = MarkdownContent.markdownTableCells(line);
    if (cells.length === 0) {
      return false;
    }
    return cells.every((cell: string): boolean => /^\s*:?-{3,}:?\s*$/.test(cell));
  }

  private static firstMarkdownImageUrl(cell: string): string {
    const match = /!\[[^\]]*\]\(\s*(https?:\/\/[^\s)]+)\s*\)/i.exec(cell || '');
    if (!match || !match[1]) {
      return '';
    }
    return MediaUrlUtils.imageUrlForRender(match[1]) || '';
  }

  private static convertHtmlList(listHtml: string, ordered: boolean): string {
    const items: string[] = [];
    const re = /<li\b[^>]*>([\s\S]*?)<\/li>/gi;
    let match: RegExpExecArray | null = re.exec(listHtml);
    while (match) {
      const text = MarkdownContent.inlineHtmlToMarkdown(match[1])
        .replace(/\s*\n\s*/g, ' ')
        .trim();
      if (text.length > 0) {
        items.push(text);
      }
      match = re.exec(listHtml);
    }
    if (items.length === 0) {
      return '\n\n';
    }
    let lines: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const marker = ordered ? `${i + 1}.` : '-';
      lines.push(`${marker} ${items[i]}`);
    }
    return `\n\n${lines.join('\n')}\n\n`;
  }

  private static convertImageTableToMarkdownImages(tableHtml: string): string {
    const imageUrls = MarkdownContent.extractImageUrlsFromHtml(tableHtml);
    if (imageUrls.length === 0) {
      return tableHtml;
    }
    const labels = MarkdownContent.extractTableHeaderLabels(tableHtml);
    return MarkdownContent.buildImageTableMarker(imageUrls, labels);
  }

  private static convertHtmlTable(tableHtml: string): string {
    const imageUrls = MarkdownContent.extractImageUrlsFromHtml(tableHtml);
    if (imageUrls.length > 0) {
      const labels = MarkdownContent.extractTableHeaderLabels(tableHtml);
      return MarkdownContent.buildImageTableMarker(imageUrls, labels);
    }

    const rows: string[][] = [];
    const rowRe = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
    let rowMatch: RegExpExecArray | null = rowRe.exec(tableHtml);
    while (rowMatch) {
      const cells: string[] = [];
      const cellRe = /<t[hd]\b[^>]*>([\s\S]*?)<\/t[hd]>/gi;
      let cellMatch: RegExpExecArray | null = cellRe.exec(rowMatch[1]);
      while (cellMatch) {
        cells.push(MarkdownContent.inlineHtmlToMarkdown(cellMatch[1])
          .replace(/\s*\n\s*/g, ' ')
          .replace(/\|/g, '\\|')
          .trim());
        cellMatch = cellRe.exec(rowMatch[1]);
      }
      if (cells.length > 0) {
        rows.push(cells);
      }
      rowMatch = rowRe.exec(tableHtml);
    }
    if (rows.length === 0) {
      return '\n\n';
    }

    let width = 0;
    for (const row of rows) {
      width = Math.max(width, row.length);
    }
    const lines: string[] = [];
    lines.push(`| ${MarkdownContent.padTableRow(rows[0], width).join(' | ')} |`);
    const divider: string[] = [];
    for (let i = 0; i < width; i++) {
      divider.push('---');
    }
    lines.push(`| ${divider.join(' | ')} |`);
    for (let i = 1; i < rows.length; i++) {
      lines.push(`| ${MarkdownContent.padTableRow(rows[i], width).join(' | ')} |`);
    }
    return `\n\n${lines.join('\n')}\n\n`;
  }

  private static padTableRow(row: string[], width: number): string[] {
    const padded: string[] = [];
    for (let i = 0; i < width; i++) {
      padded.push(row[i] || '');
    }
    return padded;
  }

  private static extractImageUrlsFromHtml(html: string): string[] {
    const urls: string[] = [];
    const re = /<img\b[^>]*>/gi;
    let match: RegExpExecArray | null = re.exec(html || '');
    while (match) {
      const src = MarkdownContent.htmlAttr(match[0], 'src');
      if (src) {
        urls.push(src);
      }
      match = re.exec(html || '');
    }
    return urls;
  }

  private static extractTableHeaderLabels(tableHtml: string): string[] {
    const labels: string[] = [];
    const re = /<th\b[^>]*>([\s\S]*?)<\/th>/gi;
    let match: RegExpExecArray | null = re.exec(tableHtml || '');
    while (match) {
      labels.push(MarkdownContent.stripHtmlTags(match[1]));
      match = re.exec(tableHtml || '');
    }
    return labels;
  }

  private static buildImageTableMarker(imageUrls: string[], labels: string[]): string {
    const lines: string[] = [IMAGE_TABLE_START];
    for (let i = 0; i < imageUrls.length; i++) {
      const label = encodeURIComponent(labels[i] ?? '');
      const url = encodeURIComponent(imageUrls[i] ?? '');
      lines.push(`${label}\t${url}`);
    }
    lines.push(IMAGE_TABLE_END);
    return `\n\n${lines.join('\n')}\n\n`;
  }

  private static enhanceBase64TextTokens(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = String(token["type"] ?? '');
      // Only enhance ordinary visible text. Code blocks, pre/code/codespan and
      // links keep their original semantics and click targets unchanged.
      if (type === 'code' || type === 'codespan' || type === 'link' || type === 'image') {
        continue;
      }
      if (type === 'text') {
        const replacement = MarkdownContent.base64EnhancedTextTokenRun(tokens[i]);
        if (replacement.length > 0) {
          tokens.splice(i, 1, ...replacement);
          i += replacement.length - 1;
        }
        continue;
      }
      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.enhanceBase64TextTokens(childTokens);
      }
      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.enhanceBase64TextTokens(itemTokens);
          }
        }
      }
      const headers = token["headers"] as Array<TokenRecord> | undefined;
      if (Array.isArray(headers) && headers.length > 0) {
        for (const cell of headers) {
          const cellTokens = cell["tokens"] as Token[] | undefined;
          if (Array.isArray(cellTokens) && cellTokens.length > 0) {
            MarkdownContent.enhanceBase64TextTokens(cellTokens);
          }
        }
      }
      const rows = token["rows"] as Array<Array<TokenRecord>> | undefined;
      if (Array.isArray(rows) && rows.length > 0) {
        for (const row of rows) {
          for (const cell of row) {
            const cellTokens = cell["tokens"] as Token[] | undefined;
            if (Array.isArray(cellTokens) && cellTokens.length > 0) {
              MarkdownContent.enhanceBase64TextTokens(cellTokens);
            }
          }
        }
      }
    }
  }

  private static base64EnhancedTextTokenRun(token: Token): Token[] {
    const record = token as TokenRecord;
    const text = String(record["text"] ?? '');
    if (!text || text.length < Base64DecodeUtils.MIN_TOKEN_LENGTH) {
      return [];
    }
    const result: Token[] = [];
    const re = /[A-Za-z0-9+/_=\-]+/g;
    let last = 0;
    let changed = false;
    let match: RegExpExecArray | null = re.exec(text);
    while (match) {
      const candidate = match[0];
      const decoded = Base64DecodeUtils.tryDecodeToken(candidate);
      if (!decoded) {
        match = re.exec(text);
        continue;
      }
      if (match.index > last) {
        result.push(MarkdownContent.buildTextToken(text.slice(last, match.index)) as Token);
      }
      result.push(MarkdownContent.buildTextToken(candidate) as Token);
      result.push({
        type: 'base64Decode',
        raw: candidate,
        text: '',
        original: decoded.original,
        decoded: decoded.decoded,
      } as Base64DecodeToken);
      last = match.index + candidate.length;
      changed = true;
      match = re.exec(text);
    }
    if (!changed) {
      return [];
    }
    if (last < text.length) {
      result.push(MarkdownContent.buildTextToken(text.slice(last)) as Token);
    }
    return result;
  }

  private static rewriteImageTableMarkers(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      if (token["type"] === "paragraph") {
        const tableToken = MarkdownContent.parseImageTableMarker(String(token["text"] ?? token["raw"] ?? ''));
        if (tableToken) {
          tokens.splice(i, 1, tableToken as Token);
          continue;
        }
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.rewriteImageTableMarkers(childTokens);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.rewriteImageTableMarkers(itemTokens);
          }
        }
      }
    }
  }

  private static parseImageTableMarker(text: string): ImageTableToken | null {
    const clean = (text || '').trim();
    if (!clean.startsWith(IMAGE_TABLE_START) || !clean.endsWith(IMAGE_TABLE_END)) {
      return null;
    }
    const lines = clean.split('\n').map((line: string): string => line.trim()).filter((line: string): boolean => line.length > 0);
    const urls: string[] = [];
    const labels: string[] = [];
    for (const line of lines) {
      if (line === IMAGE_TABLE_START || line === IMAGE_TABLE_END) {
        continue;
      }
      const parts = line.split('\t');
      const label = parts.length > 1 ? parts[0] : '';
      const url = parts.length > 1 ? parts[1] : parts[0];
      try {
        labels.push(decodeURIComponent(label || ''));
        urls.push(decodeURIComponent(url || ''));
      } catch (_error) {
        labels.push(label || '');
        urls.push(url || '');
      }
    }
    if (urls.length === 0) {
      return null;
    }
    return {
      type: IMAGE_TABLE_MONO,
      raw: text,
      imageUrls: urls,
      imageLabels: labels,
    } as ImageTableToken;
  }

  private static inlineHtmlToMarkdown(value: string): string {
    return (value || '')
      .replace(/<a\b[^>]*href=(["'])(.*?)\1[^>]*>\s*(<img\b[^>]*>)\s*<\/a>/gi,
        (_all: string, _quote: string, href: string, imgTag: string): string => {
          const src = MarkdownContent.htmlAttr(imgTag, 'src') || HtmlEntityUtils.decode(href).trim();
          return src ? ` ${src} ` : '';
        })
      .replace(/<img\b[^>]*>/gi, (tag: string): string => {
        const src = MarkdownContent.htmlAttr(tag, 'src');
        return src ? ` ${src} ` : '';
      })
      .replace(/<a\b[^>]*href=(["'])(.*?)\1[^>]*>([\s\S]*?)<\/a>/gi,
        (_all: string, _quote: string, href: string, text: string): string => {
          const label = MarkdownContent.stripHtmlTags(text);
          const url = HtmlEntityUtils.decode(href).trim();
          if (!url) {
            return label;
          }
          return label && label !== url ? `[${label}](${url})` : url;
        })
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<code\b[^>]*>([\s\S]*?)<\/code>/gi, (_all: string, code: string): string => {
        return `\`${MarkdownContent.stripHtmlTags(code)}\``;
      })
      .replace(/<(strong|b)\b[^>]*>([\s\S]*?)<\/\1>/gi, (_all: string, _tag: string, text: string): string => {
        return `**${MarkdownContent.stripHtmlTags(text)}**`;
      })
      .replace(/<(em|i)\b[^>]*>([\s\S]*?)<\/\1>/gi, (_all: string, _tag: string, text: string): string => {
        return `*${MarkdownContent.stripHtmlTags(text)}*`;
      })
      .replace(/<[^>]+>/g, '');
  }

  private static normalizeCodeBlockTokens(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      if (token["type"] === 'code') {
        tokens[i] = MarkdownContent.buildCodeBlockToken(
          String(token["text"] ?? ''),
          String(token["lang"] ?? ''),
          String(token["raw"] ?? ''),
        ) as Token;
        continue;
      }
      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.normalizeCodeBlockTokens(childTokens);
      }
      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.normalizeCodeBlockTokens(itemTokens);
          }
        }
      }
    }
  }

  private static buildCodeBlockToken(text: string, lang: string, raw: string): Tokens.Code {
    return {
      type: 'code',
      raw: raw || text,
      text: text || '',
      lang: normalizeCodeLanguage(lang || ''),
    } as Tokens.Code;
  }

  private static extractPreCodeLanguageFromRenderedHtml(raw: string, body: string): string {
    const codeOpen = /^\s*(<code\b[^>]*>)/i.exec(body || '');
    const codeTag = codeOpen ? codeOpen[1] : '';
    const preOpen = /^(<pre\b[^>]*>)/i.exec(raw || '');
    const preTag = preOpen ? preOpen[1] : '';
    return normalizeCodeLanguage(
      MarkdownContent.extractCodeLanguageFromTag(codeTag) ||
        MarkdownContent.extractCodeLanguageFromTag(preTag)
    );
  }

  private static extractCodeLanguageFromTag(tag: string): string {
    if (!tag) {
      return '';
    }
    const dataLanguage = MarkdownContent.htmlAttr(tag, 'data-language');
    if (dataLanguage) {
      return dataLanguage;
    }
    const dataLang = MarkdownContent.htmlAttr(tag, 'data-lang');
    if (dataLang) {
      return dataLang;
    }
    const className = MarkdownContent.htmlAttr(tag, 'class');
    if (className) {
      const language = /(?:^|\s)language-([A-Za-z0-9_+.-]+)/i.exec(className);
      if (language && language[1]) {
        return language[1];
      }
      const lang = /(?:^|\s)lang-([A-Za-z0-9_+.-]+)/i.exec(className);
      if (lang && lang[1]) {
        return lang[1];
      }
      const brush = /(?:^|\s)brush\s*:\s*([A-Za-z0-9_+.-]+)/i.exec(className);
      if (brush && brush[1]) {
        return brush[1];
      }
    }
    return '';
  }

  private static extractPreCodeTextFromRenderedHtml(body: string): string {
    let code = body || '';
    const codeMatch = /^\s*<code\b[^>]*>([\s\S]*?)<\/code>\s*$/i.exec(code);
    if (codeMatch) {
      code = codeMatch[1];
    }
    return HtmlEntityUtils.decode(code)
      .replace(/\r\n/g, '\n')
      .replace(/\r/g, '\n')
      .trim();
  }

  private static stripHtmlTags(value: string): string {
    return HtmlEntityUtils.decode((value || '').replace(/<[^>]+>/g, ''))
      .replace(/[ \t\f\v]+/g, ' ')
      .trim();
  }

  private static htmlAttr(tag: string, name: string): string {
    const re = new RegExp(`(?:^|\\s)${name}\\s*=\\s*(?:(["'])(.*?)\\1|([^\\s"'=<>]+))`, 'i');
    const match = re.exec(tag || '');
    const value = match ? (match[2] || match[3] || '') : '';
    return value ? HtmlEntityUtils.decode(value).trim() : '';
  }

  private static htmlClassContains(tag: string, className: string): boolean {
    const classes = MarkdownContent.htmlAttr(tag, 'class').split(/\s+/);
    for (const value of classes) {
      if (value === className) {
        return true;
      }
    }
    return false;
  }

  private static decodeCloudflareEmail(cfemail: string): string {
    const value = (cfemail || '').trim();
    if (value.length < 4 || value.length % 2 !== 0 || !/^[0-9a-f]+$/i.test(value)) {
      return '';
    }
    const key = Number.parseInt(value.slice(0, 2), 16);
    if (Number.isNaN(key)) {
      return '';
    }
    let result = '';
    for (let i = 2; i < value.length; i += 2) {
      const byteValue = Number.parseInt(value.slice(i, i + 2), 16);
      if (Number.isNaN(byteValue)) {
        return '';
      }
      result += String.fromCharCode(byteValue ^ key);
    }
    return result;
  }

  private static splitMixedImageParagraphs(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      if (type === "paragraph") {
        const replacement = MarkdownContent.splitParagraphByImages(token);
        if (replacement.length > 0) {
          tokens.splice(i, 1, ...replacement);
          i += replacement.length - 1;
          continue;
        }
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.splitMixedImageParagraphs(childTokens);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.splitMixedImageParagraphs(itemTokens);
          }
        }
      }
    }
  }

  private static splitResolvedWideInlineImages(tokens: Token[], sizeRecords: InlineImageSizeRecord[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      if (type === "paragraph") {
        const replacement = MarkdownContent.splitParagraphByResolvedWideInlineImages(token, sizeRecords);
        if (replacement.length > 0) {
          tokens.splice(i, 1, ...replacement);
          i += replacement.length - 1;
          continue;
        }
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.splitResolvedWideInlineImages(childTokens, sizeRecords);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.splitResolvedWideInlineImages(itemTokens, sizeRecords);
          }
        }
      }
    }
  }

  private static splitParagraphByResolvedWideInlineImages(paragraph: TokenRecord, sizeRecords: InlineImageSizeRecord[]): Token[] {
    const inlineTokens = paragraph["tokens"] as Token[] | undefined;
    if (!Array.isArray(inlineTokens) || inlineTokens.length === 0) {
      return [];
    }
    if (!inlineTokens.some((token: Token): boolean => MarkdownContent.shouldFlowInlineImageAsBlock(token, sizeRecords))) {
      return [];
    }
    const result: Token[] = [];
    let textTokens: Token[] = [];
    for (const token of inlineTokens) {
      if (MarkdownContent.shouldFlowInlineImageAsBlock(token, sizeRecords)) {
        MarkdownContent.flushParagraphTokens(result, textTokens);
        textTokens = [];
        (token as InlineImageToken).inlineImage = false;
        result.push({
          type: "paragraph",
          raw: String((token as TokenRecord)["raw"] ?? ""),
          text: String((token as TokenRecord)["text"] ?? ""),
          tokens: [token],
        } as Tokens.Paragraph);
      } else {
        textTokens.push(token);
      }
    }
    MarkdownContent.flushParagraphTokens(result, textTokens);
    return result.length > 1 ? result : [];
  }

  private static shouldFlowInlineImageAsBlock(token: Token, sizeRecords: InlineImageSizeRecord[]): boolean {
    if (!token || token.type !== "image" || !_isInlineImageToken(token)) {
      return false;
    }
    const url = _inlineImageRenderUrl(token);
    const record = _findInlineImageSizeRecord(sizeRecords, url);
    if (!record || record.widthPx <= 0 || record.heightPx <= 0) {
      return false;
    }
    return record.widthPx > 96 || record.heightPx > 48;
  }

  private static splitParagraphByImages(paragraph: TokenRecord): Token[] {
    const inlineTokens = paragraph["tokens"] as Token[] | undefined;
    if (!Array.isArray(inlineTokens) || inlineTokens.length === 0) {
      return [];
    }
    if (!inlineTokens.some((t: Token) => t && t.type === "image" && !_isMixedInlineImageCandidate(t))) {
      return [];
    }

    const hasNonImageText = inlineTokens.some((t: Token) => {
      if (!t || t.type === "image" || t.type === "br") {
        return false;
      }
      const text = ((t as Tokens.Text).text ?? t.raw ?? "").trim();
      return text.length > 0;
    });
    const canKeepImagesInline = inlineTokens
      .filter((t: Token) => t && t.type === "image")
      .every((t: Token) => _isMixedInlineImageCandidate(t));
    if (hasNonImageText && canKeepImagesInline) {
      for (const token of inlineTokens) {
        if (token && token.type === "image") {
          (token as InlineImageToken).inlineImage = true;
        }
      }
      return [];
    }

    const result: Token[] = [];
    let textTokens: Token[] = [];
    for (const token of inlineTokens) {
      if (token && token.type === "image" && _isMixedInlineImageCandidate(token)) {
        (token as InlineImageToken).inlineImage = true;
        textTokens.push(token);
      } else if (token && token.type === "image" && !_isMixedInlineImageCandidate(token)) {
        MarkdownContent.flushParagraphTokens(result, textTokens);
        textTokens = [];
        (token as InlineImageToken).inlineImage = false;
        const imageParagraph: Tokens.Paragraph = {
          type: "paragraph",
          raw: String((token as TokenRecord)["raw"] ?? ""),
          text: String((token as TokenRecord)["text"] ?? ""),
          tokens: [token],
        } as Tokens.Paragraph;
        result.push(imageParagraph);
      } else {
        textTokens.push(token);
      }
    }
    MarkdownContent.flushParagraphTokens(result, textTokens);
    return result.length > 1 ? result : [];
  }

  private static flushParagraphTokens(result: Token[], tokens: Token[]): void {
    const meaningful = tokens.filter((t: Token) => t && t.type !== "br" && String((t as TokenRecord)["raw"] ?? (t as TokenRecord)["text"] ?? "").trim().length > 0);
    if (meaningful.length === 0) {
      return;
    }
    const raw = tokens.map((t: Token) => String((t as TokenRecord)["raw"] ?? (t as TokenRecord)["text"] ?? "")).join("");
    const text = tokens.map((t: Token) => String((t as TokenRecord)["text"] ?? (t as TokenRecord)["raw"] ?? "")).join("");
    result.push({
      type: "paragraph",
      raw: raw,
      text: text,
      tokens: tokens,
    } as Tokens.Paragraph);
  }

  private static rewriteInlineImageLinks(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      if (type === "paragraph") {
        MarkdownContent.rewriteParagraphInlineImages(token);
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.rewriteInlineImageLinks(childTokens);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.rewriteInlineImageLinks(itemTokens);
          }
        }
      }
    }
  }

  private static rewriteParagraphInlineImages(paragraph: TokenRecord): void {
    const inlineTokens = paragraph["tokens"] as Token[] | undefined;
    if (!Array.isArray(inlineTokens) || inlineTokens.length === 0) {
      return;
    }
    const rewritten: Token[] = [];
    for (const token of inlineTokens) {
      rewritten.push(...MarkdownContent.rewriteInlineImageToken(token));
    }
    MarkdownContent.markStandaloneInlineImages(rewritten);
    paragraph["tokens"] = rewritten;
  }

  private static markStandaloneInlineImages(tokens: Token[]): void {
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as Token;
      if (!token || token.type !== "image") {
        continue;
      }
      if (MarkdownContent.isImageTokenAloneOnInlineLine(tokens, i)) {
        (token as InlineImageToken).inlineImage = false;
      }
    }
  }

  private static isImageTokenAloneOnInlineLine(tokens: Token[], index: number): boolean {
    let before = '';
    for (let i = index - 1; i >= 0; i--) {
      const token = tokens[i] as TokenRecord;
      if (!token) {
        continue;
      }
      if (token["type"] === "br") {
        break;
      }
      const text = String(token["text"] ?? token["raw"] ?? "");
      const breakIndex = Math.max(text.lastIndexOf('\n'), text.lastIndexOf('\r'));
      if (breakIndex >= 0) {
        before = text.slice(breakIndex + 1) + before;
        break;
      }
      before = text + before;
    }

    let after = '';
    for (let i = index + 1; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      if (!token) {
        continue;
      }
      if (token["type"] === "br") {
        break;
      }
      const text = String(token["text"] ?? token["raw"] ?? "");
      const lineFeed = text.indexOf('\n');
      const carriage = text.indexOf('\r');
      let breakIndex = -1;
      if (lineFeed >= 0 && carriage >= 0) {
        breakIndex = Math.min(lineFeed, carriage);
      } else {
        breakIndex = Math.max(lineFeed, carriage);
      }
      if (breakIndex >= 0) {
        after += text.slice(0, breakIndex);
        break;
      }
      after += text;
    }
    return before.trim().length === 0 && after.trim().length === 0;
  }

  private static rewriteInlineImageToken(token: Token): Token[] {
    const record = token as TokenRecord;
    const type = (record["type"] as string) || "";
    if (type === "link") {
      const nestedImage = MarkdownContent.firstNestedImage(record);
      if (nestedImage) {
        return [nestedImage as Token];
      }
      const href = MediaUrlUtils.imageUrlForRender(String(record["href"] ?? ""));
      const text = String(record["text"] ?? "").trim();
      const normalizedText = MediaUrlUtils.normalizeUrl(text);
      if (href && (!text || normalizedText === MediaUrlUtils.normalizeUrl(String(record["href"] ?? "")))) {
        // Treat bare/autolinked image URLs as inline candidates first. A later
        // pass demotes images that are actually alone on their source line to
        // block images, while mixed text + URL replies keep webpage inline flow.
        return [MarkdownContent.buildImageToken(String(record["raw"] ?? text), href, text, true) as Token];
      }
      return [token];
    }
    if (type === "text") {
      return MarkdownContent.splitTextImageUrls(token);
    }
    return [token];
  }

  private static firstNestedImage(record: TokenRecord): Tokens.Image | null {
    const children = record["tokens"] as Token[] | undefined;
    if (!Array.isArray(children) || children.length === 0) {
      return null;
    }
    for (const child of children) {
      const childRecord = child as TokenRecord;
      if ((childRecord["type"] as string) === "image") {
        const renderUrl = MediaUrlUtils.imageUrlForRender(String(childRecord["href"] ?? ""));
        if (renderUrl) {
          childRecord["href"] = renderUrl;
          return child as Tokens.Image;
        }
      }
    }
    return null;
  }

  private static splitTextImageUrls(token: Token): Token[] {
    const record = token as TokenRecord;
    const text = String(record["text"] ?? record["raw"] ?? "");
    if (!text) {
      return [token];
    }
    const result: Token[] = [];
    const re = /https?:\/\/[^\s<>()]+/gi;
    let last = 0;
    let m: RegExpExecArray | null = re.exec(text);
    while (m) {
      const rawUrl = m[0].replace(/[.,!?;:，。！？；：]+$/g, "");
      const renderUrl = MediaUrlUtils.imageUrlForRender(rawUrl);
      if (!renderUrl) {
        m = re.exec(text);
        continue;
      }
      if (m.index > last) {
        result.push(MarkdownContent.buildTextToken(text.slice(last, m.index)) as Token);
      }
      const beforeOnLine = text.slice(Math.max(last, text.lastIndexOf('\n', m.index - 1) + 1), m.index).trim().length > 0;
      const nextBreak = text.indexOf('\n', m.index + rawUrl.length);
      const afterEnd = nextBreak >= 0 ? nextBreak : text.length;
      const afterOnLine = text.slice(m.index + rawUrl.length, afterEnd).trim().length > 0;
      result.push(MarkdownContent.buildImageToken(rawUrl, renderUrl, "", beforeOnLine || afterOnLine) as Token);
      last = m.index + rawUrl.length;
      m = re.exec(text);
    }
    if (last === 0) {
      return [token];
    }
    if (last < text.length) {
      result.push(MarkdownContent.buildTextToken(text.slice(last)) as Token);
    }
    return result;
  }


  private static buildTextToken(text: string): Tokens.Text {
    return {
      type: "text",
      raw: text,
      text: text,
    } as Tokens.Text;
  }

  private static buildImageToken(raw: string, href: string, text: string, inlineImage: boolean = false): Tokens.Image {
    const imageToken: InlineImageToken = {
      type: "image",
      raw: raw,
      href: href,
      title: null,
      text: text,
      inlineImage: inlineImage,
    } as InlineImageToken;
    return imageToken;
  }

  private static promoteStandaloneImageParagraphs(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      if (type === "paragraph") {
        const inlineTokens = token["tokens"] as Token[] | undefined;
        if (Array.isArray(inlineTokens) && inlineTokens.length > 0) {
          const meaningful = inlineTokens.filter((t: Token) => t && t.type !== "br");
          if (meaningful.length > 0 && meaningful.every((t: Token) => t.type === "image")) {
            continue;
          }
        }
      }

      if (type === "list") {
        // CustomList renders list items; avoid rewriting list internals here.
        continue;
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.promoteStandaloneImageParagraphs(childTokens);
      }
    }
  }

  private static retypeBlockTokens(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      if (type === "code") {
        token["type"] = CODE_MONO;
      } else if (type === "list") {
        token["type"] = LIST_MONO;
      } else if (type === "paragraph") {
        token["type"] = PARAGRAPH_MONO;
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.retypeBlockTokens(childTokens);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.retypeBlockTokens(itemTokens);
          }
        }
      }
    }
  }

  private static rewriteStandaloneTextLinks(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      if (type === "paragraph") {
        MarkdownContent.rewriteStandaloneTextLink(token);
      }

      if (type === "list") {
        continue;
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.rewriteStandaloneTextLinks(childTokens);
      }
    }
  }

  private static removeIgnorableLayoutTokens(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = tokens.length - 1; i >= 0; i--) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      const raw = String(token["raw"] ?? token["text"] ?? "");
      if ((type === "space" || type === "html") && raw.trim().length === 0) {
        tokens.splice(i, 1);
        continue;
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.removeIgnorableLayoutTokens(childTokens);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.removeIgnorableLayoutTokens(itemTokens);
          }
        }
      }
    }
  }

  private static mergeSelectableParagraphRuns(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }

    let i = 0;
    while (i < tokens.length) {
      const current = tokens[i] as TokenRecord;
      if (!MarkdownContent.canMergeSelectableParagraph(current)) {
        MarkdownContent.mergeChildSelectableParagraphRuns(current);
        i++;
        continue;
      }

      let end = i + 1;
      while (end < tokens.length && MarkdownContent.canMergeSelectableParagraph(tokens[end] as TokenRecord)) {
        end++;
      }

      if (end - i > 1) {
        const merged = MarkdownContent.mergeParagraphRange(tokens.slice(i, end));
        tokens.splice(i, end - i, merged as Token);
      }
      i++;
    }
  }

  private static mergeChildSelectableParagraphRuns(token: TokenRecord): void {
    const childTokens = token["tokens"] as Token[] | undefined;
    if (Array.isArray(childTokens) && childTokens.length > 0) {
      MarkdownContent.mergeSelectableParagraphRuns(childTokens);
    }

    const items = token["items"] as Array<TokenRecord> | undefined;
    if (Array.isArray(items) && items.length > 0) {
      for (const item of items) {
        const itemTokens = item["tokens"] as Token[] | undefined;
        if (Array.isArray(itemTokens) && itemTokens.length > 0) {
          MarkdownContent.mergeSelectableParagraphRuns(itemTokens);
        }
      }
    }
  }

  private static canMergeSelectableParagraph(token: TokenRecord): boolean {
    if (!token || token["type"] !== "paragraph") {
      return false;
    }
    const inlineTokens = token["tokens"] as Token[] | undefined;
    if (!Array.isArray(inlineTokens) || inlineTokens.length === 0) {
      return false;
    }
    return !inlineTokens.some((t: Token) => t && (t.type === "image" || _isInlineImageToken(t)));
  }

  private static mergeParagraphRange(paragraphs: Token[]): Tokens.Paragraph {
    const mergedTokens: Token[] = [];
    const rawParts: string[] = [];
    const textParts: string[] = [];
    for (let i = 0; i < paragraphs.length; i++) {
      const paragraph = paragraphs[i] as TokenRecord;
      const inlineTokens = paragraph["tokens"] as Token[] | undefined;
      if (i > 0) {
        const separator = MarkdownContent.buildTextToken("\n\n");
        mergedTokens.push(separator as Token);
        rawParts.push("\n\n");
        textParts.push("\n\n");
      }
      if (Array.isArray(inlineTokens)) {
        mergedTokens.push(...inlineTokens);
      }
      rawParts.push(String(paragraph["raw"] ?? ""));
      textParts.push(String(paragraph["text"] ?? paragraph["raw"] ?? ""));
    }

    return {
      type: "paragraph",
      raw: rawParts.join(""),
      text: textParts.join(""),
      tokens: mergedTokens,
    } as Tokens.Paragraph;
  }

  private static rewriteStandaloneTextLink(paragraph: TokenRecord): void {
    const inlineTokens = paragraph["tokens"] as Token[] | undefined;
    if (!Array.isArray(inlineTokens) || inlineTokens.length === 0) {
      return;
    }

    const meaningful = inlineTokens.filter((t: Token) => t && t.type !== "br");
    if (meaningful.length !== 1) {
      return;
    }

    const only = meaningful[0] as TokenRecord;
    const onlyType = only["type"] as string;
    if (!only || typeof onlyType !== "string") {
      return;
    }

    if (onlyType === "text") {
      const rawText = String(only["text"] ?? "").trim();
      const href = MediaUrlUtils.normalizeUrl(rawText);
      if (!MediaUrlUtils.isStandaloneHttpUrl(rawText) || MediaUrlUtils.isProbablyImageUrl(href)) {
        return;
      }
      only["type"] = "link";
      only["raw"] = String(only["raw"] ?? rawText);
      only["href"] = href;
      only["text"] = rawText;
    }
  }

  private static rewriteBareImageLinks(tokens: Token[]): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";

      if (type === "paragraph") {
        MarkdownContent.rewriteParagraphBareImageLink(token);
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.rewriteBareImageLinks(childTokens);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.rewriteBareImageLinks(itemTokens);
          }
        }
      }
    }
  }

  private static rewriteParagraphBareImageLink(paragraph: TokenRecord): void {
    const inlineTokens = paragraph["tokens"] as Token[] | undefined;
    if (!Array.isArray(inlineTokens) || inlineTokens.length === 0) {
      return;
    }

    const meaningful = inlineTokens.filter((t: Token) => t && t.type !== "br");
    if (meaningful.length !== 1) {
      return;
    }

    const only = meaningful[0] as TokenRecord;
    const onlyType = only["type"] as string;
    if (!only || typeof onlyType !== "string") {
      return;
    }

    if (onlyType === "link") {
      const href = MediaUrlUtils.normalizeUrl(String(only["href"] ?? ""));
      const text = String(only["text"] ?? "").trim();
      const normalizedText = MediaUrlUtils.normalizeUrl(text);
      const renderUrl = MediaUrlUtils.imageUrlForRender(href);
      if (!renderUrl) {
        return;
      }
      if (text.length > 0 && normalizedText !== href) {
        return;
      }
      only["type"] = "image";
      only["href"] = renderUrl;
      only["title"] = only["title"] ?? null;
      only["text"] = "";
      only["tokens"] = [];
      return;
    }

    if (onlyType === "text") {
      const rawText = String(only["text"] ?? "").trim();
      const href = MediaUrlUtils.normalizeUrl(rawText);
      const renderUrl = MediaUrlUtils.imageUrlForRender(href);
      if (!renderUrl) {
        return;
      }
      const imageToken: Tokens.Image = {
        type: "image",
        raw: String(only["raw"] ?? rawText),
        href: renderUrl,
        title: null,
        text: "",
      };
      paragraph["tokens"] = [imageToken];
    }
  }

  private sourceIdentity(): string {
    const raw = this.source || "";
    return `${raw.length}:${raw.slice(0, 32)}:${raw.slice(Math.max(0, raw.length - 32))}`;
  }

  private markdownOptions(): MarkdownOptions {
    return {
      darkMode: this.themeEffectiveDark,
      theme: {
        themeColor: ThemeConstants.TEXT_SECONDARY,
        fontStyle: {
          fontSize: this.bodyFontSize(),
          fontColor: ThemeConstants.TEXT_PRIMARY,
        },
        linkColor: ThemeConstants.TEXT_LINK,
        code: {
          fontColor: _codeColors(this.themeEffectiveDark),
          backgroundColor: _codeBackground(this.themeEffectiveDark),
          borderRadius: ThemeConstants.RADIUS_SM,
          codeSpanBackgroundColor: this.themeEffectiveDark ? '#30363D' : '#EFF1F3',
          codeSpanBorderRadius: ThemeConstants.RADIUS_SM,
        },
        codeSpan: {
          backgroundColor: this.themeEffectiveDark ? '#30363D' : '#EFF1F3',
          borderRadius: ThemeConstants.RADIUS_SM,
        },
      },
      imageClick: (url?: string) => {
        const normalized = MediaUrlUtils.normalizeUrl(url ?? "");
        if (normalized && this.onImageClick) {
          this.onImageClick(normalized);
        }
      },
      linkClick: (url?: string) => {
        const normalized = MediaUrlUtils.normalizeUrl(url ?? "");
        if (normalized) {
          this.openLink(normalized);
        }
      },
      mentionClick: (username: string) => {
        if (this.onMentionClick) {
          this.onMentionClick(username);
        }
      },
    } as MarkdownOptions;
  }

  private tokenKey(token: Token, index: number): string {
    const record = token as TokenRecord;
    return `${String(record["type"] ?? "token")}-${String(record["raw"] ?? record["href"] ?? record["text"] ?? index)}-${index}`;
  }

  private headingLevel(token: Token): number {
    const depth = Number((token as TokenRecord)["depth"] ?? 0);
    if (!Number.isFinite(depth) || depth <= 0) {
      return 6;
    }
    return Math.max(1, Math.min(6, depth));
  }

  private headingBaseFontSize(token: Token): number {
    const level = this.headingLevel(token);
    if (level <= 1) {
      return RENDER_H1_FONT_SIZE;
    }
    if (level === 2) {
      return RENDER_H2_FONT_SIZE;
    }
    if (level === 3) {
      return RENDER_H3_FONT_SIZE;
    }
    if (level === 4) {
      return RENDER_H4_FONT_SIZE;
    }
    if (level === 5) {
      return RENDER_H5_FONT_SIZE;
    }
    return RENDER_H6_FONT_SIZE;
  }

  private headingBaseLineHeight(token: Token): number {
    const level = this.headingLevel(token);
    if (level <= 1) {
      return RENDER_H1_LINE_HEIGHT;
    }
    if (level === 2) {
      return RENDER_H2_LINE_HEIGHT;
    }
    if (level === 3) {
      return RENDER_H3_LINE_HEIGHT;
    }
    if (level === 4) {
      return RENDER_H4_LINE_HEIGHT;
    }
    if (level === 5) {
      return RENDER_H5_LINE_HEIGHT;
    }
    return RENDER_H6_LINE_HEIGHT;
  }

  private headingSize(token: Token): number {
    return ReadingSettings.scaleTypographyToken(this.headingBaseFontSize(token), this.readingFontSize);
  }

  private headingLineHeight(token: Token): number {
    return ReadingSettings.scaleTypographyToken(this.headingBaseLineHeight(token), this.readingFontSize);
  }

  private headingWeight(token: Token): FontWeight {
    const level = this.headingLevel(token);
    if (level <= 2) {
      return FontWeight.Bold;
    }
    return FontWeight.Medium;
  }

  private headingColor(_token: Token): ResourceColor {
    return ThemeConstants.TEXT_PRIMARY;
  }

  private headingInlineTokens(token: Token): Token[] {
    const tokens = (token as TokenRecord)["tokens"] as Token[] | undefined;
    if (Array.isArray(tokens) && tokens.length > 0) {
      return tokens;
    }
    return [MarkdownContent.buildTextToken(String((token as TokenRecord)["text"] ?? "")) as Token];
  }

  private plainTokenText(token: Token): string {
    return String((token as TokenRecord)["text"] ?? (token as TokenRecord)["raw"] ?? "").trim();
  }

  @Builder RenderProcessedToken(token: Token) {
    if (token.type === CODE_MONO) {
      MarkdownCodeBlock({ codeToken: token as Tokens.Code, options: this.markdownOptions() });
    } else if (token.type === LIST_MONO) {
      CustomList({
        listToken: token as Tokens.List,
        options: this.markdownOptions(),
        inlineImageSizeRecords: this.inlineImageSizeRecords,
        reportImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
        reportImageError: (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
      });
    } else if (token.type === PARAGRAPH_MONO) {
      MarkdownParagraph({
        paragraphToken: token as Tokens.Paragraph,
        options: this.markdownOptions(),
        inlineImageSizeRecords: this.inlineImageSizeRecords,
        contentAvailableWidth: this.contentAvailableWidth,
        reportImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
        reportImageError: (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
      });
    } else if (token.type === IMAGE_BLOCK_MONO) {
      MarkdownAutoImage({
        url: MediaUrlUtils.imageUrlForRender((token as Tokens.Image).href),
        options: this.markdownOptions(),
        reportImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
        reportImageError: (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
      });
    } else if (token.type === "table") {
      MarkdownTable({
        tableToken: token as RenderTableToken,
        options: this.markdownOptions(),
        inlineImageSizeRecords: this.inlineImageSizeRecords,
        reportImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
        reportImageError: (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
      });
    } else if (token.type === IMAGE_TABLE_MONO) {
      MarkdownImageTable({
        tableToken: token as ImageTableToken,
        options: this.markdownOptions(),
        reportImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
        reportImageError: (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
      });
    } else if (token.type === "blockquote") {
      MarkdownBlockquote({
        quoteToken: token,
        options: this.markdownOptions(),
        inlineImageSizeRecords: this.inlineImageSizeRecords,
        contentAvailableWidth: this.contentAvailableWidth,
        reportImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
        reportImageError: (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
      });
    } else if (token.type === "heading") {
      if (this.base64DecodeMode === ReadingSettings.BASE64_MODE_BADGE && _tokensContainBase64Decode(this.headingInlineTokens(token))) {
        SelectableInlineTokenFlow({
          tokens: this.headingInlineTokens(token),
          fontSize: this.headingSize(token),
          fontColor: this.headingColor(token),
          fontWeight: this.headingWeight(token),
          lineHeight: this.headingLineHeight(token),
          textAlign: TextAlign.Start,
          wordBreak: WordBreak.BREAK_WORD,
          copyOption: CopyOptions.LocalDevice,
          textSelectable: TextSelectableMode.SELECTABLE_FOCUSABLE,
          options: this.markdownOptions(),
          inlineImageSizeRecords: this.inlineImageSizeRecords,
          reportImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
          reportImageError: (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
          availableWidth: this.contentAvailableWidth,
          base64DecodeMode: this.base64DecodeMode,
          activeBase64PopupKey: this.activeBase64PopupKey,
          showBase64Popup: (key: string) => { this.showBase64Popup(key); },
          hideBase64Popup: (key: string) => { this.hideBase64Popup(key); },
          base64PopupScope: `heading-${String((token as TokenRecord)["raw"] ?? (token as TokenRecord)["text"] ?? "")}`,
        })
      } else {
        Text() {
          SelectableInlineTokenSpans(
            this.headingInlineTokens(token),
            this.headingSize(token),
            this.markdownOptions(),
            this.inlineImageSizeRecords,
            (url: string, event?: MarkdownImageCompleteEvent) => { this.reportInlineImageComplete(url, event); },
            (url: string, event?: MarkdownImageErrorEvent) => { this.reportInlineImageError(url, event); },
            this.contentAvailableWidth,
            this.base64DecodeMode,
            this.activeBase64PopupKey,
            (key: string) => { this.showBase64Popup(key); },
            (key: string) => { this.hideBase64Popup(key); },
            `heading-${String((token as TokenRecord)["raw"] ?? (token as TokenRecord)["text"] ?? "")}`,
          );
        }
          .fontSize(this.headingSize(token))
          .fontWeight(this.headingWeight(token))
          .fontColor(this.headingColor(token))
          .lineHeight(this.headingLineHeight(token))
          .width("100%")
          .copyOption(CopyOptions.LocalDevice)
          .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE);
      }
    } else if (token.type === "space" || token.type === "html") {
    } else if (this.plainTokenText(token).length > 0) {
      Text(this.plainTokenText(token))
        .fontSize(this.bodyFontSize())
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .lineHeight(this.bodyLineHeight())
        .width("100%");
    }
  }

  build() {
    Column({ space: this.blockSpace() }) {
      ForEach(MarkdownContent.processTokens(this.source, this.inlineImageSizeRecords), (token: Token, index: number) => {
        this.RenderProcessedToken(token);
      }, (token: Token, index: number) => this.tokenKey(token, index))
    }
    .id(this.sourceIdentity())
    .width("100%")
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateContentAvailableWidth(newValue);
    })
    .alignItems(HorizontalAlign.Start)
    .margin({ top: this.effectiveTopMargin() });
  }
}
