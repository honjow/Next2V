import { common } from '@kit.AbilityKit'
import type { TabItem } from 'shared'
import {
  ApiConstants,
  AppTextField,
  ConciseListRow,
  FeedTabSettings,
  GroupedListSection,
  ListDivider as SharedListDivider,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  StorageKeys,
  ThemeConstants
} from 'shared'
import { promptAction } from '@kit.ArkUI'

@Component
export struct HomeNodeSettingsPage {
  @StorageLink(StorageKeys.FEED_TAB_KEYS) feedTabKeys: string = FeedTabSettings.defaultKeysJson()
  @State private nodeTabName: string = ''

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          this.SectionHeader('已显示栏目  长按栏目可拖动排序')
        }

        GroupedListSection() {
          List() {
            ForEach(this.visibleTabs(), (tab: TabItem, index: number): void => {
              ListItem() {
                Column() {
                  ConciseListRow({
                    title: tab.label,
                    suffixBuilderParam: (): void => this.ButtonSuffix(tab.key, this.visibleTabs().length > 1),
                  })
                  if (index < this.visibleTabs().length - 1) {
                    this.SettingsDivider()
                  }
                }
                .width('100%')
              }
              .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
              .borderRadius({
                topLeft: index === 0 ? ThemeConstants.RADIUS_CARD : 0,
                topRight: index === 0 ? ThemeConstants.RADIUS_CARD : 0,
                bottomLeft: index === this.visibleTabs().length - 1 ? ThemeConstants.RADIUS_CARD : 0,
                bottomRight: index === this.visibleTabs().length - 1 ? ThemeConstants.RADIUS_CARD : 0
              })
              .clip(true)
            }, (tab: TabItem) => tab.key)
              .onMove((from: number, to: number) => {
                this.moveFeedTabToIndex(from, to)
              })
          }
          .width('100%')
        }

        ListItem() {
          this.SectionHeader('添加栏目')
        }

        ListItem() {
          this.AddSection()
        }

        ListItem() {
          this.SectionHeader('重置')
        }

        ListItem() {
          GroupedListSection() {
            ConciseListRow({
              title: '恢复默认栏目',
              showChevron: false,
              action: () => {
                this.resetFeedTabs()
              }
            })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  ButtonSuffix(key: string, enabled: boolean) {
    Button(FeedTabSettings.isNodeKey(key) ? '删除' : '隐藏')
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .height(ThemeConstants.TOUCH_TARGET_SM)
      // .width(48)
      .enabled(enabled)
      .type(ButtonType.Capsule)
      .borderRadius(ThemeConstants.RADIUS_MD)
      .fontColor(enabled ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.font_tertiary'))
      .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => {
        this.updateFeedTabVisibility(key)
      })
  }

  @Builder
  SectionHeader(title: string) {
    SharedSectionHeader({ title: title }).margin({ top: ThemeConstants.SPACE_MD })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  @Builder
  AddSection() {
    GroupedListSection() {
      ForEach(this.hiddenBuiltInTabs(), (tab: TabItem) => {
        ConciseListRow({
          title: `添加 ${tab.label}`,
          showChevron: false,
          action: () => {
            this.updateFeedTabVisibility(tab.key)
          }
        })
        this.SettingsDivider()
      }, (tab: TabItem) => tab.key)

      Column({ space: ThemeConstants.SPACE_SM }) {
        AppTextField({
          text: $nodeTabName,
          placeholder: '节点名（如 create）',
          onTextChange: (value: string) => {
            this.nodeTabName = value
          }
        })
          .width('100%')
        Button('添加节点栏目')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .type(ButtonType.Normal)
          .borderRadius(ThemeConstants.RADIUS_MD)
          .fontColor(Color.White)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .width('100%')
          .onClick(() => {
            this.addNodeFeedTab()
          })
      }
      .padding(ThemeConstants.SPACE_LG)
    }
  }

  private visibleTabs(): TabItem[] {
    return FeedTabSettings.tabsFromKeysJson(this.feedTabKeys)
  }

  private hiddenBuiltInTabs(): TabItem[] {
    return ApiConstants.TAB_ITEMS.filter((tab: TabItem) => !FeedTabSettings.isVisible(this.feedTabKeys, tab.key))
  }

  private updateFeedTabVisibility(key: string): void {
    const nextKeys = FeedTabSettings.toggleKey(this.feedTabKeys, key)
    if (nextKeys === this.feedTabKeys) {
      return
    }
    this.saveFeedTabs(nextKeys)
  }

  private moveFeedTabToIndex(from: number, to: number): void {
    const tabs = this.visibleTabs()
    if (from < 0 || from >= tabs.length || to < 0 || to >= tabs.length || from === to) {
      return
    }
    const keys = tabs.map((tab: TabItem) => tab.key)
    const moved = keys.splice(from, 1)
    keys.splice(to, 0, moved[0])
    this.saveFeedTabs(JSON.stringify(keys))
  }

  private addNodeFeedTab(): void {
    const cleanName = FeedTabSettings.normalizeNodeName(this.nodeTabName)
    if (!cleanName) {
      promptAction.openToast({ message: '请输入有效节点名' }).catch((_error: Error) => {
      })
      return
    }
    const nextKeys = FeedTabSettings.addNode(this.feedTabKeys, cleanName)
    if (nextKeys === this.feedTabKeys) {
      promptAction.openToast({ message: '节点栏目已存在' }).catch((_error: Error) => {
      })
      return
    }
    this.nodeTabName = ''
    this.saveFeedTabs(nextKeys)
  }

  private resetFeedTabs(): void {
    if (FeedTabSettings.isDefault(this.feedTabKeys)) {
      return
    }
    this.saveFeedTabs(FeedTabSettings.defaultKeysJson())
  }

  private saveFeedTabs(keysJson: string): void {
    this.feedTabKeys = keysJson
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    FeedTabSettings.save(context, keysJson).catch((error: Error) => {
      console.error('save feed tab settings failed: ' + error.message)
    })
  }
}
