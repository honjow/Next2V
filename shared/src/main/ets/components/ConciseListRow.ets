import { HdsListItemCard, PrefixImage, SuffixSwitch, SuffixText, SuffixTextAndArrow } from '@kit.UIDesignKit'
import { ImageModifier, TextModifier } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'
import { hilog } from '@kit.PerformanceAnalysisKit'

@Component
export struct ConciseListRow {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop trailingText: string = ''
  @Prop leadingImageUrl: string = ''
  @Prop count: number = -1
  @Prop destructive: boolean = false
  @Prop showChevron: boolean = true
  @Prop hasSwitch: boolean = false
  @Prop checked: boolean = false
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

  private suffixItem(): SuffixSwitch | SuffixTextAndArrow | SuffixText | undefined {
    if (this.hasSwitch) {
      return new SuffixSwitch({
        isCheck: this.checked,
        selectColor: ThemeConstants.BRAND_PRIMARY,
        onChange: (value: boolean) => {
          if (this.switchAction) {
            this.switchAction(value)
          }
        }
      })
    }
    if (this.count >= 0) {
      return new SuffixTextAndArrow({ text: `${this.count}` }, { color: Color.Gray })
    }
    if (this.trailingText) {
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

  private prefixItem(): PrefixImage | undefined {
    hilog.info(0x0000, 'ConciseListRow', 'Creating PrefixImage with url: %{public}s', this.leadingImageUrl);
    if (this.leadingImageUrl) {
      return new PrefixImage({
        image: this.leadingImageUrl,
        modifier: new ImageModifier()
          // .padding(6)
          .alt($r('sys.media.ohos_app_icon'))
      })
    }
    return undefined
  }

  private hasLeadingImage(): boolean {
    return (this.leadingImageUrl || '').trim().length > 0
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
      onClick: () => {
        if (this.action) {
          this.action()
        }
      }
    })
  }

  build() {
    this.RowContent()
  }
}
