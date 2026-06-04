import { NodeTopicListParams, TopicDetailParams, UserProfileParams } from '../model/RouteParams'
import { SearchQueryBus } from './SearchQueryBus'
import { V2exRoute, V2exUrlRouter } from './V2exUrlRouter'

/**
 * Single source of truth for "open a V2EX URL on the native nav stack".
 *
 * A V2EX URL that maps to a built-in destination (topic /t/, node /go/, member /member/, search) is
 * pushed onto the given NavPathStack as the corresponding native page; everything else returns false so
 * the caller can fall back (in-app WebView / system browser). This is the policy shared by the deep-link
 * handler (Index), topic/reply in-content links (TopicDetailPage) and node-description links
 * (NodeTopicPage) so they all route identically.
 */
export class V2exRouteNavigator {
  /** Parse `url` and push its native page. Returns false when the URL has no native destination. */
  static openInApp(stack: NavPathStack, url: string): boolean {
    const route: V2exRoute | null = V2exUrlRouter.parse(url)
    if (!route) {
      return false
    }
    return V2exRouteNavigator.pushRoute(stack, route)
  }

  /** Push the native page for an already-parsed route. Returns false for a kind without a native page. */
  static pushRoute(stack: NavPathStack, route: V2exRoute): boolean {
    if (route.kind === 'topic' && route.topicId && route.topicId > 0) {
      const p: TopicDetailParams =
        route.targetFloor && route.targetFloor > 0
          ? { topicId: route.topicId, targetFloor: route.targetFloor }
          : { topicId: route.topicId }
      stack.pushPathByName('TopicDetail', p as Object)
      return true
    }
    if (route.kind === 'member' && route.username) {
      const p: UserProfileParams = { username: route.username }
      stack.pushPathByName('UserProfile', p as Object)
      return true
    }
    if (route.kind === 'node' && route.nodeName) {
      const p: NodeTopicListParams = { nodeName: route.nodeName, nodeTitle: route.nodeName }
      stack.pushPathByName('NodeTopicList', p as Object)
      return true
    }
    if (route.kind === 'search' && route.query) {
      // Single dual-write point for the pending-query bus (AppStorage + V2 mirror).
      SearchQueryBus.publishPending(route.query.trim())
      stack.pushPathByName('Search', null)
      return true
    }
    return false
  }
}
