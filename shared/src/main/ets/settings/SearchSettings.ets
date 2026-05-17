import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { LocalDataStore } from '../storage/LocalDataStore'
import { deleteKeysAndFlush, withPreferencesStore } from './SettingsStorage'
import { STORE_NAME_SEARCH } from './SettingsStores'

const STORE_NAME: string = STORE_NAME_SEARCH
const KEY_HISTORY: string = 'searchHistory'
const KEY_SOURCE_MODE: string = 'sourceMode'
const MAX_HISTORY: number = 20
const SQL_SELECT_HISTORY: string = 'SELECT query FROM search_history ORDER BY searched_at DESC LIMIT 20'
const SQL_UPSERT_HISTORY: string = 'INSERT OR REPLACE INTO search_history (query, searched_at) VALUES (?, ?)'
const SQL_PRUNE_HISTORY: string = 'DELETE FROM search_history WHERE query NOT IN (SELECT query FROM search_history ORDER BY searched_at DESC LIMIT 20)'
const SQL_CLEAR_HISTORY: string = 'DELETE FROM search_history'

export type SearchSourceMode = 'local' | 'localWithNodes' | 'remote' | 'externalWeb'
const DEFAULT_SOURCE_MODE: SearchSourceMode = 'localWithNodes'

export class SearchSettings {
  static async loadHistory(context: common.UIAbilityContext): Promise<string[]> {
    try {
      const store = await LocalDataStore.open(context)
      const resultSet = await store.querySql(SQL_SELECT_HISTORY)
      return SearchSettings.readHistoryResult(resultSet)
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
    try {
      const store = await LocalDataStore.open(context)
      const args: relationalStore.ValueType[] = [clean, Date.now()]
      await store.executeSql(SQL_UPSERT_HISTORY, args)
      await store.executeSql(SQL_PRUNE_HISTORY)
      SearchSettings.deleteLegacyHistoryBestEffort(context)
      return await SearchSettings.loadHistory(context)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存搜索历史失败')
    }
  }

  static async clearHistory(context: common.UIAbilityContext): Promise<void> {
    try {
      const store = await LocalDataStore.open(context)
      await store.executeSql(SQL_CLEAR_HISTORY)
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '清空搜索历史失败')
    }
  }

  static async loadSourceMode(context: common.UIAbilityContext): Promise<SearchSourceMode> {
    try {
      return await withPreferencesStore<SearchSourceMode>(context, STORE_NAME, (store) => {
        const raw = store.getSync(KEY_SOURCE_MODE, DEFAULT_SOURCE_MODE) as string
        return SearchSettings.parseSourceMode(raw)
      })
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '读取搜索来源失败')
    }
  }

  static async saveSourceMode(context: common.UIAbilityContext, mode: SearchSourceMode): Promise<SearchSourceMode> {
    const next = SearchSettings.parseSourceMode(mode)
    try {
      return await withPreferencesStore<SearchSourceMode>(context, STORE_NAME, (store) => {
        store.putSync(KEY_SOURCE_MODE, next)
        store.flushSync()
        return next
      })
    } catch (error) {
      const e = error as Error
      throw new Error(e.message || '保存搜索来源失败')
    }
  }

  private static readHistoryResult(resultSet: relationalStore.ResultSet): string[] {
    const seen: Record<string, boolean> = {}
    const items: string[] = []
    try {
      const queryIndex = resultSet.getColumnIndex('query')
      while (resultSet.goToNextRow()) {
        const clean = resultSet.getString(queryIndex).trim()
        if (!clean || seen[clean]) {
          continue
        }
        seen[clean] = true
        items.push(clean)
        if (items.length >= MAX_HISTORY) {
          break
        }
      }
    } finally {
      resultSet.close()
    }
    return items
  }

  private static deleteLegacyHistoryBestEffort(context: common.UIAbilityContext): void {
    withPreferencesStore<void>(context, STORE_NAME, (store) => {
      deleteKeysAndFlush(store, [KEY_HISTORY])
    }).catch(() => {})
  }

  private static parseSourceMode(raw: string): SearchSourceMode {
    if (raw === 'local') {
      return 'local'
    }
    if (raw === 'externalWeb') {
      return 'externalWeb'
    }
    if (raw === 'remote') {
      return 'remote'
    }
    return DEFAULT_SOURCE_MODE
  }
}
