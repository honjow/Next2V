import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  ConciseListRow,
  GroupedListSection,
  ListDivider as SharedListDivider,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  ThemeConstants
} from 'shared'

interface AboutInfoRow {
  label: string
  value: string
}

@Component
export struct AboutPage {
  private readonly appName: string = 'Next2V'
  private readonly appVersion: string = '0.1.0'
  private readonly projectUrl: string = 'https://github.com/honjow/Next2V'
  private readonly licenseUrl: string = 'https://github.com/honjow/Next2V'
  private readonly developerName: string = 'honjow'

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          this.AppHeader()
        }

        ListItem() {
          this.SectionHeader('应用信息')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.AppInfoSection()
        }

        ListItem() {
          this.SectionHeader('项目')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.ProjectSection()
        }

        ListItem() {
          this.SectionHeader('开源许可')
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
      Text('HarmonyOS 原生 V2EX 客户端')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Text(`版本 ${this.appVersion}`)
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
      }, (row: AboutInfoRow) => row.label)
    }
  }

  @Builder
  ProjectSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '项目地址',
        subtitle: this.projectUrl,
        action: () => {
          this.openInSystemBrowser(this.projectUrl)
        }
      })
      this.SettingsDivider()
      ConciseListRow({
        title: '开发者',
        trailingText: this.developerName,
        showChevron: false
      })
    }
  }

  @Builder
  LicenseSection() {
    GroupedListSection() {
      ConciseListRow({
        title: '源代码许可证',
        trailingText: 'MIT License',
        action: () => {
          this.openInSystemBrowser(this.licenseUrl)
        }
      })
      this.SettingsDivider()
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text('Next2V 是面向 V2EX 的第三方客户端。')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
        Text('应用源代码按 MIT License 开源；V2EX 名称、标识和内容归其各自权利人所有。')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(ThemeConstants.SPACE_LG)
    }
  }

  @Builder
  SectionHeader(title: string) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  private appInfoRows(): AboutInfoRow[] {
    return [
      { label: '应用名称', value: this.appName },
      { label: '平台', value: 'HarmonyOS' }
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
        promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => {
        })
      })
  }
}
