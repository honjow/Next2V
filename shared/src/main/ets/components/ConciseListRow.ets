import {
  HdsListItemCard,
  PrefixCustomBuilder,
  PrefixImage,
  SuffixCustomBuilder,
  SuffixSwitch,
  SuffixText,
  SuffixTextAndArrow
} from '@kit.UIDesignKit'
import { ImageModifier, TextModifier } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ImageUtils } from '../utils/ImageUtils'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

@ComponentV2
export struct ConciseListRow {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr = ''
  @Param trailingText: ResourceStr = ''
  @Param leadingImageUrl: string = ''
  @Param count: number = -1
  @Param destructive: boolean = false
  @Param showChevron: boolean = true
  @Param trailingDropdown: boolean = false
  @Param hasSwitch: boolean = false
  @Param hasCounter: boolean = false
  @Param counterValue: string = ''
  @Param counterDecreaseEnabled: boolean = true
  @Param counterIncreaseEnabled: boolean = true
  @Param checked: boolean = false
  @Param isEnabled: boolean = true
  @Param primaryColor: Color | undefined = undefined
  @Param secondaryColor: Color | undefined = undefined
  @Event action?: () => void
  @BuilderParam suffixBuilderParam?: () => void
  @BuilderParam prefixBuilderParam?: () => void
  @Event switchAction?: (value: boolean) => void
  @Event counterDecreaseAction?: () => void
  @Event counterIncreaseAction?: () => void
  private language: LanguageState = connectLanguageState()

  private primaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(this.leadingImageUrl ? undefined : ThemeConstants.LIST_ROW_TEXT_INDENT)
      .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Regular)
      .fontColor(this.primaryColor ?? (this.destructive ? Color.Red : $r('sys.color.font_primary')))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private secondaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(this.leadingImageUrl ? undefined : ThemeConstants.LIST_ROW_TEXT_INDENT)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private trailingTextModifier(): TextModifier {
    return new TextModifier()
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private cardHeight(): number {
    return this.subtitle ? 60 : 52
  }

  @Builder
  private WrappedSuffixBuilder() {
    Row() {
      if (this.suffixBuilderParam) {
        this.suffixBuilderParam()
      }
    }
    .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_MD })
  }

  @Builder
  private WrappedPrefixBuilder() {
    Row() {
      if (this.prefixBuilderParam) {
        this.prefixBuilderParam()
      }
    }
    .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
  }

  private suffixItem(): SuffixTextAndArrow | SuffixText | SuffixCustomBuilder | SuffixSwitch | undefined {
    if (this.suffixBuilderParam) {
      return new SuffixCustomBuilder(() => {
        this.WrappedSuffixBuilder()
      })
    }

    if (this.hasSwitch) {
      return new SuffixSwitch({
        isCheck: this.checked,
        selectColor: ThemeConstants.BRAND_PRIMARY,
        enable: this.isEnabled,
        onChange: (value: boolean) => {
          if (this.isEnabled && this.switchAction) {
            this.switchAction(value)
          }
        }
      })
    }
    if (this.hasCounter) {
      return new SuffixCustomBuilder(() => {
        this.CounterSuffix()
      })
    }
    if (this.count >= 0) {
      return new SuffixTextAndArrow({ text: `${this.count}` }, { color: Color.Gray })
    }
    if (this.trailingText) {
      if (this.trailingDropdown) {
        return new SuffixCustomBuilder(() => {
          this.DropdownSuffix()
        })
      }
      if (this.showChevron) {
        return new SuffixTextAndArrow({
          text: this.localeAwareResource(this.trailingText),
          modifier: this.trailingTextModifier()
        }, { color: Color.Gray })
      }
      return new SuffixText({
        text: this.localeAwareResource(this.trailingText),
        modifier: this.trailingTextModifier()
      })
    }
    if (this.showChevron) {
      return new SuffixTextAndArrow({ text: `` }, { color: Color.Gray })
    }
    return undefined
  }

  @Builder
  private CounterSuffix() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      this.CounterButton('−', this.counterDecreaseEnabled, () => {
        if (this.counterDecreaseAction) {
          this.counterDecreaseAction()
        }
      })
      Text(this.counterValue)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .width(44)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.CounterButton('+', this.counterIncreaseEnabled, () => {
        if (this.counterIncreaseAction) {
          this.counterIncreaseAction()
        }
      })
    }
    .alignItems(VerticalAlign.Center)
    .opacity(this.isEnabled ? 1.0 : 0.45)
    .padding({ right: ThemeConstants.SPACE_MD })
  }

  @Builder
  private CounterButton(label: string, enabled: boolean, action: () => void) {
    Button() {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
        .textAlign(TextAlign.Center)
        .width('100%')
    }
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .width(32)
      .height(30)
      .enabled(enabled && this.isEnabled)
      .opacity(enabled ? 1.0 : 0.45)
      .onClick(action)
  }

  @Builder
  private DropdownSuffix() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.localeAwareResource(this.trailingText))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_tertiary')])
        .padding({ left: 4, right: 12 })
    }
    .alignItems(VerticalAlign.Center)
  }

  private prefixItem(): PrefixImage | PrefixCustomBuilder | undefined {
    if (this.prefixBuilderParam) {
      return new PrefixCustomBuilder(() => {
        this.WrappedPrefixBuilder()
      })
    }

    const imageUrl = ImageUtils.avatarUrl(this.leadingImageUrl)
    if (imageUrl) {
      return new PrefixImage({
        image: imageUrl,
        modifier: new ImageModifier()
          .alt($r('sys.media.ohos_app_icon'))
      })
    }
    return undefined
  }

  @Builder
  private RowContent() {
    HdsListItemCard({
      textItem: {
        primaryText: {
          text: this.localeAwareResource(this.title),
          modifier: this.primaryTextModifier()
        },
        secondaryText: this.subtitle ? {
          text: this.localeAwareResource(this.subtitle),
          modifier: this.secondaryTextModifier()
        } : undefined
      },
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      prefixItem: this.prefixItem(),
      suffixItem: this.suffixItem(),
      cardHeight: this.cardHeight(),
      cardBackgroundColor: Color.Transparent,
      cardBorderRadius: ThemeConstants.LIST_ROW_RADIUS,
      hoverBorderRadius: ThemeConstants.LIST_ROW_RADIUS,
      enable: this.hasSwitch ? true : this.isEnabled,
      onClick: () => {
        if (this.isEnabled && this.action) {
          this.action()
        }
      }
    })
  }

  build() {
    Column() {
      this.RowContent()
    }
    .width('100%')
    .opacity(this.isEnabled ? 1.0 : 0.4)
  }

  private localeAwareResource(resource: ResourceStr): ResourceStr {
    if (this.language.effectiveLocale.length >= 0) {
      return resource
    }
    return resource
  }
}
