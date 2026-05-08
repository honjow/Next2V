# Codex 静态分析发现汇总

更新时间：2026-05-08 11:38 CST  
来源：两个循环静态分析 Codex 会话

- Agent A：`codex-next2v-static-a`，侧重网络、认证、状态、缓存、安全、稳定性。
- Agent B：`codex-next2v-static-b`，侧重页面、组件、UI/UX、导航、交互状态、待实现功能。

说明：本文档记录“候选问题/待实现功能”，用于避免长跑日志遗失。多数条目仍需真机、mock、抓包或截图验证，不应直接当成已确认线上 bug。

## 快速索引

### P1

- 网络层对所有失败类型统一重试，可能放大 4xx、429、解析错误和写操作副作用。
- Cookie 清理是全域清空，可能误删另一个域名的登录态。
- PAT/Cookie 存在 Preferences 中，缺少安全存储边界。
- 搜索承诺“主题、节点、用户”，但“用户”筛选没有独立用户结果模型。
- PullRefreshListScaffold 的刷新回调 reject 时可能无法复位刷新状态。

### P2

- 缓存缺少 TTL、总量上限和陈旧数据标记，详情缓存可能膨胀。
- 域名设置先改运行态再持久化，保存失败会造成当前进程和下次启动状态不一致。
- URL query 参数拼接未统一 encode，特殊字符用户名/节点名可能破坏请求。
- HTML 操作链接若允许绝对 URL，带 Cookie 请求可能有外域泄露风险。
- 批量主题详情聚合使用 Promise.all，单个失败可能拖垮整批列表。
- 通知分页 hasMore 只按数量判断，缺少服务端/HTML 分页证据。
- 首页自定义节点为空列表时可能显示 loading/error 混合态而非空态。
- 通知中无 topicId / 系统通知点击可能无反馈。
- 设置页多项看起来可配置但没有 action 或说明。
- 搜索筛选 sheet 的“应用/取消”边界不清，编辑中可能已经改变结果。
- 搜索页新装/清空历史时空白，缺少引导态。
- 通知 tab 冷启动可能短暂闪现未登录态。
- 账号页签到按钮嵌套在可点击账号 Row 中，可能触发交互冲突。

---

## Agent A：网络 / 认证 / 数据流 / 缓存 / 安全

### A1. P1：网络层会重试所有失败类型

**文件/符号**

- `shared/src/main/ets/network/HttpClient.ets`
  - `request`
  - `requestText`
- `shared/src/main/ets/network/ApiV2Service.ets`
  - `request`

**白帽事实**

- HTTP 非 2xx、JSON parse 失败、网络异常都会进入统一 `catch`。
- 只要 `retryCount > 0`，就按退避策略重试。
- `ApiV2Service` 对 `POST/DELETE`、401/403/404/429/5xx 使用相同重试逻辑。

**黑帽风险**

- 401/403/404 通常不应重试。
- 429 应尊重 rate limit，而不是继续消耗配额。
- `DELETE` 或未来 `POST` 如果服务端已执行但响应异常，重复请求可能产生副作用。
- JSON 结构变更会被包装成网络错误，延迟暴露真实问题。

**建议验证**

- mock HTTP 返回 401、404、429、500、非法 JSON，统计实际请求次数。
- 对 `deleteNotification` 模拟第一次响应丢失，观察是否重复 DELETE。

**绿帽最小方案**

- 引入错误分类：认证/权限/404/解析错误不重试。
- 对 429 单独处理；写操作默认不自动重试，除非明确幂等。

### A2. P1：Cookie 清理是全域清空

**文件/符号**

- `shared/src/main/ets/settings/CookieJarSettings.ets`
  - `clear`
  - `getCurrentCookie`
  - `getCookieForBaseUrl`

**白帽事实**

- Cookie 存储区分 `cookieCom` / `cookieCo`。
- `clear()` 同时删除两者，并调用 `clearAllCookies()`。
- Account / Notification 等页面的会话失效处理会调用 `CookieJarSettings.clear(context)`。

**黑帽风险**

- 用户可能只有当前域名的登录态失效，但另一个域名仍有效。
- 当前实现可能导致切回另一个域时也被退出登录。

**建议验证**

- 分别为 `.com` 和 `.co` 保存不同 Cookie。
- 在其中一个域触发“Web 会话已失效”。
- 切回另一个域，检查 `AUTH_COOKIE_CONFIGURED` 和实际请求 Cookie。

**绿帽最小方案**

- 增加按域清理方法，例如 `clearForBaseUrl`。
- 会话失效只清当前域；用户明确退出登录时再全域清理。

### A3. P1：PAT/Cookie 存储缺少安全边界

**文件/符号**

- `shared/src/main/ets/settings/AuthSettings.ets`
  - `saveToken`
- `shared/src/main/ets/settings/CookieJarSettings.ets`
  - `saveForBaseUrl`

**白帽事实**

- `personalAccessToken`、`cookieCom`、`cookieCo` 使用 Preferences 键值存储。
- 这些值是长期登录凭据。

**黑帽风险**

- 普通 Preferences 更适合低敏配置。
- 设备备份、调试、崩溃采集或沙盒文件读取如果暴露 Preferences，会扩大凭据泄露影响。

**建议验证**

- 检查 HarmonyOS NEXT 是否可用 KeyStore / 加密偏好。
- 登录后在调试环境定位 preferences 文件，确认 token/cookie 是否可直接读出。

**绿帽最小方案**

- 先抽象凭据存储接口，再迁移到底层安全存储。
- 对日志和调试输出做凭据脱敏审查。

### A4. P2：缓存缺少 TTL 和总量上限

**文件/符号**

- `shared/src/main/ets/settings/CacheSettings.ets`
  - `saveTopicList`
  - `saveTopicDetail`
  - `loadKeyIndex`
  - `loadTopicDetail`
- `FeedViewModel.ets` 相关缓存读取路径

**白帽事实**

- 列表每个 key 只截断 50 条。
- `cacheKey` 数量和 `topicDetails` 数量没有总量上限。
- 详情写入 `cachedAt`，读取时没有过期判断。
- 清理依赖 index；如果 index 损坏，可能留下孤儿缓存。

**黑帽风险**

- 长期浏览大量主题后，Preferences 体积可能膨胀。
- 搜索/详情可能读取陈旧数据。
- 搜索页遍历缓存索引时可能变慢。

**建议验证**

- 连续打开大量 topic 后查看 `CacheSettings.loadStats()` 或 `next2v_cache` 体积。
- 模拟 30 天前 `cachedAt`，观察详情/搜索是否仍无提示使用。
- 损坏 `KEY_CACHE_INDEX` 后执行清理，观察是否残留孤儿键。

**绿帽最小方案**

- 加 TTL、LRU 或总量上限。
- 展示陈旧缓存时给 UI 标记。
- 增加 index 修复/全量清理兜底。

### A5. P2：域名设置保存失败时运行态和持久态可能分裂

**文件/符号**

- `shared/src/main/ets/settings/ApiDomainSettings.ets`
  - `save`
- `feature/settings/src/main/ets/pages/SettingsPage.ets`
  - `updateApiDomain`

**白帽事实**

- `ApiDomainSettings.save()` 先 `apply(useCoDomain)`，再写 Preferences。
- 设置页也会先设置 `HttpClient.baseUrl`，失败只 `console.error`。

**黑帽风险**

- Preferences 写失败时，本次运行已切域，重启后恢复旧域。
- UI 开关、`HttpClient.baseUrl`、Cookie 配置状态可能短期不一致。

**建议验证**

- mock `preferences.flushSync()` 抛错。
- 检查 UI 开关、`HttpClient.baseUrl`、重启后 `USE_CO_DOMAIN` 是否分裂。

**绿帽最小方案**

- 持久化成功后再 apply。
- 失败时回滚 UI 开关，并给用户可见提示。

### A6. P2：URL query 参数未统一 encode

**文件/符号**

- `shared/src/main/ets/network/ApiV2Service.ets`
  - 用户名、节点名、name 参数拼接路径

**白帽事实**

- 部分 endpoint 直接拼接 `username=${username}`、`node_name=${nodeName}`、`name=${name}`。
- 同文件中有些路径已使用 `encodeURIComponent`，说明编码策略不一致。

**黑帽风险**

- 用户名/节点名包含 `&`、空格、`#`、中文等字符时，可能改变请求语义。
- 后续复用网络层时容易引入隐藏 bug。

**建议验证**

- 传入 `foo&bar=baz`、`C++`、中文节点名，断言最终 endpoint 使用编码值。

**绿帽最小方案**

- 网络层集中提供 query builder 或统一 `encodeURIComponent`。

### A7. P2：HTML 操作链接若允许绝对 URL，可能带 Cookie 请求外域

**文件/符号**

- HTML action 解析路径
- `requestHtmlWithCookieAllowRedirect` 或相关带 Cookie 请求方法

**白帽事实**

- 如果 `pathOrUrl` 以 `http://` 或 `https://` 开头，可能直接使用。
- 请求会附带 Cookie。
- 操作链接来自 HTML 解析，当前隐含假设页面可信。

**黑帽风险**

- 页面内容被污染或解析误匹配时，可能把 Cookie 发往外域。

**建议验证**

- 构造含外域 `/thank`、`/ignore`、收藏/关注 action 的 HTML fixture。
- 抓包确认请求目标和 Cookie 发送行为。

**绿帽最小方案**

- 带 Cookie 的 HTML 操作只允许同源或站内相对路径。
- 对绝对 URL 做 host 白名单校验。

### A8. P2：批量详情聚合可能被单个失败拖垮

**文件/符号**

- `ApiService` / 聚合 HTML 列表与 V2 topic detail 的路径

**白帽事实**

- 每批 `Promise.all(batch.map(...))` 只要一个主题详情接口失败，整批会失败。

**黑帽风险**

- 列表类功能通常应允许部分主题缺失。
- V2EX 页面上的主题可能被删除、隐藏或 API 临时异常。

**建议验证**

- mock 一批 10 个 ID，其中 1 个返回 404 或网络错误，观察 `getRecentTopics` 是否完全报错。

**绿帽最小方案**

- 改为 `Promise.allSettled` 或单项 catch 后过滤，并记录部分失败。

### A9. P2：通知分页 hasMore 判断过粗

**文件/符号**

- 通知分页加载逻辑

**白帽事实**

- `hasMore` 不读取服务端分页元信息，只按数量判断。

**黑帽风险**

- HTML 解析过滤、最后一页刚好等于 pageSize、页面不足固定 pageSize 等场景都可能导致“加载更多”状态错误。

**建议验证**

- 准备最后一页刚好等于 pageSize、解析过滤无 id 通知、空页三种 fixture，检查 `hasMore`。

**绿帽最小方案**

- 使用 HTML 分页证据或下一页链接判断。
- 没有可靠证据时降低“还有更多”的确定性。

---

## Agent B：页面 / UI / 交互 / 待实现功能

### B1. P1：搜索“用户”筛选没有独立用户结果模型

**文件/符号**

- `entry/src/main/ets/pages/SearchPage.ets`
  - 搜索框占位：“搜索主题、节点、用户”
  - `用户` 筛选
  - `resultFilter === 'users'`
  - `topicMatches` / `showNodeResults`

**白帽事实**

- UI 文案承诺可搜索主题、节点、用户。
- “用户”筛选存在。
- 当前实现把 `users` 归入主题结果，用 `item.username` 过滤主题。
- 没有独立 user result model，也没有用户卡片结果。

**红帽体验**

- 用户切到“用户”后预期看到用户列表和进入用户主页入口。
- 实际可能只看到“该用户相关主题”，语义不一致。

**建议验证**

- 搜索已浏览主题中的作者名。
- 切换“用户”筛选。
- 观察是否出现可点击用户卡片，点击是否进入 `UserProfile`。

**绿帽最小方案**

- 如果暂不实现用户搜索，把筛选文案改成“作者相关主题”。
- 如果要实现，增加独立用户结果模型和用户主页跳转。

### B2. P1：PullRefreshListScaffold 刷新失败可能无法复位

**文件/符号**

- `PullRefreshListScaffold`
  - `doRefresh`
  - `onPullEnd`
  - `refreshState`
  - `pullOffset`

**白帽事实**

- `doRefresh()` 直接 `await this.onRefresh()`，没有 `try/finally`。
- `onPullEnd()` 已将 `refreshState` 置为刷新中，并设置 `pullOffset`。

**黑帽风险**

- `onRefresh` reject 后，`refreshState = 3` 和 `bounceBack(0)` 可能不执行。
- 页面可能卡在刷新态或顶部偏移状态。

**建议验证**

- 用断网/代理或测试页面让 `onRefresh` reject。
- 在详情页、通知页、首页列表下拉刷新后观察刷新圈和布局是否复位。

**绿帽最小方案**

- `doRefresh` 使用 `try/catch/finally` 确保刷新态复位。
- 错误通过回调或 toast 统一暴露。

### B3. P2：首页自定义节点空列表可能显示 loading/error 混合态

**文件/符号**

- `FeedViewModel.loadData()`
- 首页 Tab / 自定义 `node:<name>` 栏目
- `ApiService.getTabTopics()` / `getTopicsByNode()`

**白帽事实**

- `loadData()` 成功返回 `[]` 后：`isLoading=false`、`errorMessage=''`。
- UI 主要用 `dataSource.totalCount() > 0` 判断是否展示内容。
- 设置页允许添加 `node:<name>` 自定义栏目。

**黑帽风险**

- 合法但无主题的节点可能显示 loading/error 混合态，而不是明确空态。

**建议验证**

- 设置 -> 首页 -> 添加合法但不存在或无主题节点名，例如 `zzzz_unused_2026`。
- 回首页切到该栏目，截图顶部栏目和中间内容。

**绿帽最小方案**

- 区分 loading、error、empty 三态。
- 自定义节点无数据时展示明确空态和编辑入口。

### B4. P2：通知中无 topicId / 系统通知点击可能无反馈

**文件/符号**

- 通知页通知卡片点击逻辑
- 通知数据模型中的 `topicId`

**白帽事实**

- 部分系统通知或非主题通知可能没有 `topicId`。
- 当前点击逻辑可能依赖 topicId 导航。

**红帽体验**

- 用户点击通知卡片无反馈，会误以为应用卡死或点击区域失效。

**建议验证**

- 准备含系统通知/无 topicId 的通知数据。
- 打开通知页点击该卡片，观察是否无反馈、toast 或详情跳转。

**绿帽最小方案**

- 无 topicId 时显示 toast、展开原文，或跳转到通知对应 URL / WebView。

### B5. P2：通知删除弱网时 UI 反馈可能滞后

**文件/符号**

- 通知页左滑删除 / 确认删除逻辑
- V2 API 删除通知接口

**白帽事实**

- 删除确认后需要等待远端接口结果。

**红帽体验**

- 弱网时确认删除到 toast 前，用户可能感觉没有发生任何事情。

**建议验证**

- 弱网或代理延迟 V2 API 删除接口。
- 左滑通知并确认删除，观察确认后到 toast 前 UI 是否无变化。

**绿帽最小方案**

- 确认后立即进入 pending 状态、禁用重复操作。
- 成功后移除，失败后恢复并提示。

### B6. P2：设置页通知相关项看起来可配置但没有 action

**文件/符号**

- `feature/settings/src/main/ets/pages/SettingsPage.ets`
  - `通知同步`
  - `本地通知`
  - `安静时段`

**白帽事实**

- 多个配置语义的 `ConciseListRow` 为 `showChevron: false`，且没有 action。

**红帽体验**

- 用户会把这些看成设置入口，但点击无反馈。

**建议验证**

- 设置页点击“本地通知”“安静时段”等，确认是否无 toast、无弹窗、无权限请求。

**绿帽最小方案**

- 暂未实现时改成禁用说明或状态文本。
- 计划实现时接入权限请求、系统通知开关、安静时段编辑。

### B7. P2：设置页“账号管理”入口无 action

**文件/符号**

- `feature/settings/src/main/ets/pages/SettingsPage.ets`
  - `账号管理`

**白帽事实**

- 账号管理项 `showChevron: false` 且无 action。

**红帽体验**

- 设置页提供“账号管理”标题但没有实际导航，用户从深层页面返回设置时会感觉割裂。

**建议验证**

- 在设置页点击账号管理区域，确认是否无反馈。

**绿帽最小方案**

- 接入账号页/账号设置页跳转，或改为纯状态展示并移除入口语义。

### B8. P2：搜索筛选“应用/取消”边界不清

**文件/符号**

- `entry/src/main/ets/pages/SearchPage.ets`
  - filter sheet
  - `resetRemoteResults()`
  - `executeRemoteSearch(true)`

**白帽事实**

- UI 有“应用搜索”按钮。
- 多个筛选控件在编辑阶段就可能调用 `resetRemoteResults()` 或 `executeRemoteSearch(true)`。

**黑帽风险**

- 用户关闭 sheet 或未点击应用时，底层结果可能已经变化。
- 筛选编辑态和已应用态不清晰。

**建议验证**

- 搜索任意关键词取得结果。
- 打开筛选，依次点排序、输入作者、点“一周”，再点遮罩关闭。
- 录屏观察底层列表是否变化。

**绿帽最小方案**

- 使用 draft filter 与 applied filter 两套状态。
- 只有点击“应用”才触发远端搜索。

### B9. P2：搜索页新装/清空历史时缺少引导态

**文件/符号**

- `entry/src/main/ets/pages/SearchPage.ets`
  - `SearchResultSurface()`
  - `HistorySection()`

**白帽事实**

- 空关键词时只调用 `HistorySection()`。
- `HistorySection()` 又要求 `history.length > 0` 才渲染。

**红帽体验**

- 新装或清空历史后，搜索框下方可能大面积空白。

**建议验证**

- 清空搜索历史或新装启动。
- 进入搜索页，在 360x780、平板横屏下截图检查搜索框下方。

**绿帽最小方案**

- 无历史时展示轻量引导：可搜索主题、节点、用户；或展示热门节点/最近缓存。

### B10. P2：通知 tab 冷启动可能短暂闪现未登录态

**文件/符号**

- 通知页 / 首页通知 tab
- `hasNotificationAuth()`
- `AuthSettings.load()`

**白帽事实**

- `hasNotificationAuth()` 依赖 `authToken` 实值。
- 初始构建可能发生在 `AuthSettings.load()` 完成前。

**黑帽风险**

- 已登录 PAT 账号冷启动进入通知 tab 时，可能短暂显示未登录态。

**建议验证**

- 已登录 PAT 账号冷启动，立即切到通知 tab。
- 低端机/慢存储下录屏观察是否闪现未登录态。

**绿帽最小方案**

- 增加 auth loading 状态，加载完成前不显示未登录 CTA。

### B11. P2：账号页签到按钮嵌套在可点击 Row 中

**文件/符号**

- `entry/src/main/ets/pages/AccountPage.ets`
  - 签到 Button
  - 父 Row `.onClick` 推入 `Account` 详情

**白帽事实**

- 签到 Button 位于也带 `.onClick` 的父 Row 内。

**红帽体验**

- 用户点签到可能同时触发进入账号详情，交互意图冲突。

**建议验证**

- 在账号页点击签到按钮不同区域，录屏观察是否触发账号详情导航。

**绿帽最小方案**

- 拆分点击区域。
- 对签到按钮阻止父 Row 点击或移出父可点击区域。

### B12. P2：发帖草稿选择节点返回后可能不立即更新

**文件/符号**

- 发帖草稿页
- 节点选择页 / `create` 返回路径

**白帽事实**

- Codex B 报告：进入“我的 > 发帖草稿”，输入标题正文，点选择节点，选 `create`，返回后节点框可能不立即更新；重进草稿才更新。

**红帽体验**

- 用户会以为节点选择失败，或重复选择节点。

**建议验证**

- 真机/模拟器进入“我的 > 发帖草稿”。
- 输入标题正文，选择节点 `create`，返回后立即查看节点框。
- 再按返回重进草稿，对比是否才更新。

**绿帽最小方案**

- 节点选择返回时显式刷新草稿状态。
- 如果依赖持久化，返回页订阅/重新读取选中节点。

---

## 建议下一步

1. 先人工/设备验证 P1 项：网络重试、Cookie 全域清理、用户搜索、刷新失败复位。
2. 把 P2 中 UI 可见且易验证的项拆成小任务：设置项无 action、搜索空引导、通知无 topicId 点击、账号签到点击冲突。
3. 对网络/缓存/凭据类问题，先写单元或 mock 验证，再安排实现 Codex，避免凭静态推断直接大改。
4. 持续把后续 Codex 静态分析的新发现追加到本文档，避免日志滚动丢失。
