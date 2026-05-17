import type {
  Sov2exOrderMode,
  Sov2exSearchOptions,
  Sov2exSearchResponse,
  Sov2exSortMode,
} from 'shared'
import type {
  RemoteDateRange,
  RemoteTopicItem,
} from '../components/SearchPageComponents'
import {
  SearchPageStateCoordinator,
} from './SearchPageStateCoordinator'

export interface RemoteSearchRequestInput {
  keyword: string
  from: number
  sort: Sov2exSortMode
  order: Sov2exOrderMode
  username: string
  node: string
  dateRange: RemoteDateRange
}

export interface RemoteSearchResultsState {
  results: RemoteTopicItem[]
  total: number
  from: number
}

export class RemoteSearchCoordinator {
  static canExecute(keyword: string, loading: boolean): boolean {
    return keyword.trim().length > 0 && !loading
  }

  static buildRequest(input: RemoteSearchRequestInput, reset: boolean): Sov2exSearchOptions {
    return {
      q: input.keyword.trim(),
      from: reset ? 0 : input.from,
      size: 20,
      sort: input.sort,
      order: input.order,
      username: input.username.trim(),
      node: input.node.trim(),
      gte: SearchPageStateCoordinator.remoteGte(input.dateRange),
    }
  }

  static mergeResponse(
    currentResults: RemoteTopicItem[],
    response: Sov2exSearchResponse,
    reset: boolean,
  ): RemoteSearchResultsState {
    const hits = response.hits || []
    const next = hits.map((hit) => SearchPageStateCoordinator.remoteHitToItem(hit))
      .filter((item: RemoteTopicItem) => item.id > 0)
    const results = reset ? next : currentResults.concat(next)
    return {
      results,
      total: response.total || results.length,
      from: results.length,
    }
  }
}
