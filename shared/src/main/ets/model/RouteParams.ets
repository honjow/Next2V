// Route parameter types — the typed params pushed onto the NavPathStack for each named destination.
// Kept in their own module (re-exported by the shared barrel) so shared-internal code (e.g.
// V2exRouteNavigator) can import them without a cycle back through the barrel.

export interface TopicDetailParams {
  topicId: number
  targetFloor?: number
}

export interface NodeTopicListParams {
  nodeName: string
  nodeTitle: string
}

export interface UserProfileParams {
  username: string
}

export interface ImagePreviewParams {
  url: string
}
