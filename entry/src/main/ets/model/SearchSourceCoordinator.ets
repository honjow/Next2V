import type {
  SearchSourceMode,
} from 'shared'

export type SearchPrimaryAction = 'none' | 'local' | 'remote' | 'external'
export type SearchRefreshAction = 'localRefresh' | 'remote' | 'external'

export interface SearchHistorySelection {
  query: string
  shouldApply: boolean
  shouldExecuteRemote: boolean
}

export interface SearchKeywordChangeEffect {
  query: string
  shouldApplyLocalFilter: boolean
  shouldResetRemote: boolean
}

export interface SearchSourceTransition {
  changed: boolean
  mode: SearchSourceMode
  shouldResetRemote: boolean
  shouldLoadNodeIndex: boolean
  shouldExecuteRemote: boolean
  shouldApplyLocalFilter: boolean
}

export interface SearchSourceModeEffect {
  shouldLoadNodeIndex: boolean
  shouldExecuteRemote: boolean
  shouldApplyLocalFilter: boolean
}

export class SearchSourceCoordinator {
  static shouldShowHistory(keyword: string, historyLength: number): boolean {
    return keyword.trim().length === 0 && historyLength > 0
  }

  static applyHistory(query: string, sourceMode: SearchSourceMode): SearchHistorySelection {
    const clean = (query ?? '').trim()
    return {
      query: clean,
      shouldApply: clean.length > 0,
      shouldExecuteRemote: sourceMode === 'remote' && clean.length > 0,
    }
  }

  static keywordChanged(query: string): SearchKeywordChangeEffect {
    return {
      query,
      shouldApplyLocalFilter: true,
      shouldResetRemote: true,
    }
  }

  static recordableQuery(query: string): string {
    return (query ?? '').trim()
  }

  static primaryAction(sourceMode: SearchSourceMode, keyword: string): SearchPrimaryAction {
    if (keyword.trim().length === 0) {
      return 'none'
    }
    if (sourceMode === 'remote') {
      return 'remote'
    }
    if (sourceMode === 'externalWeb') {
      return 'external'
    }
    return 'local'
  }

  static refreshAction(sourceMode: SearchSourceMode, keyword: string): SearchRefreshAction {
    if (sourceMode === 'remote') {
      return 'remote'
    }
    if (sourceMode === 'externalWeb' && keyword.trim().length > 0) {
      return 'external'
    }
    return 'localRefresh'
  }

  static transitionSourceMode(
    currentMode: SearchSourceMode,
    nextMode: SearchSourceMode,
    keyword: string,
  ): SearchSourceTransition {
    const changed = currentMode !== nextMode
    const hasKeyword = keyword.trim().length > 0
    const shouldLoadNodeIndex = nextMode === 'localWithNodes'
    return {
      changed,
      mode: nextMode,
      shouldResetRemote: changed,
      shouldLoadNodeIndex,
      shouldExecuteRemote: changed && nextMode === 'remote' && hasKeyword,
      shouldApplyLocalFilter: changed && nextMode !== 'remote' && !shouldLoadNodeIndex,
    }
  }

  static loadedSourceModeEffect(sourceMode: SearchSourceMode, keyword: string): SearchSourceModeEffect {
    const shouldLoadNodeIndex = sourceMode === 'localWithNodes'
    return {
      shouldLoadNodeIndex,
      shouldExecuteRemote: sourceMode === 'remote' && keyword.trim().length > 0,
      shouldApplyLocalFilter: sourceMode !== 'remote' && !shouldLoadNodeIndex,
    }
  }
}
