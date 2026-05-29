import { common } from '@kit.AbilityKit'
import {
  ApiService,
  AppStrings,
  Avatar,
  BlockedListSettings,
  CardEmptyState,
  CookieJarSettings,
  DiagnosticLogger,
  LocalTopicCard,
  PageLoadingState,
  PullRefreshListScaffold,
  StorageKeys,
  ThemeConstants,
  type BlockedListSnapshot,
  type BlockedMemberMeta,
  type IgnoredTopicMeta,
  type TopicDetailParams,
  type UserProfileParams,
  type V2exMemberProfile,
  type V2exTopic,
} from 'shared'

@ObservedV2
class BlockedMemberListItem {
  id: number = 0
  @Trace username: string = ''
  @Trace tagline: string = ''
  @Trace avatar: string = ''
  @Trace created: number = 0
  @Trace resolved: boolean = false

  constructor(id: number) {
    this.id = id
  }

  applyProfile(profile: V2exMemberProfile): void {
    this.username = profile.username || ''
    this.tagline = profile.tagline || ''
    this.avatar = profile.avatar_large || profile.avatar_normal || profile.avatar_mini || ''
    this.created = profile.created || 0
    this.resolved = true
  }

  applyMeta(meta: BlockedMemberMeta): void {
    if (meta.id !== this.id) {
      return
    }
    this.username = meta.username || ''
    this.tagline = meta.tagline || ''
    this.avatar = meta.avatar || ''
    this.created = meta.created || 0
    this.resolved = this.username.length > 0 || this.avatar.length > 0 || this.tagline.length > 0 || this.created > 0
  }

  toMeta(): BlockedMemberMeta {
    return {
      id: this.id,
      username: this.username,
      tagline: this.tagline,
      avatar: this.avatar,
      created: this.created,
      updatedAt: Date.now(),
    }
  }
}

@ComponentV2
struct BlockedMemberCardView {
  @Param item: BlockedMemberListItem = new BlockedMemberListItem(0)
  @Param avatarSize: number = ThemeConstants.AVATAR_SIZE_TOPIC
  @Param rowMinHeight: number = ThemeConstants.AVATAR_SIZE_TOPIC + ThemeConstants.SPACE_MD * 2

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({ url: this.item.avatar, avatarSize: this.avatarSize })
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.memberTitle())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.memberMeta()) {
          Text(this.memberMeta())
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(this.rowMinHeight)
    .padding({
      left: ThemeConstants.SPACE_LG,
      right: ThemeConstants.SPACE_LG,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_MD,
    })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private memberMeta(): string {
    const parts: string[] = []
    if (this.item.tagline) {
      parts.push(this.item.tagline)
    }
    if (this.item.resolved && this.item.username) {
      parts.push(`#${this.item.id}`)
    }
    return parts.join(' · ')
  }

  private memberTitle(): string {
    if (this.item.username) {
      return this.item.username
    }
    return `#${this.item.id}`
  }
}

@Component
export struct BlockedListsPage {
  @Consume('ns') stack: NavPathStack
  @StorageLink(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS) @Watch('onBlockedListStorageChanged') ignoredTopicIdsJson: string = '[]'
  @StorageLink(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS) @Watch('onBlockedListStorageChanged') blockedMemberIdsJson: string = '[]'
  @StorageLink(StorageKeys.BLOCKED_LIST_UPDATED_AT) @Watch('onBlockedListStorageChanged') updatedAt: number = 0
  @StorageLink(StorageKeys.BLOCKED_LIST_SELECTED_TAB) selectedTab: number = 0
  @StorageProp(StorageKeys.TOP_AVOID_HEIGHT) topH: number = 0
  @StorageProp(StorageKeys.BOTTOM_AVOID_HEIGHT) bottomH: number = 0
  @State private snapshot: BlockedListSnapshot = BlockedListSettings.runtimeSnapshot()
  @State private topics: V2exTopic[] = []
  @State private members: BlockedMemberListItem[] = []
  @State private loadingTopics: boolean = false
  @State private loadingMembers: boolean = false
  @State private syncInFlight: boolean = false
  @State private syncError: boolean = false
  private readonly BOTTOM_BUILDER_HEIGHT: number = ThemeConstants.TITLE_BAR_HEIGHT
  private readonly MEMBER_AVATAR_SIZE: number = ThemeConstants.AVATAR_SIZE_TOPIC
  private readonly MEMBER_ROW_MIN_HEIGHT: number = 64
  private api: ApiService = new ApiService()
  private memberRowsById: Map<number, BlockedMemberListItem> = new Map()
  private lastStorageSignature: string = ''

  aboutToAppear(): void {
    this.refreshAll('page_open')
  }

  build() {
    Column() {
      if (this.shouldShowPageLoading()) {
        this.BlockedPageLoadingState()
      } else if (this.hasPageStateMessage()) {
        this.BlockedPageMessageState(this.pageStateMessage())
      } else {
        this.BlockedListContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  BlockedListContent() {
    PullRefreshListScaffold({
      onRefresh: () => this.refreshAll('manual_refresh'),
      topPadding: this.BOTTOM_BUILDER_HEIGHT,
      indicatorTop: ThemeConstants.TITLE_BAR_HEIGHT + this.BOTTOM_BUILDER_HEIGHT,
    }) {
      this.SyncStatusItem()
      if (this.selectedTab === 0) {
        this.BlockedMembersList()
      } else {
        this.IgnoredTopicsList()
      }
    }
  }

  @Builder
  SyncStatusItem() {
    if (this.syncError && (this.members.length > 0 || this.topics.length > 0)) {
      ListItem() {
        Text(AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XS })
      }
    }
  }

  @Builder
  IgnoredTopicsList() {
    ForEach(this.topics, (item: V2exTopic) => {
      ListItem() {
        LocalTopicCard({
          topicId: item.id,
          title: item.title,
          nodeName: item.node.name,
          nodeTitle: item.node.title,
          username: item.member.username,
          avatar: item.member.avatar_normal || item.member.avatar_large || item.member.avatar_mini,
          memberPro: item.member.pro || 0,
          created: item.created,
          replyCount: item.replies,
          hasReplyCount: true,
          onUserClick: () => { this.openTopic(item.id) },
          onNodeClick: () => { this.openTopic(item.id) },
        })
          .onClick(() => { this.openTopic(item.id) })
      }
      .onClick(() => { this.openTopic(item.id) })
    }, (item: V2exTopic) => `ignored-topic-${item.id}`)
  }

  @Builder
  BlockedMembersList() {
    ForEach(this.members, (item: BlockedMemberListItem) => {
      ListItem() {
        BlockedMemberCardView({
          item: item,
          avatarSize: this.MEMBER_AVATAR_SIZE,
          rowMinHeight: this.MEMBER_ROW_MIN_HEIGHT,
        })
      }
      .onClick(() => { this.openMember(item) })
    }, (item: BlockedMemberListItem) => `blocked-member-${item.id}`)
  }

  @Builder
  BlockedPageLoadingState() {
    Column() {
      Blank().height(this.topContentInset())
      PageLoadingState()
      Blank().height(this.bottomContentInset())
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  BlockedPageMessageState(message: string) {
    Column() {
      Blank().height(this.topContentInset())
      CardEmptyState({
        message: message,
      })
      Blank().height(this.bottomContentInset())
    }
    .width('100%')
    .height('100%')
  }

  private shouldShowPageLoading(): boolean {
    if (!this.snapshot.ownerKey) {
      return false
    }
    if (this.hasAnyRenderableForCurrentTab()) {
      return false
    }
    return this.isRefreshPendingForCurrentTab()
  }

  private hasPageStateMessage(): boolean {
    return this.pageStateMessage().length > 0
  }

  private pageStateMessage(): string {
    if (!this.snapshot.ownerKey) {
      return AppStrings.text(AppStrings.R_LOGIN_TO_VIEW_BLOCKED, 'Log in to view blocked lists')
    }
    if (this.selectedTab === 0) {
      if (this.snapshot.blockedMemberIds.length === 0) {
        return AppStrings.text(AppStrings.R_NO_BLOCKED_USERS, 'No blocked users')
      }
      if (this.members.length === 0) {
        return AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed')
      }
      return ''
    }
    if (this.snapshot.ignoredTopicIds.length === 0) {
      return AppStrings.text(AppStrings.R_NO_IGNORED_TOPICS, 'No blocked topics')
    }
    if (this.topics.length === 0) {
      return AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed')
    }
    return ''
  }

  private pageStateName(): string {
    if (this.shouldShowPageLoading()) {
      return 'loading'
    }
    if (this.hasPageStateMessage()) {
      return this.snapshot.ownerKey ? 'message' : 'login_required'
    }
    return 'list'
  }

  private topContentInset(): number {
    return this.topH + ThemeConstants.TITLE_BAR_HEIGHT + this.BOTTOM_BUILDER_HEIGHT
  }

  private bottomContentInset(): number {
    return this.bottomH + ThemeConstants.SPACE_XL
  }

  private hasResolvedMembers(): boolean {
    return this.resolvedMemberCount() > 0
  }

  private hasAnyRenderableForCurrentTab(): boolean {
    if (this.selectedTab === 0) {
      return this.members.length > 0
    }
    return this.topics.length > 0
  }

  private isRefreshPendingForCurrentTab(): boolean {
    if (this.selectedTab === 0) {
      return this.syncInFlight || this.loadingMembers
    }
    return this.syncInFlight || this.loadingTopics
  }

  private resolvedMemberCount(): number {
    return this.members.filter((item: BlockedMemberListItem) => item.resolved).length
  }

  private memberIdsMatch(items: BlockedMemberListItem[], ids: number[]): boolean {
    if (items.length !== ids.length) {
      return false
    }
    for (let index = 0; index < ids.length; index++) {
      if (items[index].id !== ids[index]) {
        return false
      }
    }
    return true
  }

  private topicIdsMatch(items: V2exTopic[], ids: number[]): boolean {
    if (items.length !== ids.length) {
      return false
    }
    for (let index = 0; index < ids.length; index++) {
      if (items[index].id !== ids[index]) {
        return false
      }
    }
    return true
  }

  private refreshAll(trigger: string = 'manual_refresh'): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const cookie = CookieJarSettings.getCurrentCookie()
    this.syncError = false
    this.syncInFlight = !!cookie
    return BlockedListSettings.loadActive(context)
      .then((snapshot: BlockedListSnapshot) => {
        return this.applySnapshot(snapshot, `${trigger}_cache`)
      })
      .then(() => {
        if (!cookie) {
          return Promise.resolve()
        }
        this.syncInFlight = true
        return this.syncBlockedListsOnPageOpen(cookie, trigger)
          .then(() => BlockedListSettings.loadActive(context))
          .then((snapshot: BlockedListSnapshot) => this.applySnapshot(snapshot, `${trigger}_network`))
      })
      .then(() => {})
      .catch((error: Error) => {
        this.syncError = true
        DiagnosticLogger.exception('ui_lifecycle', 'blocked_lists_page_load_failed', error, {})
      })
      .finally(() => {
        this.syncInFlight = false
        this.logRenderSnapshot(this.snapshot)
      })
  }

  private applySnapshot(snapshot: BlockedListSnapshot, trigger: string): Promise<void> {
    const ownerChanged = this.snapshot.ownerKey !== snapshot.ownerKey
    this.snapshot = snapshot
    if (ownerChanged) {
      this.topics = []
      this.members = []
      this.memberRowsById.clear()
    }
    this.members = this.ensureMemberRowsForIds(this.uniqueIds(snapshot.blockedMemberIds).slice(0, 80))
    this.applyMemberMetaCache(snapshot.blockedMemberMetas)
    this.applyIgnoredTopicMetaCache(snapshot.ignoredTopicIds, snapshot.ignoredTopicMetas)
    BlockedListSettings.apply(snapshot)
    this.logRenderSnapshot(snapshot, trigger)
    return Promise.all([
      this.resolveTopics(snapshot.ignoredTopicIds),
      this.resolveMembers(snapshot.blockedMemberIds),
    ]).then(() => {})
  }

  private onBlockedListStorageChanged(): void {
    const signature = `${this.ignoredTopicIdsJson}|${this.blockedMemberIdsJson}|${this.updatedAt}`
    if (signature === this.lastStorageSignature) {
      return
    }
    this.lastStorageSignature = signature
    this.applyRuntimeSnapshot('storage_change')
  }

  private applyRuntimeSnapshot(trigger: string): void {
    const snapshot = BlockedListSettings.runtimeSnapshot()
    this.applySnapshot(snapshot, trigger)
  }

  private syncBlockedListsOnPageOpen(cookie: string, trigger: string): Promise<void> {
    if (!cookie) {
      return Promise.resolve()
    }
    return this.api.syncBlockedListsFromCookieHtmlSources(cookie, trigger)
      .catch((error: Error) => {
        this.syncError = true
        DiagnosticLogger.exception('network', 'blocked_lists_page_sync_failed', error, { trigger: trigger, hasCookie: !!cookie })
      })
  }

  private logRenderSnapshot(snapshot: BlockedListSnapshot, trigger: string = ''): void {
    DiagnosticLogger.info('ui_lifecycle', 'blocked_list_render_snapshot', {
      trigger: trigger,
      selectedTab: this.selectedTab,
      ignored_count: snapshot.ignoredTopicIds.length,
      blocked_count: snapshot.blockedMemberIds.length,
      blocked_member_meta_count: snapshot.blockedMemberMetas.length,
      ignored_topic_meta_count: snapshot.ignoredTopicMetas.length,
      topics_visible_count: this.topics.length,
      members_visible_count: this.members.length,
      members_resolved_count: this.resolvedMemberCount(),
      pageState: this.pageStateName(),
      updatedAt: snapshot.updatedAt || 0,
      syncInFlight: this.syncInFlight,
      syncError: this.syncError,
      ownerKeyPresent: !!snapshot.ownerKey,
      ownerKeyHash: DiagnosticLogger.ownerHash(snapshot.ownerKey),
    })
  }

  private resolveTopics(ids: number[]): Promise<void> {
    const topicIds = this.uniqueIds(ids).slice(0, 80)
    if (topicIds.length === 0) {
      this.topics = []
      return Promise.resolve()
    }
    this.loadingTopics = true
    return this.api.getTopicsByIds(topicIds)
      .then((topics: V2exTopic[]) => {
        this.topics = topics
        this.persistIgnoredTopicMetas(topics)
      })
      .catch((error: Error) => {
        DiagnosticLogger.exception('network', 'blocked_lists_resolve_topics_failed', error, { count: topicIds.length })
        if (this.topics.length === 0) {
          this.topics = []
        }
      })
      .finally(() => {
        this.loadingTopics = false
      })
  }

  private resolveMembers(ids: number[]): Promise<void> {
    const memberIds = this.uniqueIds(ids).slice(0, 80)
    if (memberIds.length === 0) {
      this.members = []
      this.memberRowsById.clear()
      return Promise.resolve()
    }
    this.members = this.ensureMemberRowsForIds(memberIds)
    this.loadingMembers = true
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    return Promise.all(memberIds.map((id: number): Promise<void> => {
      return this.api.getMemberById(id)
        .then((profile: V2exMemberProfile) => {
          const row = this.memberRowsById.get(id)
          if (!row) {
            return
          }
          row.applyProfile(profile)
          this.logMemberRowResolved(row)
          BlockedListSettings.upsertBlockedMemberMeta(row.toMeta(), context, {
            source: 'blocked_lists_page',
            trigger: 'member_resolve_success',
          }).catch((error: Error) => {
            DiagnosticLogger.exception('storage', 'blocked_member_meta_upsert_failed', error, {
              memberId: row.id,
              usernamePresent: row.username.length > 0,
              avatarPresent: row.avatar.length > 0,
            })
          })
        })
        .catch((error: Error) => {
          DiagnosticLogger.exception('network', 'blocked_member_row_resolve_failed', error, {
            memberId: id,
            rowStillPresent: this.memberRowsById.has(id),
          })
        })
    }))
      .then(() => {
        this.members = this.ensureMemberRowsForIds(memberIds)
      })
      .finally(() => {
        this.loadingMembers = false
      })
  }

  private openTopic(topicId: number): void {
    if (topicId <= 0) {
      return
    }
    let p: TopicDetailParams = { topicId: topicId }
    this.stack.pushPathByName('TopicDetail', p as Object)
  }

  private openMember(item: BlockedMemberListItem): void {
    const username = (item.username || '').trim()
    if (!item.resolved || !username) {
      return
    }
    let p: UserProfileParams = { username: username }
    this.stack.pushPathByName('UserProfile', p as Object)
  }

  private ensureMemberRowsForIds(memberIds: number[]): BlockedMemberListItem[] {
    const validIds: Set<number> = new Set(memberIds)
    const byId: Map<number, BlockedMemberListItem> = this.memberRowsById
    for (const existingId of Array.from(byId.keys())) {
      if (!validIds.has(existingId)) {
        byId.delete(existingId)
      }
    }
    return memberIds.map((id: number): BlockedMemberListItem => this.memberRowForId(id))
  }

  private applyMemberMetaCache(metas: BlockedMemberMeta[]): void {
    let hydratedCount = 0
    const source = Array.isArray(metas) ? metas : []
    for (const meta of source) {
      const row = this.memberRowsById.get(meta.id)
      if (!row) {
        continue
      }
      row.applyMeta(meta)
      if (row.resolved) {
        hydratedCount++
      }
    }
    DiagnosticLogger.info('ui_lifecycle', 'blocked_member_meta_cache_hydrated', {
      meta_count: source.length,
      hydrated_count: hydratedCount,
      members_visible_count: this.members.length,
    })
  }

  private applyIgnoredTopicMetaCache(ids: number[], metas: IgnoredTopicMeta[]): void {
    const orderedIds = this.uniqueIds(ids).slice(0, 80)
    const metaById: Map<number, IgnoredTopicMeta> = new Map()
    const metaSource = Array.isArray(metas) ? metas : []
    for (const meta of metaSource) {
      if (meta && meta.id > 0) {
        metaById.set(meta.id, meta)
      }
    }
    const existingById: Map<number, V2exTopic> = new Map()
    for (const topic of this.topics) {
      existingById.set(topic.id, topic)
    }
    const hydrated: V2exTopic[] = []
    let hydratedCount = 0
    for (const id of orderedIds) {
      const existing = existingById.get(id)
      if (existing) {
        hydrated.push(existing)
        continue
      }
      const meta = metaById.get(id)
      if (meta) {
        hydrated.push(this.topicFromMeta(meta))
        hydratedCount++
      }
    }
    this.topics = hydrated
    DiagnosticLogger.info('ui_lifecycle', 'ignored_topic_meta_cache_hydrated', {
      meta_count: metaSource.length,
      hydrated_count: hydratedCount,
      topics_visible_count: this.topics.length,
    })
  }

  private persistIgnoredTopicMetas(topics: V2exTopic[]): void {
    if (!Array.isArray(topics) || topics.length === 0) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const metas = topics.map((topic: V2exTopic): IgnoredTopicMeta => this.toIgnoredTopicMeta(topic))
    BlockedListSettings.upsertIgnoredTopicMetas(metas, context, {
      source: 'blocked_lists_page',
      trigger: 'topic_resolve_success',
    }).catch((error: Error) => {
      DiagnosticLogger.exception('storage', 'ignored_topic_meta_upsert_failed', error, { count: metas.length })
    })
  }

  private topicFromMeta(meta: IgnoredTopicMeta): V2exTopic {
    return {
      id: meta.id,
      title: meta.title,
      url: '',
      content: '',
      content_rendered: '',
      replies: meta.replies,
      member: {
        id: 0,
        username: meta.username,
        tagline: '',
        pro: meta.memberPro,
        avatar_mini: meta.avatar,
        avatar_normal: meta.avatar,
        avatar_large: meta.avatar,
      },
      node: {
        id: 0,
        name: meta.nodeName,
        title: meta.nodeTitle,
        title_alternative: '',
        url: '',
        topics: 0,
        avatar_mini: '',
        avatar_normal: '',
        avatar_large: '',
      },
      created: meta.created,
      last_modified: 0,
      last_touched: meta.updatedAt > 0 ? meta.updatedAt : meta.created,
    }
  }

  private toIgnoredTopicMeta(topic: V2exTopic): IgnoredTopicMeta {
    return {
      id: topic.id,
      title: topic.title || '',
      nodeName: topic.node.name || '',
      nodeTitle: topic.node.title || '',
      username: topic.member.username || '',
      avatar: topic.member.avatar_normal || topic.member.avatar_large || topic.member.avatar_mini || '',
      memberPro: topic.member.pro || 0,
      created: topic.created || 0,
      replies: topic.replies || 0,
      updatedAt: Date.now(),
    }
  }

  private memberRowForId(id: number): BlockedMemberListItem {
    const existing = this.memberRowsById.get(id)
    if (existing) {
      return existing
    }
    const row = new BlockedMemberListItem(id)
    this.memberRowsById.set(id, row)
    return row
  }

  private logMemberRowResolved(item: BlockedMemberListItem): void {
    DiagnosticLogger.info('ui_lifecycle', 'blocked_member_row_resolved', {
      memberId: item.id,
      usernamePresent: item.username.length > 0,
      avatarPresent: item.avatar.length > 0,
      taglinePresent: item.tagline.length > 0,
      resolved: item.resolved,
    })
  }


  private uniqueIds(ids: number[]): number[] {
    const result: number[] = []
    const seen: Set<number> = new Set()
    const source = Array.isArray(ids) ? ids : []
    for (const value of source) {
      const id = Math.floor(value)
      if (id > 0 && !seen.has(id)) {
        result.push(id)
        seen.add(id)
      }
    }
    return result
  }

}
