import {
  HdsListItemCard,
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
  action?: () => void
  switchAction?: (value: boolean) => void

  private primaryTextModifier(): TextModifier {
    return new TextModifier()
      .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Regular)
      .fontColor(this.destructive ? Color.Red : $r('sys.color.font_primary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private secondaryTextModifier(): TextModifier {
    return new TextModifier()
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor($r('sys.color.font_secondary'))
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
    if (this.count >= 0 && this.showChevron) {
      return new SuffixTextAndArrow({ text: `${this.count}` })
    }
    if (this.count >= 0) {
      return new SuffixTextAndArrow({ text: `${this.count}` }, { color: Color.Transparent })
    }
    if (this.showChevron) {
      return new SuffixBadgeAndArrow()
    }
    return undefined
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
      suffixItem: this.suffixItem(),
      cardHeight: this.subtitle ? 60 : 48,
      cardBackgroundColor: Color.Transparent,
      cardBorderRadius: ThemeConstants.RADIUS_MD - 4,
      hoverBorderRadius: ThemeConstants.RADIUS_MD - 4,
      onClick: () => {
        if (this.action) {
          this.action()
        }
      }
    })
  }
}
