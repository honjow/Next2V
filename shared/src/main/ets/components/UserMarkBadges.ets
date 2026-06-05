import { LengthMetrics } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
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
  @Local private sheetVisible: boolean = false
  private marks: UserMarkState = connectUserMarks()

  build() {
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
    .bindSheet(
      $$this.sheetVisible,
      this.AllMarksSheet(),
      defaultSheetOptions(SheetSize.MEDIUM, () => {
        this.sheetVisible = false
      }),
    )
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
      .constraintSize({ maxWidth: 92 })
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
  private AllMarksSheet() {
    AppModalScaffold({
      title: AppStrings.R_USER_MARK_SHEET_TITLE,
      closeAction: () => {
        this.sheetVisible = false
      },
    }) {
      ListItem() {
        GroupedListSection({ inset: ThemeConstants.SPACE_LG, radius: ThemeConstants.RADIUS_CARD }) {
          if (this.allLabels().length === 0) {
            Text(AppStrings.R_USER_MARK_EMPTY)
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
                  this.Badge(label)
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
      this.marks.displayLimit,
    )
  }

  private allLabels(): UserMarkLabel[] {
    return UserMarkSettings.allLabelsForUsername(this.username, this.marks.labelsJson, this.marks.assignmentsJson)
  }

  private overflowCount(): number {
    return UserMarkSettings.overflowCountForUsername(
      this.username,
      this.marks.labelsJson,
      this.marks.assignmentsJson,
      this.marks.displayLimit,
    )
  }
}
