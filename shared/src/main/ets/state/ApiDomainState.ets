import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the selected V2EX base URL (`StorageKeys.SELECTED_BASE_URL`).
 *
 * `ApiDomainSettings.apply()` is the single AppStorage writer (hydration `loadFromStore`
 * and `save()` both route through it, and it normalizes). During the V1->V2 backbone
 * migration it dual-writes the legacy `AppStorage` key (V1 `@StorageLink` readers) AND this
 * `@Trace` field (`@ComponentV2` readers, e.g. `DomainSettingsPage`). Transitional.
 */
@ObservedV2
export class ApiDomainState {
  // Default mirrors ApiConstants.BASE_URL_COM; real value published by apply() at hydration.
  @Trace selectedBaseUrl: string = 'https://www.v2ex.com'
}

const API_DOMAIN_V2_KEY: string = 'v2:apiDomain'

/** Returns the app-wide ApiDomainState singleton from AppStorageV2. */
export function connectApiDomain(): ApiDomainState {
  return AppStorageV2.connect(
    ApiDomainState,
    API_DOMAIN_V2_KEY,
    () => new ApiDomainState(),
  )!
}
