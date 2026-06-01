import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2-safe holder for the app's single `NavPathStack`.
 *
 * Historical background: navigation used to be provided by `Index` via `@Provide('ns')`
 * and consumed by routed pages via `@Consume('ns')`. The State Management V2 migration
 * retired those live decorators. `ns` is never observed as reactive state — every consumer
 * uses it purely as a method target (`pushPathByName` / `pop`), and `NavPathStack`
 * self-manages the stack observation that `HdsNavigation(stack)` binds to. A
 * `@ComponentV2` consumer only needs the *same* `NavPathStack` instance that
 * `HdsNavigation` is bound to.
 *
 * This holder is that single instance, shared app-wide through `AppStorageV2`.
 * `Index` and routed pages now use `connectNavStack().stack`, so every consumer
 * references the identical object without a V1 adapter tail.
 *
 * `@Trace` is harmless here (the reference is never reassigned, so no reactivity
 * fires) and keeps the class shape consistent with the other AppStorageV2 mirrors.
 */
@ObservedV2
export class NavStackHolder {
  @Trace stack: NavPathStack = new NavPathStack()
}

const NAV_STACK_V2_KEY: string = 'v2:navStack'

/** Returns the app-wide NavStackHolder singleton from AppStorageV2. */
export function connectNavStack(): NavStackHolder {
  return AppStorageV2.connect(NavStackHolder, NAV_STACK_V2_KEY, () => new NavStackHolder())!
}
