import { Markdown, MarkdownOptions, Token, Tokens, lexer } from "@lidary/markdown";
import { pasteboard } from "@kit.BasicServicesKit";
import { promptAction } from "@kit.ArkUI";
import { ThemeConstants } from "../theme/ThemeConstants";

// Custom token types used to hijack @lidary/markdown's built-in rendering.
// By changing a token's type before passing it to the Markdown component,
// it falls through to customBlockBuilder where we render it ourselves.
const CODE_MONO = "customCode";
const LIST_MONO = "customList";

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

// ---------- Custom block rendering ----------
// Handles token types we've hijacked from the library (code blocks, lists).
@Builder
function CustomBlockBuilder(token: Token, options: MarkdownOptions) {
  if (token.type === CODE_MONO) {
    Row() {
      Column() {
        Scroll() {
          Column() {
            ForEach((token as Tokens.Code).text.split("\n"), (line: string) => {
              Text() {
                ForEach(highlightLine(line), (ht: CodeToken) => {
                  Span(ht.text)
                    .fontColor(
                      options.theme?.code?.fontColor?.[ht.type] ??
                        _defaultCodeColors[ht.type] ??
                        ThemeConstants.CODE_TEXT,
                    )
                    .fontSize(options.theme?.code?.fontSize ?? ThemeConstants.FONT_SIZE_CODE)
                    .fontFamily("Noto Sans Mono");
                })
              }
              .lineHeight(ThemeConstants.LINE_HEIGHT_CODE)
              .maxLines(1); // prevent wrapping; parent Scroll handles overflow
            })
          }
          .alignItems(HorizontalAlign.Start)
          .padding({
            top: ThemeConstants.SPACE_MD,
            bottom: ThemeConstants.SPACE_MD,
            left: ThemeConstants.SPACE_MD,
            right: ThemeConstants.SPACE_SM,
          })
        }.scrollable(ScrollDirection.Horizontal)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Row() {
        Image($r("sys.media.ohos_ic_public_copy"))
          .width(ThemeConstants.ICON_SIZE_SM)
          .height(ThemeConstants.ICON_SIZE_SM)
          .fillColor(ThemeConstants.CODE_ICON)
      }
      .width(ThemeConstants.TOUCH_TARGET_SM)
      .height(ThemeConstants.TOUCH_TARGET_SM)
      .justifyContent(FlexAlign.Center)
      .borderRadius(ThemeConstants.RADIUS_SM)
      .stateStyles({
        pressed: { .backgroundColor(ThemeConstants.PRESSED_OVERLAY) },
        normal: { .backgroundColor(Color.Transparent) },
      })
      .onClick(() => {
        let data = pasteboard.createData(
          pasteboard.MIMETYPE_TEXT_PLAIN,
          (token as Tokens.Code).text,
        );
        pasteboard.getSystemPasteboard().setDataSync(data);
        promptAction.openToast({ message: "已复制" }).catch((error: Error) => {
          console.error(`openToast failed: ${error.message}`);
        });
      })
    }
    .width("100%")
    .alignItems(VerticalAlign.Top)
    .borderRadius(options.theme?.code?.borderRadius ?? ThemeConstants.RADIUS_SM)
    .backgroundColor(options.theme?.code?.backgroundColor ?? ThemeConstants.CODE_BG);
  } else if (token.type === LIST_MONO) {
    CustomList({ listToken: token as Tokens.List, options: options });
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

// Replaces the library's built-in MList which has broken bullet centering.
// Uses Text('•') as the bullet so it shares the same line metrics as the content,
// guaranteeing vertical alignment regardless of fontSize changes.
@Component
struct CustomList {
  @Prop listToken: Tokens.List;
  @Prop options: MarkdownOptions;
  private fontSize: number = ThemeConstants.FONT_SIZE_BODY;

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
                  Text() {
                    InlineTokenSpans((child as Tokens.Paragraph).tokens, this.fontSize)
                  }.width("100%");
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
  @Prop source: string = "";
  @Prop topMargin: number = ThemeConstants.SPACE_LG;
  @State private tokens: Token[] = [];

  aboutToAppear() {
    this.tokens = MarkdownContent.processTokens(this.source);
  }

  // Re-type certain tokens so the Markdown component doesn't recognize them
  // and delegates to our customBlockBuilder instead.
  private static processTokens(md: string): Token[] {
    let tokens = lexer(md, { gfm: true, breaks: true });
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i].type === "code") {
        (tokens[i] as Record<string, Object>)["type"] = CODE_MONO;
      } else if (tokens[i].type === "list") {
        (tokens[i] as Record<string, Object>)["type"] = LIST_MONO;
      }
    }
    return tokens;
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
