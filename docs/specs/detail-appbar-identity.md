# 主题详情页 AppBar 主帖身份标题规格

## 原始证据 / Quote

用户/控制器诉求：

> 主题详情页上滑后，AppBar 标题栏显示主帖头像 + 主帖标题（参考用户页实现）。

当前已知参照实现：

- `feature/user/src/main/ets/pages/UserProfilePage.ets`
  - `titleVisibilityHysteresis = 4`
  - 通过 `onAreaChange + currentScrollOffset` 记录用户名底部位置。
  - 通过 `topH + ThemeConstants.TITLE_BAR_HEIGHT` 判断是否被标题栏覆盖。
  - 通过 `USER_PROFILE_APPBAR_TITLE_STATES` / `USER_PROFILE_APPBAR_AVATAR_STATES` 按 route key 隔离多页面堆叠状态。
- `entry/src/main/ets/pages/Index.ets`
  - `UserProfileAppbarIdentity`
  - `UserProfileIdentityCCBuilder`
  - `userProfileTitleBarOpts(...)`
  - `ComponentContent<...>` 注入自定义 titleBar 内容，同时保留右侧 menu。

## 产品语义

进入主题详情页时，AppBar 标题栏初始保持原行为：空标题 + 右侧操作菜单。

当用户上滑主题详情列表，并且主帖标题（`TopicCard` 内的帖子标题 `Text`）底部被 AppBar 标题栏覆盖时，AppBar 标题栏自动显示主帖身份信息：

- 左侧显示主帖作者头像，来源优先级为 `topic.member.avatar_large || topic.member.avatar_normal`。
- 头像为圆形，尺寸约 `24vp`，与用户页 AppBar 身份头像保持一致。
- 头像右侧紧邻主帖标题文本，内容为 `topic.title`。
- 标题单行显示，超长省略。
- 标题栏右侧操作菜单保持现有 `topicDetailTitleBarOpts()` 内容和顺序。

当用户下滑，使主帖标题重新可见时，AppBar 中的头像 + 标题自动隐藏，回到默认空标题。

显示/隐藏临界点必须有 hysteresis，避免停在临界位置时抖动。

## 明确数值 / 常量

- `TOPIC_DETAIL_TITLE_VISIBILITY_HYSTERESIS = 4`，单位沿用 ArkUI 当前布局测量单位（项目内按 vu/vp 语义处理）。
- 判断基线：`appbarBottom = topH + ThemeConstants.TITLE_BAR_HEIGHT`。
- 从隐藏到显示：`currentTitleBottom <= appbarBottom`。
- 从显示到隐藏：`currentTitleBottom > appbarBottom + 4` 后才隐藏。
- AppBar 身份头像尺寸：`24`。
- AppBar 身份组件高度：`ThemeConstants.TITLE_BAR_HEIGHT`。
- AppBar 身份组件横向 padding 建议复用用户页：`left: 64, right: 96`，除非实现中发现 topic detail 右侧 menu 需要更保守的避让；若调整，必须在 review 中说明原因并截图验证。

## 新增 StorageKeys 合同

建议在 `shared/src/main/ets/constants/StorageKeys.ets` 新增以下 key。命名可按代码风格微调，但语义不可改变：

```ts
static readonly TOPIC_DETAIL_APPBAR_TITLE: string = 'topicDetailAppbarTitle'
static readonly TOPIC_DETAIL_APPBAR_AVATAR_URL: string = 'topicDetailAppbarAvatarUrl'
static readonly TOPIC_DETAIL_APPBAR_USERNAME: string = 'topicDetailAppbarUsername'
static readonly TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID: string = 'topicDetailAppbarRouteTopicId'
static readonly TOPIC_DETAIL_APPBAR_TITLE_STATES: string = 'topicDetailAppbarTitleStates'
static readonly TOPIC_DETAIL_APPBAR_AVATAR_STATES: string = 'topicDetailAppbarAvatarStates'
static readonly TOPIC_DETAIL_APPBAR_USERNAME_STATES: string = 'topicDetailAppbarUsernameStates'
```

语义：

- `TOPIC_DETAIL_APPBAR_TITLE`: 当前可见 detail 页应显示的主帖标题；不可用时为空字符串。
- `TOPIC_DETAIL_APPBAR_AVATAR_URL`: 当前可见 detail 页应显示的主帖作者头像 URL；不可用时为空字符串。
- `TOPIC_DETAIL_APPBAR_USERNAME`: 当前可见 detail 页主帖作者用户名；用于头像 placeholder 和调试判断；不可用时为空字符串。
- `TOPIC_DETAIL_APPBAR_ROUTE_TOPIC_ID`: 当前发布全局 title 状态的 detail route key；使用 `topicId.toString()`。
- `TOPIC_DETAIL_APPBAR_TITLE_STATES`: JSON object map，`topicId -> visible title`。
- `TOPIC_DETAIL_APPBAR_AVATAR_STATES`: JSON object map，`topicId -> avatarUrl`。
- `TOPIC_DETAIL_APPBAR_USERNAME_STATES`: JSON object map，`topicId -> username`。

多 detail 页面堆叠时，`*_STATES` 是主合同；单值 key 仅作为与现有 UserProfile 模式对齐的当前可见态/兜底态，不得依赖单值 key 跨 route 判断。

## ComponentContent 参数接口合同

在 `entry/src/main/ets/pages/Index.ets` 中建议新增与用户页并列的参数接口：

```ts
interface TopicDetailAppbarIdentityParams {
  title: string
  avatarUrl: string
  username: string
}
```

语义：

- `title`: AppBar 中显示的主帖标题，来自 `topic.title`，trim 后为空则不显示 identity。
- `avatarUrl`: AppBar 头像 URL，来自 `topic.member.avatar_large || topic.member.avatar_normal`。
- `username`: AppBar 头像 placeholder，来自 `topic.member.username`。

建议 builder 形态：

```ts
@Builder
function TopicDetailIdentityCCBuilder(params: TopicDetailAppbarIdentityParams) {
  TopicDetailAppbarIdentity({ title: params.title, avatarUrl: params.avatarUrl, username: params.username })
}
```

`TopicDetailAppbarIdentity` 视觉结构应与 `UserProfileAppbarIdentity` 保持同一模式：

- `Row({ space: ThemeConstants.SPACE_XS })`
- `Avatar({ url: avatarUrl, avatarSize: 24, placeholder: username || title })`
- `Text(title)` 使用 `ThemeConstants.FONT_SIZE_TITLE`、`FontWeight.Medium`、`font_primary`、单行省略。
- `.hitTestBehavior(HitTestMode.None)`，避免阻挡 titleBar 右侧菜单或返回区域。

## 多 detail 堆叠 disambiguation 策略

必须按 `topicId.toString()` 做 route key，采用 states map 隔离每个 detail 页的 AppBar identity 状态，参考 `UserProfilePage` 的 `userProfileAppbarTitleStates` / `userProfileAppbarAvatarStates`。

要求：

1. `TopicDetailPage(topicId=A)` 只写入 key `A` 对应的 states。
2. `TopicDetailPage(topicId=B)` 只写入 key `B` 对应的 states。
3. `Index.topicDetailTitleBarOpts(topicId)` 或等价函数必须根据当前 route topicId 读取 states，不得只读全局单值。
4. 当 `B` 滚出 identity 后 pop 回 `A`，`A` 的 AppBar 不得残留 `B` 的标题/头像。
5. 页面重新 shown/visible 时，应 republish 当前页自己的状态，避免 NavPathStack 复用导致显示旧页状态。
6. states 解析失败时回退为空 object；失败不得崩溃，也不得显示其他页面的 identity。

建议把 `topicDetailTitleBarOpts()` 改成带 route key 的函数，例如：

```ts
private topicDetailTitleBarOpts(topicId: number): Record<string, Object>
```

并在 `pm(name, param)` 的 `TopicDetail` 分支传入 `param.topicId`。这比在 titleBar 函数里猜当前路由更稳定。

## 行为实现建议（非强制，但需等价）

### TopicDetailPage

新增本页局部状态：

- `private layout: LayoutSafeAreaState = connectLayoutSafeArea()`；top safe-area 从 AppStorageV2 `v2:layoutSafeArea` mirror 读取。
- `@StorageLink(...)` 对应上述 topic detail appbar keys。
- `@State private titleContentBottom: number = 0`
- `@State private currentScrollOffset: number = 0`
- `@State private isTitleCoveredByAppbar: boolean = false`
- `private readonly titleVisibilityHysteresis: number = 4`

在主帖标题 `Text(topic.title)` 上记录位置：

- 使用 `onAreaChange` 读取 `newValue.globalPosition.y + newValue.height`。
- 写入 `titleContentBottom = measuredGlobalBottom + currentScrollOffset`。
- 随后调用 `evaluateAppbarIdentityVisibility()`。

滚动监听：

- `PullRefreshListScaffold` 当前已有 `onScrollIndex`，但需要连续 scroll offset。
- 推荐扩展 `PullRefreshListScaffold`，新增可选 `onDidScroll?: (offset: number, state: ScrollState) => void`，与 `SecondaryListScaffold` 对齐。
- 新 callback 必须默认无行为，不得改变 PullRefreshListScaffold 现有刷新、触底、滚动、bottomPadding 语义。
- 若实现选择在 `onScrollIndex` 内读取 `scroller.currentOffset()`，必须证明不会降低临界判断稳定性，也不得改变 `updateReadFloor(center)` 调用。

可见性判断：

```ts
const currentTitleBottom = this.titleContentBottom - this.currentScrollOffset
const appbarBottom = this.topH + ThemeConstants.TITLE_BAR_HEIGHT
const shouldShowIdentity = this.isTitleCoveredByAppbar
  ? currentTitleBottom <= appbarBottom + this.titleVisibilityHysteresis
  : currentTitleBottom <= appbarBottom
```

当状态变化时发布：

- visible=true：发布当前 topicId 的 title/avatar/username 到 states map，并同步当前单值 key。
- visible=false：当前 topicId 的 states value 置空字符串或删除该 key；两者均可，但 `Index` 读取时必须把缺失/空值视为不显示。
- `aboutToAppear` 初始必须清空当前 route 的 visible 状态，等数据加载和标题测量后再按实际位置显示。
- `aboutToDisappear` 或不可见时不得清空其他 topicId 的状态。

### Index titleBar

`TopicDetail` route 分支建议从：

```ts
.titleBar(this.topicDetailTitleBarOpts())
```

调整为等价的 route-aware 形式：

```ts
.titleBar(this.topicDetailTitleBarOpts(((param as Record<string, Object>)['topicId'] as number) || 0))
```

`topicDetailTitleBarOpts(topicId)` 必须：

1. 完整保留现有 menu item 内容、顺序、图标、action、`maxCount: 3`。
2. 根据 `topicId` 从 states map 读取 title/avatar/username。
3. 若当前 topicId 有非空 title，则创建 `ComponentContent<TopicDetailAppbarIdentityParams>` 注入 `navDestTitleBarOpts(' ', menu, undefined, undefined, cc, title)` 或项目内等价方式。
4. 若无 title，则保持当前 `navDestTitleBarOpts(undefined, menu)` 行为。

## 保留语义（不得改变）

- `TopicCard` 主帖正文、头像、标题、节点、作者、时间、点击/长按/链接/图片行为不变。
- `TopicCard` 内原主帖标题仍在内容区渲染，不得因 AppBar 显示而移除、替换或隐藏。
- `topicDetailTitleBarOpts` 右侧 menu 内容、顺序、icon、action、loading/状态更新不变：感谢主题、站内收藏、稍后读、忽略主题、举报主题、复制标题、复制链接、分享链接、浏览器打开。
- `ReplyCard` 渲染、楼层、Markdown、图片预览、链接跳转、感谢/忽略/举报/复制等行为不变。
- 浮动「回复/登录」按钮位置和行为不变。
- 跳楼对话框、回复 sheet、上下文 sheet 不变。
- `PullRefreshListScaffold` 顶部下拉刷新、`onReachEnd` 触底加载更多、`bottomPadding` 不变。
- `DetailViewModel` 数据路径不变，包括登录态 API、未登录网页 fallback、缓存、已读位置恢复。
- 单击状态栏回顶等系统/导航默认行为不变。

## Non-goals

- 不处理主题详情页触底自动加载 / 末页上拉刷新策略；该范围由 lane `detail-bottom-refresh` 处理。
- 不修改用户页、节点页、首页 AppBar 行为。
- 不做标题栏全局视觉风格调整。
- 不重构 `TopicCard` 数据结构或 `DetailViewModel` 加载路径。
- 不调整回复列表分页策略、回复排序、楼层算法。
- 不新增设置开关。

## 六顶思考帽决策摘要

### 白帽（事实）

- 用户页已有相似 AppBar identity 机制，可以复用状态发布、hysteresis、ComponentContent 注入模式。
- 主题详情页当前 titleBar 只有空标题 + 右侧 menu。
- 主题详情页当前 `PullRefreshListScaffold` 缺少 `onDidScroll`，需要可获取连续 scroll offset 才能稳定判断标题底部与 AppBar 的关系。
- 多个 TopicDetail 可以通过 V2EX 链接或列表点击在 stack 中堆叠。

### 红帽（体验）

- 主帖标题滚出屏幕后，详情页上下文感变弱；AppBar 显示头像 + 标题能降低用户迷失感。
- 临界点抖动会显得“不稳”，因此 hysteresis 是体验要求，不是可选优化。

### 黄帽（收益）

- 提升长帖阅读时的上下文识别。
- 与用户页已有行为一致，降低学习成本。
- states map 方案能提升多 detail 堆叠可靠性。

### 黑帽（风险）

- 只用全局单值 key 会导致 A/B detail 堆叠串页。
- 改 `PullRefreshListScaffold` 容易误伤下拉刷新/触底加载。
- AppBar 自定义内容若 hitTest 或 padding 不当，可能遮挡返回区或右侧 menu。
- 若未处理未登录网页 fallback 或加载中状态，可能出现空标题误显示。

### 绿帽（备选）

- 最小方案：在 `onScrollIndex` 读取 `scroller.currentOffset()`；改动小，但连续性和触发频率需验证。
- 推荐方案：给 `PullRefreshListScaffold` 增加可选 `onDidScroll`，与 `SecondaryListScaffold` 对齐；默认 no-op，风险可控。
- 长期方案：抽象 AppBar identity state publisher，但本任务不做，避免扩大范围。

### 蓝帽（收敛）

推荐采用 route-aware states map + 可选 `onDidScroll` 扩展 `PullRefreshListScaffold`。实现后必须先做 spec-compliance review，再做代码质量 review 和真机/截图验收。

## 验收路径

验收必须在真实 V2Next worktree 和设备/截图环境中完成；实现 agent 自述不算完成证据。

1. 单 detail 页：
   - 打开 topic `1212003`。
   - 初始 AppBar 无 identity，只保留右侧菜单。
   - 上滑至主帖标题底部被标题栏覆盖。
   - AppBar 出现主帖作者头像 + 「紧急避雷！...」主帖标题。
   - 下滑回主帖标题重新可见。
   - identity 消失，恢复空标题。
   - 提供截图序列。

2. Hysteresis：
   - 停在临界位置附近小幅上下滑动。
   - identity 显示状态不抖动。
   - 提供视频或多张连续截图。

3. 多 detail 堆叠：
   - 打开 A detail。
   - 从 A 内打开 B detail。
   - 滚动 B 直到 AppBar 出现 B 的 identity。
   - pop 回 A。
   - A 的 AppBar 状态独立，不残留 B 的标题/头像。
   - 若 A 未滚出标题，则 A 无 identity；若 A 之前已滚出标题，则显示 A 自己的 identity。
   - 提供截图。

4. 右侧 menu：
   - identity 显示时打开右上角菜单。
   - 至少执行一项无破坏操作（如复制标题或复制链接）。
   - 菜单内容、顺序和 action 与实现前一致。
   - 提供截图/日志。

5. 顶部下拉刷新：
   - 回到顶部触发下拉刷新。
   - 刷新 indicator 和数据加载不与 identity 冲突。
   - `onRefresh` 仍调用 `v.load()`。

6. 触底/加载更多：
   - 在有多页回复的主题下滚到底部。
   - `onReachEnd` / `loadMoreReplies()` 行为不变。
   - 不与本任务新增 scroll callback 冲突。

7. 浮动回复按钮：
   - 登录态显示「回复」，未登录态显示「登录」。
   - 位置和点击行为不变。

8. 构建前置：
   - 任意 build/install/device 验证前，先在 lane worktree 执行 `scripts/sync-signing-materials.sh`。
   - 不打印签名材料内容，不提交签名材料。

## 实现交付要求

实现任务完成时必须提交：

- 修改文件列表。
- 对照本 spec 的逐项 compliance 说明。
- 构建/测试命令与结果。
- 上述验收路径的截图或视频证据。
- 若 `PullRefreshListScaffold` 被扩展，说明默认行为如何保持不变。
- 若未采用推荐 states map 方案，必须说明替代方案如何防止多 detail 堆叠串页。

## 禁止项

- 不得修改主工作区 `/home/gamer/git/V2Next`。
- 不得修改 lane `detail-bottom-refresh` worktree。
- 不得在本 spec 任务中写实现代码、build、install、控制设备或 commit。
- 不得删除/重排主题详情右侧 menu 项。
- 不得以隐藏内容区主帖标题来替代 AppBar identity。

## Trailing 避让修订（2026-05-12）

### 原始证据 / Quote

实机验证发现，MINI 模式下 `TopicDetailAppbarIdentity` 通过 `stackBuilderComponent` 注入的自定义标题层会延伸到 HDS trailing actions 区域下方，导致长标题文字被右侧爱心/星标/更多按钮遮挡。

### 白帽：已确认事实

- HDS `mainTitle: ResourceStr` 仅支持字符串，不能承载“头像 + 标题”的复合 title。
- HDS `subTitleBuilder` / `subTitleComponent` 仅在 MODAL 模式生效，不适用于当前主题详情页 MINI 模式标题栏。
- MINI 模式下复合自定义 title 只能继续使用 `stackBuilderComponent` / `ComponentContent` 路径。
- HDS 不会为 `stackBuilderComponent` 回吐或自动预留 trailing actions 宽度；开发者必须在自定义 title 内容层手动设置右侧 padding。
- 参考 SDK 文档：`references/JsEtsAPIReference/topics/components/HdsNavigation.md` 中 `HdsNavigationTitle`、`TitleBarContentOptions` 相关段落（约 L1100-L1180）。

### 实测数据

- 设备：`192.168.50.237:12345`。
- 分辨率：`1320 × 2120 px`。
- 标题栏高度截图测量：约 `180 px`，对应 HDS MINI titleBar `56 vp`，反推 `vpRatio ≈ 180 / 56 = 3.21`。
- 登录态主题详情页，上滑触发 AppBar identity 渐显后截图测量：第一个 trailing icon 左边缘 `x = 858 px`。
- trailing 实占宽度推导：`(1320 - 858) / 3.21 + 4 ≈ 148 + 4 = 152 vp`。
- `4 vp` 为呼吸余量，避免边界测量误差和图标抗锯齿边缘导致文字贴边。

### 产品语义修订

`TopicDetailAppbarIdentity` 的标题文本必须在右侧 trailing actions 左边结束；当标题过长时，用单行省略号截断，不得绘制到爱心/星标/更多按钮下方。

### 实现合同修订

在 `entry/src/main/ets/pages/Index.ets` 的 `TopicDetailAppbarIdentity` 中，将当前：

```ts
.padding({ left: 64, right: 96 })
```

修订为：

```ts
// 152vp is the measured trailing action width for the current
// topicDetailTitleBarOpts menu (maxCount=3, 9 items total). HDS does not
// auto-reserve trailing space for stackBuilderComponent content in MINI mode.
// If menu maxCount or menu item count/order changes, remeasure and update this
// value: swipe until identity appears, screenshot, measure first trailing icon
// left edge x, then vp = (screenWidthPx - x) / vpRatio + 4.
.padding({ left: 64, right: 156 })
```

说明：`156 vp` = 实测 trailing 区 `152 vp` + 保守余量，用于覆盖当前 menu `maxCount=3` 且总计 9 个 items 的可见 trailing 区。此值是与当前 HDS menu 结构绑定的测量合同，不是通用设计 token。

### 保留语义

- 继续使用 `stackBuilderComponent` / `ComponentContent` 注入复合 title，不改用 `mainTitle`。
- 保留 `topicDetailTitleBarOpts` 现有 menu item 内容、顺序、icon、action 和 `maxCount: 3`。
- 保留 AppBar identity 的头像、标题文本来源、单行省略、hysteresis、route-aware states map 和 hitTest 语义。
- 保留内容区主帖标题，不用隐藏正文标题来规避遮挡。

### Non-goals

- 不降低 menu `maxCount`。
- 不删除、重排或合并 menu items。
- 不用 `onAreaChange` 动态测量 trailing 区；当前 HDS 不暴露 trailing area，动态测量会增加不稳定性。
- 不重构 HDS Navigation 或标题栏封装。

### 验收补充

QA 需要在实机 `192.168.50.237:12345` 复测：

1. 登录态打开任意主题详情页，确认右侧 3 个 trailing 按钮齐全（爱心 / 星标 / 更多）。
2. 上滑触发 identity 渐显，截图确认标题文字末尾严格位于第一个 trailing icon 左边缘左侧；长标题以省略号截断。
3. 下滑回顶部，identity 渐隐，trailing 按钮无横向抖动。
4. 如设备支持横屏或折叠态，再复测一次；若不支持，在 QA 结果中说明未覆盖原因。
5. 若后续修改 `topicDetailTitleBarOpts` 的 `maxCount` 或 menu items 数量/顺序，必须重新执行上述截图测量并同步更新 `right` padding 与本节数据。
