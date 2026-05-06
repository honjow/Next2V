import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  CookieJarSettings,
  LoadingFooter,
  SecondaryListScaffold,
  ThemeConstants,
  TopicCard,
  type TopicDetailParams,
  type V2exTopic
} from 'shared'

@Component
export struct MyRepliesPage {
  @Consume('ns') stack: NavPathStack

  @State private topics: V2exTopic[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false
  @State private isLoadingMore: boolean = false
  @State private page: number = 1
  @State private hasMore: boolean = true

  private api: ApiService = new ApiService()
  private readonly PAGE_SIZE: number = 20

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      SecondaryListScaffold({ onReachEnd: () => { this.loadMore() } }) {
        if (!CookieJarSettings.getCurrentCookie()) {
          ListItem() { this.LoginRequiredView() }
        } else if (this.isLoading && this.topics.length === 0) {
          ListItem() { this.LoadingView() }
        } else if (this.errorMessage && this.topics.length === 0) {
          ListItem() { this.ErrorView() }
        } else {
          ForEach(this.topics, (item: V2exTopic) => {
            ListItem() {
              TopicCard({ item: item })
            }
              .onClick(() => {
                let p: TopicDetailParams = { topicId: item.id }
                this.stack.pushPathByName('TopicDetail', p as Object)
              })
          }, (item: V2exTopic) => `my-reply-topic-${item.id}`)

          if (this.topics.length === 0) {
            ListItem() { this.EmptyView() }
          }

          ListItem() {
            LoadingFooter({ isLoading: this.isLoadingMore, hasMore: this.hasMore })
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder private LoadingView() {
    Column() {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE)
        .height(ThemeConstants.LOADING_SIZE)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private LoginRequiredView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('登录后可查看我的回复')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('去登录')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .onClick(() => { this.stack.pushPathByName('V2exNativeLogin', null) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private ErrorView() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.errorMessage)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .onClick(() => { this.refresh(true) })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  @Builder private EmptyView() {
    Column() {
      Text('还没有回复')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(240)
  }

  private refresh(force: boolean = false): void {
    if (this.isLoading || this.isLoadingMore) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.topics = []
      this.errorMessage = ''
      this.page = 1
      this.hasMore = false
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    this.page = 1
    this.hasMore = true

    this.api.getMyRepliesWithCookie(cookie, 1)
      .then((topics) => {
        this.topics = topics
        this.hasMore = topics.length >= this.PAGE_SIZE
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '加载失败'
        this.topics = []
        this.hasMore = false
      })
      .finally(() => {
        this.isLoading = false
        if (!force && this.errorMessage) {
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => { })
        }
      })
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
    this.api.getMyRepliesWithCookie(cookie, nextPage)
      .then((topics) => {
        const existing = new Set(this.topics.map(item => item.id))
        const appended = topics.filter(item => !existing.has(item.id))
        this.topics = this.topics.concat(appended)
        this.page = nextPage
        this.hasMore = topics.length >= this.PAGE_SIZE
      })
      .catch((error: Error) => {
        this.hasMore = false
        promptAction.openToast({ message: error.message || '加载更多失败' }).catch((_error: Error) => { })
      })
      .finally(() => {
        this.isLoadingMore = false
      })
  }
}

