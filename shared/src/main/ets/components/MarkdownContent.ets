import { Markdown, MarkdownOptions, Token, Tokens, lexer } from "@lidary/markdown";
import { pasteboard } from "@kit.BasicServicesKit";
import { connection } from "@kit.NetworkKit";
import { promptAction } from "@kit.ArkUI";
import { StorageKeys } from "../constants/StorageKeys";
import { ThemeConstants } from "../theme/ThemeConstants";

// Custom token types used to hijack @lidary/markdown's built-in rendering.
// By changing a token's type before passing it to the Markdown component,
// it falls through to customBlockBuilder where we render it ourselves.
const CODE_MONO = "customCode";
const LIST_MONO = "customList";
const IMAGE_BLOCK_MONO = "customImageBlock";

type TokenValue = Object | null | undefined;
type TokenRecord = Record<string, TokenValue>;

const _imageExtRegex = /\.(jpe?g|png|gif|webp)(?:[?#].*)?$/i;
const _imageHostPrefixes: string[] = [
  "https://i.imgur.com/",
  "http://i.imgur.com/",
  "https://sm.ms/",
  "http://sm.ms/",
  "https://s2.loli.net/",
  "http://s2.loli.net/",
  "https://v2ex.assets.uxengine.net/",
  "http://v2ex.assets.uxengine.net/",
  "https://i.v2ex.co/",
  "http://i.v2ex.co/",
  "https://i.v2ex.com/",
  "http://i.v2ex.com/",
  "https://raw.githubusercontent.com/",
  "http://raw.githubusercontent.com/",
  "https://pbs.twimg.com/media/",
  "http://pbs.twimg.com/media/",
  "https://github.com/user-attachments/assets/",
  "http://github.com/user-attachments/assets/",
];

function _normalizeUrl(raw: string): string {
  const url = (raw ?? "").trim();
  if (!url) {
    return "";
  }
  if (url.startsWith("//")) {
    return `https:${url}`;
  }
  return url;
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

function _isProbablyImageUrl(raw: string): boolean {
  const url = _normalizeUrl(raw);
  if (!url) {
    return false;
  }
  if (url.startsWith("http://") || url.startsWith("https://")) {
    if (_imageExtRegex.test(url)) {
      return true;
    }
    return _imageHostPrefixes.some(prefix => url.startsWith(prefix));
  }
  return false;
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

// Matches @lidary/markdown's default dark-bg code block palette
const _defaultCodeColors: Record<string, ResourceColor> = {
  "text": ThemeConstants.CODE_TEXT,
  "string": ThemeConstants.CODE_TEXT,
  "keyword": "#0A69DA",
  "type": "#0A69DA",
  "symbol": "#E3DA90",
  "number": "#B3E54C",
  "boolean": ThemeConstants.CODE_TEXT,
};

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
}

interface MarkdownImageErrorEvent {
  message?: string;
}

// ---------- Custom block rendering ----------
// Handles token types we've hijacked from the library (code blocks, lists).
@Builder
function CustomBlockBuilder(token: Token, options: MarkdownOptions) {
  if (token.type === CODE_MONO) {
    MarkdownCodeBlock({ codeToken: token as Tokens.Code, options: options });
  } else if (token.type === LIST_MONO) {
    CustomList({ listToken: token as Tokens.List, options: options });
  } else if (token.type === IMAGE_BLOCK_MONO) {
    MarkdownAutoImage({ url: _normalizeUrl((token as Tokens.Image).href), options: options });
  }
}

@Component
struct MarkdownCodeBlock {
  @Prop codeToken: Tokens.Code;
  @Prop options: MarkdownOptions;
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

  @Builder CodeLineSpans(line: string) {
    ForEach(highlightLine(line), (ht: CodeToken) => {
      Span(ht.text)
        .fontColor(
          this.options.theme?.code?.fontColor?.[ht.type] ??
            _defaultCodeColors[ht.type] ??
            ThemeConstants.CODE_TEXT,
        )
        .fontSize(this.options.theme?.code?.fontSize ?? ThemeConstants.FONT_SIZE_CODE)
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
          .lineHeight(ThemeConstants.LINE_HEIGHT_CODE);
        } else {
          Text() {
            this.CodeLineSpans(line);
          }
          .lineHeight(ThemeConstants.LINE_HEIGHT_CODE)
          .maxLines(1);
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
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
          .fontColor(ThemeConstants.CODE_ICON)
          .fontFamily("Noto Sans Mono")
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Blank();

        Button() {
          Text(this.wrapLines ? "滚动" : "换行")
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor(ThemeConstants.CODE_ICON);
        }
        .type(ButtonType.Normal)
        .height(28)
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor(Color.Transparent)
        .stateStyles({
          pressed: { .backgroundColor(ThemeConstants.PRESSED_OVERLAY) },
          normal: { .backgroundColor(Color.Transparent) },
        })
        .onClick(() => {
          this.wrapLines = !this.wrapLines;
        });

        Button() {
          Image($r("sys.media.ohos_ic_public_copy"))
            .width(ThemeConstants.ICON_SIZE_SM)
            .height(ThemeConstants.ICON_SIZE_SM)
            .fillColor(ThemeConstants.CODE_ICON);
        }
        .type(ButtonType.Normal)
        .width(ThemeConstants.TOUCH_TARGET_SM)
        .height(28)
        .borderRadius(ThemeConstants.RADIUS_SM)
        .backgroundColor(Color.Transparent)
        .stateStyles({
          pressed: { .backgroundColor(ThemeConstants.PRESSED_OVERLAY) },
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
        top: ThemeConstants.SPACE_SM,
        bottom: ThemeConstants.SPACE_XS,
      })
      .backgroundColor("#3A3D42");

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
    .backgroundColor(this.options.theme?.code?.backgroundColor ?? ThemeConstants.CODE_BG);
  }
}

// Renders inline markdown tokens (bold, italic, code, link, etc.) as Span children.
// Used inside CustomList since the library's Inline component is not exported.
@Builder
function InlineTokenSpans(tokens: Token[], fontSize: number) {
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
    } else {
      // Token union includes Space which has no .text — cast needed
      Span((t as Tokens.Text).text ?? t.raw ?? "")
        .fontSize(fontSize)
        .fontColor(ThemeConstants.TEXT_PRIMARY);
    }
  });
}

@Component
struct MarkdownAutoImage {
  @Prop url: string = "";
  @Prop options: MarkdownOptions;
  @StorageLink(StorageKeys.MEDIA_AUTO_LOAD_IMAGES) @Watch('onImageLoadPolicyChanged') autoLoadImages: boolean = true
  @StorageLink(StorageKeys.MEDIA_ONLY_LOAD_IMAGES_ON_WIFI) @Watch('onImageLoadPolicyChanged') onlyLoadImagesOnWifi: boolean = false
  @State private loadState: number = 0 // 0: idle, 1: loading, 2: loaded, 3: error
  @State private reloadNonce: number = 0
  @State private networkChecked: boolean = false
  @State private isWifiNetwork: boolean = false

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

  build() {
    if (this.imageLoadingAllowed()) {
      Stack({ alignContent: Alignment.Center }) {
        Image(_appendCacheBust(this.url, this.reloadNonce))
          .width("100%")
          .objectFit(ImageFit.Contain)
          .borderRadius(ThemeConstants.RADIUS_SM)
          .onComplete((event?: MarkdownImageCompleteEvent) => {
            if ((event?.loadingStatus ?? 0) === 1) {
              this.loadState = 2;
            }
          })
          .onError((_event?: MarkdownImageErrorEvent) => {
            this.loadState = 3;
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
  private fontSize: number = ThemeConstants.FONT_SIZE_BODY;

  private paragraphTokens(child: Token): Token[] {
    const paragraph = child as Tokens.Paragraph;
    const tokens = paragraph.tokens as Token[] | undefined;
    if (!Array.isArray(tokens) || tokens.length === 0) {
      return [];
    }
    return tokens;
  }

  private paragraphTextTokens(child: Token): Token[] {
    return this.paragraphTokens(child).filter((t: Token) => t && t.type !== "image" && t.type !== "br");
  }

  private paragraphImageTokens(child: Token): Tokens.Image[] {
    return this.paragraphTokens(child).filter((t: Token) => t && t.type === "image") as Tokens.Image[];
  }

  private hasImageToken(tokens: Token[]): boolean {
    if (!tokens || tokens.length === 0) {
      return false;
    }
    return tokens.some((t: Token) => t && t.type === "image");
  }

  build() {
    Column({ space: this.options.lineSpace }) {
      ForEach(this.listToken.items, (item: Tokens.ListItem, index: number) => {
        Row({ space: ThemeConstants.SPACE_SM }) {
          if (this.listToken.ordered) {
            Text(`${(this.listToken.start as number) + index}.`)
              .fontSize(this.fontSize)
              .fontColor(ThemeConstants.TEXT_PRIMARY);
          } else {
            Text("•")
              .fontSize(this.fontSize)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_SECONDARY);
          }
          Column({ space: this.options.lineSpace }) {
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
                          InlineTokenSpans(this.paragraphTextTokens(child), this.fontSize)
                        }.width("100%");
                      }
                      ForEach(this.paragraphImageTokens(child), (img: Tokens.Image, imgIdx: number) => {
                        MarkdownAutoImage({ url: _normalizeUrl(img.href), options: this.options });
                      }, (img: Tokens.Image, imgIdx: number) => `${img.href}-${imgIdx}`)
                    }.width("100%");
                  } else {
                    Text() {
                      InlineTokenSpans(this.paragraphTokens(child), this.fontSize)
                    }.width("100%");
                  }
                } else {
                  Text(child.text)
                    .fontSize(this.fontSize)
                    .fontColor(ThemeConstants.TEXT_PRIMARY)
                    .width("100%");
                }
              } else if (child.type === LIST_MONO || child.type === "list") {
                CustomList({ listToken: child as Tokens.List, options: this.options }).padding({
                  left: ThemeConstants.SPACE_SM,
                });
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
  @State private tokens: Token[] = [];

  aboutToAppear() {
    this.refreshTokens();
  }

  onSourceChanged(_propName: string): void {
    this.refreshTokens();
  }

  private refreshTokens(): void {
    this.tokens = MarkdownContent.processTokens(this.source);
  }

  // Re-type certain tokens so the Markdown component doesn't recognize them
  // and delegates to our customBlockBuilder instead.
  private static processTokens(md: string): Token[] {
    let tokens = lexer(md, { gfm: true, breaks: true });
    MarkdownContent.rewriteBareImageLinks(tokens);
    MarkdownContent.promoteStandaloneImageParagraphs(tokens);
    MarkdownContent.retypeBlockTokens(tokens);
    return tokens;
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
          if (meaningful.length === 1 && meaningful[0].type === "image") {
            const imageToken = meaningful[0] as Token;
            (imageToken as TokenRecord)["type"] = IMAGE_BLOCK_MONO;
            tokens[i] = imageToken;
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
      const href = _normalizeUrl(String(only["href"] ?? ""));
      const text = String(only["text"] ?? "").trim();
      const normalizedText = _normalizeUrl(text);
      if (!_isProbablyImageUrl(href)) {
        return;
      }
      if (text.length > 0 && normalizedText !== href) {
        return;
      }
      only["type"] = "image";
      only["href"] = href;
      only["title"] = only["title"] ?? null;
      only["text"] = "";
      only["tokens"] = [];
      return;
    }

    if (onlyType === "text") {
      const rawText = String(only["text"] ?? "").trim();
      const href = _normalizeUrl(rawText);
      if (!_isProbablyImageUrl(href)) {
        return;
      }
      const imageToken: Tokens.Image = {
        type: "image",
        raw: String(only["raw"] ?? rawText),
        href: href,
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
          lineSpace: ThemeConstants.SPACE_SM,
          options: {
            gfm: true,
            breaks: true,
          },
          theme: {
            // overrides blue default for list bullets etc.
            themeColor: ThemeConstants.TEXT_SECONDARY,
            fontStyle: {
              fontSize: ThemeConstants.FONT_SIZE_BODY,
              fontColor: ThemeConstants.TEXT_PRIMARY,
            },
            // one level smaller than library defaults
            headingStyle: [
              {
                fontSize: ThemeConstants.FONT_SIZE_H1,
                fontWeight: FontWeight.Bold,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: ThemeConstants.FONT_SIZE_H2,
                fontWeight: FontWeight.Bold,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: ThemeConstants.FONT_SIZE_H3,
                fontWeight: FontWeight.Medium,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: ThemeConstants.FONT_SIZE_HEADING,
                fontWeight: FontWeight.Medium,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: ThemeConstants.FONT_SIZE_TITLE,
                fontWeight: FontWeight.Normal,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
              {
                fontSize: ThemeConstants.FONT_SIZE_BODY,
                fontWeight: FontWeight.Normal,
                fontColor: ThemeConstants.TEXT_PRIMARY,
              },
            ],
            linkColor: ThemeConstants.TEXT_LINK,
          },
          imageClick: (url?: string) => {
            const normalized = _normalizeUrl(url ?? "");
            if (normalized && this.onImageClick) {
              this.onImageClick(normalized);
            }
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
      .margin({ top: this.topMargin });
  }
}
