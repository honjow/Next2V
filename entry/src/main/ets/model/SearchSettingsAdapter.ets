import { common } from '@kit.AbilityKit'
import {
  SearchSettings,
  type SearchSourceMode,
} from 'shared'

export class SearchSettingsAdapter {
  static loadSourceMode(context: common.UIAbilityContext): Promise<SearchSourceMode> {
    return SearchSettings.loadSourceMode(context)
  }

  static saveSourceMode(context: common.UIAbilityContext, mode: SearchSourceMode): Promise<SearchSourceMode> {
    return SearchSettings.saveSourceMode(context, mode)
  }

  static loadHistory(context: common.UIAbilityContext): Promise<string[]> {
    return SearchSettings.loadHistory(context)
  }

  static recordHistory(context: common.UIAbilityContext, query: string): Promise<string[]> {
    return SearchSettings.recordQuery(context, query)
  }

  static clearHistory(context: common.UIAbilityContext): Promise<void> {
    return SearchSettings.clearHistory(context)
  }
}
