import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AppStrings,
  AppTextField,
  ConciseListRow,
  connectImageUpload,
  GroupedListSection,
  ImageUploadSettings,
  ImageUploadState,
  SecondaryListScaffold,
  ThemeConstants,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'

/**
 * Image-upload configuration. MVP: a single Imgur Client-ID field plus onboarding links. The user's own
 * Client-ID is required — a bundled shared one would get rate-limited (429) across the whole userbase.
 * (The V2EX gallery provider is deferred behind a live endpoint capture.)
 */
@ComponentV2
export struct ImageUploadSettingsPage {
  // Live config mirror; the field seeds clientIdText from it on each push. This page is the sole writer,
  // so no live reactivity to external mirror changes is needed (it is not read in build()).
  private image: ImageUploadState = connectImageUpload()
  @Local private clientIdText: string = ''

  aboutToAppear(): void {
    this.clientIdText = this.image.imgurClientId
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_IMAGE_UPLOAD_IMGUR_SECTION })
        }
        ListItem() {
          this.ConfigSection()
        }
        ListItem() {
          this.LinksSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  ConfigSection() {
    // Form card. Inset SPACE_MD (12) so the field/button content lands on the SAME left edge as the
    // ConciseListRow links below it (their text sits at section-inset 4 + text-indent 8 = 12 from the card
    // edge); SPACE_XL (24) double-inset the content and read as too much side padding.
    GroupedListSection({ inset: ThemeConstants.SPACE_MD, radius: ThemeConstants.RADIUS_CARD }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(AppStrings.R_IMAGE_UPLOAD_IMGUR_HINT)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(AppStrings.R_IMAGE_UPLOAD_IMGUR_CLIENTID_LABEL)
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
          AppTextField({
            text: this.clientIdText,
            placeholder: AppStrings.R_IMAGE_UPLOAD_IMGUR_CLIENTID_PLACEHOLDER,
            onTextChange: (value: string) => { this.clientIdText = value },
          })
            .width('100%')
        }
        .width('100%')
        Button(AppStrings.R_COMMON_SAVE)
          .type(ButtonType.Normal)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .width('100%')
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .onClick(() => { this.save() })
      }
      .width('100%')
    }
  }

  @Builder
  LinksSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.R_IMAGE_UPLOAD_REGISTER_IMGUR,
        showChevron: true,
        action: () => { this.openUrl('https://imgur.com/register') },
      })
      ConciseListRow({
        title: AppStrings.R_IMAGE_UPLOAD_CREATE_APP,
        showChevron: true,
        action: () => { this.openUrl('https://api.imgur.com/oauth2/addclient') },
      })
    }
  }

  private save(): void {
    const clientId = this.clientIdText.trim()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ImageUploadSettings.save(context, { provider: 'imgur', imgurClientId: clientId })
      .then(() => { this.showToast(AppStrings.text(AppStrings.R_COMMON_SAVED, 'Saved')) })
      .catch((error: Error) => { this.showToast(error.message || AppStrings.text(AppStrings.R_COMMON_SAVE_FAILED, 'Save failed')) })
  }

  private openUrl(url: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: url }
    context.startAbility(want).catch((_error: Error) => {})
  }

  private showToast(message: string): void {
    promptAction.openToast({ message }).catch((_error: Error) => {})
  }
}
