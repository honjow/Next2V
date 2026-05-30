import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 holder for the Discover tab's node-search keyword.
 *
 * The keyword has exactly two parties: the title-bar search field
 * (`DiscoverSearchComponent`) writes it as the user types, and `DiscoverPage` reads it to
 * filter its node list (and seeds it empty on appear). Both are `@ComponentV2`, so the
 * keyword lives entirely in this `AppStorageV2` mirror — there is no remaining V1
 * `@StorageLink` reader, so the legacy `StorageKeys.DISCOVER_NODE_KEYWORD` AppStorage key
 * is no longer written/read (it is a transient search string, never persisted).
 *
 * Reading `keyword` inside a `@ComponentV2` `build()` subscribes that component to changes;
 * a `@Monitor('<member>.keyword')` runs side-effects (filter / lazy index load).
 */
@ObservedV2
export class DiscoverKeywordState {
  @Trace keyword: string = ''
}

const DISCOVER_KEYWORD_V2_KEY: string = 'v2:discoverNodeKeyword'

/** Returns the app-wide DiscoverKeywordState singleton from AppStorageV2. */
export function connectDiscoverKeyword(): DiscoverKeywordState {
  return AppStorageV2.connect(DiscoverKeywordState, DISCOVER_KEYWORD_V2_KEY, () => new DiscoverKeywordState())!
}
