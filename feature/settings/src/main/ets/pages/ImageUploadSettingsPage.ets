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
  type ImageUploadProviderId,
  type ImageUploadSettingsSnapshot,
} from 'shared'
import { SettingsSectionHeader } from '../components/SettingsPageComponents'

/**
 * Image-upload configuration: pick the active host (ImgBB / sm.ms / Imgur) and set its credential. Each
 * host keeps its own credential; switching the radio persists the active choice immediately (so the editor
 * uses it), while the credential field is saved by the Save button. Imgur is kept only for users who hold a
 * Client-ID from before Imgur closed new app registration.
 */
@ComponentV2
export struct ImageUploadSettingsPage {
  // Live config mirror. Read in build() (the "configured" subtitles + the active provider) so the page
  // reflects saves; this page is the sole writer.
  private image: ImageUploadState = connectImageUpload()
  @Local private selectedProvider: string = 'imgbb'
  // The credential field for the currently selected provider; reseeded whenever the provider changes.
  @Local private credentialText: string = ''

  aboutToAppear(): void {
    this.selectedProvider = ImageUploadSettings.normalizeProvider(this.image.provider)
    this.credentialText = this.storedCredential(this.selectedProvider)
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_IMAGE_UPLOAD_PROVIDER_SECTION })
        }
        ListItem() {
          this.ProviderPickerSection()
        }
        ListItem() {
          SettingsSectionHeader({ title: this.providerLabel(this.selectedProvider) })
        }
        ListItem() {
          this.ConfigSection()
        }
        if (this.selectedProvider !== ImageUploadSettings.PROVIDER_IMGUR) {
          ListItem() {
            this.LinksSection()
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  ProviderPickerSection() {
    GroupedListSection() {
      this.ProviderRow(ImageUploadSettings.PROVIDER_IMGBB, AppStrings.R_IMAGE_UPLOAD_PROVIDER_IMGBB)
      this.ProviderRow(ImageUploadSettings.PROVIDER_SMMS, AppStrings.R_IMAGE_UPLOAD_PROVIDER_SMMS)
      this.ProviderRow(ImageUploadSettings.PROVIDER_IMGUR, AppStrings.R_IMAGE_UPLOAD_IMGUR_SECTION)
    }
  }

  @Builder
  ProviderRow(id: string, label: ResourceStr) {
    ConciseListRow({
      title: label,
      subtitle: this.configuredSubtitle(id),
      showChevron: false,
      prefixBuilderParam: (): void => this.ProviderRadio(id),
      action: () => { this.selectProvider(id) },
    })
  }

  @Builder
  ProviderRadio(id: string) {
    Radio({ value: id, group: 'imageUploadProvider' })
      .checked(this.selectedProvider === id)
      .onChange((checked: boolean) => {
        if (checked) {
          this.selectProvider(id)
        }
      })
  }

  @Builder
  ConfigSection() {
    // Inset SPACE_MD so the field/button align with the list rows above (see DomainSettingsPage).
    GroupedListSection({ inset: ThemeConstants.SPACE_MD, radius: ThemeConstants.RADIUS_CARD }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(this.providerHint())
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.credentialLabel())
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
          AppTextField({
            text: this.credentialText,
            placeholder: this.credentialPlaceholder(),
            onTextChange: (value: string) => { this.credentialText = value },
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
      if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGBB) {
        ConciseListRow({
          title: AppStrings.R_IMAGE_UPLOAD_IMGBB_GET_KEY,
          showChevron: true,
          action: () => { this.openUrl('https://api.imgbb.com/') },
        })
      } else if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
        ConciseListRow({
          title: AppStrings.R_IMAGE_UPLOAD_SMMS_GET_TOKEN,
          showChevron: true,
          action: () => { this.openUrl('https://sm.ms/home/apitoken') },
        })
      }
    }
  }

  private providerLabel(id: string): ResourceStr {
    if (id === ImageUploadSettings.PROVIDER_SMMS) {
      return AppStrings.R_IMAGE_UPLOAD_PROVIDER_SMMS
    }
    if (id === ImageUploadSettings.PROVIDER_IMGUR) {
      return AppStrings.R_IMAGE_UPLOAD_IMGUR_SECTION
    }
    return AppStrings.R_IMAGE_UPLOAD_PROVIDER_IMGBB
  }

  private providerHint(): ResourceStr {
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
      return AppStrings.R_IMAGE_UPLOAD_SMMS_HINT
    }
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGUR) {
      return AppStrings.R_IMAGE_UPLOAD_IMGUR_HINT
    }
    return AppStrings.R_IMAGE_UPLOAD_IMGBB_HINT
  }

  private credentialLabel(): ResourceStr {
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
      return AppStrings.R_IMAGE_UPLOAD_SMMS_TOKEN_LABEL
    }
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGUR) {
      return AppStrings.R_IMAGE_UPLOAD_IMGUR_CLIENTID_LABEL
    }
    return AppStrings.R_IMAGE_UPLOAD_IMGBB_APIKEY_LABEL
  }

  private credentialPlaceholder(): ResourceStr {
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
      return AppStrings.R_IMAGE_UPLOAD_SMMS_TOKEN_PLACEHOLDER
    }
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGUR) {
      return AppStrings.R_IMAGE_UPLOAD_IMGUR_CLIENTID_PLACEHOLDER
    }
    return AppStrings.R_IMAGE_UPLOAD_IMGBB_APIKEY_PLACEHOLDER
  }

  private configuredSubtitle(id: string): ResourceStr {
    return this.storedCredential(id) ? AppStrings.R_IMAGE_UPLOAD_SUMMARY_CONFIGURED : $r('app.string.proxy_not_configured')
  }

  private storedCredential(id: string): string {
    if (id === ImageUploadSettings.PROVIDER_SMMS) {
      return this.image.smmsToken
    }
    if (id === ImageUploadSettings.PROVIDER_IMGUR) {
      return this.image.imgurClientId
    }
    return this.image.imgbbApiKey
  }

  // Switch the active provider: reseed the field from that provider's stored credential and persist the
  // choice immediately (unsaved text in the previous provider's field is discarded, as on any tab switch).
  private selectProvider(id: string): void {
    if (this.selectedProvider === id) {
      return
    }
    this.selectedProvider = id
    this.credentialText = this.storedCredential(id)
    // Persist the active-provider choice immediately so the editor follows it; no toast for a mere switch.
    this.persist(this.storedCredential(id), false)
  }

  private save(): void {
    this.persist(this.credentialText.trim(), true)
  }

  private persist(activeCredential: string, notify: boolean): void {
    const provider = ImageUploadSettings.normalizeProvider(this.selectedProvider)
    const snapshot: ImageUploadSettingsSnapshot = {
      provider: provider,
      imgbbApiKey: provider === ImageUploadSettings.PROVIDER_IMGBB ? activeCredential : this.image.imgbbApiKey,
      smmsToken: provider === ImageUploadSettings.PROVIDER_SMMS ? activeCredential : this.image.smmsToken,
      imgurClientId: provider === ImageUploadSettings.PROVIDER_IMGUR ? activeCredential : this.image.imgurClientId,
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ImageUploadSettings.save(context, snapshot)
      .then(() => {
        if (notify) {
          this.showToast(AppStrings.text(AppStrings.R_COMMON_SAVED, 'Saved'))
        }
      })
      .catch((error: Error) => {
        if (notify) {
          this.showToast(error.message || AppStrings.text(AppStrings.R_COMMON_SAVE_FAILED, 'Save failed'))
        }
      })
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
