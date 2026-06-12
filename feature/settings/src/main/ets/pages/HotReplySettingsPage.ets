import { common } from '@kit.AbilityKit'
import {
  connectHotReplySettings,
  GroupedListSection,
  HotReplySettings,
  HotReplySettingsState,
  SecondaryListScaffold,
  ThemeConstants,
} from 'shared'
import {
  SettingsCheckedMenuItem,
  SettingsDivider,
  SettingsDropdownRow,
  SettingsToggleRow,
} from '../components/SettingsPageComponents'
import { SettingsPageCoordinator, type SettingsOption } from '../model/SettingsPageCoordinator'
import { SettingsSaveCoordinator } from '../model/SettingsSaveCoordinator'

@ComponentV2
export struct HotReplySettingsPage {
  private hotReplies: HotReplySettingsState = connectHotReplySettings();
  @Local private hotRepliesEnabled: boolean = HotReplySettings.DEFAULT_ENABLED;
  @Local private hotReplyOptionsMounted: boolean = HotReplySettings.DEFAULT_ENABLED;
  @Local private hotReplyMaxCountMenuShown: boolean = false;
  @Local private hotReplyMinThanksMenuShown: boolean = false;

  aboutToAppear(): void {
    this.hotRepliesEnabled = this.hotReplies.enabled
    this.hotReplyOptionsMounted = this.hotReplies.enabled
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          this.HotReplySwitchSection()
        }
        if (this.hotReplyOptionsMounted) {
          ListItem() {
            this.HotReplyOptionsSection()
          }
          .transition(TransitionEffect.OPACITY)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  HotReplySwitchSection() {
    GroupedListSection() {
      SettingsToggleRow({
        title: $r('app.string.hot_replies'),
        checked: this.hotRepliesEnabled,
        changeAction: (value: boolean) => {
          this.updateHotRepliesEnabled(value)
        },
      })
    }
  }

  @Builder
  HotReplyOptionsSection() {
    GroupedListSection() {
      SettingsDropdownRow({
        title: $r('app.string.hot_replies_count'),
        trailingText: SettingsPageCoordinator.hotReplyCountLabel(this.hotReplies.maxCount),
        openAction: () => {
          this.showHotReplyMaxCountMenu()
        },
      })
        .bindMenu(this.hotReplyMaxCountMenuShown, this.HotReplyMaxCountMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.hotReplyMaxCountMenuShown = false
          },
        })

      SettingsDivider()
      SettingsDropdownRow({
        title: $r('app.string.hot_replies_min_thanks'),
        trailingText: SettingsPageCoordinator.hotReplyMinThanksLabel(this.hotReplies.minThanks),
        openAction: () => {
          this.showHotReplyMinThanksMenu()
        },
      })
        .bindMenu(this.hotReplyMinThanksMenuShown, this.HotReplyMinThanksMenu, {
          placement: Placement.BottomRight,
          aboutToDisappear: () => {
            this.hotReplyMinThanksMenuShown = false
          },
        })

      SettingsDivider()
      SettingsToggleRow({
        title: $r('app.string.hot_replies_child_replies_expanded'),
        checked: this.hotReplies.childRepliesExpanded,
        changeAction: (value: boolean) => {
          this.updateHotReplyChildRepliesExpanded(value)
        },
      })
    }
  }

  @Builder
  HotReplyMaxCountMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.hotReplyMaxCountOptions(),
        (option: SettingsOption) => {
          this.HotReplyMaxCountMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  HotReplyMinThanksMenu() {
    Menu() {
      ForEach(
        SettingsPageCoordinator.hotReplyMinThanksOptions(),
        (option: SettingsOption) => {
          this.HotReplyMinThanksMenuItem(option)
        },
        (option: SettingsOption) => option.value,
      )
    }
  }

  @Builder
  HotReplyMaxCountMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected:
        this.hotReplies.maxCount ===
        HotReplySettings.normalizeMaxCount(Number.parseInt(option.value)),
      selectAction: () => {
        this.updateHotReplyMaxCount(option.value)
      },
    })
  }

  @Builder
  HotReplyMinThanksMenuItem(option: SettingsOption) {
    SettingsCheckedMenuItem({
      label: option.label,
      selected:
        this.hotReplies.minThanks ===
        HotReplySettings.normalizeMinThanks(Number.parseInt(option.value)),
      selectAction: () => {
        this.updateHotReplyMinThanks(option.value)
      },
    })
  }

  private showHotReplyMaxCountMenu(): void {
    this.hotReplyMaxCountMenuShown = false
    setTimeout(() => {
      this.hotReplyMaxCountMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private showHotReplyMinThanksMenu(): void {
    this.hotReplyMinThanksMenuShown = false
    setTimeout(() => {
      this.hotReplyMinThanksMenuShown = true
    }, SettingsPageCoordinator.MENU_OPEN_DELAY_MS)
  }

  private updateHotRepliesEnabled(enabled: boolean): void {
    this.hotRepliesEnabled = enabled
    this.animateHotReplyOptions(enabled)
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveHotReplies(
      context,
      enabled,
      this.hotReplies.maxCount,
      this.hotReplies.minThanks,
      this.hotReplies.childRepliesExpanded,
    )
  }

  private animateHotReplyOptions(mounted: boolean): void {
    this.hotReplyMaxCountMenuShown = false
    this.hotReplyMinThanksMenuShown = false
    this.getUIContext().animateTo(
      { duration: ThemeConstants.ANIM_DURATION, curve: Curve.EaseOut },
      () => {
        this.hotReplyOptionsMounted = mounted
      },
    )
  }

  private updateHotReplyChildRepliesExpanded(expanded: boolean): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveHotReplies(
      context,
      this.hotReplies.enabled,
      this.hotReplies.maxCount,
      this.hotReplies.minThanks,
      expanded,
    )
  }

  private updateHotReplyMaxCount(value: string): void {
    this.hotReplyMaxCountMenuShown = false
    const normalized = HotReplySettings.normalizeMaxCount(Number.parseInt(value))
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveHotReplies(
      context,
      this.hotReplies.enabled,
      normalized,
      this.hotReplies.minThanks,
      this.hotReplies.childRepliesExpanded,
    )
  }

  private updateHotReplyMinThanks(value: string): void {
    this.hotReplyMinThanksMenuShown = false
    const normalized = HotReplySettings.normalizeMinThanks(Number.parseInt(value))
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SettingsSaveCoordinator.saveHotReplies(
      context,
      this.hotReplies.enabled,
      this.hotReplies.maxCount,
      normalized,
      this.hotReplies.childRepliesExpanded,
    )
  }
}
