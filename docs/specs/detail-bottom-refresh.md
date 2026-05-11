# 主题详情页触底自动加载 + 末页上拉刷新 Controller Spec

## 0. 原始需求 / 证据

用户需求原文：

> 主题详情页 触底自动加载下一页 + 末页上拉刷新

任务卡补充语义：

- 范围仅限主题详情页 `feature/detail`。
- 未登录路径（公开 API + 网页 fallback）和登录路径（V2 API）都需要支持。
- 未到末页时，接近底部自动加载下一页，不需要额外手势。
- 到达末页且停在底部后，继续上拉才触发“底部刷新”。
- 底部刷新只抓取最后一页、diff 新回复并追加到末尾，不重置列表、不自动滚到新增内容、不触发顶部下拉刷新。

## 1. 当前代码事实（白帽）

已检查当前 worktree：`/home/gamer/v2next-worktrees/detail-bottom-refresh`。

相关现状：

- `feature/detail/src/main/ets/pages/TopicDetailPage.ets`
  - 详情页内容使用 `PullRefreshListScaffold`。
  - 顶部刷新入口：`onRefresh: async () => { await this.v.load() }`。
  - 触底入口：`onReachEnd: () => { this.loadMoreReplies() }`。
  - 当前 footer 仅在 `this.v.repliesUseV2` 时展示 `LoadingFooter({ isLoading, hasMore })`。
- `feature/detail/src/main/ets/viewmodel/DetailViewModel.ets`
  - 登录态：`ApiV2Service.getTopicReplies(token, topicId, page)` 已按 `p=` 分页；当前以 `V2_REPLY_PAGE_SIZE = 20` 推断是否还有下一页。
  - 未登录态：`ApiService.getRepliesWithWebFallback(topicId, expectedReplies)` 当前一次性返回公开 API 或网页 fallback 后的完整回复数组，并将 `repliesHasMore = false`。
  - 现有 V2 加载更多 `loadMoreRepliesV2()` 会按 `reply.id` 去重并 append 到 `ReplyDataSource`。
- `shared/src/main/ets/network/ApiV2Service.ets`
  - `getTopicReplies` 请求 `/api/v2/topics/{topicId}/replies?p={page}`，登录态存在真实分页入口。
- `shared/src/main/ets/network/ApiService.ets`
  - `getTopicWebReplies(topicId)` 当前会请求 `/t/{topicId}?p=1&_={Date.now()}`，解析 pageCount 后循环抓取 2..N 页，最终返回完整回复列表。
  - 公开网页 URL 支持 `/t/{id}?p=N`，已有 `V2exTopicRepliesParser.extractPageCount` 和 `parseReplies` 可复用。
- `shared/src/main/ets/components/PullRefresh.ets`
  - 当前只实现顶部下拉刷新，触发条件是 `deltaY > PULL_START_DRAG_VP && isListAtTop()`。
  - 底部反向 pull-to-refresh 需要新状态机或扩展 scaffold；不能复用成顶部刷新。
- `shared/src/main/ets/components/LoadingFooter.ets`
  - 当前文案为 `加载中...` / `— 没有更多了 —`，没有失败重试态。

## 2. 产品语义（蓝帽收敛）

### 2.1 范围

仅主题详情页回复列表：`TopicDetailPage` + `DetailViewModel` + 共享网络/组件的必要扩展。

必须覆盖两条回复数据路径：

1. 登录态 V2 API：`/api/v2/topics/{topicId}/replies?p=N`。
2. 未登录态公开路径：公开 replies API + 主题网页 `/t/{id}?p=N` fallback。

### 2.2 自动分页（无手势）

当回复列表滚动接近底部，且状态机判断“仍有下一页”时，自动抓取下一页并 append 到列表末尾。

明确采用的触发阈值：

- 首选实现阈值：距离回复列表末尾小于等于 3 个可见/已渲染列表项时触发。
- 如果 ArkUI 当前 List 指标难以稳定表达“剩余 3 项”，可退化为 `onReachEnd` 触发，但实现者必须在 compliance 中说明实际阈值。
- 不采用“用户继续上拉”作为下一页加载前置条件；用户自然滚动到底即应自动加载。

自动分页必须满足：

- 并发保护：同一时刻最多一个 load-more 请求。
- 去重：使用 `reply.id` 作为主 key；`id <= 0` 的异常项不得破坏现有列表，可跳过或以解析器可证明稳定的 fallback key 处理，并在实现说明中记录。
- 追加：只 append 新回复到当前列表末尾。
- 位置稳定：不得 `setData` 重置全量列表导致当前位置跳动；不得自动滚动到新内容。
- `onlyOp` 过滤保持现有语义：内部全量 replies 仍保存所有回复；可见 datasource 只 append 符合 OP 条件的新项。

### 2.3 底部 footer 状态

footer 三态必须明确，且只用于“自动分页”反馈：

1. 加载中：`加载中…`
2. 加载失败：`加载失败，点击重试`
3. 已无更多：允许无 footer，或显示 `没有更多了`

本 spec 选定推荐行为：

- 加载中、加载失败必须展示 footer。
- 已无更多默认不展示 `LoadingFooter`，避免与底部刷新提示条竞争；如实现选择展示 `没有更多了`，必须保证底部刷新提示条出现时不会同时显示两条互相冲突的底部提示。
- 失败 footer 必须可点击重试；重试只重试同一 nextPage，不改变当前列表、不重跑第一页。

### 2.4 末页底部上拉刷新（反向 pull-to-refresh）

仅当满足全部条件时启用：

- 已经加载到最后一页（`hasMore === false`，且当前页信息可信）。
- 当前滚动位置在列表底部。
- 当前没有顶部刷新、自动分页、底部刷新请求在进行。
- 不是横向手势；需保留现有方向锁语义。

底部刷新三态文案：

1. `上拉刷新`
2. `松开刷新`
3. `刷新中…`

触发动作：

- 重新抓取“最后一页”而不是重抓全部页。
- 请求必须带缓存破坏参数：`_=${Date.now()}`。
- 与当前已加载 replies 按 `reply.id` diff。
- 仅将新增回复 append 到列表末尾。
- 不重置 list，不重新从 p=1 跑分页，不自动滚动到新增回复。
- 如果没有新增回复，保持原列表和当前位置不变，只结束刷新状态。

### 2.5 单页主题语义

对于单页主题，例如 Topic `1212003`（13 回复）：

- 初始加载后应直接处于“已是最后一页”的底部状态。
- 滚到底部不出现自动加载下一页。
- 在底部继续上拉时，出现底部刷新三态，并按“重新抓取最后一页 + diff append”执行。

### 2.6 多页主题语义

对于多页主题（>100 回复 / pageCount > 1）：

- p=1 底部：自动加载 p=2，不显示底部刷新提示条。
- 中间页底部：继续自动加载下一页。
- 最后一页底部：自动分页状态结束；继续上拉才进入底部刷新。
- 自动分页与底部刷新不能在同一次底部交互中同时触发。

## 3. 数据路径决策（白帽 + 绿帽 + 蓝帽）

### 3.1 登录态 V2 API audit 结论

当前代码已经有登录态分页能力：

- `ApiV2Service.getTopicReplies(token, topicId, page)` 请求 `/api/v2/topics/{topicId}/replies?p={page}`。
- `DetailViewModel.loadMoreRepliesV2()` 已有 nextPage、append、`reply.id` 去重、pageSize 推断。

因此登录态推荐继续使用 V2 API 分页；不需要为了分页退回公开网页 fallback。

需要补齐：

- footer 失败重试态。
- 末页底部刷新：重新请求当前最后一页；如 V2 API 不接受 `_` 参数，则至少保持 `usingCache: false`，并在 endpoint 允许时追加 `&_=${Date.now()}`。
- 不再在失败时直接把 `repliesHasMore = false` 当作“末页”，否则会把网络失败误判成可底部刷新。失败应进入 load-more error 状态。

### 3.2 未登录公开路径决策

当前 `getTopicWebReplies(topicId)` 一次性抓取所有网页页码，不符合“触底自动加载下一页”的产品语义。

推荐新增/拆分公开网页分页接口，而不是破坏现有函数：

- 保留 `getTopicWebReplies(topicId)` 作为兼容全量抓取能力，避免影响顶部刷新或其他调用方。
- 新增页级接口，例如 `getTopicWebRepliesPage(topicId, page, cacheBuster?)`，返回：
  - `replies: V2exReply[]`
  - `page: number`
  - `pageCount: number`
  - `hasMore: boolean`
- 未登录详情页初始加载：
  - 先获取 topic 以得到 `topic.replies`。
  - 当 `topic.replies` 指示可能多页，或 legacy `/api/replies/show.json` 返回数量小于 expectedReplies，进入网页分页模式，从 p=1 开始逐页加载。
  - 当 legacy API 返回完整且主题为单页，可直接视为最后一页，底部只提供刷新语义。
- 未登录自动分页：用网页 `/t/{id}?p=N&_={cacheBuster}` 抓下一页。

说明：公开 API `/api/replies/show.json?topic_id=` 没有已确认的分页参数，不应伪造分页能力；多页公开场景以网页页码为准。

## 4. 状态机规格（黑帽风险控制）

建议将回复分页/刷新拆成可观测状态，而不是用多个 boolean 隐式推断。

### 4.1 自动分页状态

建议状态：

- `idle`
- `loadingMore`
- `loadMoreError`
- `endReached`

状态转移：

- `idle + nearBottom + hasMore` → `loadingMore`
- `loadingMore + success + hasMore` → `idle`
- `loadingMore + success + !hasMore` → `endReached`
- `loadingMore + failure` → `loadMoreError`
- `loadMoreError + retry` → `loadingMore`

禁止转移：

- `failure` 不得直接转 `endReached`。
- `endReached` 不得再触发 load-more。
- `loadingMore` 期间不得触发底部刷新。

### 4.2 底部刷新状态

建议状态：

- `hidden`
- `pulling`
- `ready`
- `refreshing`

文案映射：

- `pulling` → `上拉刷新`
- `ready` → `松开刷新`
- `refreshing` → `刷新中…`

状态转移：

- `endReached + atBottom + upwardPullBelowThreshold` → `pulling`
- `pulling + upwardPullOverThreshold` → `ready`
- `ready + release` → `refreshing`
- `refreshing + success/failure` → `hidden`（失败可 toast 或轻量错误提示，但不得进入 load-more error）

阈值建议：

- 与顶部下拉刷新保持近似：40 vp；可复用 `PullRefreshListScaffold.refreshThreshold` 默认值。
- 需要方向锁：横向移动超过 6 vp 且大于纵向位移时，不进入底部刷新。

### 4.3 手势优先级

优先级从高到低：

1. 横向手势 / 内容内点击：不拦截。
2. 顶部下拉刷新：仅 `isListAtTop()` 且向下拖动时触发现有顶部刷新。
3. 自动分页：未到末页时，接近底部自动触发；不需要用户继续上拉。
4. 底部刷新：仅末页 + 底部 + 用户继续上拉时触发。

关键禁止项：

- 未到末页时，不显示 `上拉刷新` / `松开刷新` / `刷新中…`。
- 末页底部刷新不得调用 `v.load()`，不得触发顶部刷新状态。
- 自动分页失败不得让底部刷新出现；用户应看到 `加载失败，点击重试`。

## 5. 保留语义（不得回归）

必须保持：

- 顶部下拉刷新行为不变：仍由 `PullRefreshListScaffold.onRefresh → DetailViewModel.load()` 驱动。
- 登录态 token/PAT 验证路径不动，不改变 `ApiV2Service` 的 token 校验错误语义。
- 未登录公开 API + `V2exTopicRepliesParser` 网页 fallback 语义保留；只是新增“页级抓取”能力。
- 单击状态栏回顶系统行为不变。
- 楼层编号、回复时间、感谢数、Markdown/HTML 渲染不变。
- `onlyOp` 过滤不变。
- `回复` 浮动按钮位置、避让 `bottomH`、点击登录/回复行为不变。
- 已读楼层恢复、跳转目标楼层、图片预览、用户跳转、链接路由不变。
- 主题正文区域不做任何产品变更。

## 6. 非目标

本 lane 不做：

- 首页帖子列表分页/刷新。
- 节点列表、通知页、我的主题页等其他列表的 footer 重构，除非为了共享组件兼容且不改变其现有行为。
- 主题正文布局、标题区、节点信息、作者信息改版。
- 评论排序、筛选、楼中楼。
- 回复发布流程优化。
- PAT 登录/2FA/会话修复。
- 广泛重构 `PullRefresh` 造成其他页面行为变化。

## 7. 接口与文件改动建议（不写代码）

建议实现者优先按最小安全路径：

### 7.1 `shared/src/main/ets/network/ApiService.ets`

建议新增页级网页接口：

- `getTopicWebRepliesPage(topicId: number, page: number = 1, cacheBuster: number = Date.now())`
- 返回包含 `replies/page/pageCount/hasMore` 的 snapshot 类型。
- 内部请求 `/t/{topicId}?p={page}&_={cacheBuster}`。
- 使用 `V2exTopicRepliesParser.parseReplies` 和 `extractPageCount`。
- 保留现有 `getTopicWebReplies(topicId)` 兼容行为。

### 7.2 `shared/src/main/ets/network/ApiV2Service.ets`

建议为 `getTopicReplies` 增加可选 cache-buster 或专用 refresh 方法：

- 自动分页仍请求 `p=nextPage`。
- 底部刷新请求 lastPage 时应避免缓存：如果接口允许，endpoint 追加 `_=${Date.now()}`；如果不允许，至少依赖现有 `usingCache: false` 并在 compliance 说明。

### 7.3 `feature/detail/src/main/ets/viewmodel/DetailViewModel.ets`

建议新增/整理状态：

- 当前回复来源：`v2` / `publicApi` / `publicWebPage`。
- 当前页：`repliesPage`。
- 末页：`repliesLastPage` 或 `repliesHasMore`。
- 自动分页状态：idle/loading/error/end。
- 底部刷新状态：hidden/pulling/ready/refreshing 可放 UI 层，但请求动作建议在 VM。
- load-more error message，不复用全页 `errorMessage`。

建议新增动作：

- `loadMoreReplies()`：统一处理 V2 / public web page 下一页。
- `retryLoadMoreReplies()`：只重试失败页。
- `refreshLastRepliesPage()`：只抓最后一页，按 `reply.id` diff append。

### 7.4 `feature/detail/src/main/ets/pages/TopicDetailPage.ets`

建议调整：

- `onReachEnd` 或 `onScrollIndex` 根据阈值触发统一 `v.loadMoreReplies()`。
- footer 根据 VM 的 load-more 状态渲染：加载中 / 失败重试 / 可选无更多。
- 末页底部上拉刷新提示条应靠近底部，但不得与浮动“回复”按钮冲突；需要继续使用 `topicDetailBottomPadding()` / `bottomH` 避让。
- `ReplyComposerSheet.submittedAction` 当前调用 `this.v.load()`，此路径不是本需求重点；不得因底部刷新实现而破坏该行为。

### 7.5 共享组件

可选方案：

- A：扩展 `PullRefreshListScaffold` 支持 bottom refresh（推荐，复用列表容器、scroller、方向锁）。
- B：在 `TopicDetailPage` 局部实现底部反向 pull 控制（更局部，但要避免和现有顶部 `PullRefresh` touch 处理冲突）。

推荐 A，但必须保证默认参数下其他页面行为不变；bottom refresh 功能应 opt-in。

## 8. 边界条件

必须处理：

- 单页主题：无下一页，底部上拉刷新可用。
- 多页主题中间页：只自动分页，不出现底部刷新提示。
- 最后一页：自动分页停止，底部上拉刷新可用。
- 网络失败：显示 `加载失败，点击重试`，点击后重试同一页。
- 重试成功：append 新页，清除 load-more error。
- 重试失败：保留现有列表和当前位置。
- 刷新最后一页失败：不得清空列表；可 toast/轻量错误，但不应伪装为 load-more 失败。
- 最后一页新增回复数超过一页容量：本 spec 只要求 diff 当前最后一页并 append；若服务端因新增回复导致 pageCount 增长，视为 follow-up，需要实现者在 compliance 中说明观察结果和后续建议。
- `onlyOp` 模式：全量 replies diff 后，只有 OP 回复 append 到可见 datasource；楼层仍按全量 replies 计算。
- 目标楼层跳转/恢复阅读位置：初始加载后的既有逻辑保持；自动 append 不触发重新跳转。
- 缓存：底部刷新必须 cache-bust；普通自动分页可使用同一轮 cacheBuster 或每页独立 cacheBuster，但不得拿旧缓存误判无新增。

## 9. 明确禁止

实现不得：

- 不得在自动加载下一页或底部刷新时重置整个 list。
- 不得自动滚动到新加载/新增回复。
- 不得用底部上拉触发顶部 `onRefresh` 或 `v.load()`。
- 不得未到末页就显示底部刷新提示条。
- 不得把网络失败当作“没有更多”。
- 不得改主题正文区域。
- 不得改回复浮动按钮位置和行为。
- 不得改 PAT/token 验证路径。

## 10. 验收标准 / Verification path

### 10.1 静态验收

- Spec compliance 中必须说明实际自动加载阈值：`剩余 <= 3 项` 或实现选择的等价阈值。
- 明确 footer 文案：`加载中…`、`加载失败，点击重试`、`没有更多了` 或无 footer。
- 明确底部刷新文案：`上拉刷新`、`松开刷新`、`刷新中…`。
- 明确 diff key：`reply.id`。
- 明确 cache-buster：`_=${Date.now()}`。
- 明确失败重试策略：只重试失败页，不重置列表。

### 10.2 单页主题

用 Topic `1212003`（13 回复）：

1. 打开主题详情页。
2. 滚动到底部。
3. 预期：不触发加载下一页；进入末页语义。
4. 继续上拉。
5. 预期：依次可见 `上拉刷新` / `松开刷新` / `刷新中…`。
6. 刷新成功后：列表位置不自动跳动，不清空、不重排。

### 10.3 多页主题

用任意 >100 回复、确认 pageCount > 1 的主题：

1. 打开 p=1 初始列表。
2. 滚动接近底部。
3. 预期：自动触发 p=2；footer 显示 `加载中…`。
4. 加载完成后：新增回复 append 到底部下方，当前位置不跳动。
5. 中间页重复滚动，继续自动加载下一页。
6. 到最后一页后：不再自动加载；底部继续上拉才显示底部刷新提示。

### 10.4 网络失败路径 — 跳过（已与用户确认）

跳过理由：当前 QA 设备仅通过 WLAN HDC 控制，执行断网/飞行模式会切断设备控制；设备 shell 也缺少可用的定向 V2EX 断网工具，无法安全、可重复地验证该场景。

原场景要求保留为后续可用测试环境的参考，不作为本轮 QA 必过项：

1. 在自动加载下一页时模拟网络失败。
2. 预期：footer 显示 `加载失败，点击重试`。
3. 点击重试。
4. 预期：重试同一 nextPage；成功后 append，失败后保留错误 footer。
5. 失败期间不得出现底部刷新提示。

### 10.5 回归路径

必须回归：

- 顶部下拉刷新仍正常。
- 状态栏回顶仍正常。
- 楼层编号、回复时间、感谢数、Markdown/HTML 渲染不变。
- `onlyOp` 切换后楼层与可见回复仍正确。
- 回复浮动按钮仍在原位置，且登录/回复行为不变。
- 登录态和未登录态各跑一次分页/末页刷新路径。

## 11. 六顶思考帽摘要

- 白帽：当前登录态已有 V2 分页；未登录网页 fallback 当前全量抓取，需要新增页级公开网页接口；顶部 PullRefresh 仅支持下拉。
- 红帽：用户预期是“刷到哪加载到哪”，末页才像聊天/论坛尾部那样手动检查新回复；中间页出现上拉刷新会困惑。
- 黄帽：减少多页主题初始加载成本，让长帖阅读自然连续，同时保留末页检查新回复能力。
- 黑帽：最大风险是网络失败误判末页、底部刷新误触发顶部刷新、append 时位置跳动、公开路径一次性抓全页导致需求落空。
- 绿帽：最小方案是复用 V2 分页 + 新增公开网页页级抓取；共享 bottom refresh opt-in 扩展，避免改其他列表。
- 蓝帽：交给 v2frontend 实现；完成后必须提交 spec compliance、静态 diff 说明、登录/未登录设备或截图/日志验证证据。

## 12. 建议后续 Kanban 拆分

1. v2frontend implementation：按本 spec 实现主题详情页自动分页和末页底部刷新。
2. reviewer spec-compliance：检查 diff 是否满足禁止项、状态机、公开/登录两条路径。
3. QA/device：在单页、多页、失败重试、顶部刷新回归、onlyOp 回归上做真机/日志验证。

## 13. Indicator top revision (2026-05-12)

### 13.1 原始反馈 / 证据

用户实机反馈：主题详情页顶部下拉刷新时，刷新指示器起始位置太靠上，视觉上与 `titleBar` 或第一条内容发生重叠。

代码证据：`shared/src/main/ets/components/PullRefreshListScaffold.ets` 的 `resolvedIndicatorTop()` 当前默认分支（`indicatorTop < 0`）使用：

```ts
return this.topH + ThemeConstants.TITLE_BAR_HEIGHT / 2 + this.topPadding
```

而同一 scaffold 内列表内容顶部 spacer 的高度为：

```ts
this.topH + ThemeConstants.TITLE_BAR_HEIGHT + this.topPadding
```

两者相差 `ThemeConstants.TITLE_BAR_HEIGHT / 2`（当前约 28vp），导致 indicator 默认锚点落在 titleBar 垂直中部附近，而不是 titleBar 底边下方的内容留白区域。

### 13.2 产品语义

顶部下拉刷新 indicator 的默认位置应表达“列表内容区域正在刷新”，而不是“titleBar 内部正在刷新”。当调用方没有显式传入 `indicatorTop` 时，默认 indicator 应锚定在 titleBar 底边下方、第一条内容上方的安全留白带，并留出一段呼吸量。

建议默认公式修订为：

```ts
return this.topH + ThemeConstants.TITLE_BAR_HEIGHT + this.topPadding + ThemeConstants.SPACE_MD
```

如实机视觉复测发现 `SPACE_MD` 偏紧或偏松，允许在 `SPACE_SM` / `SPACE_MD` / `SPACE_LG` 中调整呼吸量；但结构必须保持为 `topH + TITLE_BAR_HEIGHT 全量 + topPadding + spacing token`，不得回退到 `TITLE_BAR_HEIGHT / 2`。

### 13.3 保留语义

必须保持：

- `PullRefresh.ets` 内部 `indicatorTop` prop 语义不变：仍表示绝对 y 坐标。
- 显式传入 `indicatorTop >= 0` 的调用方优先级不变。
- `topH` / `topPadding` 自适应语义不变，继续适配状态栏、titleBar 和调用方顶部 padding。
- 列表顶部 spacer 高度不变，不通过挤压内容或移动首条回复来“修复”indicator。
- 顶部下拉刷新触发阈值、状态文案、spinner/文字居中逻辑不变。
- bottom refresh、自动分页、footer 状态机不因本修订改变。

### 13.4 非目标 / 禁止项

本修订不做：

- 不改 `PullRefresh.ets` 的 indicator 布局契约或 `indicatorTop` 坐标系。
- 不把 `indicatorTop` 写成固定大常量；必须保留 `topH` / `topPadding` 自适应。
- 不修改第一条回复、顶部 spacer、titleBar 高度或页面内容布局。
- 不顺手调整底部上拉刷新 indicator、footer、分页状态机或其他 refresh 行为。
- 不扩大为 titleBar / scaffold 视觉重构。

### 13.5 六顶思考帽摘要

- 白帽：当前默认公式使用 `TITLE_BAR_HEIGHT / 2`；列表内容起点使用 `TITLE_BAR_HEIGHT` 全量；差值让 indicator 落在 titleBar 内部。
- 红帽：用户看到的是“太靠上/重叠”，刷新反馈不像属于列表内容，容易显得拥挤和误触。
- 黄帽：小范围公式修订即可改善主题详情页及其他 `PullRefreshListScaffold` 页面的一致刷新反馈。
- 黑帽：风险在于误改 `PullRefresh` 坐标语义、移动内容 spacer、或影响显式 `indicatorTop` 调用方。
- 绿帽：最小安全方案是只改 scaffold 默认分支，使用 HDS spacing token 增加呼吸量；必要时由实机 QA 在 SM/MD/LG 间微调。
- 蓝帽：交给实现者做最小代码改动，之后由 reviewer 做 spec-compliance，再由 QA 在实机验证主题详情页和其他 scaffold 页面。

### 13.6 验收标准 / Verification path

静态验收：

- `resolvedIndicatorTop()` 的 `indicatorTop >= 0` 分支保持原样。
- 默认分支不再包含 `ThemeConstants.TITLE_BAR_HEIGHT / 2`。
- 默认分支包含 `this.topH + ThemeConstants.TITLE_BAR_HEIGHT + this.topPadding + ThemeConstants.SPACE_*` 结构。
- 未修改 `PullRefresh.ets` 的 `indicatorTop` prop 语义。
- 未修改列表顶部 spacer 高度或第一条回复布局。

实机 QA：

1. 设备：`192.168.50.237:12345`，沿用 shared device lease 流程。
2. 打开任意含若干回复的主题详情页。
3. 在顶部下拉触发刷新。
4. 预期：indicator 位于 titleBar 底边下方、第一条回复上方的留白区域；不与 titleBar 重叠，不贴紧第一条回复。
5. 刷新过程中 spinner 与文字提示居中、可读，顶部下拉刷新功能仍正常完成。
6. 同步抽查首页、分类页等其他使用 `PullRefreshListScaffold` 的页面，确认默认 indicator 位置一致改善且无明显回退。

## 14. Bottom indicator centering fix (2026-05-12)

### 14.1 原始反馈 / 证据

用户实机反馈：末页上拉刷新时，`上拉刷新` / `松开刷新` 底部刷新指示器覆盖最后一条回复。

代码证据：`shared/src/main/ets/components/PullRefresh.ets` 的 `bottomIndicatorY()` 当前公式为：

```ts
return Math.max(0,
  this.containerHeight
  - this.bottomIndicatorBottom
  - ThemeConstants.TITLE_BAR_HEIGHT
  - this.bottomPullOffset / 2)
```

`bottomIndicatorBottom` 已由 `PullRefreshListScaffold` 传入 `bottomH + bottomPadding`，语义正确；问题不在避让参数，而在 `PullRefresh.ets` 内部把 56vp Row 的顶部固定到内容底边上方 56vp，导致 Row 整体悬浮在最后一条回复区域内，只随 `bottomPullOffset / 2` 轻微上移。

### 14.2 产品语义

末页继续上拉时，底部刷新 Row 应表达“位于上拉露出区中的刷新提示”，而不是覆盖列表最后一条内容的浮层。

定义：

```text
露出区中心 y = containerHeight - bottomH - bottomPadding - bottomPullOffset / 2
Row 顶部 y = 露出区中心 y - TITLE_BAR_HEIGHT / 2
```

由于 `bottomIndicatorBottom = bottomH + bottomPadding`，目标公式应为：

```ts
return Math.max(0,
  this.containerHeight
  - this.bottomIndicatorBottom
  - this.bottomPullOffset / 2
  - ThemeConstants.TITLE_BAR_HEIGHT / 2)
```

核心语义变化：从“Row 顶部固定在内容底边上方 56vp”改为“Row 中心动态对齐上拉露出区中心”。`/ 2` 是因为 `TITLE_BAR_HEIGHT` 对应底部提示 Row 的高度；定位 Row 顶部时需要从目标中心减去半个 Row 高度。

### 14.3 六顶思考帽摘要

- 白帽：当前公式多减了半个 Row 高度，导致底部刷新提示整体上偏约 28vp，并进入最后一条回复区域。
- 红帽：用户看到提示覆盖回复，会觉得刷新反馈遮挡正文、动作不干净，尤其在末页阅读最后回复时刺眼。
- 黄帽：单点公式修正即可改善末页上拉反馈，不改变数据分页、末页状态机或底部避让传参。
- 黑帽：风险在于误改 `bottomIndicatorBottom` 来源、`PullRefreshListScaffold`、`LoadingFooter` 或顶部下拉 indicator，造成连带回归。
- 绿帽：最小安全方案是只改 `PullRefresh.ets` 的 `bottomIndicatorY()` 单个方法，把 `TITLE_BAR_HEIGHT` 改为 `TITLE_BAR_HEIGHT / 2`。
- 蓝帽：交给实现者做单点改动；随后 review 静态确认只触及目标方法，QA 在实机末页上拉路径复测动态居中和不遮挡。

### 14.4 保留语义

必须保持：

- `bottomIndicatorBottom` 传值语义不变，继续由调用方传入 `bottomH + bottomPadding`。
- 底部刷新启用门控不变：仍只在 `canStartBottomRefresh()` 满足末页、底部、非加载中等条件时出现。
- 底部刷新文案不变：`上拉刷新`、`松开刷新`、`刷新中…`。
- 顶部下拉刷新坐标、阈值、状态机、文案不变。
- 自动触底加载 `LoadingFooter` 语义不变；它是自动分页反馈，不是本问题的底部上拉刷新提示。
- 回复列表内容、最后一条回复布局、浮动回复按钮避让与 bottom padding 不变。

### 14.5 非目标 / 禁止项

本修订不做：

- 不修改 `PullRefreshListScaffold.ets`。
- 不修改 `LoadingFooter.ets`。
- 不修改 `bottomIndicatorBottom` 传参或底部 padding 计算。
- 不修改 `pullOffset` / `indicatorTop` / 顶部下拉刷新相关逻辑。
- 不修改分页状态机、网络请求、回复列表数据流或 footer 状态。
- 不通过移动最后一条回复、增加额外 spacer、改变回复 item padding 来规避覆盖问题。

### 14.6 验收标准 / Verification path

静态验收：

- 仅 `shared/src/main/ets/components/PullRefresh.ets` 的 `bottomIndicatorY()` 方法发生目标代码改动。
- `bottomIndicatorY()` 新公式包含 `- this.bottomPullOffset / 2 - ThemeConstants.TITLE_BAR_HEIGHT / 2`。
- 不再包含 `- ThemeConstants.TITLE_BAR_HEIGHT - this.bottomPullOffset / 2` 的旧公式。
- `PullRefreshListScaffold.ets`、`LoadingFooter.ets`、顶部 `indicatorTop` / `pullOffset` 相关逻辑未因本修订变更。

实机 QA：

1. 设备：`192.168.50.237:12345`，沿用 shared device lease 流程。
2. 打开存在多页回复的主题详情页，翻到最后一页并确认进入末页状态。
3. 缓慢上拉：底部刷新 Row 应从屏幕底边外渐入；进入露出区时，Row 垂直居中于露出区。
4. 指示器不得覆盖最后一条回复。
5. 继续加大上拉距离时，Row 仍保持围绕露出区中心的动态位置关系。
6. 松开触发刷新后，回弹动画正常，列表不重置、不自动跳动。
7. 在非末页或未到底部时继续上拉，不显示底部刷新指示器，保持既有 `canStartBottomRefresh()` 门控。

## 15. Bottom indicator extra clearance revision (2026-05-12)

### 15.1 原始反馈 / 证据

用户实机反馈：当前 `bottomIndicatorY()` 已按 section 14 改为动态居中后，末页上拉刷新指示器仍然“有一点遮挡最后一条回复”。用户提出两个候选方向：

1. 再把底部刷新指示器下移一点；
2. 或者把列表底部避让加高一点。

当前代码证据：`shared/src/main/ets/components/PullRefresh.ets` 的 `bottomIndicatorY()` 已是动态居中公式：

```ts
return Math.max(0,
  this.containerHeight
  - this.bottomIndicatorBottom
  - this.bottomPullOffset / 2
  - ThemeConstants.TITLE_BAR_HEIGHT / 2)
```

`shared/src/main/ets/components/PullRefreshListScaffold.ets` 同时用同一组避让值：

```ts
bottomIndicatorBottom: this.bottomH + this.bottomPadding
Blank().height(this.bottomH + this.bottomPadding)
```

因此本轮问题不是 section 14 的“整行未居中”根因，而是实机阅读场景里 Row 动态居中后仍与最后一条回复的视觉安全距离不足。

### 15.2 产品语义

末页底部上拉刷新提示应表达“随用户上拉从底部露出区进入的刷新提示”。它可以略低于露出区几何中心，以给最后一条回复留出额外呼吸量，但仍不应变成贴底浮层或被底部安全区/导航遮挡。

推荐语义：

```text
露出区中心 y = containerHeight - bottomIndicatorBottom - bottomPullOffset / 2
Row 顶部 y = 露出区中心 y - TITLE_BAR_HEIGHT / 2 + bottomRefreshClearance
bottomRefreshClearance = ThemeConstants.SPACE_SM  // 8vp，实机若仍略遮挡可调到 SPACE_MD(12vp)
```

对应最小实现建议：

```ts
private bottomIndicatorY(): number {
  return Math.max(0,
    this.containerHeight
    - this.bottomIndicatorBottom
    - this.bottomPullOffset / 2
    - ThemeConstants.TITLE_BAR_HEIGHT / 2
    + ThemeConstants.SPACE_SM)
}
```

`+ ThemeConstants.SPACE_SM` 是向下偏移 Row 顶部；数值必须小幅，首选 8vp。只有实机复测仍看到轻微遮挡时，才允许扩大到 `ThemeConstants.SPACE_MD`（12vp）。不要一次性使用 `SPACE_LG` 或更大值，避免提示贴近底部露出区边缘。

### 15.3 两个候选方向的六顶思考帽比较

#### 方案 A：只下移底部刷新指示器（推荐）

- 白帽：当前遮挡发生在 `PullRefresh.ets` 的 bottom refresh Row 位置；`bottomIndicatorY()` 直接决定 Row 的 y 坐标。增加 8vp 向下 clearance 是单点、可预期的视觉修正。
- 红帽：用户感受是“还有一点遮挡”，不是“列表整体底部太拥挤”。小幅下移更贴合反馈，不会改变阅读列表的整体节奏。
- 黄帽：最小改动即可改善末页最后回复可读性，并保留 section 14 的动态居中语义。
- 黑帽：风险是下移过多导致 Row 靠近底部避让/导航区；用 `SPACE_SM` 起步并实机截图验证可控。
- 绿帽：若 8vp 不够，允许同一位置微调到 12vp；不引入新 prop，不改调用方，不改列表内容布局。
- 蓝帽：执行者只改 `bottomIndicatorY()` 或在同文件提取私有常量；review 确认未触及顶部刷新、门控、分页状态机。

#### 方案 B：增加列表底部避让 / bottom padding（不推荐作为首选）

- 白帽：`PullRefreshListScaffold.ets` 当前用同一 `bottomH + bottomPadding` 同时作为列表底部 Blank 高度和 `bottomIndicatorBottom`。如果只增大 `bottomIndicatorBottom`，公式会把 indicator 往上移，反而更接近最后回复；如果增大共享 `bottomPadding`，列表最后回复和 indicator 会同时随避让体系改变，语义更宽、更容易影响其他 scaffold 页面。
- 红帽：加大列表底部空白会让末页阅读区显得更“空”，可能让用户感到内容被人为抬高；它解决的是内容布局安全区，不是本次“刷新提示位置仍略高”的直接反馈。
- 黄帽：底部 padding 方案在存在真实底部控件遮挡时有价值，但本轮证据指向 Row 与最后回复的相对视觉间距不足。
- 黑帽：它会影响所有使用 `PullRefreshListScaffold` 的页面底部留白、触底体验和 LoadingFooter 视觉距离，回归面大于单点公式修正。
- 绿帽：只有实机证明最后回复本身确实被底部安全区/浮动控件遮挡，而不是被 bottom refresh Row 覆盖时，才另开任务调整列表底部内容 padding。
- 蓝帽：本轮不采用；保留为后续独立问题，不混入 bottom refresh indicator 修正。

### 15.4 决策

选择方案 A：在 `shared/src/main/ets/components/PullRefresh.ets` 的 `bottomIndicatorY()` 中为 bottom refresh Row 增加小幅向下 clearance，首选 `ThemeConstants.SPACE_SM`（8vp），必要时经实机证据微调到 `ThemeConstants.SPACE_MD`（12vp）。

理由：

- 最小：只影响 bottom refresh indicator 的 y 坐标，不改列表数据、分页、footer 或 scaffold 默认布局。
- 语义正确：问题是指示器覆盖最后回复；修正目标应是指示器位置，而不是全局抬高列表底部内容。
- 风险更小：不触碰顶部下拉刷新，也不扩大 `PullRefreshListScaffold` / `LoadingFooter` 回归面。
- 可验证：实机直接比较末页上拉时最后回复完整可见、Row 仍接近露出区中心但略低。

### 15.5 保留语义

必须保持：

- 顶部下拉刷新不变：`indicatorTop`、`pullOffset`、顶部 `refreshState`、顶部文案/阈值/动画不因本修订改变。
- bottom refresh 门控不变：`canStartBottomRefresh()` 继续决定是否能进入底部上拉刷新；非末页、未到底部、加载中等状态不得显示 bottom refresh。
- 分页状态机不变：自动触底加载、末页判定、加载中/错误/完成状态不因本修订改变。
- bottom refresh 状态机不变：`bottomRefreshState`、`onBottomPullEnd()`、`doBottomRefresh()`、回弹动画不因本修订改变。
- `bottomIndicatorBottom` 传值语义不变：继续表示底部避让高度 `bottomH + bottomPadding`，不要把它当作“额外下移”参数。
- `LoadingFooter` 语义不变：它是自动分页 footer，不是本问题的 bottom refresh indicator。
- 回复 item 布局、最后一条回复内容、底部 Blank 高度、浮动回复按钮避让不因本修订改变。

### 15.6 非目标 / 禁止项

本修订不做：

- 不修改 `PullRefreshListScaffold.ets` 的 `bottomIndicatorBottom` 传参、底部 Blank 或默认 `bottomPadding`。
- 不修改 `LoadingFooter.ets` 或将 LoadingFooter 与 bottom refresh indicator 合并讨论。
- 不增加列表底部 spacer、回复 item padding 或滚动内容 offset 来“躲开”指示器。
- 不修改 `canStartBottomRefresh` 条件、末页判定、分页请求或刷新请求。
- 不修改顶部下拉刷新坐标或顶部刷新状态机。
- 不做大范围重构，不新增跨组件 API，除非 review 证明单点常量无法满足实机验收。

### 15.7 验收标准 / Verification path

静态验收：

- 目标改动限定在 `shared/src/main/ets/components/PullRefresh.ets` 的 bottom refresh indicator 定位逻辑；允许在同文件为 clearance 增加私有常量。
- `bottomIndicatorY()` 保留动态居中公式 `- this.bottomPullOffset / 2 - ThemeConstants.TITLE_BAR_HEIGHT / 2`，并在最终 y 上增加小幅向下 clearance（首选 `+ ThemeConstants.SPACE_SM`）。
- 未修改 `PullRefreshListScaffold.ets` 的 `bottomIndicatorBottom: this.bottomH + this.bottomPadding` 和底部 `Blank().height(this.bottomH + this.bottomPadding)`。
- 未修改 `LoadingFooter.ets`。
- 未修改 `indicatorTop` / `pullOffset` / 顶部下拉刷新相关逻辑。
- 未修改 `canStartBottomRefresh`、分页状态机、刷新状态机或网络请求。

实机 QA：

1. 设备：`192.168.50.237:12345`，沿用 shared device lease 流程。
2. 打开存在多页回复的主题详情页，触底翻到最后一页，确认 `canStartBottomRefresh()` 所需末页状态成立。
3. 缓慢上拉到底部刷新 Row 刚进入可见区；预期最后一条回复正文、头像/作者/时间等可读信息完整可见，不被 `上拉刷新` 文案或 spinner 遮挡。
4. 继续上拉到 `松开刷新` 阈值；预期 Row 仍接近底部露出区中心，但相比 section 14 的动态居中位置略低，和最后回复之间有可见额外间距。
5. 松手触发刷新；预期 `刷新中…`、回弹动画、列表位置保持既有行为，不出现跳动、重置或误触顶部刷新。
6. 在非末页或未到底部时上拉；预期不出现 bottom refresh indicator，仍由 `canStartBottomRefresh()` 门控。
7. 顶部下拉刷新抽查一次；预期顶部 indicator 位置、阈值、刷新完成行为不变。
8. 截图/录屏证据：至少保留“Row 刚进入”“松开刷新阈值附近”“非末页不上拉刷新”三类实机证据；若 8vp 仍遮挡，记录截图后仅在同一公式将 clearance 微调到 12vp 并复测。
