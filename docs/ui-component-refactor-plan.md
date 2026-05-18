# V2Next UI 组件重构规划

更新时间：2026-05-18
当前 master：本提交，`refactor(detail): extract reply thank executor`

## 0. 目标

目标不是重做视觉风格，而是把页面内重复 UI 模式收口到稳定组件层，让页面文件主要保留数据流、导航和业务决策。

本轮重构必须保持用户可见语义：

- 不改变路由名称和参数。
- 不改变登录、写操作、收藏、感谢、屏蔽、搜索等业务语义。
- 不新增假入口、假设置或不可验证的静态控件。
- 不把渲染契约任务混入普通 UI 重构；`MarkdownContent.ets` 继续按独立 rendering contract 推进。

## 1. 当前结构判断

已有共享基础：

- `SecondaryListScaffold`
- `PullRefreshListScaffold`
- `ConciseListRow`
- `GroupedListSection`
- `AppSearchField`
- `AppTextField`
- `AppActionButton`
- `FilterChip`
- `EmptyState`
- `TopicCard`
- `ReplyCard`

主要问题：

1. 页面状态重复：Loading / Error / Login required / Empty 在多个页面内手写。
2. 列表 row 重复：账号关注、屏蔽用户等 member row 重复。
3. 搜索页过重：输入、历史、本地结果、远程结果、筛选 sheet、row/card、数据逻辑混在一个页面。
4. 分页列表模式不统一：初始加载、空态、错误、footer loading、pull refresh 分散实现。
5. `TopicDetailPage` 业务复杂，不能一次大拆。
6. `MarkdownContent` 是渲染专项，不纳入本轮普通 UI lane。

## 2. Lane 顺序

### Lane 1：PageState 组件收口

范围：

- 新增共享页面状态组件。
- 迁移低风险页面中重复的 loading/error/login/empty builder。

候选组件：

- `PageLoadingState`
- `PageErrorState`
- `PageLoginRequiredState`
- `CardEmptyState`

优先迁移页面：

- `feature/user/src/main/ets/pages/UserTopicsPage.ets`
- `feature/user/src/main/ets/pages/UserRepliesPage.ets`
- `entry/src/main/ets/pages/MyNodesPage.ets`
- `entry/src/main/ets/pages/MyTopicsPage.ets`
- `entry/src/main/ets/pages/AccountFollowingPage.ets`
- `entry/src/main/ets/pages/AccountBlacklistPage.ets`
- `feature/node/src/main/ets/pages/NodeTopicPage.ets`

验收：

- 页面原有状态文案不变。
- 重试、去登录等动作保持原行为。
- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 设备 QA 覆盖至少一个 loading/empty/error/login 状态或可达替代路径，并截图/记录。

### Lane 2：AccountMemberRow 收口

范围：

- 抽 `AccountMemberRow`，统一关注用户、屏蔽用户列表 row。
- 替换页面内重复 avatar + username + subtitle + chevron 结构。

优先迁移页面：

- `entry/src/main/ets/pages/AccountFollowingPage.ets`
- `entry/src/main/ets/pages/AccountBlacklistPage.ets`

验收：

- 头像、用户名、副标题、点击进入用户页行为不变。
- 有数据/空态/未登录状态实机截图。

### Lane 3：SearchPage UI 拆分

范围：

- 只拆 UI 组件，不改搜索数据语义。
- 搜索历史、本地结果、远程结果、筛选 sheet 分离。

候选组件：

- `SearchPanel`
- `SearchHistoryStrip`
- `SearchTopicRow`
- `SearchNodeRow`
- `RemoteTopicRow`
- `SearchFilterSheetContent`

验收：

- 本地、节点库、SOV2EX、网页搜索四种模式入口行为不变。
- 搜索历史保存/清空不变。
- 筛选 sheet 打开/应用/清除行为不变。
- 设备 QA 截图覆盖搜索页主态、筛选 sheet、至少一种结果列表。

### Lane 4：PagedListScaffold 试点

范围：

- 新增高阶分页列表脚手架或扩展现有 scaffold。
- 封装 initial loading、empty、error/retry、pull refresh、load more footer、bottom safe area。

优先试点：

- `entry/src/main/ets/pages/MyTopicsPage.ets`
- `feature/node/src/main/ets/pages/NodeTopicPage.ets`

验收：

- 下拉刷新、触底加载、加载更多失败重试保持不变。
- 空态/错误/有数据/加载更多截图或 layout 证据。

### Lane 5：TopicDetailPage 结构拆分

范围：

- 先拆 UI，不动写操作和解析逻辑。
- 禁止一次性大改。

候选拆分：

- `TopicHeaderCard`
- `ReplyFilterBar`
- `ReplyContextSheet`
- `TopicActionCoordinator`（后续，非第一步）

验收：

- 详情页打开、回复列表、只看楼主、排序、跳楼、回复 sheet、图片预览至少覆盖主路径。
- 写操作相关改动必须保留确认与全局保护语义。

## 3. 明确不做

- 不在普通 UI 重构中修改 `MarkdownContent.ets` 渲染算法。
- 不在 PageState lane 中改业务加载逻辑。
- 不在组件收口时更换页面 IA 或删除入口。
- 不用 disabled 控件掩盖未实现功能。
- 不提交 `.hermes-artifacts/` 截图、layout、日志证据。

## 4. 验证规则

每个 UI lane 必须：

1. `git diff --check`
2. `bash dev.sh --build-only`
3. 按 `AGENTS.md` 的 hdc readiness probe 连接设备。
4. 安装到 `192.168.50.237:12345`。
5. 设备 QA 保存到 `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/`。
6. QA 结果包含 `validation-summary.md` 和 `result.json`。
7. `result.json` 必须有 `verdict`、`summary`、`artifact_dir`、`commands`、`changed_files`、`evidence`、`commit`。

如果设备 probe 不输出 `ok`，该 lane 的设备 QA 记为 `BLOCKED`，不得把 build 通过当作 UI PASS。

## 5. 当前执行入口

从 Lane 1 开始：

1. 新增 shared PageState 组件。
2. 先迁移 `UserTopicsPage` / `UserRepliesPage` 两个相似页面。
3. build + device QA。
4. PASS 后再继续迁移账号本地列表页。

## 6. 执行记录

### 2026-05-17 Lane 1 第一批

状态：PASS

变更：

- 新增 `shared/src/main/ets/components/PageState.ets`。
- 从 shared 入口导出 `PageLoadingState`、`PageErrorState`、`PageLoginRequiredState`、`CardEmptyState`。
- 迁移 `UserTopicsPage` 和 `UserRepliesPage` 的 loading/error/empty/footer loading 重复 builder。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2115-page-state-lane1-qa/`。
- 实机路径覆盖：发现页主题 -> 作者用户页 -> `查看全部主题` -> `全部主题`；用户页回复 tab -> `查看全部回复` -> `全部回复`。

后续入口：

1. 继续 Lane 1，迁移 `MyNodesPage` / `MyTopicsPage` / `AccountFollowingPage` / `AccountBlacklistPage`。
2. 每批保持小范围迁移、build-only、实机 QA。

### 2026-05-17 Lane 1 第二批

状态：PASS

变更：

- 迁移 `MyTopicsPage` / `MyNodesPage` 的登录、加载、错误、空态。
- 迁移 `AccountFollowingPage` / `AccountBlacklistPage` 的登录、加载、错误和列表内空态。
- 保持原有路由、文案和重试/去登录动作。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2131-page-state-account-qa/`。
- 实机路径覆盖：账号页 -> `收藏主题`、`收藏节点`、`关注用户`、`屏蔽与忽略`。
- 覆盖状态：收藏主题有数据、收藏节点有数据、关注用户有数据、屏蔽与忽略列表内空态。

后续入口：

1. 完成 Lane 1 剩余 `feature/node/src/main/ets/pages/NodeTopicPage.ets`。
2. 进入 Lane 2，抽 `AccountMemberRow` 收口关注/屏蔽用户 row。

### 2026-05-17 Lane 1 第三批

状态：PASS

变更：

- 迁移 `NodeTopicPage` 的初始 loading overlay 内部实现、空态和错误态到共享 PageState。
- 保留原 Stack + PullRefreshListScaffold 结构、分页、下拉刷新、加载更多错误和节点收藏动作。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2137-page-state-node-topic-qa/`。
- 实机路径覆盖：账号页 -> `收藏节点` -> `iPhone` 节点主题页。

Lane 1 结论：完成。下一步进入 Lane 2，抽 `AccountMemberRow`。

### 2026-05-17 Lane 2

状态：PASS

变更：

- 新增 `shared/src/main/ets/components/AccountMemberRow.ets`。
- 从 shared 入口导出 `AccountMemberRow`。
- 迁移 `AccountFollowingPage` 和 `AccountBlacklistPage` 的 member row，保留原点击进入用户页行为。
- 保留关注用户头像 placeholder、用户名、副标题、右侧箭头和卡片视觉。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2142-account-member-row-qa/`。
- 实机路径覆盖：账号页 -> `关注用户`；账号页 -> `屏蔽与忽略`。
- 覆盖状态：关注用户有数据 row、屏蔽与忽略空态。

Lane 2 结论：完成。下一步进入 Lane 3，拆分 `SearchPage` UI 层，先只抽展示组件，不改变搜索数据语义。

### 2026-05-17 Lane 3 第一批

状态：PASS

变更：

- 新增 `entry/src/main/ets/components/SearchPageComponents.ets`。
- 抽出 `SearchPanelHeader`，承载搜索输入、加载/错误提示和来源 chip。
- 抽出 `SearchHistoryStrip`，承载历史标题、清空入口和历史关键词 chip。
- 抽出 `SearchTopicRow` / `SearchNodeRow` / `RemoteTopicRow`，承载本地主题、节点和 SOV2EX 结果 row。
- 抽出 `ExternalWebSearchCard`，承载网页搜索模式卡片。
- `SearchPage` 保留搜索状态、过滤、远程请求、历史持久化、导航和 sheet 状态，不改变业务语义。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2149-search-ui-components-qa/`。
- 实机路径覆盖：应用内搜索路由 `https://www.v2ex.com/search?q=apple` -> 本地结果 -> `SOV2EX` 结果 -> 搜索筛选 sheet -> 清空关键词后的搜索历史。

后续入口：

1. Lane 3 第二批继续拆筛选 sheet 内容，但必须保持远程筛选状态和执行时机不变。
2. 如果 sheet 拆分引入 `@Link` 状态较多，优先拆本地筛选内容，再拆远程筛选内容。

### 2026-05-17 Lane 3 第二批

状态：PASS

变更：

- 在 `SearchPageComponents.ets` 中抽出 `LocalSearchFilterSheetContent`。
- 在 `SearchPageComponents.ets` 中抽出 `RemoteSearchFilterSheetContent`。
- 将 `SearchResultFilter` 和 `RemoteDateRange` 类型移入搜索组件文件统一导出。
- `SearchPage` 保留筛选状态写入、远程搜索执行、结果重置和 sheet 关闭时机。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2155-search-filter-components-qa/`。
- 实机路径覆盖：应用内搜索路由 `https://www.v2ex.com/search?q=apple` -> 本地筛选 sheet -> SOV2EX 远程筛选 sheet -> 作者输入 `Dream4U` -> 键盘收起后的远程筛选 sheet。

Lane 3 结论：主要 UI 拆分完成。后续若继续瘦身，优先评估是否抽搜索数据/状态 viewmodel；不要在同一 lane 中再扩大到网络语义。

### 2026-05-17 Lane 4 第一批

状态：PASS

变更：

- 新增 `shared/src/main/ets/components/PagedListScaffold.ets`。
- 从 shared 入口导出 `PagedListScaffold`。
- `PagedListScaffold` 收口分页列表的初始 loading、初始 error/retry、empty、`PullRefreshListScaffold` 包装和底部 `LoadingFooter`。
- 迁移 `MyTopicsPage`，保留登录态、两步验证、数据请求、分页去重、toast 和路由行为。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2208-paged-list-my-topics-qa/`。
- 实机路径覆盖：账号页 -> `收藏主题` -> 有数据列表 -> 连续上滑触发分页/后续主题渲染。

后续入口：

1. Lane 4 第二批再评估 `NodeTopicPage` 是否适合接入 `PagedListScaffold`。
2. `NodeTopicPage` 当前有 loading overlay、节点收藏状态和加载更多错误重试，迁移时必须保留这些页面级交互，不强行一次收口。

### 2026-05-17 Lane 4 第二批

状态：PASS

变更：

- 扩展 `PagedListScaffold`，支持可选隐藏 footer、加载更多错误文案和显式重试按钮文案。
- 扩展 `LoadingFooter`，保留默认“加载失败，点击重试”的点击重试语义，同时支持页面传入错误文案和按钮式重试。
- 迁移 `NodeTopicPage` 接入 `PagedListScaffold`，保留节点主题 loading overlay、空态、错误态、下拉刷新、触底加载、加载更多失败重试和节点收藏相关状态。
- 避免给 `PagedListScaffold` 增加第二个 `@BuilderParam`；ArkUI 尾随 builder 调用要求组件只有一个 `@BuilderParam`。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2217-paged-list-node-topic-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> `Apple` 节点主题页 -> 连续上滑触发分页/后续主题渲染。

Lane 4 结论：`PagedListScaffold` 已完成 `MyTopicsPage` 和 `NodeTopicPage` 两个试点。下一步进入 Lane 5 前，先拆分范围较小、可独立验证的 `TopicDetailPage` 展示组件，不碰写操作和解析逻辑。

### 2026-05-17 Lane 5 第一批

状态：PASS

范围：

- 只拆 `TopicDetailPage` 的回复列表展示组件。
- 不改主题正文解析、Markdown 渲染、回复编辑器、感谢、收藏、屏蔽、举报、复制、图片预览、链接跳转等行为逻辑。

变更：

- 新增 `feature/detail/src/main/ets/components/TopicDetailComponents.ets`。
- 抽出 `TopicDetailReplyDivider`，承载回复数量、楼层跳转、回复显示模式菜单和“最新”入口。
- 抽出 `ReplyContextSheetContent` 和 `ReplyContextListItem`，承载回复上下文 sheet 外壳和上下文预览条目。
- `TopicDetailPage` 保留状态、楼层计算、菜单状态、跳转和回调行为。

验收：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2226-topic-detail-components-qa/`。
- 实机路径覆盖：`Apple` 节点主题页 -> 第一条主题详情 -> 回复工具条 -> 显示模式菜单 -> 回复操作菜单 -> `#2 回复上下文` sheet。

后续入口：

1. `TopicDetailPage` 下一批仍只拆纯展示：优先评估主题头部元信息卡或预加载进度/footer。
2. 写回复、感谢、收藏、屏蔽、举报、解析和 Markdown 渲染继续保持原页面内逻辑，不在同一批移动。

### 2026-05-17 Lane 5 第二批

状态：PASS

范围：

- 继续只拆 `TopicDetailPage` 的纯展示组件。
- 不改主题正文 Markdown、补充内容解析、图片/链接/mention 点击、写回复、感谢、收藏、屏蔽、举报等行为逻辑。

变更：

- 在 `TopicDetailComponents.ets` 中抽出 `TopicDetailHeader`，承载主题作者、发布时间、节点 tag 和标题展示。
- `TopicDetailHeader` 通过 `onTitleAreaChange` 回传标题测量结果，`TopicDetailPage` 继续负责 appbar identity 显隐状态。
- 抽出 `TopicRepliesPreloadIndicator`，承载回复预加载进度展示。
- `TopicDetailPage` 保留主题正文、补充内容、导航参数和所有交互行为。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2251-topic-detail-header-qa/`。
- 实机路径覆盖：`Apple` 节点主题页 -> 第一条主题详情 -> 主题头部/正文渲染 -> 连续上滑触发 appbar identity 与回复区展示。

Lane 5 展示拆分结论：低风险展示层已拆出回复工具条、回复上下文、主题头部和预加载提示。后续若继续拆 `TopicDetailPage`，应进入行为协调或正文渲染边界，风险显著高于当前批次。

### 2026-05-17 Lane 6 第一批

状态：PASS

范围：

- 先拆 `SearchPage` 本地结果构建逻辑，降低页面内数据合并和排序代码量。
- 不改搜索入口、历史记录、远端 Web 搜索、节点索引加载、筛选 sheet 和结果点击行为。

变更：

- 新增 `SearchLocalResultBuilder`，集中处理本地主题/节点搜索结果的匹配、去重、来源合并和排序。
- `SearchPage` 保留 keyword/source/filter 状态、缓存加载、远端搜索时序和页面交互，只调用 builder 接收 `topicResults` 与 `nodeResults`。
- 保留原有本地搜索来源优先级：收藏主题、最近浏览、详情缓存、列表缓存、关注节点、节点库。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2256-search-local-builder-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/search?q=apple` -> 本地搜索结果渲染 -> 本地筛选 sheet 展开。

后续入口：

1. `SearchPage` 后续可继续拆状态协调，但应先明确远端搜索、本地搜索、历史记录三条状态线的职责边界。
2. 下一步按计划进入 `TopicDetailPage` 行为协调拆分，优先选择纯协调、无写操作、无网络请求的上下文构建逻辑。

### 2026-05-17 Lane 7 第一批

状态：PASS

范围：

- 拆 `TopicDetailPage` 回复上下文构建协调逻辑。
- 不改回复感谢、回复提交、主题收藏/感谢、屏蔽/举报、Markdown 渲染、图片预览、链接跳转和网络请求。

变更：

- 新增 `ReplyContextCoordinator`，集中生成回复上下文 sheet 的条目。
- 将上文/下文楼层、当前回复、当前回复 mention 到的历史作者、后续提到当前作者的回复等上下文规则移出页面。
- `TopicDetailPage` 保留 sheet 显隐、标题、跳转到楼层和 UI 事件接线。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260517-2301-reply-context-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 回复操作菜单 -> `查看上下文` -> `#1 回复上下文` sheet，确认 `当前回复`、`提到 @di11wei`、`下文` 条目渲染。

后续入口：

1. `TopicDetailPage` 仍有较重的写操作与网络行为，后续拆分必须按“单一行为族 + 实机 QA”的节奏推进。
2. 下一批可评估把回复/主题 action preparation 拆成 service/coordinator，但感谢、收藏、屏蔽、举报属于有副作用行为，不能和展示/上下文构建混在一批。

### 2026-05-18 Lane 7 第二批

状态：PASS

范围：

- 拆 `TopicDetailPage` action 协调中的纯解析、文案和本地状态处理。
- 不移动 AlertDialog、toast、网络调用、登录 cookie 读取、真实感谢/收藏/忽略/举报执行。
- 不改变主题 action command payload、topicId 过滤、菜单入口、确认弹窗按钮和副作用保护语义。

变更：

- 新增 `TopicDetailActionCoordinator`。
- 将 topic action command 解析移出页面，并继续按 topicId 过滤当前前台详情页。
- 将主题收藏/感谢/忽略/举报确认文案、回复 action 文案、解析失败 fallback 文案集中到 coordinator。
- 将回复感谢状态 JSON 读取和写入集中到 coordinator，`TopicDetailPage` 仍负责 view model 标记和持久状态字段赋值。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0002-topic-detail-action-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 更多 action 菜单 -> `忽略主题` 确认弹窗 -> 取消，不执行真实忽略。

后续入口：

1. 下一批若继续拆 action 行为，应只选一个行为族，例如 topic favorite/thank 或 reply thank。
2. 涉及真实写操作执行时，必须明确账号状态和副作用回滚策略；未明确前只验证确认/取消和未登录提示路径。

### 2026-05-18 Lane 7 第三批

状态：PASS

范围：

- 按剩余计划依序完成：
  1. action 行为族的前置 guard 收口。
  2. 阅读/滚动协调逻辑收口。
- 不移动真实写操作执行、AlertDialog、toast、cookie 读取、view model 网络请求、页面滚动器实例。
- 不改变楼层编号、列表 index 偏移、阅读位置保存/恢复、目标楼层跳转、回复预加载上限和 action 未登录/已感谢/缺失提示语义。

变更：

- 扩展 `TopicDetailActionCoordinator`，集中 topic thank、reply thank、topic/reply moderation 的前置 guard 与 topic thank 状态解析。
- 新增 `TopicDetailScrollCoordinator`，集中回复列表末尾 index、跳楼输入解析、楼层到列表 index 映射、阅读中心 index 到回复 index 映射、目标楼层预加载循环。
- `TopicDetailPage` 继续负责 UIContext、CollectionSettings、DetailViewModel、Scroller、toast/dialog 和真实副作用执行。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0012-topic-detail-action-scroll-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 连续滚动到回复区 -> 更多 action 菜单 -> `忽略主题` 确认弹窗 -> 取消，不执行真实忽略。

后续入口：

1. `TopicDetailPage` 后续若继续拆，应转向更高风险的真实写操作执行器或 ReplyComposerSheet，必须一批一个行为族。
2. `SearchPage` 仍可拆本地/远端/网页搜索状态协调，但需覆盖本地结果、SOV2EX、filter sheet 和历史记录。

### 2026-05-18 Lane 7 第四批

状态：PASS

范围：

- 拆回复编辑器中的纯文本协调逻辑。
- 覆盖 `ReplyComposerSheet` 和独立 `ReplyEditorPage` 两个回复编辑入口。
- 不移动真实回复提交、草稿 I/O、AlertDialog、toast、UIContext、ApiService 调用和页面关闭/刷新副作用。
- 保留 sheet 与独立页的差异：sheet 保存节流仍为 600ms，独立页保存节流仍为 500ms；独立页提交按钮继续受 cookie gate 约束。

变更：

- 新增 `ReplyComposerCoordinator`，集中 initial content 归一化、草稿/mention 合并、Markdown inline/line prefix 插入、提交可用性判断和 sheet 编辑区高度计算。
- `ReplyComposerSheet` 调用 coordinator 处理 initialContent watch、草稿合并、Markdown toolbar 插入、提交按钮 enabled 和 keyboard 高度下的编辑区高度。
- `ReplyEditorPage` 调用同一 coordinator 处理草稿合并、Markdown toolbar 插入和基础提交可用性，同时保留原 cookie gate、提交确认文案、成功后返回页面和草稿保存时序。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0140-reply-composer-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 打开回复 sheet -> 输入 `qa_test_reply` -> Markdown bold 插入 `**文字**` -> 预览渲染 -> 清空草稿确认 -> 清空后提交按钮恢复 disabled。

后续入口：

1. `ReplyComposerSheet` / `ReplyEditorPage` 仍有草稿 I/O 和提交状态机重复；下一批如继续拆，应先抽 draft persistence adapter，仍不移动真实提交执行。
2. `TopicDetailPage` 的真实感谢/收藏/忽略/举报执行器仍属高风险区；若继续，应一批只选一个行为族，并覆盖确认/取消与未提交真实副作用路径。

### 2026-05-18 Lane 7 第五批

状态：PASS

范围：

- 继续拆回复编辑器草稿状态机。
- 覆盖 `ReplyComposerSheet` 和独立 `ReplyEditorPage` 两个入口。
- 不移动真实回复提交、提交确认弹窗、toast 文案、页面关闭/刷新副作用和各入口的节流差异。
- 保留差异：sheet 无 `isSaving` gate；独立页继续有 `isSaving` gate 和清空成功/失败 toast。

变更：

- 新增 `ReplyComposerDraftCoordinator`，集中草稿初始 state、load draft + initialContent merge、保存判断、保存时间戳和清草稿调用。
- `ReplyComposerSheet` 通过 draft coordinator 初始化/加载/保存/清空草稿，仍保留 600ms 节流、关闭时保存、提交成功后 `hasSubmitted` 防止再次保存。
- `ReplyEditorPage` 通过 draft coordinator 初始化/加载/保存/清空草稿，仍保留 500ms 节流、`isSaving` gate、清空 toast、提交成功后清草稿并返回。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0152-reply-composer-draft-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 打开回复 sheet -> 输入 `draft_state_qa` -> 关闭 sheet -> 重新打开并确认草稿恢复 -> 清空草稿确认 -> 清空后 TextArea 为空且提交按钮 disabled。

后续入口：

1. 下一步进入 `SearchPage` 状态协调拆分，先明确本地搜索、远端 SOV2EX、网页搜索、历史记录四条状态线，避免混入 UI 视觉变更。
2. `ReplyComposerSheet` / `ReplyEditorPage` 剩余提交前状态机可后续单独拆，但真实 `ApiService.submitReplyWithCookie` 仍不应和 Search lane 混在一起。

### 2026-05-18 Lane 8 第一批

状态：PASS

范围：

- 拆 `SearchPage` 中的纯状态/决策 helper。
- 不移动本地集合加载、缓存加载、节点库加载、SOV2EX 网络请求、历史记录 I/O、浏览器启动和页面导航。
- 不改本地搜索、远端搜索、网页搜索和 filter sheet 的触发时机。

变更：

- 新增 `SearchPageStateCoordinator`。
- 集中 action command 解析、pending search query 解析、source/filter 结果显示判断、文案、remote reset state、remote filter 判断、date range 到 `gte`、SOV2EX hit 到 UI item 映射、highlight 清洗和外部搜索 URL 构建。
- `SearchPage` 继续负责状态字段、加载副作用、SOV2EX 请求执行、历史记录持久化、sheet 显隐和导航。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0159-search-state-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/search?q=apple` -> SOV2EX 模式空态/筛选 sheet -> 切换节点库本地搜索 -> `主题结果 19` -> 本地 filter sheet。

后续入口：

1. `SearchPage` 下一批如继续拆，应优先抽 `RemoteSearchCoordinator`，但仍需要保留 remote 输入 reset、日期立即请求、apply 才关闭 sheet、分页 from 语义。
2. 本轮用户指定顺序里的第 3 项进入 `TopicDetailPage` 单一写操作执行器拆分，建议只选 `reply thank` 或 `topic thank`，并实机只覆盖确认/取消或非破坏路径。

### 2026-05-18 Lane 7 第六批

状态：PASS

范围：

- 拆 `TopicDetailPage` 中单一写操作族：reply thank 执行器。
- 只移动回复感谢 action 加载与执行的 ApiService 链路，以及回复感谢锁定状态的纯状态对象。
- 不移动 AlertDialog、toast、cookie 读取、loading/finally、view model 标记、已感谢 JSON 写入和真实副作用成功后的 UI 更新。
- 实机 QA 只验证确认/取消路径，不提交真实感谢。

变更：

- 扩展 `TopicDetailActionCoordinator`，新增 reply thank 锁定状态构建、清理状态构建和 `executeReplyThank`。
- `TopicDetailPage` 继续负责回复感谢 guard、确认弹窗、按钮文案、toast、loading、成功后标记和取消/完成清理。
- 移除页面对 `V2exReplyThankAction` 的直接类型依赖。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0203-reply-thank-executor-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 滚动到回复区 -> 点击回复感谢按钮 -> `感谢回复` 确认弹窗 -> 点击 `取消`，未提交真实感谢。

后续入口：

1. `TopicDetailPage` 若继续拆写操作执行器，应继续保持一批一个行为族，例如 topic thank 或 topic favorite。
2. 写操作 QA 默认优先覆盖确认/取消、未登录或已完成保护路径；真实提交必须先明确账号状态和回滚/可接受副作用。

### 2026-05-18 Lane 7 第七批

状态：PASS

范围：

- 拆 `TopicDetailPage` 中单一写操作族：topic thank 执行器。
- 只移动主题感谢 action 加载与执行的 ApiService 链路。
- 不移动主题感谢 guard、AlertDialog、取消逻辑、toast、loading/finally、`isTopicThanked` 和 `topicDetailThanked` 状态写入。
- 实机 QA 只验证确认/取消路径，不提交真实感谢。

变更：

- 扩展 `TopicDetailActionCoordinator`，新增 `executeTopicThank`。
- `TopicDetailPage` 的 `executeTopicThank` 改为调用 coordinator 执行 API 链路，页面继续负责所有 UI 和状态副作用。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0212-topic-thank-executor-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 点击顶部 `感谢主题` 图标 -> `感谢主题` 确认弹窗 -> 点击 `取消`，未提交真实感谢。

后续入口：

1. 继续写操作执行器时，下一项可选 `site favorite`，它有确认框和可逆状态，但仍应先只验证确认/取消路径。
2. 更高风险的 ignore/report 或真实提交路径暂缓，除非需要专项处理。

### 2026-05-18 Lane 7 第八批

状态：PASS

范围：

- 拆 `TopicDetailPage` 中单一写操作族：site favorite 执行器。
- 只移动站内收藏 toggle 的真实执行 API 调用。
- 不移动 toggle action 加载、确认弹窗、取消逻辑、toast、loading/finally、`isSiteFavorited` 和 `topicDetailSiteFavorited` 状态写入。
- 实机 QA 只验证确认/取消路径，不改变收藏状态。

变更：

- 扩展 `TopicDetailActionCoordinator`，新增 `executeSiteFavoriteToggle`。
- `TopicDetailPage` 的 `executeSiteFavoriteToggle` 改为调用 coordinator 执行 API 链路，页面继续负责所有 UI 和状态副作用。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0216-site-favorite-executor-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 点击顶部 `站内收藏` 图标 -> `站内收藏` 确认弹窗 -> 点击 `取消`，未改变收藏状态。

后续入口：

1. `TopicDetailPage` 写操作执行器中，ignore/report 具有更明显账号副作用，暂不继续扩大。
2. 下一步回到 `SearchPage`，优先抽 `RemoteSearchCoordinator`，但必须严格保留远端请求时序和 filter apply 语义。

### 2026-05-18 Lane 8 第二批

状态：PASS

范围：

- 拆 `SearchPage` 远端 SOV2EX 搜索协调逻辑。
- 只移动远端请求参数构建、执行条件判断和响应结果合并。
- 不移动 SOV2EX 网络请求执行、loading、错误处理、history 记录、sheet 显隐、搜索来源切换和导航。
- 保留 reset 时 `from=0`、非 reset 时使用当前 `remoteFrom`、日期范围转 `gte`、username/node trim、响应追加分页语义。

变更：

- 新增 `entry/src/main/ets/model/RemoteSearchCoordinator.ets`。
- `RemoteSearchCoordinator` 集中 `canExecute`、`buildRequest` 和 `mergeResponse`。
- `SearchPage` 继续负责 `this.sov2ex.search(...)`、`remoteLoading`、`remoteError`、`SearchSettings.recordQuery` 和 UI 状态字段赋值。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0220-remote-search-coordinator-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/search?q=apple` -> 切换 `SOV2EX` -> 远端结果 `SOV2EX 62140` -> 打开筛选 sheet -> 选择 `一周` 后结果 reset 为 `SOV2EX 73` -> 关闭 sheet -> 滚动到底部 -> 点击 `加载更多` 后列表继续追加结果。

后续入口：

1. `SearchPage` 后续可继续拆 history/source mode 协调，但不应再扩大到网络服务实现。
2. `ReplyComposer` 剩余提交前状态机可作为下一批低副作用重构。

### 2026-05-18 Lane 7 第九批

状态：PASS

范围：

- 拆 `ReplyComposerSheet` 和 `ReplyEditorPage` 的提交前状态机。
- 只移动提交前可用性、阻断原因、清洗后的提交内容和确认文案构建。
- 不移动真实 `submitReplyWithCookie`、草稿保存/清理、成功/失败 toast、sheet 关闭、页面返回和提交副作用。
- 保留两入口差异：sheet 未登录只写 `errorMessage`；独立页未登录 toast；独立页提交按钮继续受 cookie gate 约束。

变更：

- 扩展 `ReplyComposerCoordinator`，新增 `checkSubmit`、`canSubmitWithCookie`、sheet/page 确认文案 helper。
- `ReplyComposerSheet` 使用 coordinator 检查空内容、登录和提交快照，确认文案保持 `确定提交这条回复吗？`。
- `ReplyEditorPage` 使用 coordinator 检查空内容、登录和提交快照，确认文案保留主题标题与 5 铜币提示。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0233-reply-submit-preflight-qa/`。
- 实机路径覆盖：应用内路由 `https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 打开回复 sheet -> 空内容提交按钮 disabled -> 输入 `preflight_qa_cancel` -> 提交按钮 enabled -> `提交回复` 确认弹窗 -> 点击 `取消`，未提交真实回复。

后续入口：

1. `ReplyComposer` 的真实提交执行器仍属于高副作用路径，暂不继续移动。
2. 下一步可做 `SearchPage` history/source mode 协调，或回到 `TopicDetailPage` 做非写操作的剩余瘦身。

## 7. 后续重构路线（2026-05-18 更新）

本节覆盖上方各批次里的旧“后续入口”。后续执行以本节排序为准；历史批次只保留为过程记录和验证索引。

已完成且不再作为后续入口：

1. Search UI/状态拆分：`SearchPageComponents`、`SearchLocalResultBuilder`、`SearchPageStateCoordinator`、`RemoteSearchCoordinator`。
2. Search 回归修复：本地和远端搜索结果标题恢复左对齐。
3. TopicDetail 展示拆分：回复分隔线、右键/长按菜单、首屏加载/header preload 等纯展示或非写操作 helper。
4. TopicDetail action 协调：guard/message/local state、reply thank、topic thank、site favorite。
5. ReplyComposer 协调：基础 action、草稿持久化、提交前 preflight。

### 7.1 低到中风险，可继续自主推进

1. `SearchPage` history/source mode 协调。
   - 目标：整理搜索来源切换、本地/远端/网页搜索入口、pending query 消费、历史记录展示与查询复用的决策逻辑。
   - 边界：先不移动 `SearchSettings` 持久化 I/O，不改 SOV2EX 请求执行，不打开外部浏览器作为核心 QA 依赖。
   - 验证重点：应用内路由搜索、本地结果、SOV2EX 结果、历史 chip 复用、来源切换后列表/空态/筛选入口一致。

2. `SearchPage` filter/apply 状态瘦身。
   - 目标：把筛选草稿、已应用筛选、reset/pagination 判断继续从页面中剥离。
   - 边界：必须保留现有语义：日期范围变更会触发 reset 请求，apply 负责关闭 sheet，分页继续使用 `remoteFrom`。
   - 验证重点：远端筛选 sheet、日期范围、用户名/节点筛选、加载更多追加。

3. `TopicDetailPage` 非写操作瘦身。
   - 目标：继续拆 appbar identity、标题可见性、顶部按钮展示条件等无账号副作用逻辑。
   - 边界：不碰真实 thank/favorite/ignore/report 执行，不改 Markdown 渲染合同。
   - 验证重点：详情首屏、滚动后 appbar 标题/头像/节点显示、返回与刷新状态。

4. `ReplyComposer` 纯 UI/helper 收口。
   - 目标：整理 toolbar command metadata、链接/图片/格式模板 helper 等无提交副作用重复逻辑。
   - 边界：不移动 `submitReplyWithCookie`，不改变草稿保存节流、确认弹窗和成功后关闭/返回流程。
   - 验证重点：sheet 和独立回复页 toolbar、预览切换、草稿恢复、清空草稿确认。

### 7.2 中风险，单 lane 推进并强制 review + 实机 QA

1. Search settings/history I/O adapter。
   - 风险：会影响用户本地搜索历史、来源偏好和筛选持久化。
   - 要求：一批只移动一个 I/O 面；QA 前后记录关键设置状态，避免把清空历史作为默认验证步骤。

2. Search node/cache/local loading coordinator。
   - 风险：会影响本地搜索数据来源、缓存加载顺序和空态文案。
   - 要求：先锁定本地集合、节点库和缓存 fallback 语义，再拆加载协调器。

3. TopicDetail moderation preflight。
   - 风险：ignore/report 属于账号级副作用，哪怕只拆 preflight 也容易误触真实执行。
   - 要求：只覆盖确认/取消、未登录、action 缺失等非提交路径；真实执行必须单独确认。

### 7.3 高风险，执行前必须再确认

1. ReplyComposer 真实提交执行器：涉及发帖/回复账号状态和铜币消耗提示。
2. Topic/reply ignore、report 真实执行：涉及账号内容治理状态，副作用不可轻易回滚。
3. 登录、2FA、session、cookie、账号设置相关重构：涉及凭据、安全和设备登录态。
4. `MarkdownContent` 渲染合同重构：影响全局内容展示、链接跳转、图片/代码块等高频路径。

### 7.4 每个代码 lane 的固定 gate

1. `git diff --check`。
2. `bash dev.sh --build-only`。
3. 只读 review：检查 diff、构建日志、语义边界和静态风险。
4. 实机 QA：使用共享设备 `192.168.50.237:12345`，产出 `.hermes-artifacts/<yyyymmdd-HHMM>-<lane>-qa/` 证据和 result JSON。
5. commit：按 Conventional Commit 写清 `Why`、`What changed`、`Validation`。

破坏性或账号副作用路径的 QA 默认只覆盖确认/取消、未登录、action 缺失或其他非提交路径；真实执行必须先有明确授权。

### 7.5 推荐下一步

下一批优先做 `SearchPage` history/source mode 协调。它紧接当前 Search 拆分，账号副作用低，且可沿用已有搜索路由和 SOV2EX 实机 QA 路径。完成后再进入 filter/apply 状态瘦身；若过程中发现历史 I/O 必须移动，则拆成单独 lane，不和 source mode 合并。

### 2026-05-18 Lane 8 第三批

状态：PASS

范围：

- 拆 `SearchPage` history/source mode 决策协调逻辑。
- 移动历史展示判断、历史选择决策、主搜索动作决策、刷新动作决策、来源切换后的下一步决策。
- 不移动 `SearchSettings` I/O、SOV2EX 网络请求、外部浏览器打开、页面路由和状态字段归属。
- 修复保存来源为 SOV2EX 时，外部搜索路由 query 先于异步 sourceMode 加载被消费后停留在 `SOV2EX 0` 的初始化竞态。

变更：

- 新增 `SearchSourceCoordinator`，集中 history/source mode 的纯决策和 effect 计算。
- `SearchPage` 继续负责状态赋值、历史持久化、远端搜索执行、外部浏览器启动和本地 filter 执行。
- `loadSourceMode` 在加载到远端来源且当前已有 keyword 时，通过 coordinator effect 触发页面执行 `executeRemoteSearch(true)`。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0252-search-source-coordinator-qa/`。
- 实机路径覆盖：保存来源为 SOV2EX 时打开 `https://www.v2ex.com/search?q=apple` -> 首屏直接显示 `SOV2EX 62140` -> 切回本地显示 `主题结果 20` -> 清空关键词后历史区显示 `apple`。

后续入口：

1. 下一批继续 `SearchPage` filter/apply 状态瘦身，重点拆筛选草稿、已应用筛选、reset/pagination 判断。
2. 仍不移动 `SearchSettings` I/O；如果必须移动历史或来源持久化，单独开中风险 lane。

### 2026-05-18 Lane 8 第四批

状态：PASS

范围：

- 拆 `SearchPage` 本地和远端筛选 effect 决策。
- 移动本地 result filter 变更判断、远端 sort/order/text/date/clear 的 reset 和 execute 决策。
- 不移动 SOV2EX 请求执行、filter sheet 显隐、`SearchSettings` I/O、远端请求参数构建和响应合并。
- 保留远端筛选语义：sort 每次点击 reset 但不立即搜索；order/text reset 但不立即搜索；date range 变更立即搜索；重复 date range 不动作；clear reset 并搜索；apply 搜索并关闭 sheet。

变更：

- 新增 `SearchFilterCoordinator`，集中本地 result filter 和远端 filter effect。
- `SearchPage` 新增 `applyRemoteFilterEffect`，页面继续负责实际状态赋值、reset 和 `executeRemoteSearch(true)`。
- `RemoteSearchFilterSheetContent` 回调改为通过 coordinator effect 驱动页面动作。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0258-search-filter-coordinator-qa/`。
- 实机路径覆盖：`https://www.v2ex.com/search?q=apple` -> SOV2EX `62140` -> 打开远端筛选 sheet -> 选择 `一周` 后立即变为 `SOV2EX 73` 且出现 `清除` -> 点击 `清除` 后回到 `SOV2EX 62140` -> 点击 `应用搜索` 后 sheet 关闭。

后续入口：

1. `SearchPage` 的低风险拆分已完成到 source/history 与 filter/effect；后续若继续 Search，应进入中风险的 settings/history I/O adapter 或 node/cache/local loading coordinator。
2. 下一批建议转到 `TopicDetailPage` 非写操作瘦身，避免继续扩大 Search I/O 面。

### 2026-05-18 Lane 7 第十批

状态：PASS

范围：

- 拆 `TopicDetailPage` appbar identity 纯展示协调逻辑。
- 移动标题区域可见性判断、hysteresis 决策、route key、appbar title/avatar/username 取值和 StorageLink JSON state 更新 helper。
- 不移动滚动执行、详情加载、回复加载、感谢/收藏/忽略/举报/回复提交等任何写操作或副作用。

变更：

- 新增 `TopicDetailAppbarCoordinator`。
- `TopicDetailPage` 继续负责实际 StorageLink 字段赋值和 publish 时机，coordinator 只返回纯计算结果。
- 保留无 topic 或 titleContentBottom 未就绪时 publish false 的原语义。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0303-topic-detail-appbar-coordinator-qa/`。
- 实机路径覆盖：打开 `https://www.v2ex.com/t/1` -> 首屏显示作者 `Livid`、节点 `Project Babel`、标题 `♥ Introducing Project Babel 2.0` -> 向下滚动后 appbar 显示主题标题 identity，正文仍正常滚动显示。

后续入口：

1. `TopicDetailPage` 非写操作还可继续拆顶部按钮展示条件或回复显示菜单纯文案/选项构建。
2. 写操作和 moderation 仍不进入自主 lane；真实执行必须另行确认。

### 2026-05-18 Lane 7 第十一批

状态：PASS

范围：

- 拆 `ReplyComposerSheet` 和 `ReplyEditorPage` 的 Markdown toolbar 命令分发。
- 移动 bold、italic、code、quote、list、link、image 的纯插入决策。
- 不移动提交执行、提交前确认、草稿 I/O、关闭保存、登录态判断或真实回复接口。

变更：

- 扩展 `ReplyComposerCoordinator`，新增 `ReplyComposerToolbarCommand` 和 `applyToolbarCommand`。
- `ReplyComposerSheet` 与 `ReplyEditorPage` 通过同一个 toolbar command helper 应用编辑结果。
- 保留插入后 `isPreview = false`、节流保存草稿、异步恢复 caret 的原执行时序。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0308-reply-composer-toolbar-command-qa/`。
- 实机路径覆盖：`https://www.v2ex.com/go/apple` -> 第一条主题详情 -> 打开回复 sheet -> 清理旧草稿 -> 输入 `clean_toolbar_qa` -> 点击 bold 插入 `**文字**` -> 点击 link 插入 `[文字](https://)` -> 点击 image 插入 `![图片](https://)` -> 清空草稿后 TextArea 为空；全程未提交回复。

后续入口：

1. `ReplyComposer` 的可自主低风险项基本收口；真实提交执行器仍属于高副作用路径，暂不移动。
2. 下一批可转向 `TopicDetailPage` 顶部按钮展示条件或回复显示菜单纯文案/选项构建。

### 2026-05-18 Lane 7 第十二批

状态：PASS

范围：

- 拆 `TopicDetailReplyDivider` 和 `TopicDetailPage` 的回复显示纯展示决策。
- 移动回复显示模式菜单 option 列表、回复数量文案和当前模式文案 helper。
- 不移动显示模式保存、thread 预加载、滚动跳转、回复加载或任何写操作。

变更：

- 新增 `TopicDetailReplyDisplayCoordinator`。
- `TopicDetailReplyDivider` 通过 coordinator option 列表渲染菜单项，仍由组件负责 checkmark 和点击回调。
- `TopicDetailPage` 通过 coordinator 生成回复数量文案和模式文案，`updateReplyDisplayMode` 的保存/预加载语义不变。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0315-topic-reply-display-coordinator-qa/`。
- 实机路径覆盖：打开 `https://www.v2ex.com/t/1` -> 滚动到回复分隔栏 -> 显示 `共 174 条回复`、`楼层`、`楼中楼`、`最新` -> 打开显示模式菜单，选项顺序为 `楼中楼`、`楼中楼(@)`、`冗余楼中楼`、`只看楼主`、`原版` -> 选择 `原版` 后 chip 更新为 `原版` -> 再选回 `楼中楼`。

后续入口：

1. `TopicDetailPage` 还可继续抽回复正文显示判定、楼层/mention 文案等纯 helper。
2. 真实 topic/reply moderation、ignore/report、submit 仍属于高副作用路径，继续跳过自主重构。

### 2026-05-18 Lane 7 第十三批

状态：PASS

范围：

- 继续拆 `TopicDetailPage` 回复显示纯 helper。
- 移动楼中楼隐藏 mention 正文选择、楼层 fallback、回复 mention 文案生成。
- 不移动滚动执行、回复加载、回复编辑 sheet、草稿 I/O、提交或任何写操作。

变更：

- 扩展 `TopicDetailReplyDisplayCoordinator`，新增 `displayContent`、`floorForReply`、`mentionText`。
- `TopicDetailPage` 保留薄包装，继续提供 `v.getReplyFloor`、当前 `replyDisplayMode` 和 reply/member 数据。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0322-topic-reply-display-content-qa/`。
- 实机路径覆盖：打开 `https://www.v2ex.com/t/1` -> 滚动到回复区 -> 显示 `共 174 条回复`、`#1`、`#2` 和回复正文 -> 点击回复动作打开回复 sheet，TextArea 自动填入 `@Jay #1 ` -> 清空草稿后 TextArea 为空；全程未提交回复。

后续入口：

1. `TopicDetailPage` 低风险纯 helper 还剩 topic body/supplement markdown 分块、reply context title/snippet 等展示逻辑。
2. 真实写操作和 moderation 继续保留在高风险清单，不做自主移动。

### 2026-05-18 Lane 7 第十四批

状态：PASS

范围：

- 继续拆 `TopicDetailPage` 主题正文、补充内容和回复上下文纯展示 helper。
- 移动 topic body/source 分块、topic supplement meta/body 分块、reply context title/snippet 文案生成。
- 不移动 `MarkdownContent` 渲染实现、链接/图片/mention 点击回调、滚动、回复加载、菜单动作或任何写操作。

变更：

- 新增 `TopicDetailContentCoordinator`，承接主题正文与补充内容分块逻辑。
- 扩展 `ReplyContextCoordinator`，新增 `title` 和 `snippet`。
- `TopicDetailPage` 保留 UI 组装、导航回调和真实副作用，只通过 helper 取得展示数据。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 只读 review：PASS。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-0405-topic-detail-content-coordinator-qa/`。
- 实机路径覆盖：打开 `https://www.v2ex.com/t/1212580` -> 首屏主题标题/正文与回复列表正常显示 -> 打开回复菜单 -> 点击 `查看上下文` -> sheet 显示 `#1 回复上下文`、当前回复和下文摘要。

后续入口：

1. `TopicDetailPage` 低风险纯展示拆分基本收口；下一步可转向顶部按钮展示条件的纯 helper 或其他页面组件收口。
2. 真实写操作、moderation、ignore/report、submit 和 `MarkdownContent` 渲染合同仍保留在高风险清单，不做自主移动。

### 2026-05-18 Lane 9 第一批

状态：PASS

范围：

- 依次推进五个低到中风险 UI 组件重构点：`DiscoverPage`、`NotificationPage`、`UserProfilePage`、`Index` 标题栏、`AccountPage`。
- 只移动纯展示、纯状态判断和路由参数/helper 逻辑。
- 不移动真实删除通知、关注/屏蔽、登录、2FA、清授权、签到、网络请求执行或账号副作用。

变更：

- 新增 `DiscoverPageCoordinator`，集中发现页 topic mode 文案、当前列表选择、刷新清空 bucket、最近浏览节点去重。
- 新增 `NotificationPageCoordinator`，集中通知卡片展示 props、通知点击路由参数、可见刷新判断和缓存 owner key。
- 新增 `UserProfilePageCoordinator`，集中用户页 tab 文案、全部活动入口、appbar title 可见性、StorageLink JSON 合并和 action menu 状态。
- 新增 `IndexTitleBarCoordinator`，集中主 shell 标题栏空菜单、菜单计数、用户页 title identity 解析和节点标题文案。
- 新增 `AccountPageCoordinator`，集中账号 identity、账号 meta 文案、签到按钮状态、token 字段和 rate-limit snapshot 判断。

验证：

- 每个拆分阶段均执行 `git diff --check` 和 `bash dev.sh --build-only`；最终 build 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-1050-ui-refactor-12345-qa/`。
- 实机路径覆盖：发现页显示最近浏览节点和热议列表；通知页显示缓存通知列表与来源/分类摘要；我的页显示账号卡片、账号内容和本地内容入口；我的页标题菜单可进入设置页。
- 用户页深链 `https://www.v2ex.com/member/Livid` 可进入路由，但当前设备网络/API 返回 `HTTP 403`，本批只记录错误态不崩；未把该网络受限路径作为完整用户页视觉 PASS 依据。

后续入口：

1. 可继续做 `NotificationPage` cache/load coordinator 或 Account 本地内容加载 coordinator，但需要保持 I/O 单独 lane。
2. 用户页真实关注/屏蔽、账号登录/2FA/签到、通知删除仍属于副作用路径，不做自主移动。

### 2026-05-18 高优先级技术债第一批

状态：PASS

范围：

- 收口网络重试策略、网页回复分页客户端、楼中楼线程构建协调器和调试包名脚本。
- 保持现有 API 调用语义、回复显示语义、账号清理入口和 debug 设备 QA 流程。
- 不移动真实写操作执行，不改变 release 上架包名目标。

变更：

- 新增 `HttpRetryPolicy`，集中 GET 重试判断、HTTP 状态错误和 JSON parse 错误，避免对非 GET 或 JSON parse 失败进行无意义重试。
- 新增 `V2exTopicWebRepliesClient`，从 `ApiService` 中抽离主题网页回复分页、全量合并和补充内容提取。
- 新增 `ReplyThreadCoordinator`，从 `DetailViewModel` 中抽离楼中楼回复构建、mention/floor 解析、隐藏前置 mention 和 renderKey 生成；保留此前段落内前置 mention stripping 修复。
- `CookieJarSettings` 增加按 baseUrl 清理当前域 cookie，并同步过期 WebView cookie；账号页、通知页和登录页改为清理当前域。
- `AppScope/app.json5` 默认恢复 debug 包名 `com.next2v.app`；`dev.sh --release-build-only` 构建期间临时切换到上架包名 `com.honjow.next2v`，退出时恢复 debug 包名。

验证：

- `git diff --check` 通过。
- `bash -n dev.sh` 通过。
- `node scripts/test_topic_web_replies_parser.mjs` 通过。
- `node scripts/test_network_retry_security_static.mjs` 通过。
- `node scripts/test_v2ex_rendered_html_tokens.mjs` 通过。
- `node scripts/test_render_ast_contract.mjs` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-1726-tech-debt-refactor-qa/`。
- 实机路径覆盖：`https://www.v2ex.com/t/1212580` -> 切换 `楼中楼` -> 验证楼中楼嵌套回复和竖线；`https://www.v2ex.com/t/1213489#reply35` -> 验证 `support@v2ex.com` 正常渲染。

后续入口：

1. 若继续网络技术债，下一批应单独处理 `ApiService` 写操作请求 helper 的异常边界和测试，不和 UI lane 混合。
2. 若继续详情页重构，优先做非写操作 helper；真实 ignore/report/submit 继续保持高风险确认项。

### 2026-05-18 Lane 9 第二批

状态：PASS

范围：

- 拆 `NotificationPage` 通知缓存 I/O adapter。
- 只移动 ownerKey 决策、`NotificationSettings.loadCache/saveCache` 调用和缓存结果包装。
- 不移动通知网络加载、删除通知、通知点击路由、AuthSettings/CookieJarSettings 加载和会话失效清理。

变更：

- 新增 `NotificationCacheCoordinator`，集中通知缓存 load/save 的 ownerKey 解析、跳过条件和结果结构。
- `NotificationPage` 继续负责页面状态字段赋值、通知列表网络加载、分页、删除确认和 toast。
- 页面移除对 `NotificationSettings` 的直接依赖。

验证：

- `git diff --check` 通过。
- `node scripts/test_network_retry_security_static.mjs` 通过。
- `node scripts/test_topic_web_replies_parser.mjs` 通过。
- `node scripts/test_v2ex_rendered_html_tokens.mjs` 通过。
- `node scripts/test_render_ast_contract.mjs` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-1733-notification-cache-coordinator-qa/`。
- 实机路径覆盖：首页 -> 通知页；通知页显示 `100 条通知`、`来源: Web 会话` 和通知列表。

后续入口：

1. `NotificationPage` 剩余可拆项是网络加载状态机，但会触及分页和错误处理，应单独 lane。
2. 更低风险的下一步可转到 Account 本地内容加载 coordinator，继续保持 I/O 与副作用边界清晰。

### 2026-05-18 Lane 9 第三批

状态：PASS

范围：

- 拆 `AccountPage` 本地内容加载 adapter。
- 只移动 `CollectionSettings` 的本地内容读取、计数包装和 read-state sync 调用。
- 不移动登录、2FA、签到、清授权、账号 meta 网络请求和页面导航。

变更：

- 新增 `AccountLocalContentCoordinator`，集中 `loadSavedTopics/loadSavedNodes/loadViewedTopics/loadLocalContentStats/syncTopicReadStates`。
- `AccountPage` 继续保留页面状态赋值、错误日志、requestId 防旧 stats 覆盖和导航行为。
- 保持原先四条本地内容加载仍独立触发，避免某一路失败影响其他本地内容展示。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-1738-account-local-content-coordinator-qa/`。
- 实机路径覆盖：首页 -> 我的页 -> 本地内容；显示 `最近浏览 20`、`稍后读 0`、`本地关注节点 0`。

后续入口：

1. 可继续做 `AccountPage` 账号 meta 网络加载 coordinator，但它会触及 cookie/2FA/签到相邻状态，应单独 lane。
2. 更低风险的下一步可转到 `Index`/标题栏剩余纯展示 helper 或其他页面本地状态 helper。

### 2026-05-18 Lane 9 第四批

状态：PASS

范围：

- 拆 `ImagePreviewPage` 图片预览纯 helper。
- 只移动缩放 clamp、图片宽度计算、标题栏保存命令解析和响应 header 取值。
- 不移动图片下载、临时文件写入、图库保存、toast 和权限/系统弹窗流程。

变更：

- 新增 `ImagePreviewCoordinator`，集中图片预览纯决策逻辑。
- `ImagePreviewPage` 继续负责页面状态、手势更新、HTTP 下载、文件 I/O、图库写入和保存进度提示。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-1742-image-preview-coordinator-qa/`。
- 实机路径覆盖：打开 `https://www.v2ex.com/t/1048464` -> 点击帖子内图片 -> 进入黑底图片预览页；预览页显示图片和保存按钮。

后续入口：

1. `ImagePreviewPage` 剩余下载/保存流程属于系统图库和文件副作用，不做自主移动。
2. 下一步继续找纯展示 helper；账号 meta、通知网络、真实写操作仍按单独中高风险 lane 处理。

### 2026-05-18 Lane 9 第五批

状态：PASS

范围：

- 拆 `Index` 全局命令格式和 V2EX route 参数转换。
- 只移动 AppStorage 命令字符串拼装、带时间戳命令 payload 提取、route 到页面参数的纯转换。
- 不移动 `AppStorage` 写入、`NavPathStack` 导航、系统浏览器启动、标题栏 UI 构造和页面生命周期。

变更：

- 新增 `IndexRouteCoordinator`，集中 `topic/node/profile/search/web/login/image/notification` 等全局命令格式。
- `Index` 继续负责实际写入 StorageKey、清空 pending URL、push 页面和打开系统浏览器。
- deep link 路由的 topic/member/node/search 参数构造从页面方法中移出，降低 `Index.ets` 的副作用和格式规则混杂。
- 修正 debug 构建包名脚本：仓库默认保持上架包名 `com.honjow.next2v`，debug 构建时切到 `com.next2v.app`；release 构建仍使用 `com.honjow.next2v` 并恢复。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过；构建后 `AppScope/app.json5` 恢复为默认 `com.honjow.next2v`。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-1812-index-route-coordinator-qa/`。
- 实机路径覆盖：`https://www.v2ex.com/t/1212580` 进入帖子页；`https://www.v2ex.com/search?q=ArkTS` 进入搜索页并填入 `ArkTS`；`https://www.v2ex.com/go/programmer` 进入 `programmer` 节点页。
- 包名验证：`bash dev.sh --no-build -d 192.168.50.237:12345` 安装成功；`bm dump -n com.next2v.app` 显示设备安装包名为 `com.next2v.app` 且 `debug: true`。

后续入口：

1. `Index` 剩余可拆项主要是标题栏菜单构造和 `pm()` 导航目的地构造，但这会触及 HDS title/nav UI，建议单独 lane。
2. `--no-build` 仍只签名当前已有产物；若刚做过 release 构建，应先跑 debug build，避免沿用 release 产物。

### 2026-05-18 Lane 9 第六批

状态：PASS

范围：

- 拆 `SettingsPage` 纯展示规则。
- 拆 `Index` 固定标题栏菜单描述符。
- 不移动设置保存、cookie/web cookie 同步、导航栈 push、搜索筛选状态、通知刷新和图片保存等副作用。

变更：

- 新增 `SettingsPageCoordinator`，集中设置页菜单选项、Base64 文案、API 域名文案、缓存 subtitle 和菜单打开延迟。
- `SettingsPage` 继续负责 Preferences 保存、状态赋值、页面导航和 `MotionHandStateService` 应用。
- `IndexTitleBarCoordinator` 新增固定菜单 descriptor；`Index` 继续负责 `$r` 图标映射和真实 action 执行。
- 保留不同 `save` 动作的图标差异：网页登录使用确认图标，图片预览使用下载图标。

验证：

- `git diff --check` 通过。
- `bash dev.sh --build-only` 通过。
- 已安装到 `192.168.50.237:12345` 并完成实机 QA。
- 证据目录：`.hermes-artifacts/20260518-1828-settings-index-menu-refactor-qa/`。
- 实机路径覆盖：首页 -> 我的 -> 顶栏设置按钮 -> 设置页，设置页显示 `主题`、`Base64 解码`、`点击查看`、`阅读字体设置` 等文案；`https://www.v2ex.com/search?q=ArkTS` -> 顶栏筛选按钮 -> `搜索筛选` 面板，显示本地结果类型筛选项。

后续入口：

1. `Index.pm()` 导航目的地大分支仍重，但继续拆会直接触及所有页面构造和 titleBar 绑定，应单独较大 lane。
2. `SearchPage` 剩余可拆项已接近请求/筛选时序边界；如继续，应专项处理远端搜索状态机。
3. `SettingsPage` 的保存副作用可后续抽 adapter，但会触及 Preferences 写入和 cookie 恢复，不再作为低风险自主项。
