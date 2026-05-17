import type {
  Sov2exOrderMode,
  Sov2exSortMode,
} from 'shared'
import type {
  RemoteDateRange,
  SearchResultFilter,
} from '../components/SearchPageComponents'

export interface LocalResultFilterEffect {
  changed: boolean
  filter: SearchResultFilter
  shouldApplyLocalFilter: boolean
}

export interface RemoteFilterEffect {
  changed: boolean
  shouldResetRemote: boolean
  shouldExecuteRemote: boolean
}

export interface RemoteOrderEffect extends RemoteFilterEffect {
  order: Sov2exOrderMode
}

export interface RemoteDateRangeEffect extends RemoteFilterEffect {
  dateRange: RemoteDateRange
}

export interface RemoteClearFiltersEffect extends RemoteFilterEffect {
  username: string
  node: string
  dateRange: RemoteDateRange
}

export class SearchFilterCoordinator {
  static updateLocalResultFilter(
    currentFilter: SearchResultFilter,
    nextFilter: SearchResultFilter,
  ): LocalResultFilterEffect {
    const changed = currentFilter !== nextFilter
    return {
      changed,
      filter: nextFilter,
      shouldApplyLocalFilter: changed,
    }
  }

  static selectRemoteSort(_currentSort: Sov2exSortMode, _nextSort: Sov2exSortMode): RemoteFilterEffect {
    return {
      changed: true,
      shouldResetRemote: true,
      shouldExecuteRemote: false,
    }
  }

  static toggleRemoteOrder(currentOrder: Sov2exOrderMode): RemoteOrderEffect {
    return {
      changed: true,
      order: currentOrder === '0' ? '1' : '0',
      shouldResetRemote: true,
      shouldExecuteRemote: false,
    }
  }

  static remoteTextChanged(): RemoteFilterEffect {
    return {
      changed: true,
      shouldResetRemote: true,
      shouldExecuteRemote: false,
    }
  }

  static selectRemoteDateRange(
    currentRange: RemoteDateRange,
    nextRange: RemoteDateRange,
  ): RemoteDateRangeEffect {
    const changed = currentRange !== nextRange
    return {
      changed,
      dateRange: nextRange,
      shouldResetRemote: false,
      shouldExecuteRemote: changed,
    }
  }

  static clearRemoteFilters(): RemoteClearFiltersEffect {
    return {
      changed: true,
      username: '',
      node: '',
      dateRange: 'all',
      shouldResetRemote: true,
      shouldExecuteRemote: true,
    }
  }
}
