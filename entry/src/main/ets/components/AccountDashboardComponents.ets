import { AccountCoinIcon } from './AccountCoinIcon'
import {
  AppStrings,
  Avatar,
  DateUtils,
  ThemeConstants,
  V2exBalance
} from 'shared'

@ComponentV2
export struct AccountCoinBalance {
  @Param balance: V2exBalance | null = null
  @Param fallbackText: ResourceStr = ''

  build() {
    if (this.balance) {
      if (this.balance.gold > 0 || this.balance.silver > 0 || this.balance.bronze > 0) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          if (this.balance.gold > 0) {
            this.CoinAmount('#B97818', '#F6D77A', '#D59A24', this.balance.gold)
          }
          if (this.balance.silver > 0) {
            this.CoinAmount('#5C6978', '#F6FAFF', '#9FAFC0', this.balance.silver)
          }
          if (this.balance.bronze > 0) {
            this.CoinAmount('#7E4B27', '#D99B65', '#A66B3D', this.balance.bronze)
          }
        }
        .alignItems(VerticalAlign.Center)
        .height(22)
      }
    } else {
      if (this.fallbackText) {
        Text(this.fallbackText)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
  }

  @Builder private CoinAmount(rimColor: string, faceColor: string, edgeColor: string, amount: number) {
    Row({ space: 4 }) {
      AccountCoinIcon({ rimColor, faceColor, edgeColor })
      Text(this.formatCoinAmount(amount))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .alignItems(VerticalAlign.Center)
  }

  private formatCoinAmount(amount: number): string {
    if (amount > 0 && amount < 1) {
      return amount.toFixed(2)
    }
    return `${amount}`
  }
}

@ComponentV2
export struct AccountDetailHeaderCard {
  @Param avatarUrl: string = ''
  @Param username: string = ''
  @Param balance: V2exBalance | null = null
  @Param fallbackText: ResourceStr = ''
  @Param sessionError: string = ''
  @Param accountMetaError: string = ''
  @Param dailyMissionMessage: ResourceStr = ''

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Avatar({ url: this.avatarUrl, avatarSize: 72 })
      Text(this.username || $r('app.string.account_v2ex_user'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      this.MetaBlock()
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder private MetaBlock() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      AccountCoinBalance({ balance: this.balance, fallbackText: this.fallbackText })
      if (this.sessionError) {
        this.MetaText(this.sessionError, true)
      } else if (this.accountMetaError) {
        this.MetaText(this.accountMetaError, true)
      } else if (this.dailyMissionMessage) {
        this.MetaText(this.dailyMissionMessage, false)
      } else {
        Blank().height(ThemeConstants.FONT_SIZE_CAPTION)
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height(52)
  }

  @Builder private MetaText(message: ResourceStr, isError: boolean) {
    Text(message)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(isError ? Color.Red : $r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}

@ComponentV2
export struct AccountSignedInCard {
  @Param avatarUrl: string = ''
  @Param username: string = ''
  @Param balance: V2exBalance | null = null
  @Param fallbackText: ResourceStr = ''
  @Param dailyMissionText: ResourceStr = ''
  @Param dailyMissionEnabled: boolean = false
  @Event redeemDailyMission?: () => void
  @Event openDetail?: () => void

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({ url: this.avatarUrl, avatarSize: 54 })
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.username || $r('app.string.account_v2ex_user'))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        AccountCoinBalance({ balance: this.balance, fallbackText: this.fallbackText })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(this.dailyMissionText)
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(30)
        .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
        .type(ButtonType.Normal)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .fontColor(this.dailyMissionEnabled ? Color.White : $r('sys.color.font_secondary'))
        .backgroundColor(this.dailyMissionEnabled ? ThemeConstants.BRAND_PRIMARY :
          $r('sys.color.ohos_id_color_button_normal'))
        .enabled(this.dailyMissionEnabled)
        .onClick(() => {
          if (this.redeemDailyMission) {
            this.redeemDailyMission()
          }
        })

      if (this.openDetail) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(ThemeConstants.ICON_SIZE_SM)
          .fontColor([$r('sys.color.font_secondary')])
      }
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .onClick(() => {
      if (this.openDetail) {
        this.openDetail()
      }
    })
  }
}

@ComponentV2
export struct AccountTokenSummary {
  @Param scope: string = ''
  @Param expiration: number = 0
  @Param lastUsed: number = 0

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.scope) {
        Text($r('app.string.account_token_scope_arg', this.scope))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.expiration > 0) {
        Text($r('app.string.account_token_expiration_arg', DateUtils.toDateString(this.expiration)))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.lastUsed > 0) {
        Text($r('app.string.account_token_last_used_arg', DateUtils.toDateString(this.lastUsed)))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
  }
}

@ComponentV2
export struct AccountRateLimitSummary {
  @Param limit: number = 0
  @Param remaining: number = 0
  @Param resetAt: number = 0
  @Param updatedAt: number = 0

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      if (this.limit > 0) {
        Text($r('app.string.account_api_quota_arg', `${this.remaining}`, `${this.limit}`))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.resetAt > 0) {
        Text($r('app.string.account_rate_limit_reset_arg', DateUtils.toDateString(this.resetAt)))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.updatedAt > 0) {
        Text($r('app.string.updated_at', DateUtils.toDateString(this.updatedAt)))
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
  }
}
