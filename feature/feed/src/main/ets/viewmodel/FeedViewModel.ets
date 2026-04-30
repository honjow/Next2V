import { V2exTopic, ApiService } from 'shared'
import { FeedDataSource } from '../model/FeedModels'

/**
 * Feed 页面 ViewModel
 * MVVM: ViewModel 持有状态和业务逻辑，View 纯渲染
 */
@Observed
export class FeedViewModel {
  dataSource: FeedDataSource = new FeedDataSource()
  isLoading: boolean = false
  isRefreshing: boolean = false
  hasMore: boolean = true
  errorMessage: string = ''

  private api: ApiService = new ApiService()
  // 默认加载最新，子类/hot 模式通过 setLoader 注入
  private loader: () => Promise<V2exTopic[]> = () => this.api.getLatestTopics()

  setLoader(loader: () => Promise<V2exTopic[]>): void {
    this.loader = loader
  }

  async loadData(): Promise<void> {
    if (this.isLoading) return

    this.isLoading = true
    this.errorMessage = ''

    try {
      const data = await this.loader()
      this.dataSource.setData(data)
      this.hasMore = data.length >= 20  // 如果返回 20 条，可能还有更多
    } catch (error) {
      this.errorMessage = error.message || '加载失败'
    } finally {
      this.isLoading = false
    }
  }

  async refresh(): Promise<void> {
    if (this.isRefreshing) return

    this.isRefreshing = true
    this.errorMessage = ''

    try {
      const data = await this.loader()
      this.dataSource.setData(data)
      this.hasMore = data.length >= 20
    } catch (error) {
      this.errorMessage = error.message || '刷新失败'
    } finally {
      this.isRefreshing = false
    }
  }
}
