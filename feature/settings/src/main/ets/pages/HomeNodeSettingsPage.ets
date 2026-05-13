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
          this.SectionHeader('已显示栏目')
        }

        ForEach(this.visibleTabs(), (tab: TabItem, index: number) => {
          ListItem() {
            this.HomeVisibleTabRow(tab, index, this.visibleTabs().length)
          }
          .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
          .borderRadius(this.visibleRowRadius(index, this.visibleTabs().length))
          .clip(true)
        }, (tab: TabItem) => tab.key)
          .onMove((from: number, to: number) => {
            this.moveFeedTabToIndex(from, to)
          })

        ListItem() {
          this.SectionHeader('添加栏目')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

        ListItem() {
          this.AddSection()
        }

        ListItem() {
          this.SectionHeader('重置')
        }
        .margin({ top: ThemeConstants.SPACE_MD })

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
  SectionHeader(title: string) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  SettingsDivider() {
    SharedListDivider()
  }

  @Builder
  HomeVisibleTabRow(tab: TabItem, _index: number, count: number) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(tab.label)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(FeedTabSettings.isNodeKey(tab.key) ? '节点栏目 · 长按拖动排序' : '首页栏目 · 长按拖动排序')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('☰')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })

      Button(FeedTabSettings.isNodeKey(tab.key) ? '删' : '隐')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(ThemeConstants.TOUCH_TARGET_SM)
        .width(48)
        .enabled(count > 1)
        .type(ButtonType.Normal)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .fontColor(count > 1 ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
        .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
        .onClick(() => {
          this.updateFeedTabVisibility(tab.key)
        })
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_MD
    })
    .alignItems(VerticalAlign.Center)
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

  private visibleRowRadius(index: number, count: number): number {
    if (count <= 1) {
      return ThemeConstants.RADIUS_CARD
    }
    if (index === 0 || index === count - 1) {
      return ThemeConstants.RADIUS_CARD
    }
    return 0
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
