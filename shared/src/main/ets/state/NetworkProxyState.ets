import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the live network-proxy configuration (the `StorageKeys.NETWORK_PROXY_*` keys).
 *
 * `NetworkProxySettings.apply()` is the single imperative writer of those AppStorage keys (it is
 * called by `save()`, `loadFromStore()`, and directly), so it dual-writes BOTH the V1 AppStorage
 * keys (still read by any remaining V1 `@StorageLink`) AND these `@Trace` fields, read by the
 * `@ComponentV2` `NetworkProxySettingsPage` (its live config view) and `SettingsPage` (the proxy
 * summary trailing text). `exclusionListText` is the newline-joined form persisted under
 * `NETWORK_PROXY_EXCLUSION_LIST`, matching the former `@StorageLink` string.
 *
 * Transitional: drop the AppStorage half once no V1 `@StorageLink` reads these keys.
 */
@ObservedV2
export class NetworkProxyState {
  @Trace mode: string = 'off'
  @Trace host: string = ''
  @Trace port: number = 0
  @Trace proxyScheme: string = 'http'
  @Trace username: string = ''
  @Trace password: string = ''
  @Trace exclusionListText: string = ''
}

const NETWORK_PROXY_V2_KEY: string = 'v2:networkProxy'

/** Returns the app-wide NetworkProxyState singleton from AppStorageV2. */
export function connectNetworkProxy(): NetworkProxyState {
  return AppStorageV2.connect(NetworkProxyState, NETWORK_PROXY_V2_KEY, () => new NetworkProxyState())!
}
