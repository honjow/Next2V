import { V2exTopic, ApiService } from 'shared'
import { FeedDataSource } from '../model/FeedModels'
import { vibrator } from '@kit.SensorServiceKit'

/**
 * Feed 页面 ViewModel
 * MVVM: ViewModel 持有状态和业务逻辑，View 纯渲染
 */
@Observed
export class FeedViewModel {
  dataSource: FeedDataSource = new FeedDataSource()
  isLoading: boolean = false
  isRefreshing: boolean = false
  isLoadingMore: boolean = false
  hasMore: boolean = true
  errorMessage: string = ''
  activeTab: string = 'tech'
  page: number = 0

  private api: ApiService = new ApiService()
  private loader: () => Promise<V2exTopic[]> = () => this.api.getTabTopics(this.activeTab)
  private pagedLoader: ((page: number) => Promise<V2exTopic[]>) | null = null
  private cacheLoader: (() => Promise<V2exTopic[]>) | null = null
  private cacheSaver: ((topics: V2exTopic[]) => Promise<void>) | null = null

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

  setCacheHandlers(loader: () => Promise<V2exTopic[]>, saver: (topics: V2exTopic[]) => Promise<void>): void {
    this.cacheLoader = loader
    this.cacheSaver = saver
  }

  async loadCachedData(): Promise<void> {
    if (!this.cacheLoader || this.dataSource.totalCount() > 0) {
      return
    }
    try {
      const data = await this.cacheLoader()
      if (data.length > 0) {
        this.dataSource.setData(data)
        this.hasMore = this.pagedLoader !== null ? true : data.length >= 20
      }
    } catch (error) {
      console.error('load feed cache failed:', (error as Error).message)
    }
  }

  /** 切换 tab 并加载数据 */
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
      this.dataSource.setData(data)
      this.page = 1
      this.hasMore = this.resolveHasMore(data.length, data.length)
      await this.saveCache(data)
    } catch (error) {
      this.errorMessage = error.message || '加载失败'
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
      this.dataSource.setData(data)
      this.page = 1
      this.hasMore = this.resolveHasMore(data.length, data.length)
      await this.saveCache(data)
    } catch (error) {
      this.errorMessage = error.message || '刷新失败'
    } finally {
      this.isRefreshing = false
    }
  }

  /**
   * 供系统 Refresh 组件使用（$$ 绑定已设 isRefreshing=true，跳过 guard）
   */
  async refreshForce(): Promise<void> {
    // $$ 绑定已设 isRefreshing=true，不重复设置
    this.errorMessage = ''
    this.triggerHaptic()

    try {
      const data = await this.loadPage(1)
      this.dataSource.setData(data)
      this.page = 1
      this.hasMore = this.resolveHasMore(data.length, data.length)
      await this.saveCache(data)
    } catch (error) {
      this.errorMessage = error.message || '刷新失败'
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
      this.page = nextPage
      this.hasMore = this.resolveHasMore(data.length, unique.length)
      this.dataSource.appendData(unique)
      await this.saveCache(this.dataSource.getAllData())
    } catch (error) {
      this.errorMessage = error.message || '加载更多失败'
    } finally {
      this.isLoadingMore = false
    }
  }

  canLoadMore(): boolean {
    return this.pagedLoader !== null && this.hasMore && !this.isLoading && !this.isRefreshing && !this.isLoadingMore
  }

  /** HD 震动反馈 */
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
      // 静默失败
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
