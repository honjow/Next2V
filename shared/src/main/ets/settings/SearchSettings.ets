import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const STORE_NAME: string = 'next2v_search'
const KEY_HISTORY: string = 'searchHistory'
const MAX_HISTORY: number = 20

export class SearchSettings {
  static async loadHistory(context: common.UIAbilityContext): Promise<string[]> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      const raw = store.getSync(KEY_HISTORY, '[]') as string
      return SearchSettings.parseHistory(raw)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取搜索历史失败')
    }
  }

  static async recordQuery(context: common.UIAbilityContext, query: string): Promise<string[]> {
    const clean = (query ?? '').trim()
    if (!clean) {
      return await SearchSettings.loadHistory(context)
    }
    const history = await SearchSettings.loadHistory(context)
    const next = [clean].concat(history.filter((item: string) => item !== clean)).slice(0, MAX_HISTORY)
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.putSync(KEY_HISTORY, JSON.stringify(next))
      store.flushSync()
      return next
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存搜索历史失败')
    }
  }

  static async clearHistory(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, STORE_NAME)
      store.deleteSync(KEY_HISTORY)
      store.flushSync()
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清空搜索历史失败')
    }
  }

  private static parseHistory(raw: string): string[] {
    try {
      const parsed = JSON.parse(raw) as string[]
      if (!Array.isArray(parsed)) {
        return []
      }
      const seen: Record<string, boolean> = {}
      const items: string[] = []
      for (const item of parsed) {
        if (typeof item !== 'string') {
          continue
        }
        const clean = item.trim()
        if (!clean || seen[clean]) {
          continue
        }
        seen[clean] = true
        items.push(clean)
        if (items.length >= MAX_HISTORY) {
          break
        }
      }
      return items
    } catch (error) {
      return []
    }
  }
}

