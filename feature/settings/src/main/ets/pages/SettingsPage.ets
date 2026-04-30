import { HttpClient, ThemeConstants } from 'shared'

@Component
export struct SettingsPage {
  @State useCoDomain: boolean = false
  private http: HttpClient = HttpClient.getInstance()

  build() {
    NavDestination() {
      List() {
        ListItem() {
          Column() {
            Text('API 域名')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_primary'))
              .fontWeight(FontWeight.Medium)
            Row() {
              Text('当前使用: ')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
              Text(this.useCoDomain ? 'v2ex.co' : 'v2ex.com')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.ohos_id_color_activated'))
            }
            .margin({ top: ThemeConstants.SPACE_XS })

            Row({ space: ThemeConstants.SPACE_MD }) {
              Button('使用 v2ex.com')
                .fontSize(12)
                .type(ButtonType.Normal)
                .borderRadius(8)
                .onClick(() => {
                  this.http.setBaseUrl('https://www.v2ex.com')
                  this.useCoDomain = false
                })
              Button('使用 v2ex.co')
                .fontSize(12)
                .type(ButtonType.Normal)
                .borderRadius(8)
                .onClick(() => {
                  this.http.setBaseUrl('https://www.v2ex.co')
                  this.useCoDomain = true
                })
            }
            .margin({ top: ThemeConstants.SPACE_MD })
          }
          .padding(ThemeConstants.SPACE_LG)
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_MD })
        }

        ListItem() {
          Column() {
            Text('关于 Next2V')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor($r('sys.color.font_primary'))
              .fontWeight(FontWeight.Medium)
            Text('版本 0.1.0')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: ThemeConstants.SPACE_XS })
            Text('基于 ArkTS + ArkUI + HDS 构建的 V2EX 客户端')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ top: 2 })
          }
          .padding(ThemeConstants.SPACE_LG)
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))
          .margin({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS })
        }
      }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    }
    .hideTitleBar(false)
    .title('设置')
  }
}
