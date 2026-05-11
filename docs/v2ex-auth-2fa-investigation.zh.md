# V2EX 2FA 登录研究记录

日期：2026-05-11

## 目的

记录 V2EX 开启 2FA 后的登录/会话行为，避免把 2FA 当成 `NativeLoginPage` 内部的一次性步骤处理。

## 参考来源

- 当前项目：`shared/src/main/ets/network/V2exNativeAuthService.ets`
- 当前项目：`shared/src/main/ets/network/HttpClient.ets`
- 当前项目：`shared/src/main/ets/network/ApiService.ets`
- 当前项目：`docs/v2ex-auth-2fa-contract.md`
- VVEX / flutter_v2ex：`lib/http/dio_web.dart`
- CzBiX/v2ex-android：`app/src/main/kotlin/com/czbix/v2ex/network/RequestHelper.kt`
- V2Fun：主要走 WebView 登录，作为 Cookie/WebView 方向参考，不作为原生 2FA 表单协议依据。

## 关键行为

开启 2FA 的账号，在用户名/密码/CAPTCHA 登录成功后，不等于完整登录成功。

在 2FA 完成前，V2EX 会把带当前登录 Cookie 的私有页面请求重定向到：

```text
/2fa
```

这个重定向不是只发生在 `/signin` 后续流程里。用户实际反馈和参考项目都指向同一个结论：

```text
2FA 未完成时，任何需要认证的链接/页面请求都可能被重定向到 /2fa。
```

因此 2FA 是会话级状态，不是登录页局部状态。

## 参考项目结论

### flutter_v2ex

`dio_web.dart` 里有两个重要点：

1. 获取 CAPTCHA 时也检查是否被重定向到 `/2fa`。
   - 注释说明“登录后未 2fa 退出，第二次进入触发”。
2. 登录成功后请求 `/write` 获取用户信息。
   - 如果该请求发生 redirect，且目标是 `/2fa`，就把响应切到 `/2fa`，并进入 2FA 流程。

这说明它不是只看 `/signin` 响应，而是通过后续私有页面请求确认 2FA 状态。

### v2ex-android

`RequestHelper.kt` 里有两个重要点：

1. 2FA 提交协议是：

```text
POST /2fa
body: code=<当前一次性验证码>
referer: /2fa
cookie: 当前登录会话 Cookie
```

2. 全局响应检查里，任何 redirect 到 `/2fa` 都抛 `TwoFactorAuthException`，不是当普通未登录处理。

这说明 `/2fa` 应该由共享请求/会话层识别，而不是散落在单个登录页面里。

## 当前方案已经对的部分

当前 `V2exNativeAuthService` 的方向有几处是正确的：

- POST `/signin` 后检查 `Location: /2fa`。
- 不直接保存登录态，而是继续请求 `/settings` 作为私有页面 proof。
- 2FA 提交固定使用 `POST /2fa`。
- 2FA body 使用字段 `code`。
- 2FA 失败时保留 challenge，让用户重新输入 code。

这些和参考项目方向一致。

## 当前方案的致命缺陷

当前实现仍然偏登录流程局部：

```text
NativeLoginPage / V2exNativeAuthService 能识别 /2fa，
但 ApiService / HttpClient 的普通 Cookie 请求没有统一识别 /2fa。
```

问题是：开启 2FA 后，用户不一定只停留在原生登录页。

可能发生：

```text
用户已有半登录 Cookie
打开通知 / 设置 / 发帖 / 收藏 / 我的节点 / 任意私有页面
请求被 V2EX 重定向到 /2fa
当前 ApiService 只看到“没有解析出用户名”
然后误报为“Web 会话已失效，请重新登录”
```

这会把“需要完成 2FA”误判成“Cookie 失效”。

## 缺陷来源

当前 `HttpClient.getTextWithHeaders()` 只返回 HTML 字符串：

```text
text only
```

它不会把这些信息交给调用方：

```text
statusCode
Location
final URL / redirect chain
Set-Cookie
```

而 `ApiService` 大量 Cookie 页面请求都走：

```text
this.http.getTextWithHeaders(path, { Cookie: cookie })
```

所以调用方无法可靠区分：

```text
真正未登录 / Cookie 失效
vs
2FA 未完成，被重定向到 /2fa
```

这就是“只在 V2exNativeAuthService 里处理 2FA”不够的原因。

## 用户可见表现

如果不做共享层识别，可能出现：

- 登录流程中已经拿到 Cookie，但保存/验证状态不稳定。
- 开启 2FA 的账号访问任意私有页时，被提示“会话已失效”。
- 页面刷新、收藏、签到、通知、我的内容等入口各自报不同错误。
- 用户输入 2FA 的入口只在 NativeLoginPage，其他页面遇到 `/2fa` 时无法接续。

## 后续正确方向

不要只修 `NativeLoginPage`。

需要增加一个 Cookie HTML 请求的统一入口，至少能返回：

```text
statusCode
location
text
setCookie（如果平台能拿到）
```

然后在共享层统一判断：

```text
Location path == /2fa
或最终页面/HTML 是 /2fa challenge
=> 抛出/返回明确的 TwoFactorRequired 状态
```

`ApiService` 的所有 Cookie 私有请求应走这个入口，而不是直接用只返回字符串的 `getTextWithHeaders()`。

2FA challenge 应该进入一个共享会话状态，例如：

```text
pendingTwoFactor: true
challengeCookie: 当前 Cookie
blockedPath: 原请求路径，可选
```

完成 2FA 后：

```text
POST /2fa code=<code>
请求 /settings 或等价私有页验证用户名
验证成功后再保存 cookie/auth session
刷新或重试原请求
```

## 不要再走的方向

不要把 2FA 只做成：

```text
登录页里 password submit 后的第二个输入框
```

这个方案漏掉“半登录 Cookie 访问任意私有链接都会进 /2fa”的场景。

不要把 `/2fa` redirect 当成：

```text
Web 会话已失效
```

这会误导用户重新登录，且可能反复卡在同一状态。

不要在完成 2FA 前写入完整 authenticated session。

完整登录必须以私有页面 proof 成功为准，例如：

```text
/settings 能解析出当前用户名
```

## 最小验收点

后续实现至少要验证：

1. 原生登录遇到 2FA：显示 2FA 输入，不保存完整登录态。
2. 正确 2FA code：POST `/2fa` 后能通过 `/settings` 验证并保存 session。
3. 错误/过期 2FA code：保留 2FA 输入状态，只清空 code。
4. 半登录 Cookie 访问 `/settings`、`/notifications`、`/write`、`/mission/daily` 等私有页：统一识别为“需要 2FA”，不是“会话失效”。
5. 2FA 完成后可以刷新或重试原先被拦截的页面。
