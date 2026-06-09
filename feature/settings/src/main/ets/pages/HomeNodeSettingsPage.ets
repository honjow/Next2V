import { common } from '@kit.AbilityKit'
import type { TabItem } from 'shared'
import {
  AppStrings,
  ApiConstants,
  AppTextField,
  connectFeedTab,
  ConciseListRow,
  FeedTabBridge,
  FeedTabSettings,
  FeedTabState,
  GroupedListSection,
  SecondaryListScaffold,
  ThemeConstants
} from 'shared'
import { promptAction } from '@kit.ArkUI'
import {
  HomeNodeVisibilityButton,
  SettingsDivider,
  SettingsSectionHeader
} from '../components/SettingsPageComponents'

@ComponentV2
export struct HomeNodeSettingsPage {
  // This page is the settings *writer* of FEED_TAB_KEYS. Read the V2 FeedTabState mirror so reorders/
  // toggles re-render here, and route every write through FeedTabBridge.publishKeys so the AppStorage
  // key (still read imperatively by FeedTabSettings) and the V2 FeedTabState mirror stay in lockstep.
  @Local private feedTabState: FeedTabState = connectFeedTab()
  @Local private nodeTabName: string = ''

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.visible_home_nodes_reorder_hint') })
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
                    SettingsDivider()
                  }
                }
                .width('100%')
              }
              .backgroundColor($r('app.color.card_background'))
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
          SettingsSectionHeader({ title: $r('app.string.add_home_column') })
        }

        ListItem() {
          this.AddSection()
        }

        ListItem() {
          SettingsSectionHeader({ title: $r('app.string.common_reset') })
        }

        ListItem() {
          GroupedListSection() {
            ConciseListRow({
              title: $r('app.string.restore_default'),
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
    HomeNodeVisibilityButton({
      label: FeedTabSettings.isNodeKey(key) ? $r('app.string.common_delete') : $r('app.string.hide'),
      isEnabled: enabled,
      clickAction: () => {
        this.updateFeedTabVisibility(key)
      }
    })
  }

  @Builder
  AddSection() {
    GroupedListSection() {
      ForEach(this.hiddenBuiltInTabs(), (tab: TabItem) => {
        ConciseListRow({
          title: AppStrings.format(AppStrings.text($r('app.string.add_x_format'), 'Add {0}'), [typeof tab.label === 'string' ? tab.label : AppStrings.text(tab.label, '')]),
          showChevron: false,
          action: () => {
            this.updateFeedTabVisibility(tab.key)
          }
        })
        SettingsDivider()
      }, (tab: TabItem) => tab.key)

      Column({ space: ThemeConstants.SPACE_SM }) {
        AppTextField({
          text: this.nodeTabName,
          placeholder: $r('app.string.node_name_placeholder'),
          onTextChange: (value: string) => {
            this.nodeTabName = value
          }
        })
          .width('100%')
        Button($r('app.string.add_node_column'))
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
    return FeedTabSettings.tabsFromKeysJson(this.feedTabState.feedTabKeys)
  }

  private hiddenBuiltInTabs(): TabItem[] {
    return ApiConstants.TAB_ITEMS.filter((tab: TabItem) => !FeedTabSettings.isVisible(this.feedTabState.feedTabKeys, tab.key))
  }

  private updateFeedTabVisibility(key: string): void {
    const nextKeys = FeedTabSettings.toggleKey(this.feedTabState.feedTabKeys, key)
    if (nextKeys === this.feedTabState.feedTabKeys) {
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
      promptAction.openToast({ message: AppStrings.text($r('app.string.invalid_node_name'), 'Enter a valid node name') }).catch((_error: Error) => {
      })
      return
    }
    const nextKeys = FeedTabSettings.addNode(this.feedTabState.feedTabKeys, cleanName)
    if (nextKeys === this.feedTabState.feedTabKeys) {
      promptAction.openToast({ message: AppStrings.text($r('app.string.node_column_exists'), 'Node column already exists') }).catch((_error: Error) => {
      })
      return
    }
    this.nodeTabName = ''
    this.saveFeedTabs(nextKeys)
  }

  private resetFeedTabs(): void {
    if (FeedTabSettings.isDefault(this.feedTabState.feedTabKeys)) {
      return
    }
    this.saveFeedTabs(FeedTabSettings.defaultKeysJson())
  }

  private saveFeedTabs(keysJson: string): void {
    // Optimistic dual-write (V1 AppStorage + V2 FeedTabState mirror) so this page and HomePage/FeedPills
    // react immediately; FeedTabSettings.save then persists to preferences and re-publishes the normalized
    // value through the same bridge.
    FeedTabBridge.publishKeys(keysJson)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    FeedTabSettings.save(context, keysJson).catch((error: Error) => {
      console.error('save feed tab settings failed: ' + error.message)
    })
  }
}
