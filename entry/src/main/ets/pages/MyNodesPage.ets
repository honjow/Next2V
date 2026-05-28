import { promptAction } from '@kit.ArkUI'
import {
  ApiService,
  AppStrings,
  CollectionSettings,
  CardEmptyState,
  ConciseListRow,
  CookieJarSettings,
  GroupedListSection,
  ImageUtils,
  NodeIndexRepository,
  PageErrorState,
  PageLoadingState,
  PageLoginRequiredState,
  SecondaryListScaffold,
  translateApiError,
  type NodeTopicListParams,
  type V2exFavoriteNode,
  type V2exNode
} from 'shared'

@Component
export struct MyNodesPage {
  @Consume('ns') stack: NavPathStack
  @State private nodes: V2exFavoriteNode[] = []
  @State private errorMessage: string = ''
  @State private isLoading: boolean = false
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.refresh()
  }

  build() {
    Column() {
      if (!CookieJarSettings.getCurrentCookie()) {
        PageLoginRequiredState({
          message: AppStrings.text(AppStrings.R_LOGIN_TO_VIEW_NODES, 'Sign in to view favorite nodes'),
          action: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.isLoading && this.nodes.length === 0) {
        PageLoadingState()
      } else if (this.errorMessage && this.nodes.length === 0) {
        PageErrorState({
          message: this.errorMessage,
          retryAction: () => {
            this.refresh(true)
          },
          secondaryLabel: AppStrings.text(AppStrings.R_LOGIN_ACTION, 'Log in'),
          secondaryAction: () => {
            this.stack.pushPathByName('V2exNativeLogin', null)
          }
        })
      } else if (this.nodes.length === 0) {
        CardEmptyState({ message: $r('app.string.empty_no_favorite_nodes') })
      } else {
        SecondaryListScaffold() {
          ForEach(this.nodes, (item: V2exFavoriteNode) => {
            ListItem() {
              GroupedListSection() {
                ConciseListRow({
                  title: item.title || item.name,
                  subtitle: this.nodeSubtitle(item),
                  leadingImageUrl: this.nodeIcon(item),
                  action: () => {
                    this.openNode(item)
                  }
                })
              }
            }
            .onClick(() => {
              this.openNode(item)
            })
          }, (item: V2exFavoriteNode) => `my-node-${item.name}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private refresh(force: boolean = false): void {
    if (this.isLoading) {
      return
    }
    const cookie = CookieJarSettings.getCurrentCookie()
    if (!cookie) {
      this.nodes = []
      this.errorMessage = ''
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    this.api.getMyFavoriteNodesWithCookie(cookie)
      .then((nodes) => {
        this.loadNodesWithIcons(nodes, () => {
          this.isLoading = false
          if (!force && this.errorMessage) {
            promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => {
            })
          }
        })
      })
      .catch((error: Error) => {
        this.errorMessage = translateApiError(error)
        this.nodes = []
        this.isLoading = false
        if (!force && this.errorMessage) {
          promptAction.openToast({ message: this.errorMessage }).catch((_error: Error) => {
          })
        }
      })
  }

  private openNode(item: V2exFavoriteNode): void {
    const p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title || item.name }
    this.stack.pushPathByName('NodeTopicList', p as Object)
  }

  private nodeSubtitle(item: V2exFavoriteNode): string {
    const parts: string[] = [item.name]
    if ((item.topics || 0) > 0) {
      parts.push(AppStrings.format(AppStrings.text(AppStrings.R_NODE_TOPICS_COUNT, '{0} topics'), [String(item.topics)]))
    }
    return parts.join(' · ')
  }

  private nodeIcon(item: V2exFavoriteNode): string {
    return item.avatarLarge || ImageUtils.avatarUrl(item.avatarNormal ?? '') || item.avatarMini || ''
  }

  private loadNodesWithIcons(favorites: V2exFavoriteNode[], onDone: () => void): void {
    // All nodes already have icons, assign directly
    if (favorites.every((item: V2exFavoriteNode) => this.nodeIcon(item))) {
      this.nodes = favorites
      onDone()
      return
    }
    // Some nodes missing icons, fetch full node data first, merge then assign
    NodeIndexRepository.getNodes(this.api)
      .then((result) => {
        const allNodes: V2exNode[] = result.nodes
        const nodeByName: Record<string, V2exNode> = {}
        allNodes.forEach((node: V2exNode) => {
          nodeByName[node.name] = node
        })
        this.nodes = favorites.map((node: V2exFavoriteNode) => {
          const detail = nodeByName[node.name]
          if (!detail) {
            return node
          }
          return {
            name: node.name,
            title: CollectionSettings.cleanNodeTitle(
              detail.title || node.title, detail.topics || node.topics || 0),
            topics: detail.topics || node.topics,
            avatarMini: node.avatarMini || detail.avatar_mini,
            avatarNormal: node.avatarNormal || detail.avatar_normal,
            avatarLarge: node.avatarLarge || detail.avatar_large
          }
        })
      })
      .catch((error: Error) => {
        console.error('enrich favorite node icons failed: ' + error.message)
        // Fallback: use data without icons
        this.nodes = favorites
      })
      .finally(() => {
        onDone()
      })
  }
}
