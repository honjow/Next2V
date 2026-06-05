import { AppStorageV2 } from '@kit.ArkUI'

// V2 holder for the device-cloud sync (端云协同) user toggle + runtime status surfaced in Settings.
// `enabled` is the persisted preference (default OFF — sync is opt-in); `syncing`/`lastSyncAt`/`lastSyncOk`
// are in-memory status. CloudSyncSettings.apply() is the single writer for `enabled`;
// LocalDataCloudSync.cloudSyncNow updates the status fields.
@ObservedV2
export class CloudSyncState {
  @Trace enabled: boolean = false
  @Trace syncing: boolean = false
  @Trace lastSyncAt: number = 0
  @Trace lastSyncOk: boolean = false
  // Per-feature toggles (sub-switches under the master `enabled`). Default ON: enabling cloud sync syncs
  // everything unless the user opts a feature out. CloudSyncSettings is the single writer (it maps each
  // CloudSyncFeature key to the matching field); the Settings page reads them back.
  @Trace featSearchHistory: boolean = true
  @Trace featCollections: boolean = true
  @Trace featRecentViews: boolean = true
  @Trace featReadProgress: boolean = true
  @Trace featMarks: boolean = true
}

const CLOUD_SYNC_V2_KEY: string = 'v2:cloudSync'

export function connectCloudSync(): CloudSyncState {
  return AppStorageV2.connect(CloudSyncState, CLOUD_SYNC_V2_KEY, () => new CloudSyncState())!
}
