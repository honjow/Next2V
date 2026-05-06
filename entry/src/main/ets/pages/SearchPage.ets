import { common, Want } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import {
  CacheSettings,
  type CacheKeyIndex,
  CollectionSettings,
  ApiService,
  NodeSearchUtils,
  type NodeTopicListParams,
  type SavedNode,
  type SavedTopic,
  SearchSettings,
  type SearchSourceMode,
  StorageKeys,
  ThemeConstants,
  type TopicDetailParams,
  type V2exNode,
  type ViewedTopic
} from 'shared'

interface SearchTopicItem {
  id: number
  title: string
  nodeName: string
  nodeTitle: string
  username: string
  source: string
  updatedAt: number
}

interface SearchNodeItem {
  name: string
  title: string
  topics: number
  source: string
  updatedAt: number
  score: number
}

type SearchResultFilter = 'all' | 'topics' | 'nodes' | 'users'

@Component
export struct SearchPage {
  @Consume('ns') stack: NavPathStack

  @State private keyword: string = ''
  @State private errorMessage: string = ''

  @State private savedTopics: SavedTopic[] = []
  @State private viewedTopics: ViewedTopic[] = []
  @State private savedNodes: SavedNode[] = []
  @State private allNodes: V2exNode[] = []
  @State private isNodeIndexLoading: boolean = false

  @State private cacheTopicLists: SearchTopicItem[] = []
  @State private cacheTopicDetails: SearchTopicItem[] = []
  @State private isCacheLoading: boolean = false

  @State private history: string[] = []
  @State private sourceMode: SearchSourceMode = 'localWithNodes'
  @State private resultFilter: SearchResultFilter = 'all'

  @State private topicResults: SearchTopicItem[] = []
  @State private nodeResults: SearchNodeItem[] = []
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0

  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.keyword = ''
    this.errorMessage = ''
    this.loadLocalCollections()
    this.loadCacheCollections()
    this.loadSourceMode()
    this.loadHistory()
  }

  aboutToDisappear(): void {
    this.recordHistory()
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(this.sourceModeSummary())
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor($r('sys.color.font_secondary'))

      if (this.isCacheLoading) {
        Text('正在加载离线缓存索引…')
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      if (this.isNodeIndexLoading) {
        Text('正在加载节点索引…')
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(Color.Red)
      }

      TextInput({ placeholder: '输入关键词（标题/节点/用户）', text: this.keyword })
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .height(44)
        .borderRadius(ThemeConstants.RADIUS_MD)
        .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
        .onChange((value: string) => {
          this.keyword = value
          this.applyFilter()
        })

      this.SourceModeControls()
      if (this.sourceMode !== 'externalWeb') {
        this.ResultFilterControls()
      }

      if (!this.keyword.trim() && this.history.length > 0) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Row() {
            Text('搜索历史')
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor($r('sys.color.font_secondary'))
            Blank()
            Text('清空')
              .fontSize(ThemeConstants.FONT_SIZE_TINY)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
              .onClick(() => { this.clearHistory() })
          }
          .width('100%')

          Scroll() {
            Row({ space: ThemeConstants.SPACE_XS }) {
              ForEach(this.history, (q: string) => {
                Text(q)
                  .fontSize(ThemeConstants.FONT_SIZE_TINY)
                  .fontColor($r('sys.color.font_primary'))
                  .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, top: 6, bottom: 6 })
                  .borderRadius(ThemeConstants.RADIUS_SM)
                  .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
                  .onClick(() => { this.applyHistory(q) })
              }, (q: string) => q)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .width('100%')
      }

      if (this.sourceMode === 'externalWeb') {
        this.ExternalWebSearchPanel()
      } else {
        this.LocalResultList()
      }

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('返回')
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .height(40)
          .onClick(() => { this.stack.pop() })
      }
      .width('100%')
    }
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: this.topH + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD,
      bottom: this.bottomH + ThemeConstants.SPACE_LG
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder LocalResultList() {
    List({ space: ThemeConstants.SPACE_SM }) {
      if (this.showTopicResults()) {
        ListItem() {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(`${this.topicSectionTitle()} ${this.topicResults.length}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
            if (this.topicResults.length === 0) {
              Text(this.keyword.trim() ? this.emptyTopicHint() : '输入关键词开始搜索')
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
                .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            }
          }
          .width('100%')
        }

        ForEach(this.topicResults.slice(0, 80), (item: SearchTopicItem) => {
          ListItem() { this.TopicRow(item) }
            .onClick(() => {
              let p: TopicDetailParams = { topicId: item.id }
              this.stack.pushPathByName('TopicDetail', p as Object)
            })
        }, (item: SearchTopicItem) => `t:${item.id}`)
      }

      if (this.showTopicResults() && this.showNodeResults()) {
        ListItem() {
          Divider().strokeWidth(0.5).color($r('sys.color.ohos_id_color_list_separator'))
        }
      }

      if (this.showNodeResults()) {
        ListItem() {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(`节点结果 ${this.nodeResults.length}`)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor($r('sys.color.font_secondary'))
            if (this.nodeResults.length === 0) {
              Text(this.keyword.trim() ? '没有匹配的节点' : this.emptyNodeHint())
                .fontSize(ThemeConstants.FONT_SIZE_BODY)
                .fontColor($r('sys.color.font_secondary'))
                .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
            }
          }
          .width('100%')
        }

        ForEach(this.nodeResults.slice(0, 80), (item: SearchNodeItem) => {
          ListItem() { this.NodeRow(item) }
            .onClick(() => {
              let p: NodeTopicListParams = { nodeName: item.name, nodeTitle: item.title }
              this.stack.pushPathByName('NodeTopicList', p as Object)
            })
        }, (item: SearchNodeItem) => `n:${item.name}`)
      }
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder ExternalWebSearchPanel() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(this.keyword.trim() ? '网页搜索' : '输入关键词开始搜索')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_secondary'))
      Button('打开网页搜索')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .height(44)
        .enabled(this.keyword.trim().length > 0)
        .onClick(() => { this.openExternalTopicSearch() })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder TopicRow(item: SearchTopicItem) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(item.title)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(`${item.nodeTitle} / ${item.nodeName} · @${item.username}`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(item.source)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder NodeRow(item: SearchNodeItem) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.name)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.source)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
        Text(`${item.topics} 主题`)
          .fontSize(ThemeConstants.FONT_SIZE_TINY)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.End)
    }
    .padding(ThemeConstants.SPACE_MD)
    .width('100%')
    .borderRadius(ThemeConstants.RADIUS_MD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  @Builder SourceModeControls() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        this.SourceModeButton('local', '本地', 76)
        this.SourceModeButton('localWithNodes', '本地+节点库', 120)
        this.SourceModeButton('externalWeb', '网页搜索', 92)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder SourceModeButton(mode: SearchSourceMode, label: string, width: number) {
    Button(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(this.sourceMode === mode ? Color.White : $r('sys.color.font_primary'))
      .height(36)
      .width(width)
      .type(ButtonType.Normal)
      .backgroundColor(this.sourceMode === mode ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => { this.updateSourceMode(mode) })
  }

  @Builder ResultFilterControls() {
    Scroll() {
      Row({ space: ThemeConstants.SPACE_SM }) {
        this.ResultFilterButton('all', '全部', 68)
        this.ResultFilterButton('topics', '主题', 68)
        this.ResultFilterButton('nodes', '节点', 68)
        this.ResultFilterButton('users', '用户', 68)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder ResultFilterButton(filter: SearchResultFilter, label: string, width: number) {
    Button(label)
      .fontSize(ThemeConstants.FONT_SIZE_TAG)
      .fontColor(this.resultFilter === filter ? Color.White : $r('sys.color.font_primary'))
      .height(34)
      .width(width)
      .type(ButtonType.Normal)
      .backgroundColor(this.resultFilter === filter ? ThemeConstants.BRAND_PRIMARY : $r('sys.color.ohos_id_color_button_normal'))
      .onClick(() => { this.updateResultFilter(filter) })
  }

  private loadLocalCollections(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    Promise.all([
      CollectionSettings.loadSavedTopics(context),
      CollectionSettings.loadViewedTopics(context),
      CollectionSettings.loadSavedNodes(context)
    ])
      .then((results: Object[]) => {
        this.savedTopics = (results[0] as SavedTopic[]) || []
        this.viewedTopics = (results[1] as ViewedTopic[]) || []
        this.savedNodes = (results[2] as SavedNode[]) || []
        this.applyFilter()
      })
      .catch((error: Error) => {
        this.errorMessage = error.message || '读取本地数据失败'
      })
  }

  private loadCacheCollections(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.isCacheLoading = true
    CacheSettings.loadKeyIndex(context)
      .then(async (index: CacheKeyIndex) => {
        const listTopics = new Map<number, SearchTopicItem>()
        const detailTopics = new Map<number, SearchTopicItem>()

        for (const key of index.topicLists) {
          const topics = await CacheSettings.loadTopicList(context, key)
          for (const topic of topics) {
            const item: SearchTopicItem = {
              id: topic.id,
              title: topic.title,
              nodeName: topic.node.name,
              nodeTitle: topic.node.title,
              username: topic.member.username,
              source: '缓存(列表)',
              updatedAt: index.updatedAt
            }
            listTopics.set(item.id, item)
          }
        }

        for (const topicId of index.topicDetails) {
          const detail = await CacheSettings.loadTopicDetail(context, topicId)
          if (!detail || !detail.topic) {
            continue
          }
          const topic = detail.topic
          const item: SearchTopicItem = {
            id: topic.id,
            title: topic.title,
            nodeName: topic.node.name,
            nodeTitle: topic.node.title,
            username: topic.member.username,
            source: '缓存(详情)',
            updatedAt: detail.cachedAt || index.updatedAt
          }
          detailTopics.set(item.id, item)
        }

        this.cacheTopicLists = Array.from(listTopics.values())
        this.cacheTopicDetails = Array.from(detailTopics.values())
        this.applyFilter()
      })
      .catch((_error: Error) => {
        this.cacheTopicLists = []
        this.cacheTopicDetails = []
      })
      .finally(() => {
        this.isCacheLoading = false
      })
  }

  private loadNodeIndex(): void {
    if (!this.usesNodeIndex()) {
      return
    }
    if (this.allNodes.length > 0) {
      this.applyFilter()
      return
    }
    this.isNodeIndexLoading = true
    this.api.getAllNodes()
      .then((nodes: V2exNode[]) => {
        this.allNodes = NodeSearchUtils.sortByPopularity(nodes)
        this.applyFilter()
      })
      .catch((_error: Error) => {
        this.allNodes = []
      })
      .finally(() => {
        this.isNodeIndexLoading = false
      })
  }

  private loadSourceMode(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.loadSourceMode(context)
      .then((mode: SearchSourceMode) => {
        this.sourceMode = mode
        if (this.usesNodeIndex()) {
          this.loadNodeIndex()
        } else {
          this.applyFilter()
        }
      })
      .catch((_error: Error) => {
        this.sourceMode = 'localWithNodes'
        this.loadNodeIndex()
      })
  }

  private loadHistory(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.loadHistory(context)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => {
        this.history = []
      })
  }

  private recordHistory(): void {
    const q = this.keyword.trim()
    if (!q) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.recordQuery(context, q)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => { })
  }

  private clearHistory(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.clearHistory(context)
      .then(() => {
        this.history = []
      })
      .catch((_error: Error) => { })
  }

  private applyHistory(q: string): void {
    const clean = (q ?? '').trim()
    if (!clean) {
      return
    }
    this.keyword = clean
    this.applyFilter()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.recordQuery(context, clean)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => { })
  }

  private applyFilter(): void {
    const q = this.keyword.trim().toLowerCase()
    if (!q) {
      this.topicResults = []
      this.nodeResults = []
      return
    }
    if (this.sourceMode === 'externalWeb') {
      this.topicResults = []
      this.nodeResults = []
      return
    }

    const includeTopics = this.showTopicResults()
    const includeNodes = this.showNodeResults()
    const bag = new Map<number, SearchTopicItem>()

    if (includeTopics) {
      for (const item of this.savedTopics) {
        const t: SearchTopicItem = {
          id: item.id,
          title: item.title,
          nodeName: item.nodeName,
          nodeTitle: item.nodeTitle,
          username: item.username,
          source: '收藏',
          updatedAt: item.savedAt || 0
        }
        if (SearchPage.topicMatches(t, q, this.resultFilter)) {
          bag.set(t.id, t)
        }
      }

      for (const item of this.viewedTopics) {
        const existing = bag.get(item.id)
        const t: SearchTopicItem = existing ? existing : {
          id: item.id,
          title: item.title,
          nodeName: item.nodeName,
          nodeTitle: item.nodeTitle,
          username: item.username,
          source: '最近',
          updatedAt: item.viewedAt || 0
        }
        if (!SearchPage.topicMatches(t, q, this.resultFilter)) {
          continue
        }
        if (!existing) {
          bag.set(t.id, t)
        } else {
          existing.source = SearchPage.mergeSource(existing.source, '最近')
          existing.updatedAt = Math.max(existing.updatedAt, item.viewedAt || 0)
        }
      }

      for (const item of this.cacheTopicDetails) {
        if (!SearchPage.topicMatches(item, q, this.resultFilter)) {
          continue
        }
        const existing = bag.get(item.id)
        if (!existing) {
          bag.set(item.id, item)
        } else {
          existing.source = SearchPage.mergeSource(existing.source, item.source)
          existing.updatedAt = Math.max(existing.updatedAt, item.updatedAt)
        }
      }

      for (const item of this.cacheTopicLists) {
        if (!SearchPage.topicMatches(item, q, this.resultFilter)) {
          continue
        }
        const existing = bag.get(item.id)
        if (!existing) {
          bag.set(item.id, item)
        } else {
          existing.source = SearchPage.mergeSource(existing.source, item.source)
          existing.updatedAt = Math.max(existing.updatedAt, item.updatedAt)
        }
      }
    }

    this.topicResults = Array.from(bag.values())
      .sort((a: SearchTopicItem, b: SearchTopicItem) => b.updatedAt - a.updatedAt)

    const nodeBag = new Map<string, SearchNodeItem>()

    if (includeNodes) {
      for (const item of this.savedNodes) {
        const node = SearchPage.savedNodeToV2exNode(item)
        const score = NodeSearchUtils.scoreNode(node, q)
        if (score <= 0) {
          continue
        }
        const n: SearchNodeItem = {
          name: item.name,
          title: item.title,
          topics: item.topics,
          source: '关注',
          updatedAt: item.savedAt || 0,
          score: score + 1200
        }
        nodeBag.set(n.name, n)
      }

      if (this.usesNodeIndex()) {
        for (const match of NodeSearchUtils.search(this.allNodes, q).slice(0, 120)) {
          const node = match.node
          const existing = nodeBag.get(node.name)
          if (!existing) {
            nodeBag.set(node.name, {
              name: node.name,
              title: node.title,
              topics: node.topics,
              source: '节点库',
              updatedAt: 0,
              score: match.score
            })
          } else {
            existing.title = existing.title || node.title
            existing.topics = Math.max(existing.topics, node.topics)
            existing.source = SearchPage.mergeSource(existing.source, '节点库')
            existing.score = Math.max(existing.score, match.score + 1200)
          }
        }
      }
    }

    this.nodeResults = Array.from(nodeBag.values())
      .sort((a: SearchNodeItem, b: SearchNodeItem) => {
        if (b.score !== a.score) {
          return b.score - a.score
        }
        if (b.updatedAt !== a.updatedAt) {
          return b.updatedAt - a.updatedAt
        }
        return b.topics - a.topics
      })
  }

  private static topicMatches(item: SearchTopicItem, q: string, filter: SearchResultFilter): boolean {
    if (filter === 'users') {
      return item.username.toLowerCase().includes(q)
    }
    if (item.id.toString().includes(q)) {
      return true
    }
    if (item.title.toLowerCase().includes(q)) {
      return true
    }
    if (item.nodeName.toLowerCase().includes(q)) {
      return true
    }
    if (item.nodeTitle.toLowerCase().includes(q)) {
      return true
    }
    return item.username.toLowerCase().includes(q)
  }

  private static mergeSource(existing: string, incoming: string): string {
    const parts = existing.split(' · ').map(s => s.trim()).filter(s => s.length > 0)
    if (parts.indexOf(incoming) >= 0) {
      return existing
    }
    parts.push(incoming)
    return parts.join(' · ')
  }

  private updateSourceMode(mode: SearchSourceMode): void {
    if (this.sourceMode === mode) {
      return
    }
    this.sourceMode = mode
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.saveSourceMode(context, mode)
      .catch((error: Error) => {
        this.errorMessage = error.message || '保存搜索来源失败'
      })
    if (this.usesNodeIndex()) {
      this.loadNodeIndex()
    } else {
      this.applyFilter()
    }
  }

  private updateResultFilter(filter: SearchResultFilter): void {
    if (this.resultFilter === filter) {
      return
    }
    this.resultFilter = filter
    this.applyFilter()
  }

  private showTopicResults(): boolean {
    return this.resultFilter === 'all' || this.resultFilter === 'topics' || this.resultFilter === 'users'
  }

  private showNodeResults(): boolean {
    return this.resultFilter === 'all' || this.resultFilter === 'nodes'
  }

  private topicSectionTitle(): string {
    return this.resultFilter === 'users' ? '用户相关主题' : '主题结果'
  }

  private emptyTopicHint(): string {
    return this.resultFilter === 'users' ? '没有匹配该用户的本地主题' : '没有匹配的主题'
  }

  private usesNodeIndex(): boolean {
    return this.sourceMode === 'localWithNodes'
  }

  private sourceModeSummary(): string {
    if (this.sourceMode === 'externalWeb') {
      return '用系统浏览器搜索 V2EX 主题'
    }
    if (this.usesNodeIndex()) {
      return '在收藏 / 最近浏览 / 关注节点 / 离线缓存 / 节点库中搜索'
    }
    return '在收藏 / 最近浏览 / 关注节点 / 离线缓存中搜索'
  }

  private emptyNodeHint(): string {
    if (this.usesNodeIndex()) {
      return '节点库和你关注的节点会出现在这里'
    }
    return '你关注的节点会出现在这里'
  }

  private openExternalTopicSearch(): void {
    const q = this.keyword.trim()
    if (!q) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SearchSettings.recordQuery(context, q)
      .then((items: string[]) => {
        this.history = items
      })
      .catch((_error: Error) => { })
    const url = SearchPage.buildExternalTopicSearchUrl(q)
    const want: Want = { action: 'ohos.want.action.viewData', uri: url }
    context.startAbility(want)
      .catch((error: Error) => {
        promptAction.openToast({ message: error.message || '打开失败' }).catch((_error: Error) => { })
      })
  }

  private static buildExternalTopicSearchUrl(query: string): string {
    return `https://www.bing.com/search?q=${encodeURIComponent(`site:v2ex.com/t ${query}`)}`
  }

  private static savedNodeToV2exNode(item: SavedNode): V2exNode {
    return {
      id: 0,
      name: item.name,
      title: item.title,
      title_alternative: '',
      url: '',
      topics: item.topics,
      avatar_mini: '',
      avatar_normal: '',
      avatar_large: ''
    }
  }
}
