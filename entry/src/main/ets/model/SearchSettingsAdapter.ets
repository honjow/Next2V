import { common } from '@kit.AbilityKit'
import { SearchSettings } from 'shared'

export class SearchSettingsAdapter {
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
