import { NodeViewModel } from '../viewmodel/NodeViewModel'
import {
  V2exTopic, TopicCard, ThemeConstants, TopicDetailParams, StorageKeys, UserProfileParams,
  CollectionSettings, SavedNode, AuthSettings, LoadingFooter
} from 'shared'
import type { TopicReadState } from 'shared'
import { common } from '@kit.AbilityKit'

@Component
export struct NodeTopicPage {
  @Prop nodeName: string = ''
  @Prop nodeTitle: string = ''
  @Consume('ns') stack: NavPathStack
  @State vm: NodeViewModel = new NodeViewModel()
  @StorageProp('topAvoidHeight') topH: number = 0
  @StorageLink(StorageKeys.TOPIC_READ_STATES) topicReadStates: string = '[]'
  @State private isNodeSaved: boolean = false
  @State private token: string = ''
  private readonly GAP: number = ThemeConstants.SPACE_MD

  aboutToAppear(): void {
    this.loadData()
    this.loadSavedState()
  }

  build() {
    Column() {
      if (this.vm.isLoading) {
        LoadingProgress().width(ThemeConstants.LOADING_SIZE).height(ThemeConstants.LOADING_SIZE).margin({ top: ThemeConstants.MARGIN_LOADING_TOP })
      } else if (this.vm.errorMessage) {
        this.ErrorView()
      } else if (this.vm.nodeTopics.length === 0) {
        this.EmptyView()
      } else {
        List({ space: this.GAP }) {
          ListItem() { Column() { Blank().height(this.topH + ThemeConstants.TITLE_BAR_HEIGHT) } }
          ListItem() { this.NodeHeaderCard() }
          ForEach(this.vm.nodeTopics, (topic: V2exTopic) => {
            ListItem() {
              TopicCard({
                item: topic,
                isUnread: this.isTopicUnread(topic),
                onUserClick: () => {
                  let p: UserProfileParams = { username: topic.member.username }
                  this.stack.pushPathByName('UserProfile', p as Object)
                }
              })
            }
              .onClick(() => {
                let p: TopicDetailParams = { topicId: topic.id }
                this.stack.pushPathByName('TopicDetail', p as Object)
              })
          })
          if (this.vm.nodeTopicsUseV2) {
            ListItem() {
              LoadingFooter({ isLoading: this.vm.isNodeTopicsLoadingMore, hasMore: this.vm.nodeTopicsHasMore })
            }
          }
        }
          .onReachEnd(() => {
            if (this.vm.nodeTopicsUseV2 && this.token) {
              this.vm.loadMoreNodeTopicsV2(this.nodeName, this.token)
            }
          })
          .scrollBar(BarState.Off)
          .padding({ left: this.GAP, right: this.GAP })
          .width('100%').height('100%')
      }
    }
      .width('100%').height('100%')
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder NodeHeaderCard() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.nodeTitle || this.nodeName)
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.nodeName} · ${(this.vm.nodeDetail?.topics || this.vm.nodeTopics.length)} 主题`)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button(this.isNodeSaved ? '已关注' : '关注')
        .fontSize(ThemeConstants.FONT_SIZE_TAG)
        .height(40)
        .onClick(() => { this.toggleSavedNode() })
    }
    .padding(ThemeConstants.SPACE_LG)
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder EmptyView() {
    Column() {
      Text('暂无主题')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder ErrorView() {
    Column() {
      Text(this.vm.errorMessage || '节点主题加载失败')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('重试')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .margin({ top: ThemeConstants.SPACE_LG })
        .onClick(() => { this.loadData() })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  private loadSavedState(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    CollectionSettings.isNodeSaved(context, this.nodeName)
      .then((saved: boolean) => {
        this.isNodeSaved = saved
      })
      .catch((error: Error) => {
        console.error('load saved node state failed: ' + error.message)
      })
  }

  private loadData(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AuthSettings.load(context)
      .then((snapshot) => {
        this.token = snapshot.token || ''
        this.vm.loadNodeDetailV2(this.nodeName, this.token)
        if (this.token) {
          return this.vm.loadNodeTopicsV2(this.nodeName, this.token)
        }
        return this.vm.loadNodeTopics(this.nodeName)
      })
      .catch((error: Error) => {
        this.token = ''
        this.vm.nodeDetailError = error.message || '读取 Token 失败'
        this.vm.loadNodeTopics(this.nodeName)
      })
  }

  private toggleSavedNode(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const node: SavedNode = {
      name: this.nodeName,
      title: this.nodeTitle || this.nodeName,
      topics: this.vm.nodeTopics.length,
      savedAt: Math.floor(Date.now() / 1000)
    }
    const request = this.isNodeSaved
      ? CollectionSettings.removeNode(context, this.nodeName)
      : CollectionSettings.saveNode(context, node)
    request
      .then(() => {
        this.isNodeSaved = !this.isNodeSaved
      })
      .catch((error: Error) => {
        console.error('toggle saved node failed: ' + error.message)
      })
  }

  private isTopicUnread(topic: V2exTopic): boolean {
    if (topic.id <= 0) {
      return false
    }
    const lastTouched = topic.last_touched || topic.last_modified || topic.created
    const state = this.findReadState(topic.id)
    if (!state) {
      return true
    }
    return lastTouched > state.touchedAt
  }

  private findReadState(topicId: number): TopicReadState | null {
    try {
      const parsed = JSON.parse(this.topicReadStates || '[]') as TopicReadState[]
      if (!Array.isArray(parsed)) {
        return null
      }
      for (let i = 0; i < parsed.length; i++) {
        if (parsed[i].id === topicId) {
          return parsed[i]
        }
      }
      return null
    } catch (_e) {
      return null
    }
  }
}
