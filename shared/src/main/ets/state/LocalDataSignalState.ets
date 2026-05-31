import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the local-data-changed signal (`StorageKeys.LOCAL_DATA_UPDATED_AT`).
 *
 * The signal is bumped whenever local content changes (saved topics/nodes, viewed topics, drafts).
 * Unlike the single-writer settings keys it has SEVERAL writers (LocalDataSettings,
 * LocalDataPublisher, DraftSettings, Index.refreshLocalData); each dual-writes the V1 `AppStorage`
 * key (still read by V1 `@StorageLink`) AND this `@Trace` field, so a V2 `@ComponentV2` consumer
 * (AccountPage) can `@Monitor('<member>.updatedAt')` to refresh its local-content stats.
 *
 * Transitional: drop the `AppStorage` half once every reader has moved to V2.
 */
@ObservedV2
export class LocalDataSignalState {
  @Trace updatedAt: number = 0
}

const LOCAL_DATA_SIGNAL_V2_KEY: string = 'v2:localDataUpdatedAt'

/** Returns the app-wide LocalDataSignalState singleton from AppStorageV2. */
export function connectLocalDataSignal(): LocalDataSignalState {
  return AppStorageV2.connect(LocalDataSignalState, LOCAL_DATA_SIGNAL_V2_KEY, () => new LocalDataSignalState())!
}
