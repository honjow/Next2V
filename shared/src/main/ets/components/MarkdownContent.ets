import { Markdown, MarkdownOptions, Token, Tokens, lexer } from "@lidary/markdown";
import { common, Want } from "@kit.AbilityKit";
import { pasteboard } from "@kit.BasicServicesKit";
import { connection } from "@kit.NetworkKit";
import { LengthMetrics, promptAction } from "@kit.ArkUI";
import { StorageKeys } from "../constants/StorageKeys";
import { ReadingSettings } from "../settings/ReadingSettings";
import { ThemeConstants } from "../theme/ThemeConstants";
import { MediaUrlUtils } from "../utils/MediaUrlUtils";
import { HtmlEntityUtils } from "../utils/HtmlEntityUtils";

// Custom token types used to hijack @lidary/markdown's built-in rendering.
// By changing a token's type before passing it to the Markdown component,
// it falls through to customBlockBuilder where we render it ourselves.
const CODE_MONO = "customCode";
const LIST_MONO = "customList";
const PARAGRAPH_MONO = "customParagraph";
const IMAGE_BLOCK_MONO = "customImageBlock";
const IMAGE_TABLE_MONO = "customImageTable";
const IMAGE_TABLE_START = "@@V2NEXT_IMAGE_TABLE_START@@";
const IMAGE_TABLE_END = "@@V2NEXT_IMAGE_TABLE_END@@";
const INLINE_IMAGE_SIZE = 24;
const INLINE_IMAGE_MAX_SIZE = 40;
const INLINE_IMAGE_SMALL_MAX_PX = 128;
const INLINE_IMAGE_LARGE_MIN_PX = 240;
const INLINE_IMAGE_LARGE_WIDTH_MIN_PX = 160;
const INLINE_IMAGE_LARGE_HEIGHT_MIN_PX = 80;
const INLINE_IMAGE_RATIO_LIMIT = 2.0;
const INLINE_IMAGE_SIZE_RECORD_LIMIT = 64;

type TokenValue = Object | null | undefined;
type TokenRecord = Record<string, TokenValue>;

interface InlineImageToken extends Tokens.Image {
  inlineImage?: boolean;
}

type InlineImageSizeStatus = "unknown" | "inlineSmall" | "blockLarge" | "error";

interface InlineImageSizeRecord {
  url: string;
  widthPx: number;
  heightPx: number;
  status: InlineImageSizeStatus;
}

interface ImageTableToken {
  type: string;
  raw?: string;
  imageUrls?: string[];
  imageLabels?: string[];
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

function _inlineImageSize(fontSize: number): number {
  const size = Math.round(fontSize * 1.5);
  if (size < INLINE_IMAGE_SIZE) {
    return INLINE_IMAGE_SIZE;
  }
  if (size > INLINE_IMAGE_MAX_SIZE) {
    return INLINE_IMAGE_MAX_SIZE;
  }
  return size;
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

function _classifyInlineImageSize(widthPx: number, heightPx: number): InlineImageSizeStatus {
  if (widthPx <= 0 || heightPx <= 0) {
    return "unknown";
  }
  const maxSide = Math.max(widthPx, heightPx);
  const minSide = Math.min(widthPx, heightPx);
  const aspectRatio = minSide > 0 ? maxSide / minSide : maxSide;
  if (maxSide <= INLINE_IMAGE_SMALL_MAX_PX && aspectRatio <= INLINE_IMAGE_RATIO_LIMIT) {
    return "inlineSmall";
  }
  if (maxSide >= INLINE_IMAGE_LARGE_MIN_PX) {
    return "blockLarge";
  }
  if (widthPx >= INLINE_IMAGE_LARGE_WIDTH_MIN_PX && heightPx >= INLINE_IMAGE_LARGE_HEIGHT_MIN_PX) {
    return "blockLarge";
  }
  if (aspectRatio > INLINE_IMAGE_RATIO_LIMIT && maxSide >= INLINE_IMAGE_LARGE_WIDTH_MIN_PX) {
    return "blockLarge";
  }
  return aspectRatio <= INLINE_IMAGE_RATIO_LIMIT ? "inlineSmall" : "blockLarge";
}

function _inlineImageRenderUrl(token: Token): string {
  if (!token || token.type !== "image") {
    return "";
  }
  return MediaUrlUtils.imageUrlForRender((token as Tokens.Image).href);
}

function _inlineImageStatus(token: Token, sizeRecords: InlineImageSizeRecord[]): InlineImageSizeStatus {
  const url = _inlineImageRenderUrl(token);
  const record = _findInlineImageSizeRecord(sizeRecords, url);
  return record ? record.status : "unknown";
}

function _isMixedInlineImageCandidate(token: Token, sizeRecords: InlineImageSizeRecord[] = []): boolean {
  if (!token || token.type !== "image") {
    return false;
  }
  const sizeStatus = _inlineImageStatus(token, sizeRecords);
  if (sizeStatus === "blockLarge") {
    return false;
  }
  if (sizeStatus === "inlineSmall" || sizeStatus === "error") {
    return true;
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

type CodeHighLight = "string" | "text" | "keyword" | "type" | "symbol" | "number" | "boolean";

interface CodeToken {
  type: CodeHighLight;
  text: string;
}

// ---------- Code syntax highlighting ----------
// Ported from @lidary/markdown's internal HighlightAnalyzer (not exported).
// Simple regex-based tokenizer: splits each line into typed spans for coloring.
const _stringRegex = /(["'])(?:(?=(\\?))\2.)*?\1/g;
const _commonRegex = /([(\s=){}."])/gi;

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
      res.push({ type: "string", text: token.text });
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

// Two-pass tokenizer: first extract string literals, then split the rest by
// common delimiters and classify each piece (keyword, type, number, etc.).
function highlightLine(code: string): CodeToken[] {
  let tokens: CodeToken[] = [{ type: "text", text: code } as CodeToken];

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

const _darkCodeColors: Record<string, ResourceColor> = {
  "text": "#F8F8F2",
  "string": "#E6DB74",
  "keyword": "#66D9EF",
  "type": "#A6E22E",
  "symbol": "#F8F8F2",
  "number": "#AE81FF",
  "boolean": "#AE81FF",
};

const _lightCodeColors: Record<string, ResourceColor> = {
  "text": "#24292F",
  "string": "#0A3069",
  "keyword": "#CF222E",
  "type": "#8250DF",
  "symbol": "#24292F",
  "number": "#0550AE",
  "boolean": "#0550AE",
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
  reportImageComplete?: InlineImageCompleteReporter,
  reportImageError?: InlineImageErrorReporter,
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
      Span((t as Tokens.Link).text)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_LINK)
        .decoration({ type: TextDecorationType.Underline, color: ThemeConstants.TEXT_LINK })
        .onClick(() => {
          _openInlineLink(options, (t as Tokens.Link).href);
        });
    } else if (t.type === "del") {
      Span((t as Tokens.Del).text)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .decoration({ type: TextDecorationType.LineThrough });
    } else if (_isInlineImageToken(t)) {
      ImageSpan(_inlineImageRenderUrl(t))
        .width(_inlineImageSize(fontSize))
        .height(_inlineImageSize(fontSize))
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
struct MarkdownParagraph {
  @Prop paragraphToken: Tokens.Paragraph;
  @Prop options: MarkdownOptions;
  @Prop inlineImageSizeRecords: InlineImageSizeRecord[] = [];
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;

  private bodyFontSize(): number {
    return ReadingSettings.normalizeFontSize(this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.normalizeLineHeight(this.readingLineHeight, this.bodyFontSize());
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
            Text() {
              SelectableInlineTokenSpans(
                [token],
                this.bodyFontSize(),
                this.options,
                this.reportImageComplete,
                this.reportImageError,
              );
            }
            .fontSize(this.bodyFontSize())
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .lineHeight(this.bodyLineHeight())
            .textAlign(TextAlign.Start)
            .width("100%")
            .copyOption(CopyOptions.LocalDevice)
            .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
          }
        }, (token: Token, tokenIdx: number) => `${String((token as TokenRecord)["type"] ?? "token")}-${String((token as TokenRecord)["raw"] ?? (token as TokenRecord)["href"] ?? tokenIdx)}-${tokenIdx}`)
      }
      .width("100%")
      .alignItems(HorizontalAlign.Start)
    } else if (this.hasInlineImage()) {
      Text() {
        SelectableInlineTokenSpans(
          this.inlineTokens(),
          this.bodyFontSize(),
          this.options,
          this.reportImageComplete,
          this.reportImageError,
        );
      }
      .fontSize(this.bodyFontSize())
      .fontColor(ThemeConstants.TEXT_PRIMARY)
      .lineHeight(this.bodyLineHeight())
      .textAlign(TextAlign.Start)
      .width("100%")
    } else {
      Text() {
        SelectableInlineTokenSpans(
          this.inlineTokens(),
          this.bodyFontSize(),
          this.options,
          this.reportImageComplete,
          this.reportImageError,
        );
      }
      .fontSize(this.bodyFontSize())
      .fontColor(ThemeConstants.TEXT_PRIMARY)
      .lineHeight(this.bodyLineHeight())
      .textAlign(TextAlign.Start)
      .width("100%")
      .copyOption(CopyOptions.LocalDevice)
      .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
    }
  }
}

@Component
struct MarkdownCodeBlock {
  @Prop codeToken: Tokens.Code;
  @Prop options: MarkdownOptions;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;
  @State private wrapLines: boolean = false;

  private codeText(): string {
    return this.codeToken.text || "";
  }

  private languageText(): string {
    const lang = ((this.codeToken.lang || "") as string).trim();
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
    const fontSize = ReadingSettings.normalizeFontSize(this.readingFontSize) - 2;
    return fontSize < ThemeConstants.FONT_SIZE_CODE ? ThemeConstants.FONT_SIZE_CODE : fontSize;
  }

  private codeLineHeight(): number {
    const lineHeight = ReadingSettings.normalizeLineHeight(this.readingLineHeight, ReadingSettings.normalizeFontSize(this.readingFontSize)) - 2;
    return lineHeight < ThemeConstants.LINE_HEIGHT_CODE ? ThemeConstants.LINE_HEIGHT_CODE : lineHeight;
  }

  private isDarkMode(): boolean {
    return this.options.darkMode === true;
  }

  private codePalette(): Record<string, ResourceColor> {
    return _codeColors(this.isDarkMode());
  }

  @Builder CodeLineSpans(line: string) {
    ForEach(highlightLine(line), (ht: CodeToken) => {
      Span(ht.text)
        .fontColor(
          this.options.theme?.code?.fontColor?.[ht.type] ??
            this.codePalette()[ht.type] ??
            ThemeConstants.CODE_TEXT,
        )
        .fontSize(this.options.theme?.code?.fontSize ?? this.codeFontSize())
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
  reportImageComplete?: InlineImageCompleteReporter,
  reportImageError?: InlineImageErrorReporter,
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
      Span((t as Tokens.Link).text)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_LINK)
        .decoration({ type: TextDecorationType.Underline, color: ThemeConstants.TEXT_LINK });
    } else if (t.type === "del") {
      Span((t as Tokens.Del).text)
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .decoration({ type: TextDecorationType.LineThrough });
    } else if (_isInlineImageToken(t)) {
      ImageSpan(_inlineImageRenderUrl(t))
        .width(_inlineImageSize(fontSize))
        .height(_inlineImageSize(fontSize))
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
  reportImageComplete?: InlineImageCompleteReporter;
  reportImageError?: InlineImageErrorReporter;
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD;

  private bodyFontSize(): number {
    return ReadingSettings.normalizeFontSize(this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.normalizeLineHeight(this.readingLineHeight, this.bodyFontSize());
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

  private paragraphTokens(child: Token): Token[] {
    const paragraph = child as Tokens.Paragraph;
    const tokens = paragraph.tokens as Token[] | undefined;
    if (!Array.isArray(tokens) || tokens.length === 0) {
      return [];
    }
    return tokens;
  }

  private paragraphTextTokens(child: Token): Token[] {
    return this.paragraphTokens(child).filter((t: Token) => t && (t.type !== "image" || _isInlineImageToken(t)) && t.type !== "br");
  }

  private paragraphImageTokens(child: Token): Tokens.Image[] {
    return this.paragraphTokens(child).filter((t: Token) => t && t.type === "image" && !_isInlineImageToken(t)) as Tokens.Image[];
  }

  private hasImageToken(tokens: Token[]): boolean {
    if (!tokens || tokens.length === 0) {
      return false;
    }
    return tokens.some((t: Token) => t && t.type === "image" && !_isInlineImageToken(t));
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
              if (child.type === "text" || child.type === "paragraph") {
                if (
                  (child as Tokens.Paragraph).tokens &&
                  (child as Tokens.Paragraph).tokens.length > 0
                ) {
                  if (this.hasImageToken(this.paragraphTokens(child))) {
                    Column({ space: ThemeConstants.SPACE_SM }) {
                      if (this.paragraphTextTokens(child).length > 0) {
                        Text() {
                          InlineTokenSpans(
                            this.paragraphTextTokens(child),
                            this.bodyFontSize(),
                            this.reportImageComplete,
                            this.reportImageError,
                          )
                        }
                        .lineHeight(this.bodyLineHeight())
                        .width("100%");
                      }
                      ForEach(this.paragraphImageTokens(child), (img: Tokens.Image, imgIdx: number) => {
                        MarkdownAutoImage({
                          url: MediaUrlUtils.imageUrlForRender(img.href),
                          options: this.options,
                          reportImageComplete: this.reportImageComplete,
                          reportImageError: this.reportImageError,
                        });
                      }, (img: Tokens.Image, imgIdx: number) => `${img.href}-${imgIdx}`)
                    }.width("100%");
                  } else {
                    Text() {
                      InlineTokenSpans(
                        this.paragraphTokens(child),
                        this.bodyFontSize(),
                        this.reportImageComplete,
                        this.reportImageError,
                      )
                    }
                    .lineHeight(this.bodyLineHeight())
                    .width("100%");
                  }
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
  @StorageLink(StorageKeys.READING_FONT_SIZE) readingFontSize: number = ThemeConstants.FONT_SIZE_BODY;
  @StorageLink(StorageKeys.READING_LINE_HEIGHT) readingLineHeight: number = ThemeConstants.LINE_HEIGHT_BODY;
  @StorageLink(StorageKeys.READING_DENSITY) readingDensity: string = ReadingSettings.DENSITY_STANDARD;
  @StorageLink(StorageKeys.THEME_EFFECTIVE_DARK) themeEffectiveDark: boolean = false;
  @State private tokens: Token[] = [];
  @State private inlineImageSizeRecords: InlineImageSizeRecord[] = [];

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

  private reportInlineImageComplete(url: string, event?: MarkdownImageCompleteEvent): void {
    if (!url || (event?.loadingStatus ?? 0) !== 1) {
      return;
    }
    const widthPx = event?.width ?? 0;
    const heightPx = event?.height ?? 0;
    this.upsertInlineImageSizeRecord({
      url: url,
      widthPx: widthPx,
      heightPx: heightPx,
      status: _classifyInlineImageSize(widthPx, heightPx),
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
      status: "error",
    });
  }

  private upsertInlineImageSizeRecord(next: InlineImageSizeRecord): void {
    if (!next.url) {
      return;
    }
    const existing = _findInlineImageSizeRecord(this.inlineImageSizeRecords, next.url);
    if (existing && existing.widthPx === next.widthPx && existing.heightPx === next.heightPx && existing.status === next.status) {
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
    return ReadingSettings.normalizeFontSize(this.readingFontSize);
  }

  private bodyLineHeight(): number {
    return ReadingSettings.normalizeLineHeight(this.readingLineHeight, this.bodyFontSize());
  }

  private headingFontSize(delta: number): number {
    return this.bodyFontSize() + delta;
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

  // Re-type certain tokens so the Markdown component doesn't recognize them
  // and delegates to our customBlockBuilder instead.
  private static processTokens(md: string, sizeRecords: InlineImageSizeRecord[] = []): Token[] {
    let tokens = lexer(MarkdownContent.normalizeMarkdownSource(HtmlEntityUtils.decode(md)), { gfm: true, breaks: true });
    MarkdownContent.rewriteImageTableMarkers(tokens);
    MarkdownContent.rewriteBareImageLinks(tokens);
    MarkdownContent.rewriteInlineImageLinks(tokens);
    MarkdownContent.splitMixedImageParagraphs(tokens, sizeRecords);
    MarkdownContent.promoteStandaloneImageParagraphs(tokens);
    MarkdownContent.rewriteStandaloneTextLinks(tokens);
    MarkdownContent.removeIgnorableLayoutTokens(tokens);
    MarkdownContent.mergeSelectableParagraphRuns(tokens);
    MarkdownContent.retypeBlockTokens(tokens);
    return tokens;
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
    if (!value.startsWith('<')) {
      return false;
    }
    return /<(?:div|p|h[1-6]|ul|ol|li|table|img|a)\b/i.test(value);
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
      .replace(/<img\b[^>]*>/gi, (tag: string): string => {
        const src = MarkdownContent.htmlAttr(tag, 'src');
        return src || '';
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

  private static stripHtmlTags(value: string): string {
    return HtmlEntityUtils.decode((value || '').replace(/<[^>]+>/g, ''))
      .replace(/[ \t\f\v]+/g, ' ')
      .trim();
  }

  private static htmlAttr(tag: string, name: string): string {
    const re = new RegExp(`${name}\\s*=\\s*(["'])(.*?)\\1`, 'i');
    const match = re.exec(tag || '');
    return match ? HtmlEntityUtils.decode(match[2]).trim() : '';
  }

  private static splitMixedImageParagraphs(tokens: Token[], sizeRecords: InlineImageSizeRecord[] = []): void {
    if (!tokens || tokens.length === 0) {
      return;
    }
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i] as TokenRecord;
      const type = (token["type"] as string) || "";
      if (type === "paragraph") {
        const replacement = MarkdownContent.splitParagraphByImages(token, sizeRecords);
        if (replacement.length > 0) {
          tokens.splice(i, 1, ...replacement);
          i += replacement.length - 1;
          continue;
        }
      }

      const childTokens = token["tokens"] as Token[] | undefined;
      if (Array.isArray(childTokens) && childTokens.length > 0) {
        MarkdownContent.splitMixedImageParagraphs(childTokens, sizeRecords);
      }

      const items = token["items"] as Array<TokenRecord> | undefined;
      if (Array.isArray(items) && items.length > 0) {
        for (const item of items) {
          const itemTokens = item["tokens"] as Token[] | undefined;
          if (Array.isArray(itemTokens) && itemTokens.length > 0) {
            MarkdownContent.splitMixedImageParagraphs(itemTokens, sizeRecords);
          }
        }
      }
    }
  }

  private static splitParagraphByImages(paragraph: TokenRecord, sizeRecords: InlineImageSizeRecord[] = []): Token[] {
    const inlineTokens = paragraph["tokens"] as Token[] | undefined;
    if (!Array.isArray(inlineTokens) || inlineTokens.length === 0) {
      return [];
    }
    if (!inlineTokens.some((t: Token) => t && t.type === "image" && !_isMixedInlineImageCandidate(t, sizeRecords))) {
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
      .every((t: Token) => _isMixedInlineImageCandidate(t, sizeRecords));
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
      if (token && token.type === "image" && _isMixedInlineImageCandidate(token, sizeRecords)) {
        (token as InlineImageToken).inlineImage = true;
        textTokens.push(token);
      } else if (token && token.type === "image" && !_isMixedInlineImageCandidate(token, sizeRecords)) {
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
    return before.trim().length === 0;
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
        const rawHref = MediaUrlUtils.normalizeUrl(String(record["href"] ?? ""));
        const imgurPage = /^https?:\/\/(?:www\.)?imgur\.com\/[A-Za-z0-9]{5,12}(?:[?#].*)?$/i.test(rawHref);
        return [MarkdownContent.buildImageToken(String(record["raw"] ?? text), href, text, !imgurPage) as Token];
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
      const inlineImage = !MarkdownContent.isUrlAloneOnLine(text, m.index, m.index + rawUrl.length);
      result.push(MarkdownContent.buildImageToken(rawUrl, renderUrl, "", inlineImage) as Token);
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

  private static isUrlAloneOnLine(text: string, start: number, end: number): boolean {
    const raw = text || "";
    let lineStart = start;
    while (lineStart > 0) {
      const ch = raw.charAt(lineStart - 1);
      if (ch === "\n" || ch === "\r") {
        break;
      }
      lineStart--;
    }
    let lineEnd = end;
    while (lineEnd < raw.length) {
      const ch = raw.charAt(lineEnd);
      if (ch === "\n" || ch === "\r") {
        break;
      }
      lineEnd++;
    }
    const before = raw.slice(lineStart, start).trim();
    return before.length === 0;
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

  build() {
    Markdown({
      token: this.tokens,
      options: {
          lineSpace: this.blockSpace(),
          textLineSpace: LengthMetrics.vp(this.bodyLineHeight()),
          options: {
            gfm: true,
            breaks: true,
          },
          darkMode: this.themeEffectiveDark,
          theme: {
            // overrides blue default for list bullets etc.
            themeColor: ThemeConstants.TEXT_SECONDARY,
            fontStyle: {
              fontSize: this.bodyFontSize(),
              fontColor: ThemeConstants.TEXT_PRIMARY,
            },
            // one level smaller than library defaults
            headingStyle: [
              {
                fontSize: this.headingFontSize(10),
                fontWeight: FontWeight.Bold,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: this.headingFontSize(8),
                fontWeight: FontWeight.Bold,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: this.headingFontSize(6),
                fontWeight: FontWeight.Medium,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: this.headingFontSize(4),
                fontWeight: FontWeight.Medium,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: this.headingFontSize(2),
                fontWeight: FontWeight.Normal,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: this.bodyFontSize(),
                fontWeight: FontWeight.Normal,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
            ],
            linkColor: ThemeConstants.TEXT_LINK,
            blockQuoteStyle: {
              backgroundColor: _quoteBackground(this.themeEffectiveDark),
              driveColor: _quoteDriveColor(this.themeEffectiveDark),
              driveWidth: 4,
              borderRadius: ThemeConstants.RADIUS_SM,
            },
            code: {
              fontColor: _codeColors(this.themeEffectiveDark),
              fontSize: this.bodyFontSize(),
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
          darkTheme: {
            themeColor: ThemeConstants.TEXT_SECONDARY,
            fontStyle: {
              fontSize: this.bodyFontSize(),
              fontColor: ThemeConstants.TEXT_PRIMARY,
            },
            linkColor: ThemeConstants.TEXT_LINK,
            blockQuoteStyle: {
              backgroundColor: _quoteBackground(true),
              driveColor: _quoteDriveColor(true),
              driveWidth: 4,
              borderRadius: ThemeConstants.RADIUS_SM,
            },
            code: {
              fontColor: _codeColors(true),
              fontSize: this.bodyFontSize(),
              backgroundColor: _codeBackground(true),
              borderRadius: ThemeConstants.RADIUS_SM,
              codeSpanBackgroundColor: '#30363D',
              codeSpanBorderRadius: ThemeConstants.RADIUS_SM,
            },
            codeSpan: {
              backgroundColor: '#30363D',
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
          inlineImageSizeRecords: this.inlineImageSizeRecords,
          reportInlineImageComplete: (url: string, event?: MarkdownImageCompleteEvent) => {
            this.reportInlineImageComplete(url, event);
          },
          reportInlineImageError: (url: string, event?: MarkdownImageErrorEvent) => {
            this.reportInlineImageError(url, event);
          },
          customBlockBuilder: wrapBuilder(CustomBlockBuilder),
          customInlineBuilder: CodeSpanBuilder as (tokenItem: Token, params: object) => void,
        } as MarkdownOptions,
      nestedScroll: {
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST,
      },
      scrollBar: BarState.Off,
      paddings: { left: 0, right: 0, top: 0, bottom: 0 },
    })
      .width("100%")
      .margin({ top: this.effectiveTopMargin() });
  }
}
