import { HdsListItemCard, PrefixImage, SuffixCustomBuilder, SuffixText, SuffixTextAndArrow } from '@kit.UIDesignKit'
import { ImageModifier, TextModifier } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ImageUtils } from '../utils/ImageUtils'

@Component
export struct ConciseListRow {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop trailingText: string = ''
  @Prop leadingImageUrl: string = ''
  @Prop count: number = -1
  @Prop destructive: boolean = false
  @Prop showChevron: boolean = true
  @Prop trailingDropdown: boolean = false
  @Prop hasSwitch: boolean = false
  @Prop checked: boolean = false
  @Prop isEnabled: boolean = true
  primaryColor?: Color
  secondaryColor?: Color
  action?: () => void
  switchAction?: (value: boolean) => void

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

  private suffixItem(): SuffixTextAndArrow | SuffixText | SuffixCustomBuilder | undefined {
    if (this.hasSwitch) {
      return new SuffixCustomBuilder(() => {
        this.SwitchSuffix()
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
          text: this.trailingText,
          modifier: this.trailingTextModifier()
        }, { color: Color.Gray })
      }
      return new SuffixText({
        text: this.trailingText,
        modifier: this.trailingTextModifier()
      })
    }
    if (this.showChevron) {
      return new SuffixTextAndArrow({ text: `` }, { color: Color.Gray })
    }
    return undefined
  }

  @Builder
  private SwitchSuffix() {
    Toggle({ type: ToggleType.Switch, isOn: this.checked })
      .selectedColor(ThemeConstants.BRAND_PRIMARY)
      .enabled(this.isEnabled)
      .opacity(this.isEnabled ? 1.0 : 0.45)
      .onChange((value: boolean) => {
        if (!this.isEnabled) {
          return
        }
        if (this.switchAction) {
          this.switchAction(value)
        }
      })
  }

  @Builder
  private DropdownSuffix() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      Text(this.trailingText)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontColor([$r('sys.color.font_tertiary')])
        .padding({left:4, right: 12})
    }
    .alignItems(VerticalAlign.Center)
  }

  private prefixItem(): PrefixImage | undefined {
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
          text: this.title,
          modifier: this.primaryTextModifier()
        },
        secondaryText: this.subtitle ? {
          text: this.subtitle,
          modifier: this.secondaryTextModifier()
        } : undefined
      },
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      prefixItem: this.prefixItem(),
      suffixItem: this.suffixItem(),
      cardHeight: this.subtitle ? 60 : 52,
      cardBackgroundColor: Color.Transparent,
      cardBorderRadius: ThemeConstants.LIST_ROW_RADIUS,
      hoverBorderRadius: ThemeConstants.LIST_ROW_RADIUS,
      enable: this.isEnabled,
      onClick: () => {
        if (this.action) {
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
}
