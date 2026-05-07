import {
  HdsListItemCard,
  IconSize,
  PrefixCustomBuilder,
  PrefixIcon,
  PrefixImage,
  SuffixBadgeAndArrow,
  SuffixSwitch,
  SuffixTextAndArrow
} from '@kit.UIDesignKit'
import { TextModifier } from '@kit.ArkUI'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct ConciseListRow {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop count: number = -1
  @Prop destructive: boolean = false
  @Prop showChevron: boolean = true
  @Prop hasSwitch: boolean = false
  @Prop checked: boolean = false
  primaryColor?: Color
  secondaryColor?: Color
  action?: () => void
  switchAction?: (value: boolean) => void

  @LocalBuilder
  emptyPlaceholder() {
    Blank(0)
  }

  private primaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(8)
      .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Regular)
      .fontColor(this.primaryColor ?? (this.destructive ? Color.Red : $r('sys.color.font_primary')))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private secondaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(8)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private suffixItem(): SuffixBadgeAndArrow | SuffixSwitch | SuffixTextAndArrow | undefined {
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
    // if (this.count >= 0 && this.showChevron) {
    //   return new SuffixTextAndArrow({ text: `${this.count}` })
    // }
    if (this.count >= 0 ) {
      return new SuffixTextAndArrow({ text: `${this.count}` }, { color: Color.Gray })
    }
    if (this.showChevron) {
      return new SuffixTextAndArrow({ text: `` }, { color: Color.Gray })
    }
    return undefined
  }

  private prefixItem(): PrefixCustomBuilder | PrefixImage | PrefixIcon | undefined {
    return new PrefixCustomBuilder(this.emptyPlaceholder)
  }

  build() {
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
        // prefixItem: this.prefixItem(),
        suffixItem: this.suffixItem(),
        cardHeight: this.subtitle ? 60 : 52,
        cardBackgroundColor: Color.Transparent,
        cardBorderRadius: ThemeConstants.RADIUS_MD - 3,
        hoverBorderRadius: ThemeConstants.RADIUS_MD - 3,
        onClick: () => {
          if (this.action) {
            this.action()
          }
        }
      })
  }
}
