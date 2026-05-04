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
  hasMore: boolean = true
  errorMessage: string = ''
  activeTab: string = 'tech'

  private api: ApiService = new ApiService()
  private loader: () => Promise<V2exTopic[]> = () => this.api.getTabTopics(this.activeTab)

  setLoader(loader: () => Promise<V2exTopic[]>): void {
    this.loader = loader
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

  /**
   * 供系统 Refresh 组件使用（$$ 绑定已设 isRefreshing=true，跳过 guard）
   */
  async refreshForce(): Promise<void> {
    // $$ 绑定已设 isRefreshing=true，不重复设置
    this.errorMessage = ''
    this.triggerHaptic()

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
}
