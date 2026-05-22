import { common } from '@kit.AbilityKit'
import type { TabItem } from 'shared'
import {
  AppStrings,
  ApiConstants,
  AppTextField,
  ConciseListRow,
  FeedTabSettings,
  GroupedListSection,
  SecondaryListScaffold,
  StorageKeys,
  ThemeConstants
} from 'shared'
import { promptAction } from '@kit.ArkUI'
import {
  HomeNodeVisibilityButton,
  SettingsDivider,
  SettingsSectionHeader
} from '../components/SettingsPageComponents'

@Component
export struct HomeNodeSettingsPage {
  @StorageLink(StorageKeys.FEED_TAB_KEYS) feedTabKeys: string = FeedTabSettings.defaultKeysJson()
  @State private nodeTabName: string = ''

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_VISIBLE_HOME_NODES_REORDER_HINT })
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
          SettingsSectionHeader({ title: AppStrings.R_ADD_HOME_COLUMN })
        }

        ListItem() {
          this.AddSection()
        }

        ListItem() {
          SettingsSectionHeader({ title: AppStrings.R_COMMON_RESET })
        }

        ListItem() {
          GroupedListSection() {
            ConciseListRow({
              title: AppStrings.R_RESTORE_DEFAULT,
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
      label: FeedTabSettings.isNodeKey(key) ? AppStrings.R_COMMON_DELETE : AppStrings.R_HIDE,
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
          title: `添加 ${tab.label}`,
          showChevron: false,
          action: () => {
            this.updateFeedTabVisibility(tab.key)
          }
        })
        SettingsDivider()
      }, (tab: TabItem) => tab.key)

      Column({ space: ThemeConstants.SPACE_SM }) {
        AppTextField({
          text: $nodeTabName,
          placeholder: AppStrings.R_NODE_NAME_PLACEHOLDER,
          onTextChange: (value: string) => {
            this.nodeTabName = value
          }
        })
          .width('100%')
        Button(AppStrings.R_ADD_NODE_COLUMN)
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
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_INVALID_NODE_NAME, 'Enter a valid node name') }).catch((_error: Error) => {
      })
      return
    }
    const nextKeys = FeedTabSettings.addNode(this.feedTabKeys, cleanName)
    if (nextKeys === this.feedTabKeys) {
      promptAction.openToast({ message: AppStrings.text(AppStrings.R_NODE_COLUMN_EXISTS, 'Node column already exists') }).catch((_error: Error) => {
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
