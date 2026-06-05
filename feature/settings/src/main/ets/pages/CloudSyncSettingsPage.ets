import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  AppStrings,
  CloudSyncFeature,
  CloudSyncSettings,
  CloudSyncState,
  DateUtils,
  connectCloudSync,
  ConciseListRow,
  GroupedListSection,
  LocalDataCloudSync,
  SecondaryListScaffold,
  ThemeConstants,
  translateApiError,
} from 'shared'
import {
  SettingsDivider,
  SettingsSectionHeader,
  SettingsToggleRow,
} from '../components/SettingsPageComponents'

// Deep link to the system Huawei Cloud (云空间) home, so the user can jump straight there to enable or
// manage this app's cloud data sync — the switch the app itself cannot toggle (see the code-3 guidance).
const HUAWEI_CLOUD_DEEP_LINK: string = 'hicloud://cloudDrive/getInfo?path=MainActivity'

// Dedicated "云同步" sub-page (pushed from the main Settings list). Hosts the master toggle plus, when it
// is on, the per-feature "同步内容" card and the "立即同步" row. Moved off the main Settings page so the
// growing per-feature list does not bloat the top-level list. State handling mirrors the former inline
// section: @Local mirrors are hydrated in aboutToAppear and updated optimistically by the handlers, while
// the live sync status comes from the CloudSyncState holder.
@ComponentV2
export struct CloudSyncSettingsPage {
  // Live cloud-sync status holder (syncing / lastSyncAt / lastSyncOk / lastSyncCloudDisabled). Read in the
  // "立即同步" subtitle so it reflects every sync path — startup, feature toggle, and manual.
  private cloudSync: CloudSyncState = connectCloudSync();
  @Local private cloudSyncEnabled: boolean = false;
  @Local private cloudSyncFeatSearchHistory: boolean = true;
  @Local private cloudSyncFeatCollections: boolean = true;
  @Local private cloudSyncFeatRecentViews: boolean = true;
  @Local private cloudSyncFeatReadProgress: boolean = true;
  @Local private cloudSyncFeatMarks: boolean = true;

  aboutToAppear(): void {
    this.cloudSyncEnabled = CloudSyncSettings.isEnabled()
    this.cloudSyncFeatSearchHistory = CloudSyncSettings.isFeatureEnabled(
      CloudSyncFeature.SEARCH_HISTORY,
    )
    this.cloudSyncFeatCollections = CloudSyncSettings.isFeatureEnabled(CloudSyncFeature.COLLECTIONS)
    this.cloudSyncFeatRecentViews = CloudSyncSettings.isFeatureEnabled(
      CloudSyncFeature.RECENT_VIEWS,
    )
    this.cloudSyncFeatReadProgress = CloudSyncSettings.isFeatureEnabled(
      CloudSyncFeature.READ_PROGRESS,
    )
    this.cloudSyncFeatMarks = CloudSyncSettings.isFeatureEnabled(CloudSyncFeature.MARKS)
  }

  build() {
    Column() {
      SecondaryListScaffold() {
        ListItem() {
          this.MasterSection()
        }
        .margin({ top: ThemeConstants.SPACE_MD })
        if (this.cloudSyncEnabled) {
          ListItem() {
            this.SectionHeader(AppStrings.R_CLOUD_SYNC_CONTENT)
          }
          ListItem() {
            this.ContentSection()
          }
        }
        ListItem() {
          this.CloudSpaceLinkSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  // A shortcut into the system Huawei Cloud (云空间) home via deep link, so the user can enable/manage
  // this app's cloud data sync there. Always shown — it is the actionable companion to the
  // "云空间同步未开启" guidance on the 立即同步 row.
  @Builder
  CloudSpaceLinkSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AppStrings.R_CLOUD_SYNC_OPEN_CLOUD_SPACE,
        action: () => {
          this.openCloudSpace()
        },
      })
    }
  }

  private openCloudSpace(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const want: Want = { action: 'ohos.want.action.viewData', uri: HUAWEI_CLOUD_DEEP_LINK }
    context.startAbility(want).catch((error: Error) => {
      promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {})
    })
  }

  @Builder
  SectionHeader(title: ResourceStr) {
    SettingsSectionHeader({ title })
  }

  @Builder
  SettingsDivider() {
    SettingsDivider()
  }

  @Builder
  TogglePreferenceRow(
    title: ResourceStr,
    checked: boolean,
    changeAction: (value: boolean) => void,
    isEnabled: boolean = true,
  ) {
    SettingsToggleRow({
      title,
      checked,
      isEnabled,
      changeAction,
    })
  }

  @Builder
  MasterSection() {
    GroupedListSection() {
      this.TogglePreferenceRow(
        AppStrings.R_CLOUD_SYNC_ENABLE,
        this.cloudSyncEnabled,
        (value: boolean) => {
          this.updateCloudSync(value)
        },
      )
    }
  }

  // The per-feature "同步内容" card (shown only when the master toggle is on).
  @Builder
  ContentSection() {
    GroupedListSection() {
      this.TogglePreferenceRow(
        AppStrings.R_SEARCH_HISTORY,
        this.cloudSyncFeatSearchHistory,
        (value: boolean) => {
          this.updateCloudSyncFeature(CloudSyncFeature.SEARCH_HISTORY, value)
        },
      )
      this.SettingsDivider()
      this.TogglePreferenceRow(
        AppStrings.R_CLOUD_SYNC_FEAT_COLLECTIONS,
        this.cloudSyncFeatCollections,
        (value: boolean) => {
          this.updateCloudSyncFeature(CloudSyncFeature.COLLECTIONS, value)
        },
      )
      this.SettingsDivider()
      this.TogglePreferenceRow(
        AppStrings.R_NAV_RECENTLY_VIEWED,
        this.cloudSyncFeatRecentViews,
        (value: boolean) => {
          this.updateCloudSyncFeature(CloudSyncFeature.RECENT_VIEWS, value)
        },
      )
      this.SettingsDivider()
      this.TogglePreferenceRow(
        AppStrings.R_CLOUD_SYNC_FEAT_READ_PROGRESS,
        this.cloudSyncFeatReadProgress,
        (value: boolean) => {
          this.updateCloudSyncFeature(CloudSyncFeature.READ_PROGRESS, value)
        },
      )
      this.SettingsDivider()
      this.TogglePreferenceRow(
        AppStrings.R_CLOUD_SYNC_FEAT_MARKS,
        this.cloudSyncFeatMarks,
        (value: boolean) => {
          this.updateCloudSyncFeature(CloudSyncFeature.MARKS, value)
        },
      )
      this.SettingsDivider()
      ConciseListRow({
        title: AppStrings.R_CLOUD_SYNC_NOW,
        subtitle: this.cloudSyncStatusText(),
        showChevron: false,
        action: () => {
          this.runCloudSyncNow()
        },
      })
    }
  }

  private updateCloudSync(enabled: boolean): void {
    this.cloudSyncEnabled = enabled
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CloudSyncSettings.save(context, enabled)
      .then(() => {
        // Enabling: request the permission, mark the distributed tables, and run a first sync now.
        if (enabled) {
          LocalDataCloudSync.tryEnableAndSync(context).catch((_error: Error) => {})
        }
      })
      .catch((error: Error) => {
        console.error('save cloud sync setting failed: ' + error.message)
      })
  }

  private updateCloudSyncFeature(key: string, enabled: boolean): void {
    // Mirror into the matching @Local so the toggle reflects immediately, persist the choice, then
    // re-mark the distributed-table set to the new selection and sync. Only reachable while the master
    // switch is on, so permission is already granted.
    if (key === CloudSyncFeature.SEARCH_HISTORY) {
      this.cloudSyncFeatSearchHistory = enabled
    } else if (key === CloudSyncFeature.COLLECTIONS) {
      this.cloudSyncFeatCollections = enabled
    } else if (key === CloudSyncFeature.RECENT_VIEWS) {
      this.cloudSyncFeatRecentViews = enabled
    } else if (key === CloudSyncFeature.READ_PROGRESS) {
      this.cloudSyncFeatReadProgress = enabled
    } else if (key === CloudSyncFeature.MARKS) {
      this.cloudSyncFeatMarks = enabled
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CloudSyncSettings.saveFeature(context, key, enabled)
      .then(() => {
        LocalDataCloudSync.applyFeatureSelection(context).catch((_error: Error) => {})
      })
      .catch((error: Error) => {
        console.error('save cloud sync feature failed: ' + error.message)
      })
  }

  private runCloudSyncNow(): void {
    // Status is driven by CloudSyncState (syncing -> lastSyncAt/lastSyncOk) and surfaced via
    // cloudSyncStatusText(); just trigger the sync here.
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    LocalDataCloudSync.cloudSyncNow(context).catch((_error: Error) => {})
  }

  // Subtitle of the "立即同步" row: "正在同步…" while a sync runs, the system-cloud-disabled guidance when
  // the last sync returned RDB_CLOUD_DISABLED, otherwise the localized last-sync time ("上次同步:刚刚"),
  // or empty before the first sync ever. Reads @Trace fields so it updates reactively.
  private cloudSyncStatusText(): string {
    if (this.cloudSync.syncing) {
      return AppStrings.text(AppStrings.R_CLOUD_SYNC_SYNCING, 'Syncing…')
    }
    // Distinct guidance when the system 云空间 sync is off for this app (progress code 3): the app cannot
    // toggle it, so point the user at System Settings instead of showing a generic "sync failed".
    if (this.cloudSync.lastSyncCloudDisabled) {
      return AppStrings.text(
        AppStrings.R_CLOUD_SYNC_CLOUD_DISABLED,
        'Cloud sync is off for this app. Turn on data sync for this app under System Settings → Cloud.',
      )
    }
    if (this.cloudSync.lastSyncAt <= 0) {
      return ''
    }
    const when: string = DateUtils.toRelativeTime(Math.floor(this.cloudSync.lastSyncAt / 1000))
    const template: string = this.cloudSync.lastSyncOk
      ? AppStrings.text(AppStrings.R_CLOUD_SYNC_LAST, 'Last synced: {0}')
      : AppStrings.text(AppStrings.R_CLOUD_SYNC_LAST_FAILED, 'Last sync failed · {0}')
    return AppStrings.format(template, [when])
  }
}
