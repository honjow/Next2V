import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2 mirror of the pending deep-link command.
 *
 * Written by `EntryAbility` on a cold/warm deep link (as a `<ts>:<uri>` string) and cleared by `Index`
 * after consuming it; the migrated `@ComponentV2` `Index` reads this `@Trace` field and `@Monitor`s it to
 * route the pending URL. Writers route through `publishPendingV2exUrl`. The legacy V1 `AppStorage`
 * (`pendingV2exUrl`) half was retired once Index — the only consumer — read this mirror instead of the key.
 */
@ObservedV2
export class PendingV2exUrlState {
  @Trace command: string = ''
}

const PENDING_V2EX_URL_V2_KEY: string = 'v2:pendingV2exUrl'

/** Returns the app-wide PendingV2exUrlState singleton from AppStorageV2. */
export function connectPendingV2exUrl(): PendingV2exUrlState {
  return AppStorageV2.connect(PendingV2exUrlState, PENDING_V2EX_URL_V2_KEY, () => new PendingV2exUrlState())!
}

export function publishPendingV2exUrl(value: string): void {
  connectPendingV2exUrl().command = value
}
