import { pasteboard } from "@kit.BasicServicesKit";
import { promptAction } from "@kit.ArkUI";
import { ReadingSettings } from "../../settings/ReadingSettings";
import { connectReadingSettings, ReadingSettingsState } from "../../state/ReadingSettingsState";
import { ThemeConstants } from "../../theme/ThemeConstants";
import { MarkdownOptions, Tokens } from "../MarkdownContent";
import { AppStrings } from "../../i18n/AppStrings";
import {
  CodeColorPalette,
  CodeToken,
  RENDER_CODE_FONT_SIZE,
  RENDER_CODE_LINE_HEIGHT,
  _codeBackground,
  _codeColor,
  _codeColors,
  _codeHeaderBackground,
  _codeMetaColor,
  _codePressedOverlay,
  highlightCodeLine,
  normalizeCodeLanguage,
} from "./MarkdownCodeInternals";

@ComponentV2
export struct MarkdownCodeBlock {
  @Require @Param codeToken: Tokens.Code;
  @Require @Param options: MarkdownOptions;
  // Reading typography mirrored into AppStorageV2 by ReadingSettings.apply()
  // (was @StorageLink READING_TEXT_SCALE / READING_LINE_HEIGHT).
  private reading: ReadingSettingsState = connectReadingSettings();
  @Local private wrapLines: boolean = false;

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
      promptAction.openToast({ message: $r('app.string.common_copy_code') }).catch((error: Error) => {
        console.error(`openToast failed: ${error.message}`);
      });
    } catch (error) {
      promptAction.openToast({
        message: (error as Error).message || AppStrings.text($r('app.string.common_copy_failed'), 'Copy failed')
      }).catch((_error: Error) => { });
    }
  }

  private codeFontSize(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_CODE_FONT_SIZE, this.reading.textScale);
  }

  private codeLineHeight(): number {
    return ReadingSettings.scaleTypographyToken(RENDER_CODE_LINE_HEIGHT, this.reading.textScale);
  }

  private isDarkMode(): boolean {
    return this.options.darkMode === true;
  }

  private codePalette(): CodeColorPalette {
    return _codeColors(this.isDarkMode());
  }

  @Builder CodeLineSpans(line: string) {
    ForEach(highlightCodeLine(line, this.languageText()), (ht: CodeToken) => {
      Span(ht.text)
        .fontColor(_codeColor(this.isDarkMode(), ht.type))
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
          Text(this.wrapLines ?
            AppStrings.text($r('app.string.code_wrap_scroll'), 'Scroll') :
            AppStrings.text($r('app.string.code_wrap_wrap'), 'Wrap'))
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
