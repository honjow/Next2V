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
 * Image-upload configuration: pick the active host (ImgBB / S.EE / Imgur) and set its credential. Each
 * host keeps its own credential; switching the radio persists the active choice immediately (so the editor
 * uses it), while the credential field is saved by the Save button. Imgur is kept only for users who hold a
 * Client-ID from before Imgur closed new app registration.
 */
@ComponentV2
export struct ImageUploadSettingsPage {
  // Live config mirror. Read in build() (the "configured" subtitles + the active provider) so the page
  // reflects saves; this page is the sole writer.
  private image: ImageUploadState = connectImageUpload();
  @Local private selectedProvider: string = 'imgbb';
  // The credential field for the currently selected provider; reseeded whenever the provider changes.
  @Local private credentialText: string = '';

  aboutToAppear(): void {
    this.selectedProvider = ImageUploadSettings.normalizeProvider(this.image.provider)
    this.credentialText = this.storedCredential(this.selectedProvider)
  }

  build() {
    Column() {
      SecondaryListScaffold({ includeKeyboardPadding: true }) {
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.image_upload_provider_section') })
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
      this.ProviderRow(ImageUploadSettings.PROVIDER_IMGBB, $r('app.string.image_upload_provider_imgbb'))
      this.ProviderRow(ImageUploadSettings.PROVIDER_SMMS, $r('app.string.image_upload_provider_smms'))
      this.ProviderRow(ImageUploadSettings.PROVIDER_IMGUR, $r('app.string.image_upload_imgur_section'))
    }
  }

  @Builder
  ProviderRow(id: string, label: ResourceStr) {
    ConciseListRow({
      title: label,
      subtitle: this.configuredSubtitle(id),
      showChevron: false,
      prefixBuilderParam: (): void => this.ProviderRadio(id),
      action: () => {
        this.selectProvider(id)
      },
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
            onTextChange: (value: string) => {
              this.credentialText = value
            },
          }).width('100%')
        }.width('100%')
        Button($r('app.string.common_save'))
          .type(ButtonType.Normal)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .width('100%')
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .onClick(() => {
            this.save()
          })
      }.width('100%')
    }
  }

  @Builder
  LinksSection() {
    GroupedListSection() {
      if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGBB) {
        ConciseListRow({
          title: $r('app.string.image_upload_imgbb_get_key'),
          showChevron: true,
          action: () => {
            this.openUrl('https://api.imgbb.com/')
          },
        })
      } else if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
        ConciseListRow({
          title: $r('app.string.image_upload_smms_get_token'),
          showChevron: true,
          action: () => {
            this.openUrl('https://s.ee/user/developers')
          },
        })
      }
    }
  }

  private providerLabel(id: string): ResourceStr {
    if (id === ImageUploadSettings.PROVIDER_SMMS) {
      return $r('app.string.image_upload_provider_smms')
    }
    if (id === ImageUploadSettings.PROVIDER_IMGUR) {
      return $r('app.string.image_upload_imgur_section')
    }
    return $r('app.string.image_upload_provider_imgbb')
  }

  private providerHint(): ResourceStr {
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
      return $r('app.string.image_upload_smms_hint')
    }
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGUR) {
      return $r('app.string.image_upload_imgur_hint')
    }
    return $r('app.string.image_upload_imgbb_hint')
  }

  private credentialLabel(): ResourceStr {
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
      return $r('app.string.image_upload_smms_token_label')
    }
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGUR) {
      return $r('app.string.image_upload_imgur_clientid_label')
    }
    return $r('app.string.image_upload_imgbb_apikey_label')
  }

  private credentialPlaceholder(): ResourceStr {
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_SMMS) {
      return $r('app.string.image_upload_smms_token_placeholder')
    }
    if (this.selectedProvider === ImageUploadSettings.PROVIDER_IMGUR) {
      return $r('app.string.image_upload_imgur_clientid_placeholder')
    }
    return $r('app.string.image_upload_imgbb_apikey_placeholder')
  }

  private configuredSubtitle(id: string): ResourceStr {
    return this.storedCredential(id)
      ? $r('app.string.image_upload_summary_configured')
      : $r('app.string.proxy_not_configured')
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
      imgbbApiKey:
        provider === ImageUploadSettings.PROVIDER_IMGBB ? activeCredential : this.image.imgbbApiKey,
      smmsToken:
        provider === ImageUploadSettings.PROVIDER_SMMS ? activeCredential : this.image.smmsToken,
      imgurClientId:
        provider === ImageUploadSettings.PROVIDER_IMGUR
          ? activeCredential
          : this.image.imgurClientId,
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    ImageUploadSettings.save(context, snapshot)
      .then(() => {
        if (notify) {
          this.showToast(AppStrings.text($r('app.string.common_saved'), 'Saved'))
        }
      })
      .catch((error: Error) => {
        if (notify) {
          this.showToast(
            error.message || AppStrings.text($r('app.string.common_save_failed'), 'Save failed'),
          )
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
