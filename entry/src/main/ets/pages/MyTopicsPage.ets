import { AppPrompt } from 'shared'
import {
  ApiService, AppStrings,
  AuthSessionSignalState,
  connectAuthSessionSignal,
  connectNavStack,
  CookieJarSettings,
  PageLoginRequiredState,
  PagedListScaffold,
  TopicCard,
  translateApiError,
  type TopicDetailParams,
  type V2exTopic,
  type V2exPagedTopicsResult,
  V2exCookieTwoFactorRequiredError
} from 'shared'

@ComponentV2
export struct MyTopicsPage {
  // Same NavPathStack instance HdsNavigation is bound to (see NavStackHolder); method target only.
  private stack: NavPathStack = connectNavStack().stack
  // V2 mirror of AUTH_SESSION_UPDATED_AT (AuthSessionSettings.apply dual-writes AppStorage + this).
  @Local private authSignal: AuthSessionSignalState = connectAuthSessionSignal()
  @Local private topics: V2exTopic[] = []
  @Local private errorMessage: string = ''
  @Local private isLoading: boolean = true
  @Local private isLoadingMore: boolean = false
  @Local private page: number = 1
  @Local private hasMore: boolean = true
  private api: ApiService = new ApiService()
  private refreshGuard: boolean = false

  aboutToAppear(): void {
    this.refresh()
  }

  @Monitor('authSignal.updatedAt')
  onAuthSessionUpdated(): void {
    this.refresh(true)
  }

  build() {
    Column() {
      if (!CookieJarSettings.getCurrentCookie()) {
        PageLoginRequiredState({
          message: AppStrings.text($r('app.string.login_to_view_topics'), 'Sign in to view favorite topics'),
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
          secondaryLabel: AppStrings.text($r('app.string.login_action'), 'Log in'),
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
      .then((result: V2exPagedTopicsResult) => {
        this.topics = result.topics
        this.hasMore = result.hasMore
      })
      .catch((error: Error) => {
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.errorMessage = AppStrings.text($r('app.string.two_factor_required'), 'V2EX requires two-factor verification')
          this.topics = []
          this.hasMore = false
          return
        }
        this.errorMessage = translateApiError(error)
        this.topics = []
        this.hasMore = false
        if (!force) {
          AppPrompt.openToast({ message: this.errorMessage }).catch((_error: Error) => {
          })
        }
      })
      .finally(() => {
        this.isLoading = false
        this.refreshGuard = false
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
    this.api.getMyTopicsWithCookie(cookie, nextPage)
      .then((result: V2exPagedTopicsResult) => {
        const existing = new Set(this.topics.map(item => item.id))
        const appended = result.topics.filter(item => !existing.has(item.id))
        this.topics = this.topics.concat(appended)
        this.page = nextPage
        this.hasMore = result.hasMore
      })
      .catch((error: Error) => {
        this.hasMore = false
        if (error instanceof V2exCookieTwoFactorRequiredError) {
          this.errorMessage = AppStrings.text($r('app.string.two_factor_required'), 'V2EX requires two-factor verification')
          return
        }
        AppPrompt.openToast({ message: translateApiError(error) }).catch((_error: Error) => {
        })
      })
      .finally(() => {
        this.isLoadingMore = false
      })
  }
}
