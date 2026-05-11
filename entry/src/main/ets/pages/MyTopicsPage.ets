import { promptAction } from '@kit.ArkUI'
import { V2exTwoFactorPrompt } from '../components/V2exTwoFactorPrompt'
import {
  ApiService,
  CookieJarSettings,
  EmptyState,
  LoadingFooter,
  PullRefreshListScaffold,
  ThemeConstants,
  TopicCard,
  type TopicDetailParams,
  type V2exTopic,
  V2exCookieTwoFactorRequiredError
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
        this.LoginRequiredView()
      } else if (this.isLoading && this.topics.length === 0) {
        this.LoadingView()
      } else if (this.errorMessage && this.topics.length === 0) {
        this.ErrorView()
      } else if (this.topics.length === 0) {
        this.EmptyView()
      } else {
        PullRefreshListScaffold({
          onReachEnd: () => { this.loadMore() },
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
    .bindSheet($$this.twoFactorVisible, this.TwoFactorSheet(), {
      height: SheetSize.MEDIUM,
      preferType: SheetType.BOTTOM,
      dragBar: false,
      showClose: false,
      maskColor: 'rgba(0,0,0,0.24)',
      backgroundColor: $r('sys.color.ohos_id_color_card_bg'),
      onDisappear: () => {
        this.twoFactorVisible = false
      }
    })
  }

  @Builder private TwoFactorSheet() {
    V2exTwoFactorPrompt({
      visible: $twoFactorVisible,
      cookie: this.twoFactorCookie,
      message: '完成两步验证后即可继续访问 V2EX 账号内容。',
      onSuccess: () => { this.refresh(true) }
    })
  }

  @Builder private LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder private LoginRequiredView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('登录后可查看收藏主题')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去登录')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .onClick(() => { this.stack.pushPathByName('V2exNativeLogin', null) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder private ErrorView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.errorMessage)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('重试')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .onClick(() => { this.refresh(true) })
        Button('去登录')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .onClick(() => { this.stack.pushPathByName('V2exNativeLogin', null) })
      }
      .justifyContent(FlexAlign.Center)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder private EmptyView() {
    Column() {
      EmptyState({ message: '还没有收藏主题' })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
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
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
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
        promptAction.openToast({ message: error.message || '加载更多失败' }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isLoadingMore = false
      })
  }
}
