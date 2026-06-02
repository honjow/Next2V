import { ThemeConstants } from '../theme/ThemeConstants'
import { CardEmptyState, PageErrorState, PageLoadingState } from './PageState'
import { LoadingFooter } from './LoadingFooter'
import { PullRefreshListScaffold } from './PullRefreshListScaffold'
import { AppStrings } from '../i18n/AppStrings'

@ComponentV2
export struct PagedListScaffold {
  @BuilderParam content: () => void
  scroller: Scroller = new Scroller()
  @Param isInitialLoading: boolean = false
  @Param isEmpty: boolean = false
  @Param errorMessage: string = ''
  @Param emptyMessage: string = ''
  @Param isLoadingMore: boolean = false
  @Param hasMore: boolean = true
  @Param loadMoreErrorMessage: string = ''
  @Param loadMoreRetryLabel: string = ''
  @Param showFooter: boolean = true
  @Param listSpace: number = ThemeConstants.SPACE_SM - 2
  @Param horizontalPadding: number = ThemeConstants.SPACE_MD
  @Param topPadding: number = 0
  @Param bottomPadding: number = ThemeConstants.SPACE_XL
  @Param indicatorTop: number = -1
  @Param refreshThreshold: number = 120
  @Param scrollEnabled: boolean = true
  @Event retryAction?: () => void
  @Param secondaryLabel: string = ''
  @Event secondaryAction?: () => void
  @Event onRefresh?: () => Promise<void>
  @Event onReachEnd?: () => void
  @Event onLoadMoreRetry?: () => void
  @Event onDidScroll?: (offset: number, state: ScrollState) => void

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
        onReachEnd: this.onReachEnd,
        onDidScroll: this.onDidScroll
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
