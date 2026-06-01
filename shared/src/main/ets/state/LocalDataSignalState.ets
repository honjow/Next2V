import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the local-data-changed signal.
 *
 * The signal is bumped whenever local content changes (saved topics/nodes, viewed topics, drafts).
 * Unlike the single-writer settings keys it has SEVERAL writers (LocalDataSettings,
 * LocalDataPublisher, DraftSettings, Index.refreshLocalData); each writes this `@Trace` field, so a V2
 * `@ComponentV2` consumer (AccountPage) can `@Monitor('<member>.updatedAt')` to refresh its
 * local-content stats. Pure-V2: the legacy LOCAL_DATA_UPDATED_AT AppStorage half was retired once no
 * reader read it.
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

/**
 * V2 mirror of the account-page local-content counts (saved topics / saved nodes / viewed topics).
 *
 * Single writer chokepoint: `LocalDataPublisher` (driven by CollectionSettings mutations and the
 * AccountPage stats refresh). Single reader: `@ComponentV2` AccountPage, which hydrates its display
 * counts off this holder. A volatile runtime cache (counts are recomputed from the RDB), so it mirrors
 * the prior AppStorage cache exactly — defaults to 0. Pure-V2: the legacy LOCAL_SAVED_TOPIC_COUNT /
 * LOCAL_SAVED_NODE_COUNT / LOCAL_VIEWED_TOPIC_COUNT AppStorage projection was retired once no reader read it.
 */
@ObservedV2
export class LocalContentStatsState {
  @Trace savedTopicCount: number = 0
  @Trace savedNodeCount: number = 0
  @Trace viewedTopicCount: number = 0
}

const LOCAL_CONTENT_STATS_V2_KEY: string = 'v2:localContentStats'

/** Returns the app-wide LocalContentStatsState singleton from AppStorageV2. */
export function connectLocalContentStats(): LocalContentStatsState {
  return AppStorageV2.connect(LocalContentStatsState, LOCAL_CONTENT_STATS_V2_KEY, () => new LocalContentStatsState())!
}
