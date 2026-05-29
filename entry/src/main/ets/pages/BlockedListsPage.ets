import { common } from '@kit.AbilityKit'
import {
  ApiService,
  AppStrings,
  Avatar,
  BlockedListSettings,
  CookieJarSettings,
  DateUtils,
  DiagnosticLogger,
  EmptyState,
  LocalTopicCard,
  PullRefreshListScaffold,
  StorageKeys,
  ThemeConstants,
  type BlockedListSnapshot,
  type TopicDetailParams,
  type UserProfileParams,
  type V2exMemberProfile,
  type V2exTopic,
} from 'shared'

interface BlockedMemberListItem {
  id: number
  username: string
  tagline: string
  avatar: string
  created: number
  resolved: boolean
}

@Component
export struct BlockedListsPage {
  @Consume('ns') stack: NavPathStack
  @StorageLink(StorageKeys.BLOCKED_LIST_IGNORED_TOPIC_IDS) ignoredTopicIdsJson: string = '[]'
  @StorageLink(StorageKeys.BLOCKED_LIST_BLOCKED_MEMBER_IDS) blockedMemberIdsJson: string = '[]'
  @StorageLink(StorageKeys.BLOCKED_LIST_UPDATED_AT) updatedAt: number = 0
  @StorageLink(StorageKeys.BLOCKED_LIST_SELECTED_TAB) selectedTab: number = 0
  @State private snapshot: BlockedListSnapshot = BlockedListSettings.empty('')
  @State private topics: V2exTopic[] = []
  @State private members: BlockedMemberListItem[] = []
  @State private loadingTopics: boolean = false
  @State private loadingMembers: boolean = false
  @State private syncInFlight: boolean = false
  @State private syncError: boolean = false
  private api: ApiService = new ApiService()

  aboutToAppear(): void {
    this.refreshAll('page_open')
  }

  build() {
    Column() {
      PullRefreshListScaffold({ onRefresh: () => this.refreshAll('manual_refresh') }) {
        if (this.selectedTab === 0) {
          this.BlockedMembersContent()
        } else {
          this.IgnoredTopicsContent()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }


  @Builder
  IgnoredTopicsContent() {
    if (!this.snapshot.ownerKey) {
      ListItem() {
        EmptyState({
          message: AppStrings.text(AppStrings.R_LOGIN_TO_VIEW_BLOCKED, 'Log in to view blocked lists'),
          stateHeight: 220,
        })
      }
    } else if (this.snapshot.ignoredTopicIds.length === 0) {
      ListItem() {
        EmptyState({
          message: AppStrings.text(AppStrings.R_NO_IGNORED_TOPICS, 'No blocked topics'),
          stateHeight: 220,
        })
      }
    } else if (this.loadingTopics && this.topics.length === 0) {
      ListItem() {
        EmptyState({
          message: AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…'),
          stateHeight: 220,
        })
      }
    } else if (this.topics.length === 0) {
      ListItem() {
        EmptyState({
          message: AppStrings.text(AppStrings.R_COMMON_LOAD_FAILED, 'Load failed'),
          stateHeight: 220,
        })
      }
    } else {
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
            metaLabel: AppStrings.text(AppStrings.R_IGNORED_TOPICS, 'Blocked topics'),
            metaTimestamp: this.snapshot.updatedAt,
            onUserClick: () => { this.openTopic(item.id) },
            onNodeClick: () => { this.openTopic(item.id) },
          })
            .onClick(() => { this.openTopic(item.id) })
        }
        .onClick(() => { this.openTopic(item.id) })
      }, (item: V2exTopic) => `ignored-topic-${item.id}`)
    }
  }

  @Builder
  BlockedMembersContent() {
    if (!this.snapshot.ownerKey) {
      ListItem() {
        EmptyState({
          message: AppStrings.text(AppStrings.R_LOGIN_TO_VIEW_BLOCKED, 'Log in to view blocked lists'),
          stateHeight: 220,
        })
      }
    } else if (this.snapshot.blockedMemberIds.length === 0) {
      ListItem() {
        EmptyState({
          message: AppStrings.text(AppStrings.R_NO_BLOCKED_USERS, 'No blocked users'),
          stateHeight: 220,
        })
      }
    } else if (this.loadingMembers && this.members.length === 0) {
      ListItem() {
        EmptyState({
          message: AppStrings.text(AppStrings.R_COMMON_LOADING, 'Loading…'),
          stateHeight: 220,
        })
      }
    } else {
      ForEach(this.members, (item: BlockedMemberListItem) => {
        ListItem() {
          this.MemberRow(item)
        }
        .onClick(() => { this.openMember(item) })
      }, (item: BlockedMemberListItem) => `blocked-member-${item.id}`)
    }
  }

  @Builder
  MemberRow(item: BlockedMemberListItem) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Avatar({ url: item.avatar, avatarSize: 44 })
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.username || AppStrings.format('#{0}', [String(item.id)]))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.memberMeta(item))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_MD, bottom: ThemeConstants.SPACE_MD })
    .backgroundColor($r('sys.color.ohos_id_color_card_bg'))
  }

  private refreshAll(trigger: string = 'manual_refresh'): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const cookie = CookieJarSettings.getCurrentCookie()
    this.syncError = false
    this.syncInFlight = !!cookie
    return this.syncBlockedListsOnPageOpen(cookie, trigger)
      .then(() => BlockedListSettings.loadActive(context))
      .then((snapshot: BlockedListSnapshot) => {
        this.snapshot = snapshot
        BlockedListSettings.apply(snapshot)
        this.logRenderSnapshot(snapshot)
        return Promise.all([
          this.resolveTopics(snapshot.ignoredTopicIds),
          this.resolveMembers(snapshot.blockedMemberIds),
        ])
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

  private syncBlockedListsOnPageOpen(cookie: string, trigger: string): Promise<void> {
    if (!cookie) {
      return Promise.resolve()
    }
    return this.api.syncBlockedListsFromCookieRecent(cookie, trigger)
      .catch((error: Error) => {
        this.syncError = true
        DiagnosticLogger.exception('network', 'blocked_lists_page_sync_failed', error, { trigger: trigger, hasCookie: !!cookie })
      })
  }

  private logRenderSnapshot(snapshot: BlockedListSnapshot): void {
    DiagnosticLogger.info('ui_lifecycle', 'blocked_list_render_snapshot', {
      selectedTab: this.selectedTab,
      ignored_count: snapshot.ignoredTopicIds.length,
      blocked_count: snapshot.blockedMemberIds.length,
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
      })
      .catch((error: Error) => {
        DiagnosticLogger.exception('network', 'blocked_lists_resolve_topics_failed', error, { count: topicIds.length })
        this.topics = []
      })
      .finally(() => {
        this.loadingTopics = false
      })
  }

  private resolveMembers(ids: number[]): Promise<void> {
    const memberIds = this.uniqueIds(ids).slice(0, 80)
    this.members = memberIds.map((id: number): BlockedMemberListItem => this.fallbackMember(id))
    if (memberIds.length === 0) {
      return Promise.resolve()
    }
    this.loadingMembers = true
    return Promise.all(memberIds.map((id: number): Promise<BlockedMemberListItem> => {
      return this.api.getMemberById(id)
        .then((profile: V2exMemberProfile) => this.memberFromProfile(id, profile))
        .catch((_error: Error) => this.fallbackMember(id))
    }))
      .then((items: BlockedMemberListItem[]) => {
        this.members = items
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

  private memberFromProfile(id: number, profile: V2exMemberProfile): BlockedMemberListItem {
    return {
      id: profile.id && profile.id > 0 ? profile.id : id,
      username: profile.username || '',
      tagline: profile.tagline || '',
      avatar: profile.avatar_large || profile.avatar_normal || profile.avatar_mini || '',
      created: profile.created || 0,
      resolved: true,
    }
  }

  private fallbackMember(id: number): BlockedMemberListItem {
    return { id: id, username: '', tagline: '', avatar: '', created: 0, resolved: false }
  }

  private memberMeta(item: BlockedMemberListItem): string {
    const parts: string[] = [AppStrings.format('ID {0}', [String(item.id)])]
    if (item.created > 0) {
      parts.push(DateUtils.toDateString(item.created))
    }
    if (item.tagline) {
      parts.push(item.tagline)
    }
    return parts.join(' · ')
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
