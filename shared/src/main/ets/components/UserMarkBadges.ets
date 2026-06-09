import { LengthMetrics } from '@kit.ArkUI'
import { UserMarkSettings, type UserMarkLabel } from '../settings/UserMarkSettings'
import { connectUserMarks, UserMarkState } from '../state/UserMarkState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { defaultSheetOptions } from '../utils/BindSheetHelper'
import { AppModalScaffold } from './AppModalScaffold'
import { GroupedListSection } from './GroupedListSection'

@ComponentV2
export struct UserMarkBadgeRow {
  @Param username: string = ''
  @Param fontSize: number = ThemeConstants.FONT_SIZE_TINY
  @Param visibleLimit: number = 0
  @Param showOverflow: boolean = true
  @Param maxBadgeWidth: number = 92
  @Local private sheetVisible: boolean = false
  private marks: UserMarkState = connectUserMarks()

  build() {
    // Render nothing when this user has no visible marks. An empty Row still occupies a child slot in
    // the parent name Row, and the parent's `space` reserves a phantom gap before it — which pushed any
    // following badge (e.g. OP) twice as far from PRO as PRO sits from the name.
    if (this.hasVisibleBadge()) {
      Row() {
        if (this.marks.combinedBadge && this.visibleLabels().length > 0) {
          this.CombinedBadge()
        } else {
          this.SeparateBadges()
        }
      }
      .alignItems(VerticalAlign.Center)
      .bindSheet(
        $$this.sheetVisible,
        this.AllMarksSheet(),
        defaultSheetOptions(SheetSize.MEDIUM, () => {
          this.sheetVisible = false
        }),
      )
    }
  }

  private hasVisibleBadge(): boolean {
    return this.visibleLabels().length > 0 || this.overflowCount() > 0
  }

  @Builder
  private SeparateBadges() {
    Row({ space: ThemeConstants.SPACE_XS }) {
      ForEach(
        this.visibleLabels(),
        (label: UserMarkLabel) => {
          this.Badge(label)
        },
        (label: UserMarkLabel) => label.id,
      )
      if (this.overflowCount() > 0) {
        this.MoreBadge()
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private CombinedBadge() {
    Row({ space: 0 }) {
      ForEach(
        this.visibleLabels(),
        (label: UserMarkLabel) => {
          this.CombinedBadgeSegment(label)
        },
        (label: UserMarkLabel) => label.id,
      )
      if (this.overflowCount() > 0) {
        this.CombinedMoreSegment()
      }
    }
    .clip(true)
    .borderRadius(ThemeConstants.RADIUS_SM)
    .onClick(() => {
      this.openSheet()
    })
  }

  @Builder
  private Badge(label: UserMarkLabel) {
    Text(label.name)
      .fontSize(this.fontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(UserMarkSettings.textColorForBackground(label.color))
      .lineHeight(this.fontSize + 3)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ maxWidth: this.maxBadgeWidth })
      .padding({
        left: ThemeConstants.SPACE_XS + 2,
        right: ThemeConstants.SPACE_XS + 2,
        top: 1,
        bottom: 1
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor(label.color)
      .onClick(() => {
        this.openSheet()
      })
  }

  @Builder
  private CombinedBadgeSegment(label: UserMarkLabel) {
    Text(label.name)
      .fontSize(this.fontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor(UserMarkSettings.textColorForBackground(label.color))
      .lineHeight(this.fontSize + 3)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ maxWidth: this.maxBadgeWidth })
      .padding({
        left: ThemeConstants.SPACE_XS + 2,
        right: ThemeConstants.SPACE_XS + 2,
        top: 1,
        bottom: 1
      })
      .backgroundColor(label.color)
  }

  @Builder
  private CombinedMoreSegment() {
    Text(`+${this.overflowCount()}`)
      .fontSize(this.fontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .lineHeight(this.fontSize + 3)
      .padding({
        left: ThemeConstants.SPACE_XS + 2,
        right: ThemeConstants.SPACE_XS + 2,
        top: 1,
        bottom: 1
      })
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
  }

  @Builder
  private MoreBadge() {
    Text(`+${this.overflowCount()}`)
      .fontSize(this.fontSize)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .lineHeight(this.fontSize + 3)
      .padding({
        left: ThemeConstants.SPACE_XS + 2,
        right: ThemeConstants.SPACE_XS + 2,
        top: 1,
        bottom: 1
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => {
        this.openSheet()
      })
  }

  @Builder
  private SheetBadge(label: UserMarkLabel) {
    Text(label.name)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontWeight(FontWeight.Medium)
      .fontColor(UserMarkSettings.textColorForBackground(label.color))
      .lineHeight(20)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .constraintSize({ maxWidth: 160 })
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: 4,
        bottom: 4
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor(label.color)
  }

  @Builder
  private AllMarksSheet() {
    AppModalScaffold({
      title: $r('app.string.user_mark_sheet_title'),
      closeAction: () => {
        this.sheetVisible = false
      },
    }) {
      ListItem() {
        GroupedListSection({ inset: ThemeConstants.SPACE_LG, radius: ThemeConstants.RADIUS_CARD }) {
          if (this.allLabels().length === 0) {
            Text($r('app.string.user_mark_empty'))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(ThemeConstants.SPACE_LG)
          } else {
            Flex({
              wrap: FlexWrap.Wrap,
              space: {
                main: LengthMetrics.vp(ThemeConstants.SPACE_SM),
                cross: LengthMetrics.vp(ThemeConstants.SPACE_SM)
              }
            }) {
              ForEach(
                this.allLabels(),
                (label: UserMarkLabel) => {
                  this.SheetBadge(label)
                },
                (label: UserMarkLabel) => label.id,
              )
            }
            .width('100%')
          }
        }
      }
    }
  }

  private openSheet(): void {
    if (this.allLabels().length > 0) {
      this.sheetVisible = true
    }
  }

  private visibleLabels(): UserMarkLabel[] {
    return UserMarkSettings.visibleLabelsForUsername(
      this.username,
      this.marks.labelsJson,
      this.marks.assignmentsJson,
      this.effectiveDisplayLimit(),
    )
  }

  private allLabels(): UserMarkLabel[] {
    return UserMarkSettings.allLabelsForUsername(this.username, this.marks.labelsJson, this.marks.assignmentsJson)
  }

  private overflowCount(): number {
    if (!this.showOverflow) {
      return 0
    }
    return UserMarkSettings.overflowCountForUsername(
      this.username,
      this.marks.labelsJson,
      this.marks.assignmentsJson,
      this.effectiveDisplayLimit(),
    )
  }

  private effectiveDisplayLimit(): number {
    if (this.visibleLimit > 0) {
      return Math.max(
        UserMarkSettings.MIN_DISPLAY_LIMIT,
        Math.min(UserMarkSettings.MAX_DISPLAY_LIMIT, Math.floor(this.visibleLimit)),
      )
    }
    return this.marks.displayLimit
  }
}
