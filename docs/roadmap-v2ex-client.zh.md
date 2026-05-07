# V2Next 路线图与交接指南

本文档用于把 V2Next 的后续开发交给独立子线程执行。内容基于当前代码状态、最近完成的 UI/链接/用户页修改，以及对两个成熟 V2EX 客户端的功能对照：

- V2Fun: `https://github.com/liaoliao666/v2ex`
- VVEX / flutter_v2ex: `https://github.com/guozhigq/flutter_v2ex`
- ClashBox HarmonyOS 应用 master 分支：
  `https://github.com/xiaobaigroup/ClashBox/tree/master`
- HarmonyDO public HarmonyOS 应用：
  `https://github.com/Amaz1ny/HarmonyDO-public`
- V2EX 网页站点与当前项目中的 API v2 / Cookie HTML 适配器。

目标是完成一个可日常使用的 HarmonyOS NEXT 原生 V2EX 客户端。方向是：HDS 优先、界面简洁、严格避免破坏已完成能力。

## 硬性规则

1. 新 UI 和重构优先使用 Harmony Design System / `@kit.UIDesignKit` 组件与系统交互模式。
2. HDS 不可用或不合适时，在 `shared/src/main/ets/components/` 里创建或复用共享封装，不要在页面里散落一次性的按钮、输入框、弹窗、列表项、菜单样式。
3. UI 默认简洁。副标题和说明文字只有在表达状态、风险、数量、缓存新旧、隐藏行为时才保留。
4. V2EX 金币/银币/铜币必须保留原始单位语义。源文本是 `0.90 铜币` 时就显示为小数铜币，不要换算成 `90 铜币`。
5. 无人值守验证时不能自动执行付费、破坏性或账号状态变化操作，包括发帖、回复、感谢、忽略、举报、屏蔽、关注、收藏、签到、图片上传、置顶、Boost。
6. 写操作必须继续受全局写操作开关和二次确认保护。
7. 不提交账号、密码、Cookie、Token、截图、设备 dump、本地参考项目、临时测试产物。
8. 每个独立功能必须通过：
   - `bash dev.sh --build-only`
   - 安装到 `192.168.50.237:12345`
   - 受影响页面的设备交互验证
   - UI 改动需要截图检查
   - `git diff --check`
   - 人工审 diff
   - 准确提交说明

## 当前代码状态

核心页面与路由：

- `entry/src/main/ets/pages/Index.ets`
  - App 外壳、底部 Tab、路由注册。
  - 仍然承担过多职责：我的页、通知 UI、账号状态、本地列表。
  - 这是当前最大的架构债。
- `feature/feed/src/main/ets/pages/HomePage.ets`
  - 首页 Tab、Swiper 同步、主题列表、下拉刷新。
- `feature/node/src/main/ets/pages/DiscoverPage.ets`
  - 节点搜索、热议/热榜/最新/最近主题入口。
  - 仍是自定义页面布局，需要迁移到共享脚手架。
- `feature/detail/src/main/ets/pages/TopicDetailPage.ets`
  - 主题详情、回复、主题操作、阅读位置、筛选、图片。
- `feature/detail/src/main/ets/pages/ReplyEditorPage.ets`
  - 现有回复草稿/编辑路由。
  - 普通主题回复不应继续使用独立页面，应该从详情页打开贴靠键盘的悬浮回复组件。
- `entry/src/main/ets/pages/TopicEditorPage.ets`
  - 发帖草稿和编辑。
- `entry/src/main/ets/pages/SearchPage.ets`
  - 本地、节点、SOV2EX、网页搜索。
- `feature/user/src/main/ets/pages/UserProfilePage.ets`
  - 用户资料、主题/回复 Tab、关注/屏蔽、全部主题/全部回复入口。
- `feature/settings/src/main/ets/pages/SettingsPage.ets`
  - 设置和高级控制。

共享基础设施：

- `shared/src/main/ets/components/SecondaryListScaffold.ets`
  - 当前次级列表安全区脚手架。
- `shared/src/main/ets/components/SecondaryFormScaffold.ets`
  - 表单页脚手架。
- `shared/src/main/ets/components/AppSearchField.ets`
- `shared/src/main/ets/components/AppTextField.ets`
- `shared/src/main/ets/components/AppModalScaffold.ets`
- `shared/src/main/ets/components/AppActionButton.ets`
- `shared/src/main/ets/components/FilterChip.ets`
- `shared/src/main/ets/components/ConciseListRow.ets`
- `shared/src/main/ets/components/GroupedListSection.ets`
- `shared/src/main/ets/components/MarkdownContent.ets`
  - Markdown、可选文本、@ 用户、图片渲染。
  - 独立非图片链接现在是普通 inline 链接，不再是大卡片。
- `shared/src/main/ets/utils/MediaUrlUtils.ets`
  - 图片 URL 判断与媒体 URL 工具。
- `shared/src/main/ets/network/ApiService.ets`
  - V1/公开 API、HTML 解析、Cookie 账号/写入适配器。
- `shared/src/main/ets/network/ApiV2Service.ets`
  - PAT/API v2：member、token、notifications、node、topic、replies。
- `shared/src/main/ets/network/Sov2exService.ets`
  - SOV2EX 远程搜索。

已经实现且不能回退的能力：

- 公开 Tab 与首页分类内容。
- 首页左右滑切换和 Tab 指示器同步动画。
- 下拉刷新与列表滚动行为。
- 详情页阅读位置、上次阅读楼层、跳最新、跳楼层、只看楼主、最新/排序控制、回复上下文、文本选择、复制/分享/浏览器、稍后读、最近浏览。
- 当前回复筛选栏是可接受的紧凑形态，不要再把 `楼层 / 只看楼主 / 最新` 放大成重按钮。
- Markdown 图片、直接图片 URL、重试/加载、全屏预览、缩放、通过 appbar 保存图片。
- 非图片链接显示为普通可点击文本。
- Web 登录和账号密码登录原型。
- Cookie 会话验证和退出。
- 我的页账号块：头像、用户名、钱币图标、签到按钮。
- 每日任务状态和手动签到。
- 保留单位语义的余额解析。
- PAT 存储、验证、API v2 读取作为高级/调试能力。
- 通知列表分页、缓存、可支持的删除。
- 收藏主题、我的回复、收藏节点页面。
- Cookie 主题收藏和节点关注。
- 受保护的发帖/回复适配器和草稿。
- 用户页主题/回复 Tab、全部主题/全部回复页、关注/屏蔽即时 UI 更新。
- 本地搜索、节点搜索、缓存搜索、SOV2EX 和网页 fallback。

## 参考项目路径

参考项目应放在当前 repo 外，例如：

- `/tmp/v2next-reference/v2fun`
- `/tmp/v2next-reference/flutter_v2ex`

V2Fun 重点路径：

- `screens/HomeScreen.tsx`：动态首页 Tab、最近 Tab、节点 Tab。
- `screens/SortTabsScreen.tsx`：Tab 排序和自定义。
- `screens/SearchScreen.tsx`、`screens/SearchOptionsScreen.tsx`：SOV2EX 搜索和选项。
- `screens/HotestTopicsScreen.tsx`、`screens/RankScreen.tsx`、`screens/RecentTopicScreen.tsx`：发现页能力。
- `screens/MemberDetailScreen.tsx`：用户资料、主题/回复 Tab、关注/屏蔽。
- `screens/BlackListScreen.tsx`：屏蔽用户和忽略主题。
- `components/topic/TopicInfo.tsx`：收藏、感谢、忽略、举报、编辑、附言。
- `components/topic/ReplyItem.tsx`：感谢回复、忽略回复、相关回复、回复菜单。
- `screens/RelatedRepliesScreen.tsx`：相关回复/上下文。
- `components/UploadImageButton.tsx`、`screens/ImgurConfigScreen.tsx`、`servicies/other.ts`：Imgur 配置和上传。
- `servicies/helper.ts`：HTML 解析、图片 URL 转换、用户资料/钱币解析。
- `navigation/LinkingConfiguration.ts`、`app.json`：Scheme 和深链。

VVEX 重点路径：

- `lib/http/soV2ex.dart`：SOV2EX 参数和模型。
- `lib/http/dio_web.dart`：登录动态字段、验证码、2FA、感谢、忽略、签到、发帖/编辑/附言。
- `lib/http/user.dart`：用户资料、主题/回复、屏蔽、通知。
- `lib/pages/t/topic_id.dart`：详情页、通知楼层跳转、回复列表行为。
- `lib/components/message/notice_item.dart`、`lib/pages/page_message.dart`、`lib/service/local_notice.dart`：通知解析、删除、本地通知、跳转 payload。
- `lib/utils/upload.dart`：Imgur 上传。
- `lib/utils/app_scheme.dart`、Android `AndroidManifest.xml`：深链。
- `lib/utils/storage.dart`：链接打开方式、自动签到、通知、字号、Tab、楼主高亮、侧滑设置。

ClashBox master 重点路径：

- `entry/src/main/ets/pages/ConfigurationPage.ets`：悬浮新增按钮、`bindSheet` 生命周期、sheet dismiss 控制、sheet 内部路由。
- `entry/src/main/ets/common/entity/Constants.ets`：集中管理 sheet/list 尺寸常量，避免页面内散落 magic number。
- `entry/src/main/ets/components/Common/*`：可复用标题、sheet、按钮原语和圆形按钮模式。
- `entry/src/main/ets/common/breakpoint/BreakPoint.ets`：断点驱动的导航/列表边距和响应式常量。

HarmonyDO public 重点路径：

- `entry/src/main/ets/pages/Index.ets`：`HdsNavigation`、`HdsTabs`、悬浮 Tab 尺寸、HDS 动画模式协调。
- `entry/src/main/ets/views/components/ImmersiveHdsTitleBarHelper.ets`：沉浸式 HDS 标题栏、渐变模糊、状态栏文字颜色、顶部 spacer 约定。
- `entry/src/main/ets/views/pages/TopicDetailPage.ets`：底部 HDS action bar、悬浮回复按钮、多 sheet 宿主、回复 sheet 打开/关闭流程、回复/帖子菜单组织。
- `entry/src/main/ets/views/components/ReplyComposerSheet.ets`：sheet 式回复组件，包含草稿保存、预览、工具栏、图片上传 hook、文本选择。
- `entry/src/main/ets/views/pages/CategoryTopicPage.ets`、`BookmarksPage.ets`、`BrowsingHistoryPage.ets`：HDS 次级页、appbar 菜单、sheet 宿主放置、列表顶部避让和底部悬浮 Tab 避让。
- `entry/src/main/ets/common/constants/LayoutConstants.ets`：共享悬浮 Tab/action-bar 尺寸和内容 padding 常量。

参考项目只用于行为和架构对照，不要把外部 UI 风格或大段代码直接复制进 Harmony 项目。

## P0. 架构与 UI 基线

目标：停止页面级补丁式开发，让后续功能能稳定推进。

任务：

- 拆分 `entry/src/main/ets/pages/Index.ets`。
  - `Index.ets` 只保留路由注册、底部 Tab、全局状态、顶层 HDS title bar helper。
  - 我的页/账号 UI 移到 account feature 区域，例如 `feature/account/src/main/ets/...` 或项目内一致的模块位置。
  - 通知页和通知 view model 所有权移到 notification feature 区域。
  - 稍后读、最近浏览、关注节点页面移出 `Index.ets`。
- 升级共享脚手架。
  - 扩展 `SecondaryListScaffold` 或新增兼容的 HDS-first 页面脚手架，统一安全区、标题避让、列表边距、底部避让、loading、error、empty、appbar actions、下拉刷新、触底加载。
  - 保持沉浸光感正确：内容可以滚到标题模糊层下，但首个内容不能一开始就被标题栏盖住。
  - 不用页面外层 `Blank` 之类 hack 避让。
- 统一共享 UI 原语。
  - 列表项使用 `ConciseListRow`、`GroupedListSection` 或 HDS list item 封装。副标题默认没有。
  - 输入框使用 `AppSearchField` 或 `AppTextField`，不要页面内 raw `TextInput` 样式。
  - 同角色按钮/chip 保持同尺寸、同组件、同对齐。
  - Sheet 使用 `bindSheet` + `AppModalScaffold` 或 HDS/系统 sheet；返回键先关闭 sheet。
  - 页面操作和低频操作放 appbar 菜单或 `ContextMenu`。
  - 悬浮主操作：页面内最高频、反复使用的主操作，应使用底部悬浮按钮/action bar，并正确避让键盘、底部 Tab、手势安全区。不要把高频操作藏进 appbar 菜单。
- 迁移或复核这些页面：
  - Search
  - Settings
  - Login
  - WebLogin
  - TopicEditor
  - ReplyComposer sheet
  - UserProfile
  - NodeTopic
  - Discover
  - SavedTopics / ViewedTopics / SavedNodes
  - Notifications
  - 任何仍然自己绘制返回按钮的页面。
- 通知和节点相关页面在继续加功能前先纳入同一架构：
  - 通知必须由 notification feature module/view model 管理，不继续塞在 `Index.ets`。
  - 通知列表行、empty/loading/error、分页、删除、点击跳楼层，都使用共享列表脚手架。
  - 节点搜索、节点主题列表、全部节点导航、收藏节点状态、最近/常用节点，应共享同一 node feature 架构。
  - 节点和通知页面使用 appbar 菜单放次级操作，使用下拉刷新，列表/内容间距遵循共享规则。

验收标准：

- 截图覆盖 Home、Discover、Notifications、My、Settings、Search、Login、WebLogin、TopicDetail、TopicEditor、ReplyEditor、UserProfile、NodeTopic、稍后读、最近浏览、关注节点。
- 受影响页面没有内容被状态栏、标题栏、底部浮动 Tab、键盘、手势区遮挡。
- 同一行同角色控件高度、字号、形状、对齐一致。
- 页面内不新增 raw `TextInput`、伪按钮、自定义 sheet、新的一次性 row 样式。
- 详情页普通回复流程不再跳转到独立回复页面。

回归防线：

- 不改变当前紧凑回复筛选栏形态。
- 不恢复非图片链接大卡片。
- 不改余额解析，除非有测试证明源格式。

## P0. 媒体与图床处理

目标：让图片密集主题可读，同时不把普通链接变成重卡片。

当前状态：

- 明确图片后缀 URL 会显示图片。
- 已知直接图片 CDN 前缀会显示图片。
- 非图片链接显示为普通 inline 文本链接。
- 已有图片预览、保存、重试、加载偏好。

缺口：

- 图床页面链接没有可靠转直链。
- 模糊链接没有通过 `Content-Type` 探测图片类型。
- 没有 provider 规则表、测试样例、图床行为设置。
- 图片上传未实现。

任务：

- 重构 `MediaUrlUtils.ets`，引入明确的类型结果，例如：
  - `directImage`
  - `knownImageHostDirect`
  - `imageHostPageResolved`
  - `probeRequired`
  - `nonImageLink`
  - `unsupported`
- 直接图片规则优先：
  - 后缀：`.jpg`、`.jpeg`、`.png`、`.gif`、`.webp`、`.bmp`、`.svg`、`.avif`、`.heic`、`.heif`
  - query 扩展：`format`、`fm`、`ext`、`type`、`output`
  - 当前 `IMAGE_HOST_PREFIXES` 中的已知直接图片 host。
- 增加保守的图床页面规则：
  - `https://imgur.com/<id>` -> `https://i.imgur.com/<id>.png`，只处理单图 ID，不处理 `/a/` 或 `/gallery/` 相册。
  - `https://sm.ms/image/<id>`：只有能稳定派生或抓到直链时才转，否则保持普通链接。
  - `postimg.cc`、`ibb.co`、`imgbox.com`、`postimages.org`：只有实现确定直链规则或安全解析后再加入。
- 增加可选 HEAD / content-type 探测。
  - 只探测独立的 http/https 链接，不探测已知普通非图片链接。
  - 尽量遵守媒体偏好。
  - 设置超时，并按 normalized URL 缓存探测结果。
  - `Content-Type` 以 `image/` 开头时渲染图片。
  - 403/404/超时/非图片时保持普通链接，不显示错误块。
- 为 `MediaUrlUtils` 增加测试或小型确定性测试脚本，至少覆盖：
  - 直接图片后缀
  - 带 query 的图片后缀
  - `i.imgur.com/...jpg`
  - `imgur.com/<id>` 单图页
  - `imgur.com/a/<id>` 相册保持链接
  - `github.com/...` 普通链接保持链接
  - `raw.githubusercontent.com/...` 图片保持图片
  - 未知 URL 默认保持链接，除非 HEAD 证明是图片
- 更新 `MarkdownContent.ets`。
  - 图片候选继续走 `MarkdownAutoImage`。
  - 非图片链接保持可选、可点击文本。
  - 不创建大型链接预览卡片。
- 只有确实需要时才加设置项：
  - 自动加载图片
  - 仅 Wi-Fi 加载图片
  - content-type 探测开关

验收标准：

- 构建、安装、设备验证一个包含以下内容的主题：
  - 直接图片链接
  - Imgur 单图页链接
  - GitHub 普通链接
  - 至少一个不支持的图床页面链接
- 直接图片显示为图片块。
- Imgur 单图页只有在正确转换后才显示为图片。
- 相册/不支持链接保持普通文本链接。
- 不恢复灰色大链接卡片。
- 图片加载指示器仍居中。
- 全屏预览和保存图片仍可用。

P1 上传后续：

- 添加用户配置的图片上传 provider，优先 Imgur Client-ID 类流程。
- 使用 Harmony picker/media API，上传进度、错误状态、上传历史、复制 URL、插入 Markdown。
- 不内置公共 client id。
- 无人测试时不自动上传。

## P0. 搜索完善

目标：接近成熟客户端的搜索能力，同时保持页面简洁。

当前状态：

- 已有本地搜索：稍后读、最近浏览、缓存、节点等。
- 已有 SOV2EX service 和筛选项。
- 已有网页 fallback。

任务：

- 验证 SOV2EX 触发行为：页面必须有明显的 HDS 动作或键盘动作执行远程搜索。
- 确认远程参数：
  - query
  - 分页
  - sort：相关性/sumup、created
  - order：降序/升序
  - 日期范围
  - 节点筛选
  - 作者/member 筛选
- 本地结果保持即时，远程失败不能影响本地搜索。
- 搜索历史：
  - 成功搜索后记录
  - 支持清空
  - 点击历史重新搜索
- 筛选 sheet：
  - 使用带 appbar 风格标题和关闭按钮的 modal scaffold
  - 返回键关闭 sheet
  - 不混用不同大小按钮
- 结果跳转：
  - 主题 -> `TopicDetail`
  - 节点 -> `NodeTopicList`
  - 用户/作者 -> `UserProfile`

参考：

- V2Fun: `screens/SearchScreen.tsx`、`screens/SearchOptionsScreen.tsx`、`jotai/sov2exArgsAtom.ts`
- VVEX: `lib/http/soV2ex.dart`

验收标准：

- 设备测试：搜索 `github`、一个中文关键词、一个节点名、一个用户名。
- 远程搜索可以加载和翻页。
- 远程失败不影响本地搜索。
- 搜索 UI 保持 HDS 风格、简洁。

## P0. 详情、回复、通知闭环

目标：完成阅读 -> 通知 -> 精确楼层/回复 -> 响应的闭环。

任务：

- 通知楼层跳转：
  - 从 API v2 和网页通知源解析 topic id、reply id、floor。
  - 通过 `TopicDetailParams` 传入目标楼层/回复。
  - 详情页加载直到目标楼层/回复可见，或确认没有更多页。
  - 跳转使用动画滚动，不要突兀瞬移。
- 回复控制：
  - 保持紧凑 `楼层 / 只看楼主 / 最新`。
  - 楼层列表中外露高频操作：
    - 感谢回复
    - 回复该楼层
  - 低频回复操作继续放 `ContextMenu`：
    - 复制
    - 分享
    - 查看上下文/相关回复
    - 忽略回复
    - 举报
    - 可用时编辑
  - 回复操作图标更新为合适的系统/HDS symbol，触控区域保持与当前紧凑行一致。
  - 不给低频动作加大号外置按钮。
- 回复入口与回复组件：
  - 不再把主回复入口放在 appbar 菜单里。
  - 详情页底部增加悬浮回复按钮；登录态可用，会话过期时显示可恢复登录状态。
  - 打开回复时使用贴靠键盘的悬浮 composer/sheet 组件，不走独立 route/page。
  - composer 应始终位于键盘上方，随可用高度调整，提交/关闭操作始终可触达，关闭后保留草稿。
  - `ReplyEditorPage.ets` 可以保留为底层组件/草稿承载，但普通用户流应是：详情页 -> 悬浮回复按钮 -> composer sheet。
  - composer sheet 可以有内部 appbar/title row，放关闭、预览、草稿、提交等操作，但体验上应是附着在当前主题上的 modal，而不是完整次级页面。
- 相关回复：
  - 使用现有 modal scaffold 实现上下文/相关回复视图。
  - 参考 V2Fun `screens/RelatedRepliesScreen.tsx` 和 `components/topic/ReplyItem.tsx`。
- 详情账号操作：
  - 感谢主题
  - 感谢回复
  - 忽略主题
  - 忽略回复
  - 举报主题
  - 收藏/取消收藏主题保持现有能力
  - 编辑和附言如果 P0 无法安全完成，放到 P1。
- 所有付费/破坏性动作都需要确认和写操作开关。

参考：

- V2Fun: `components/topic/TopicInfo.tsx`、`components/topic/ReplyItem.tsx`
- VVEX: `lib/http/dio_web.dart`、`lib/pages/t/topic_id.dart`、`lib/components/message/notice_item.dart`
- HarmonyDO: `entry/src/main/ets/views/pages/TopicDetailPage.ets`、`entry/src/main/ets/views/components/ReplyComposerSheet.ets`
- ClashBox master: `entry/src/main/ets/pages/ConfigurationPage.ets`，参考悬浮按钮、`bindSheet` 生命周期与 dismiss 处理。

验收标准：

- 通知点击能在有数据时跳到接近精确楼层/回复。
- 长主题跨页加载目标楼层正常。
- 回复筛选栏视觉仍紧凑。
- 详情页底部有悬浮回复按钮；appbar 菜单不再是主回复入口。
- 回复 composer 以 sheet/悬浮组件打开，跟随键盘 resize，关闭/提交可触达，不跳独立回复页。
- 每条回复外露感谢和回复操作；低频操作保留在带正确图标的 ContextMenu 中。
- ContextMenu 多次打开不失效。
- 无人测试不执行付费/破坏性动作。

## P0. 账号、我的页、用户页

目标：让 Cookie 登录成为普通用户主流程，PAT 保留为高级模式。

任务：

- 我的页保持账号仪表盘：
  - 头像
  - 用户名
  - 钱币图标
  - 每日任务/签到状态
  - 简洁账号入口
  - 设置只放 appbar 菜单
- 删除冗余副标题和重复上下文。
- 增加账号详情页：
  - 余额明细
  - 浏览器 fallback
  - 会话状态
  - 退出登录放详情/设置流里，不做我的页主行。
- 增加黑名单页：
  - 屏蔽用户
  - 忽略主题
  - 清空/重置需要确认
  - 本地状态尽量影响列表展示。
- 增加关注页面：
  - 关注用户，若网页可稳定解析
  - 关注/收藏节点
  - 收藏主题
- 完善用户资料：
  - 主题/回复 Tab 保留。
  - 用户隐藏主题时遵循网页状态。
  - 全部主题/全部回复入口放列表末尾。
  - 关注/屏蔽操作放到右上 appbar/menu 区域，或稳定预留的 header action slot，不放在资料内容下方。
  - 为关注/屏蔽状态预留默认空间，加载前后不能改变 header 高度，也不能把主题/回复 Tab 向下顶。
  - 关注/屏蔽即时更新并刷新服务端状态。
  - 重新进入页面仍保持正确服务端状态。
- Session 过期：
  - 每个认证页都显示可恢复登录入口。
  - 验证失败后清理或标记 stale 登录 UI。

参考：

- V2Fun: `screens/MemberDetailScreen.tsx`、`screens/BlackListScreen.tsx`、`screens/MyTopicsScreen.tsx`、`screens/MyNodesScreen.tsx`
- VVEX: `lib/http/user.dart`、`lib/components/adaptive/slide.dart`

验收标准：

- 已登录我的页显示 `honjow` 和正确钱币单位。
- `0.90 铜币` 若源文本如此，必须保持小数铜币。
- 关注/取消关注、屏蔽/取消屏蔽无需重启刷新。
- 用户页 header 在关注/屏蔽状态加载前后高度不跳变。
- 关注/屏蔽入口位于右上操作区；加载、未登录状态使用同一预留区域表达。
- 黑名单/忽略主题页不依赖 PAT。
- Cookie 过期路径可恢复。

## P1. 登录加固

目标：账号密码登录可靠，WebView 登录作为 fallback。

任务：

- 加固 `/signin` 动态字段解析。
- 需要验证码时显示验证码图片和输入框。
- 增加 2FA 流程。
- 精确区分错误：
  - 密码错误
  - 需要验证码/验证码错误
  - 需要 2FA/2FA 错误
  - V2EX 暂时阻止登录尝试
  - 网络失败
  - 会话过期
- 保存 Cookie 后通过加载认证页验证，而不是只看 Cookie 字符串。
- Web 登录：
  - 正确使用共享脚手架
  - 不用空白 spacer hack
  - 检测到有效 session 后自动保存并返回
  - 保留 appbar 手动保存/重新加载作为 fallback。

参考：

- VVEX: `lib/http/dio_web.dart`、`lib/utils/login.dart`
- V2Fun: `screens/LoginScreen.tsx`、`screens/WebSigninScreen.tsx`

验收标准：

- 正常登录成功。
- 密码错误显示明确错误。
- 验证码挑战可显示、可重试。
- 2FA 可完成。
- 重启后有效 session 保持。

## P1. 发现与导航

目标：浏览发现能力接近 V2Fun/VVEX。

当前状态：

- Discover 已有节点搜索和热议/热榜/最新/最近主题。

任务：

- 验证并打磨当前 Discover：
  - HDS/共享脚手架
  - 下拉刷新
  - 简洁分区
  - 无夸张空白和卡片网格
  - 次级动作放 appbar 菜单
- 重构节点相关页面，使其符合项目架构：
  - `DiscoverPage`
  - 节点搜索结果
  - 节点主题列表
  - 收藏/关注节点
  - 全部节点分类导航
  - 最近/常用节点
- 节点页不能使用临时返回按钮、一次性卡片、页面内自定义输入框样式。使用共享脚手架、`AppSearchField`、appbar actions 和列表下拉刷新。
- 若有稳定来源，增加历史热门。
- 增加完整热榜/社区页，而不只是小列表。
- 增加全部节点分类导航。
- 增加常用/最近节点。
- 增加首页 Tab 管理：
  - 排序
  - 隐藏/显示
  - 添加节点 Tab
  - 恢复默认
  - 重启后保持
- 增加节点排序/收藏管理。

参考：

- V2Fun: `screens/HomeScreen.tsx`、`screens/SortTabsScreen.tsx`、`screens/HotestTopicsScreen.tsx`、`screens/RankScreen.tsx`、`screens/NavNodesScreen.tsx`
- VVEX: `lib/components/adaptive/main.dart`、`lib/components/home/tab_bar_list.dart`

验收标准：

- 热议/热榜/最新/最近都能进入详情。
- Tab 管理重启后保持。
- Discover 保持紧凑和 HDS 风格。
- 节点页和通知页在视觉上匹配详情/设置等次级页：安全区、appbar、列表间距、下拉刷新、菜单行为一致。

## P1. 写作与编辑

目标：写作可用，但账号写操作继续受保护。

任务：

- 回复 composer：
  - 贴靠键盘的悬浮 sheet，不做普通 route
  - 详情页底部悬浮回复按钮作为主入口
  - 共享 HDS/modal 脚手架，内部有关闭/预览/提交操作
  - Markdown 工具栏
  - 预览
  - @ 插入
  - 图片链接插入
  - 媒体上传完成后支持上传插入
  - 自动保存和恢复
  - 同一主题/楼层再次打开时恢复草稿
- 发帖编辑器：
  - 节点选择器
  - Markdown 工具栏
  - 预览
  - 草稿保存
  - 提交确认
- 增加编辑主题：
  - 解析原表单
  - 预览
  - 确认
  - 只有写操作开关开启才提交
- 增加附言：
  - 解析状态/表单
  - 预览
  - 确认
  - 受保护提交
- 草稿只有确认成功后才清除。

参考：

- V2Fun: `screens/WriteTopicScreen.tsx`、`components/topic/ReplyBox.tsx`、`components/UploadImageButton.tsx`
- VVEX: `lib/http/dio_web.dart`、`lib/components/topic/reply_new.dart`

验收标准：

- 草稿重启后仍在。
- 写操作开关关闭时提交控件不可用。
- 真实提交必须用户明确批准。

## P1. 设置与个性化

目标：把设置从工程项整理成产品项。

任务：

- 设置分组：
  - 账号
  - 阅读
  - 内容与媒体
  - 通知
  - 写作
  - 存储
  - 高级
- 阅读：
  - 默认回复排序
  - 默认只看楼主/楼主高亮
  - 字号
  - 行高
  - 密度
  - 代码换行
- 内容与媒体：
  - 自动加载图片
  - 仅 Wi-Fi 图片
  - 图床探测开关，如果实现探测
  - 链接打开方式
- 通知：
  - 轮询/本地通知偏好
  - 安静行为
- 写作：
  - 全局写操作开关
  - 图片上传 provider 设置
- 高级：
  - PAT 元数据
  - API 域名
  - 缓存/调试控制

参考：

- V2Fun: `screens/SettingScreen.tsx`、`screens/ConfigureDomainScreen.tsx`、`screens/CustomizeThemeScreen.tsx`、`jotai/*Atom.ts`
- VVEX: `lib/utils/storage.dart`

验收标准：

- 设置和我的页不重复账号控制。
- 行副标题不复述标题。
- 设置页间距与其他次级页一致。

## P2. 系统集成

目标：让 V2Next 更像 HarmonyOS 原生完整应用。

任务：

- 深链：
  - topic id
  - member username
  - node name
  - search query
- 外部 V2EX URL 尽量在 app 内打开。
- Harmony 支持时增加桌面快捷操作：
  - 搜索
  - 今日热议
  - 草稿
  - 通知
- 通知数据稳定后增加本地通知轮询。
- 通知点击跳到对应主题/楼层。
- 手机 UI 稳定后评估平板/two-pane。

参考：

- V2Fun: `navigation/LinkingConfiguration.ts`、`app.json`
- VVEX: Android `AndroidManifest.xml`、`lib/utils/app_scheme.dart`、`lib/service/local_notice.dart`

验收标准：

- 打开 V2EX 主题/用户/节点 URL 能进入正确页面。
- 通知点击进入预期主题/楼层。
- 系统集成功能不在不需要账号时强制登录。

## 子线程工作安排

推荐顺序：

1. P0 媒体与图床处理。
2. P0 架构与 UI 基线。
3. P0 搜索完善。
4. P0 详情/通知闭环。
5. P0 节点/通知架构清理。
6. P0 账号/我的页/用户页。
7. P1 登录加固。
8. P1 发现与导航。
9. P1 写作与编辑。
10. P1 设置与个性化。
11. P2 系统集成。

每个子线程必须：

- 先读本文档和 `docs/ui-guidelines.md`。
- 改代码前先检查相关当前文件。
- 只读取任务需要的参考项目路径。
- 明确自己的写入范围。
- 不碰无关 UI。
- 不执行真实付费/破坏性操作。
- 构建、安装、设备验证后再提交。
- 每个独立功能单独提交。

建议子线程提示词：

### 媒体子线程

```text
按照 docs/roadmap-v2ex-client.md 的 P0 Media and Image Host Handling 开发。
优先处理 MediaUrlUtils 和 MarkdownContent，除非设置项确实必要，不要扩大范围。
保留普通链接 inline 文本显示，保留直接图片渲染，不要恢复链接卡片，本轮不实现上传。
构建，安装到 192.168.50.237:12345，在包含直接图片、Imgur 页面链接、GitHub 普通链接的主题中截图验证，然后提交。
```

### 架构子线程

```text
按照 docs/roadmap-v2ex-client.md 的 P0 Architecture and UI Baseline 做第一段安全拆分。
从 Index.ets 拆出一个明确所有权区域，优先 HDS/共享组件，不改变该区域外视觉行为。
构建、安装、截图受影响页面，然后提交。
```

### 搜索子线程

```text
完成 docs/roadmap-v2ex-client.md 的 P0 Search。
验证 SOV2EX 执行、分页、筛选 sheet 返回关闭、结果跳转、本地搜索 fallback。
保持 HDS/共享控件和简洁 UI。构建、安装、截图 Search 各状态，然后提交。
```

### 详情/通知子线程

```text
完成 docs/roadmap-v2ex-client.md 的 P0 Detail/Reply/Notification 工作。
实现通知楼层跳转，楼层外露感谢/回复两个高频操作，低频动作保留在带正确图标的 ContextMenu。
把独立回复页导航替换为详情页底部悬浮回复按钮 + 贴靠键盘的 composer sheet。
保持当前紧凑 `楼层 / 只看楼主 / 最新` 筛选栏，不要无人执行付费/破坏性动作。
构建、安装，在有数据时验证通知到楼层，验证 composer 键盘行为，截图 TopicDetail 和 composer，然后提交。
```

### 节点/通知架构子线程

```text
按照 docs/roadmap-v2ex-client.md 将节点页和通知页纳入 HDS-first 共享架构。
在安全范围内将通知所有权从 Index.ets 移出，迁移 Discover/NodeTopic/Notifications 到共享脚手架。
移除页面级返回按钮、一次性输入框/卡片，按需加入下拉刷新，保持现有数据行为不变。
构建、安装，截图 Discover、NodeTopic、Notifications；有数据时验证一次通知到详情/楼层跳转，然后提交。
```

## 验证清单

每次提交前使用：

- `git status --short`
- `bash dev.sh --build-only`
- `bash dev.sh --no-build -d 192.168.50.237:12345`
- 启动应用：
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc -t 192.168.50.237:12345 shell "aa start -a EntryAbility -b com.next2v.app"`
- 交互测试受影响流程。
- 截图：
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc -t 192.168.50.237:12345 shell "snapshot_display -f /data/local/tmp/<name>.jpeg"`
- 拉取截图到 `/tmp` 并人工检查。
- 需要文本/状态证明时 dump：
  `/home/gamer/devtool/ohos/command-line-tools/sdk/default/openharmony/toolchains/hdc -t 192.168.50.237:12345 shell "uitest dumpLayout"`
- `git diff --check`
- 审查 `git diff`
- 使用准确提交信息提交。
