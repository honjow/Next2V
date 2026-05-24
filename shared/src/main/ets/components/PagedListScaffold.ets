import { ThemeConstants } from '../theme/ThemeConstants'
import { CardEmptyState, PageErrorState, PageLoadingState } from './PageState'
import { LoadingFooter } from './LoadingFooter'
import { PullRefreshListScaffold } from './PullRefreshListScaffold'
import { AppStrings } from '../i18n/AppStrings'

@Component
export struct PagedListScaffold {
  @BuilderParam content: () => void
  scroller: Scroller = new Scroller()
  @Prop isInitialLoading: boolean = false
  @Prop isEmpty: boolean = false
  @Prop errorMessage: string = ''
  @Prop emptyMessage: string = ''
  @Prop isLoadingMore: boolean = false
  @Prop hasMore: boolean = true
  @Prop loadMoreErrorMessage: string = ''
  @Prop loadMoreRetryLabel: string = ''
  @Prop showFooter: boolean = true
  @Prop listSpace: number = ThemeConstants.SPACE_SM - 2
  @Prop horizontalPadding: number = ThemeConstants.SPACE_MD
  @Prop topPadding: number = 0
  @Prop bottomPadding: number = ThemeConstants.SPACE_XL
  @Prop indicatorTop: number = -1
  @Prop refreshThreshold: number = 120
  @Prop scrollEnabled: boolean = true
  retryAction?: () => void
  secondaryLabel?: string
  secondaryAction?: () => void
  onRefresh?: () => Promise<void>
  onReachEnd?: () => void
  onLoadMoreRetry?: () => void

  build() {
    if (this.isInitialLoading) {
      PageLoadingState()
    } else if (this.errorMessage) {
      PageErrorState({
        message: this.errorMessage,
        retryAction: () => {
          if (this.retryAction) {
            this.retryAction()
          }
        },
        secondaryLabel: this.secondaryLabel,
        secondaryAction: this.secondaryAction
      })
    } else if (this.isEmpty) {
      CardEmptyState({
        message: this.emptyMessage || AppStrings.text(AppStrings.R_COMMON_NO_CONTENT, 'No content')
      })
    } else {
      PullRefreshListScaffold({
        scroller: this.scroller,
        listSpace: this.listSpace,
        horizontalPadding: this.horizontalPadding,
        topPadding: this.topPadding,
        bottomPadding: this.bottomPadding,
        indicatorTop: this.indicatorTop,
        refreshThreshold: this.refreshThreshold,
        scrollEnabled: this.scrollEnabled,
        onRefresh: this.onRefresh,
        onReachEnd: this.onReachEnd
      }) {
        this.content()

        if (this.showFooter) {
          ListItem() {
            LoadingFooter({
              isLoading: this.isLoadingMore,
              hasMore: this.hasMore,
              isError: this.loadMoreErrorMessage.length > 0,
              errorMessage: this.loadMoreErrorMessage || AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED_TAP_RETRY, 'Load failed, tap to retry'),
              retryLabel: this.loadMoreRetryLabel,
              onRetry: () => {
                if (this.onLoadMoreRetry) {
                  this.onLoadMoreRetry()
                }
              }
            })
          }
        }
      }
    }
  }
}
