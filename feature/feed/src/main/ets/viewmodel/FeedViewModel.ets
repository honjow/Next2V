import { V2exTopic, ApiService, translateApiError, CacheMergeCoordinator } from 'shared'
import type { TopicReadState } from 'shared'
import { FeedDataSource } from '../model/FeedModels'
import { vibrator } from '@kit.SensorServiceKit'

/**
 * Feed page ViewModel
 * MVVM: ViewModel holds state and business logic, View is pure rendering
 */
@ObservedV2
export class FeedViewModel {
  // Stable ref; LazyForEach subscribes to its IDataSource listeners directly, so it is not @Trace.
  dataSource: FeedDataSource = new FeedDataSource()
  @Trace isLoading: boolean = false
  @Trace isRefreshing: boolean = false
  @Trace isLoadingMore: boolean = false
  @Trace hasMore: boolean = true
  @Trace errorMessage: string = ''
  // @Trace mirror of dataSource.totalCount(); read in FeedListPage build() so the loading->list branch
  // re-evaluates under V2 (a non-@Trace dataSource mutation alone would not re-run build()).
  @Trace itemCount: number = 0
  activeTab: string = 'tech'
  page: number = 0

  private api: ApiService = new ApiService()
  private loader: () => Promise<V2exTopic[]> = () => this.api.getTabTopics(this.activeTab)
  private pagedLoader: ((page: number) => Promise<V2exTopic[]>) | null = null
  private cacheLoader: (() => Promise<V2exTopic[]>) | null = null
  private cacheSaver: ((topics: V2exTopic[]) => Promise<void>) | null = null
  private readStateLoader: (() => Promise<TopicReadState[]>) | null = null

  setLoader(loader: () => Promise<V2exTopic[]>): void {
    this.loader = loader
    this.pagedLoader = null
    this.page = 0
  }

  setPagedLoader(loader: (page: number) => Promise<V2exTopic[]>): void {
    this.pagedLoader = loader
    this.loader = () => loader(1)
    this.page = 0
  }

  setCacheHandlers(
    loader: () => Promise<V2exTopic[]>,
    saver: (topics: V2exTopic[]) => Promise<void>,
    readStateLoader?: () => Promise<TopicReadState[]>,
  ): void {
    this.cacheLoader = loader
    this.cacheSaver = saver
    this.readStateLoader = readStateLoader || null
  }

  async loadCachedData(): Promise<void> {
    if (!this.cacheLoader || this.dataSource.totalCount() > 0) {
      return
    }
    try {
      const data = await this.cacheLoader()
      if (data.length > 0) {
        this.dataSource.setData(await this.mergeTopicListWithReadStates(data))
        this.itemCount = this.dataSource.totalCount()
        this.hasMore = this.pagedLoader !== null ? true : data.length >= 20
      }
    } catch (error) {
      console.error('load feed cache failed:', (error as Error).message)
    }
  }

  /** Switch tab and load data */
  async switchTab(tab: string): Promise<void> {
    if (tab === this.activeTab && this.dataSource.totalCount() > 0) {
      return
    }
    this.activeTab = tab
    this.setLoader(() => this.api.getTabTopics(tab))
    await this.loadData()
  }

  async loadData(): Promise<void> {
    if (this.isLoading) return

    this.isLoading = true
    this.errorMessage = ''
    this.page = 0

    try {
      const data = await this.loadPage(1)
      const merged = await this.mergeTopicListWithReadStates(data)
      this.dataSource.setData(merged)
      this.itemCount = this.dataSource.totalCount()
      this.page = 1
      this.hasMore = this.resolveHasMore(data.length, data.length)
      await this.saveCache(data)
    } catch (error) {
      this.errorMessage = translateApiError(error)
      await this.loadCachedData()
    } finally {
      this.isLoading = false
    }
  }

  async refresh(): Promise<void> {
    if (this.isRefreshing) return

    this.isRefreshing = true
    this.errorMessage = ''
    this.page = 0

    try {
      const data = await this.loadPage(1)
      const merged = await this.mergeTopicListWithReadStates(data)
      this.dataSource.setData(merged)
      this.itemCount = this.dataSource.totalCount()
      this.page = 1
      this.hasMore = this.resolveHasMore(data.length, data.length)
      await this.saveCache(data)
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isRefreshing = false
    }
  }

  /**
   * For use by the system Refresh component ($$ binding already set isRefreshing=true, skip guard)
   */
  async refreshForce(): Promise<void> {
    // $$ binding already set isRefreshing=true, do not set again
    this.errorMessage = ''
    this.triggerHaptic()

    try {
      const data = await this.loadPage(1)
      const merged = await this.mergeTopicListWithReadStates(data)
      this.dataSource.setData(merged)
      this.itemCount = this.dataSource.totalCount()
      this.page = 1
      this.hasMore = this.resolveHasMore(data.length, data.length)
      await this.saveCache(data)
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isRefreshing = false
    }
  }


  async loadMore(): Promise<void> {
    if (this.isLoading || this.isRefreshing || this.isLoadingMore || !this.hasMore || !this.pagedLoader) {
      return
    }

    this.isLoadingMore = true
    this.errorMessage = ''
    try {
      const nextPage = Math.max(1, this.page + 1)
      const data = await this.loadPage(nextPage)
      const unique = this.filterNewTopics(data)
      const mergedUnique = await this.mergeTopicListWithReadStates(unique)
      this.page = nextPage
      this.hasMore = this.resolveHasMore(data.length, unique.length)
      this.dataSource.appendData(mergedUnique)
      this.itemCount = this.dataSource.totalCount()
      await this.saveCache(this.dataSource.getAllData())
    } catch (error) {
      this.errorMessage = translateApiError(error)
    } finally {
      this.isLoadingMore = false
    }
  }

  canLoadMore(): boolean {
    return this.pagedLoader !== null && this.hasMore && !this.isLoading && !this.isRefreshing && !this.isLoadingMore
  }

  /** HD haptic feedback */
  private triggerHaptic(): void {
    try {
      if (vibrator.isHdHapticSupported()) {
        vibrator.startVibration({
          type: 'preset',
          effectId: 'haptic.effect.soft',
          count: 1,
          intensity: 60,
        }, {
          usage: 'physicalFeedback',
        })
      } else {
        vibrator.startVibration({
          type: 'time',
          duration: 30,
        }, {
          usage: 'physicalFeedback',
        })
      }
    } catch (e) {
      // Silent failure
    }
  }

  private async saveCache(data: V2exTopic[]): Promise<void> {
    if (!this.cacheSaver || data.length === 0) {
      return
    }
    try {
      await this.cacheSaver(data)
    } catch (error) {
      console.error('save feed cache failed:', (error as Error).message)
    }
  }

  private async loadPage(page: number): Promise<V2exTopic[]> {
    if (this.pagedLoader) {
      return this.pagedLoader(page)
    }
    return this.loader()
  }

  private async mergeTopicListWithReadStates(data: V2exTopic[]): Promise<V2exTopic[]> {
    if (!this.readStateLoader || data.length === 0) {
      return data
    }
    try {
      const readStates = await this.readStateLoader()
      return CacheMergeCoordinator.mergeTopicListWithReadStates(data, readStates)
    } catch (_error) {
      return data
    }
  }

  private resolveHasMore(fetchedCount: number, uniqueCount: number): boolean {
    if (this.pagedLoader) {
      return fetchedCount > 0 && uniqueCount > 0
    }
    return fetchedCount >= 20
  }

  private filterNewTopics(data: V2exTopic[]): V2exTopic[] {
    const existingIds: Set<number> = new Set(this.dataSource.getAllData().map((topic: V2exTopic) => topic.id))
    const unique: V2exTopic[] = []
    data.forEach((topic: V2exTopic) => {
      if (existingIds.has(topic.id)) {
        return
      }
      existingIds.add(topic.id)
      unique.push(topic)
    })
    return unique
  }
}
