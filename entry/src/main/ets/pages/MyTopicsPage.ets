import { promptAction } from '@kit.ArkUI'
import {
  ApiService, AppStrings,
  CookieJarSettings,
  PageLoginRequiredState,
  PagedListScaffold,
  StorageKeys,
  TopicCard,
  TwoFactorChallengeService,
  translateApiError,
  type TopicDetailParams,
  type V2exTopic,
  V2exCookieTwoFactorRequiredError
} from 'shared'

@Component
export struct MyTopicsPage {
  @Consume('ns') stack: NavPathStack
  @StorageLink(StorageKeys.AUTH_SESSION_UPDATED_AT)
  @Watch('onAuthSessionUpdated')
  authSessionUpdatedAt: number = 0
  @State private topics: V2exTopic[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = true
  @State private isLoadingMore: boolean = false
  @State private page: number = 1
  @State private hasMore: boolean = true
  private api: ApiService = new ApiService()
  private readonly PAGE_SIZE: number = 20
  private refreshGuard: boolean = false

  aboutToAppear(): void {
    this.refresh()
  }

  onAuthSessionUpdated(_propName: string): void {
    this.refresh(true)
  }

  build() {
    Column() {
      if (!CookieJarSettings.getCurrentCookie()) {
        PageLoginRequiredState({
          message: AppStrings.text(AppStrings.R_LOGIN_TO_VIEW_TOPICS, 'Sign in to view favorite topics'),
          action: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.isLoading && this.topics.length === 0) {
        PagedListScaffold({
          isInitialLoading: true
        }) {}
      } else if (this.errorMessage && this.topics.length === 0) {
        PagedListScaffold({
          errorMessage: this.errorMessage,
          retryAction: () => {
            this.refresh(true)
          },
          secondaryLabel: AppStrings.text(AppStrings.R_LOGIN_ACTION, 'Log in'),
          secondaryAction: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        }) {}
      } else if (this.topics.length === 0) {
        PagedListScaffold({
          isEmpty: true,
          emptyMessage: AppStrings.text($r('app.string.empty_no_favorite_topics'), 'No favorite topics yet')
        }) {}
      } else {
        PagedListScaffold({
          isLoadingMore: this.isLoadingMore,
          hasMore: this.hasMore,
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
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
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
        this.errorMessage = translateApiError(error)
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
      this.errorMessage = AppStrings.text(AppStrings.R_TWO_FACTOR_RELOGIN_REQUIRED, 'V2EX requires two-factor verification. Please sign in again')
      return
    }
    this.errorMessage = AppStrings.text(AppStrings.R_TWO_FACTOR_REQUIRED, 'V2EX requires two-factor verification')
    TwoFactorChallengeService.request(cookie, 'myTopics')
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
        promptAction.openToast({ message: translateApiError(error) }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isLoadingMore = false
      })
  }
}
