import { bundleManager, common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AppStrings,
  ConciseListRow,
  GroupedListSection,
  ListDivider as SharedListDivider,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  ThemeConstants,
  translateApiError
} from 'shared'

interface AboutInfoRow {
  key: string
  label: ResourceStr
  value: string
}

@ComponentV2
export struct AboutPage {
  private readonly appName: string = 'Next2V'
  @Local private appVersion: string = ''
  private readonly projectUrl: string = 'https://github.com/honjow/Next2V'
  private readonly licenseUrl: string = 'https://github.com/honjow/Next2V'
  private readonly v2nextUrl: string = 'https://github.com/zyronon/V2Next'
  private readonly developerName: string = 'honjow'

  aboutToAppear(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      .then((info) => {
        this.appVersion = info.versionName
      })
      .catch((error: Error) => {
        console.error('get bundle info failed: ' + error.message)
      })
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          this.AppHeader()
        }

        ListItem() {
          this.SectionHeader($r('app.string.about_app_info'))
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.AppInfoSection()
        }

        ListItem() {
          this.SectionHeader($r('app.string.about_project'))
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.ProjectSection()
        }

        ListItem() {
          this.SectionHeader($r('app.string.about_acknowledgements'))
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.AcknowledgementSection()
        }

        ListItem() {
          this.SectionHeader($r('app.string.about_open_source_license'))
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.LicenseSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  AppHeader() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.appName)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(AppStrings.text($r('app.string.about_tagline'), 'Native HarmonyOS V2EX client'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Text(AppStrings.format(AppStrings.text($r('app.string.about_version_format'), 'Version {0}'), [this.appVersion]))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_XL,
      bottom: ThemeConstants.SPACE_LG
    })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder
  AppInfoSection() {
    GroupedListSection() {
      ForEach(this.appInfoRows(), (row: AboutInfoRow, index: number) => {
        ConciseListRow({
          title: row.label,
          trailingText: row.value,
          showChevron: false
        })
        if (index < this.appInfoRows().length - 1) {
          this.SettingsDivider()
        }
      }, (row: AboutInfoRow) => row.key)
    }
  }

  @Builder
  ProjectSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.about_project_url'),
        subtitle: this.projectUrl,
        action: () => {
          this.openInSystemBrowser(this.projectUrl)
        }
      })
      this.SettingsDivider()
      ConciseListRow({
        title: $r('app.string.about_developer'),
        trailingText: this.developerName,
        showChevron: false
      })
    }
  }

  @Builder
  AcknowledgementSection() {
    GroupedListSection() {
      ConciseListRow({
        title: 'zyronon/V2Next',
        subtitle: this.v2nextUrl,
        action: () => {
          this.openInSystemBrowser(this.v2nextUrl)
        }
      })
      this.SettingsDivider()
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text($r('app.string.about_v2next_ack'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(ThemeConstants.SPACE_LG)
    }
  }

  @Builder
  LicenseSection() {
    GroupedListSection() {
      ConciseListRow({
        title: $r('app.string.about_source_license'),
        trailingText: 'MIT License',
        action: () => {
          this.openInSystemBrowser(this.licenseUrl)
        }
      })
      this.SettingsDivider()
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text($r('app.string.about_third_party_client'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text($r('app.string.about_copyright'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(ThemeConstants.SPACE_LG)
    }
  }

  @Builder
  SectionHeader(title: ResourceStr) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  private appInfoRows(): AboutInfoRow[] {
    return [
      { key: 'appName', label: $r('app.string.about_app_name'), value: this.appName },
      { key: 'platform', label: $r('app.string.about_platform'), value: 'HarmonyOS' }
    ]
  }

  private openInSystemBrowser(url: string): void {
    const target = (url || '').trim()
    if (!target) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: target }
    context.startAbility(want)
      .catch((error: Error) => {
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {
        })
      })
  }
}
