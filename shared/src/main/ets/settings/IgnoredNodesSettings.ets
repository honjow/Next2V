import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { connectIgnoredNodes } from '../state/IgnoredNodesState'
import { STORE_NAME_SETTINGS, readJsonArray, writeJsonValue } from './SettingsStorage'

const KEY_IGNORED_NODES: string = 'ignoredNodes'

/**
 * Device-global list of ignored node slugs, persisted in the unified `next2v_settings` store (so it rides
 * the whole-store backup). Node slugs are stored normalized (trimmed + lowercased) and deduped; the order
 * is insertion order (most-recently-ignored last). NOT owner-scoped and NOT cloud-synced through the V2EX
 * account — this is the app's own local feed filter (see [[IgnoredNodesState]]).
 *
 * `apply()` is the single writer of the `IgnoredNodesState` V2 mirror. The context is captured at load()
 * time so `setIgnored()` (called from the node-page menu) needs no context argument.
 */
export class IgnoredNodesSettings {
  private static context: common.UIAbilityContext | null = null

  static apply(names: string[]): void {
    connectIgnoredNodes().names = names
  }

  /** The live ignored-node list, read from the V2 mirror apply() keeps in lockstep with the persisted key. */
  static current(): string[] {
    return connectIgnoredNodes().names
  }

  /** Lowercased lookup set for the feed filter. */
  static nameSet(): Set<string> {
    const out: Set<string> = new Set()
    for (const name of connectIgnoredNodes().names) {
      const v = IgnoredNodesSettings.normalizeName(name)
      if (v.length > 0) {
        out.add(v)
      }
    }
    return out
  }

  static isIgnored(name: string): boolean {
    const target = IgnoredNodesSettings.normalizeName(name)
    if (!target) {
      return false
    }
    return connectIgnoredNodes().names.some(
      (n: string) => IgnoredNodesSettings.normalizeName(n) === target,
    )
  }

  static async load(context: common.UIAbilityContext): Promise<void> {
    IgnoredNodesSettings.context = context
    const store = await preferences.getPreferences(context, STORE_NAME_SETTINGS)
    const raw = readJsonArray<string>(store, KEY_IGNORED_NODES, [])
    IgnoredNodesSettings.apply(IgnoredNodesSettings.normalize(raw))
  }

  /**
   * Add or remove `name` from the ignored set, mirror to the holder immediately, and persist in the
   * background. Returns the resulting ignored state for the caller's optimistic UI. Safe to call before
   * load() captured the context (it still updates the in-memory holder, just skips the disk write).
   */
  static setIgnored(name: string, ignored: boolean): boolean {
    const target = IgnoredNodesSettings.normalizeName(name)
    if (!target) {
      return false
    }
    const current = connectIgnoredNodes().names
    const next: string[] = []
    for (const existing of current) {
      if (IgnoredNodesSettings.normalizeName(existing) !== target) {
        next.push(existing)
      }
    }
    if (ignored) {
      next.push(target)
    }
    const normalized = IgnoredNodesSettings.normalize(next)
    IgnoredNodesSettings.apply(normalized)
    IgnoredNodesSettings.persist(normalized)
    return ignored
  }

  /** Flip the ignored state of `name`; returns the new state. */
  static toggle(name: string): boolean {
    return IgnoredNodesSettings.setIgnored(name, !IgnoredNodesSettings.isIgnored(name))
  }

  private static persist(names: string[]): void {
    const ctx = IgnoredNodesSettings.context
    if (!ctx) {
      return
    }
    preferences
      .getPreferences(ctx, STORE_NAME_SETTINGS)
      .then((store: preferences.Preferences) => {
        writeJsonValue(store, KEY_IGNORED_NODES, names)
      })
      .catch((_error: Error) => {
        // Best-effort persistence; the in-memory holder already reflects the change this session.
      })
  }

  private static normalize(names: string[]): string[] {
    const out: string[] = []
    const seen: Set<string> = new Set()
    const source = Array.isArray(names) ? names : []
    for (const raw of source) {
      const v = IgnoredNodesSettings.normalizeName(raw)
      if (v.length > 0 && !seen.has(v)) {
        out.push(v)
        seen.add(v)
      }
    }
    return out
  }

  private static normalizeName(name: string): string {
    return (name || '').trim().toLowerCase()
  }
}
