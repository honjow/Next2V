import { promptAction } from '@kit.ArkUI'
import { V2exTwoFactorPrompt } from '../components/V2exTwoFactorPrompt'
import {
  ApiService,
  CardEmptyState,
  CookieJarSettings,
  LoadingFooter,
  PageErrorState,
  PageLoadingState,
  PageLoginRequiredState,
  PullRefreshListScaffold,
  TopicCard,
  type TopicDetailParams,
  type V2exTopic,
  V2exCookieTwoFactorRequiredError,
  towFASheetOptions
} from 'shared'

@Component
export struct MyTopicsPage {
  @Consume('ns') stack: NavPathStack
  @State private topics: V2exTopic[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = true
  @State private isLoadingMore: boolean = false
  @State private page: number = 1
  @State private hasMore: boolean = true
  @State private twoFactorVisible: boolean = false
  @State private twoFactorCookie: string = ''
  private api: ApiService = new ApiService()
  private readonly PAGE_SIZE: number = 20
  private refreshGuard: boolean = false

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      if (!CookieJarSettings.getCurrentCookie()) {
        PageLoginRequiredState({
          message: '登录后可查看收藏主题',
          action: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.isLoading && this.topics.length === 0) {
        PageLoadingState()
      } else if (this.errorMessage && this.topics.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          retryAction: () => {
            this.refresh(true)
          },
          secondaryLabel: '去登录',
          secondaryAction: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.topics.length === 0) {
        CardEmptyState({ message: '还没有收藏主题' })
      } else {
        PullRefreshListScaffold({
          onReachEnd: () => {
            this.loadMore()
          },
          onRefresh: () => this.refresh(true)
        }) {
          ForEach(this.topics, (item: V2exTopic) => {
            ListItem() {
              TopicCard({ item: item })
            }
            .onClick(() => {
              let p: TopicDetailParams = { topicId: item.id }
              this.stack.pushPathByName('TopicDetail', p as Object)
            })
          }, (item: V2exTopic) => `my-topic-${item.id}`)

          ListItem() {
            LoadingFooter({ isLoading: this.isLoadingMore, hasMore: this.hasMore })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .bindSheet($$this.twoFactorVisible, this.TwoFactorSheet(), towFASheetOptions(SheetSize.MEDIUM, () => {
      this.twoFactorVisible = false
    }))
  }

  @Builder
  private TwoFactorSheet() {
    V2exTwoFactorPrompt({
      visible: $twoFactorVisible,
      cookie: this.twoFactorCookie,
      message: '完成两步验证后即可继续访问 V2EX 账号内容。',
      onSuccess: () => {
        this.refresh(true)
      }
    })
  }

  private refresh(force: boolean = false): Promise<void> {
    if (this.refreshGuard || this.isLoadingMore) {
      return Promise.resolve()
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.topics = []
      this.errorMessage = ''
      this.page = 1
      this.hasMore = false
      this.isLoading = false
      return Promise.resolve()
    }
    this.refreshGuard = true
    this.isLoading = true
    this.errorMessage = ''
    this.page = 1
    this.hasMore = true

    return this.api.getMyTopicsWithCookie(cookie, 1)
      .then((topics) => {
        this.topics = topics
        this.hasMore = topics.length >= this.PAGE_SIZE
      })
      .catch((error: Error) => {
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        this.errorMessage = error.message || '加载失败'
        this.topics = []
        this.hasMore = false
        if (!force) {
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => {
          })
        }
      })
      .finally(() => {
        this.isLoading = false
        this.refreshGuard = false
      })
  }

  private openTwoFactorFromCookie(): void {
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.errorMessage = 'V2EX 需要完成两步验证，请重新登录'
      return
    }
    this.errorMessage = 'V2EX 需要完成两步验证'
    this.twoFactorCookie = cookie
    this.twoFactorVisible = true
  }

  private loadMore(): void {
    if (this.isLoading || this.isLoadingMore || !this.hasMore) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.hasMore = false
      return
    }
    this.isLoadingMore = true
    const nextPage = this.page + 1
    this.api.getMyTopicsWithCookie(cookie, nextPage)
      .then((topics) => {
        const existing = new Set(this.topics.map(item => item.id))
        const appended = topics.filter(item => !existing.has(item.id))
        this.topics = this.topics.concat(appended)
        this.page = nextPage
        this.hasMore = topics.length >= this.PAGE_SIZE
      })
      .catch((error: Error) => {
        this.hasMore = false
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.openTwoFactorFromCookie()
          return
        }
        promptAction.openToast({ message: error.message || '加载更多失败' }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isLoadingMore = false
      })
  }
}
