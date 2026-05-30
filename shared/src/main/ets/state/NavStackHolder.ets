import { AppStorageV2 } from '@kit.ArkUI'

/**
 * V2-safe holder for the app's single `NavPathStack`.
 *
 * Background: navigation is provided V1-style by `Index` via `@Provide('ns')` and
 * consumed by ~27 routed pages via `@Consume('ns')`. `ns` is never observed as
 * reactive state — every consumer uses it purely as a method target
 * (`pushPathByName` / `pop`), and `NavPathStack` self-manages the stack observation
 * that `HdsNavigation(stack)` binds to. So a `@ComponentV2` consumer does not need
 * V1->V2 reactive interop on the stack; it only needs the *same* `NavPathStack`
 * instance that `HdsNavigation` is bound to.
 *
 * This holder is that single instance, shared app-wide through `AppStorageV2`.
 * `Index` (still V1) sources its `@Provide('ns')` from `connectNavStack().stack`,
 * so V1 `@Consume('ns')` readers and V2 `connectNavStack().stack` readers reference
 * the identical object. This lets the `@Consume('ns')` tail migrate to V2 one
 * consumer at a time instead of flipping all 27 atomically.
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
