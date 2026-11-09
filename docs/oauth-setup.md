# Gmail / Outlook / QQ 登录配置

本应用的普通使用流程只显示“使用 Google 登录 / 使用 Microsoft 登录 / 授权码登录”，
不会要求使用者填写 Client ID。OAuth 应用由开发者一次性注册，并通过构建参数注入；
缺失配置时界面会直接说明“此构建未配置 … 登录”，不会打开无效的授权页。

> 当前仓库没有注册任何 Google / Microsoft OAuth 应用，也没有用真实账号完成过
> OAuth 联调。下面的配置步骤是启用真实登录所必需的。

## 平台能力

| 平台 / 服务商 | 授权方式 | 构建配置 | 是否需要 Client ID 输入 |
| --- | --- | --- | --- |
| Android Gmail | Google Play Services `AuthorizationClient`，仅获取短期 access token | Google Cloud 注册 Android OAuth 客户端（包名 + SHA-1） | 否 |
| macOS / Windows / Linux Gmail | 系统浏览器 + 本机回环回调 + PKCE | `GMAIL_OAUTH_DESKTOP_CLIENT_ID` | 否 |
| iOS Gmail | 系统浏览器 + PKCE，反向 Client ID URL scheme | `GMAIL_OAUTH_IOS_CLIENT_ID` + Info.plist scheme | 否 |
| Android / iOS Outlook | 系统浏览器 + PKCE，固定回跳 scheme | `OUTLOOK_OAUTH_CLIENT_ID` | 否 |
| macOS / Windows / Linux Outlook | 系统浏览器 + 本机回环回调 + PKCE | `OUTLOOK_OAUTH_CLIENT_ID` | 否 |
| QQ / Foxmail | 官方 16 位客户端授权码（不是 OAuth） | 无 | 否 |

### Gmail 的 Android 设备授权

Android 使用 Google 当前推荐的设备端授权 API（`AuthorizationClient`），
只拿到约 1 小时有效的 access token，用于 Gmail IMAP/SMTP 的 XOAUTH2。
应用不会在设备上伪造 refresh token，也没有后端或 `client_secret`。
令牌到期时通过同一 API **静默**重新获取；如果用户撤销授权或需要重新交互，
后台只会报“需要重新登录”，不会自动弹登录框。重新授权入口在账户管理页。

授权请求通过 `setAccount(Account(邮箱, "com.google"))` 绑定具体 Google 账户，
并调用 Google 官方 `userinfo` 接口核对登录邮箱；不匹配的账户不会被保存。
多账户场景下，每个账户的令牌只绑定自己的邮箱，不会刷新到系统的默认 Google 账号。

无 Google Play 服务、取消、授权进行中、账户不存在、授权失败都会显示明确提示；
不会把普通网页密码或短信验证码交给应用。

### 注册 Google OAuth

1. 在 <https://console.cloud.google.com/> 创建项目。
2. 配置 OAuth consent screen（测试阶段把使用者的 Google 账号加入 Test users；
   `https://mail.google.com/` 是受限 scope，长期公开使用通常需要 Google 验证）。
3. 为 Android 创建 **Android** 类型 OAuth 客户端：
   - 包名：`com.localmail.local_mail_client`
   - SHA-1：当前 release 使用本机 debug 签名，必须与安装包签名一致。
     可用以下命令查看（或 `cd android && ./gradlew signingReport`）：
     ```sh
     keytool -list -v -keystore ~/.android/debug.keystore \
       -alias androiddebugkey -storepass android -keypass android
     ```
   - 如果以后更换正式签名，需要为新 SHA-1 重新注册 Android 客户端。
4. 桌面端另建 **Desktop app** 类型客户端，把 Client ID 传给
   `GMAIL_OAUTH_DESKTOP_CLIENT_ID`。桌面包使用 `http://127.0.0.1:<随机端口>/oauth2redirect`
   回环回调，Google 的 Desktop app 客户端无需预先登记该回环地址。
5. iOS 另建 **iOS** 类型客户端，传 `GMAIL_OAUTH_IOS_CLIENT_ID`，并把反向 Client ID
   scheme 加入 `ios/Runner/Info.plist` 的 `CFBundleURLTypes`，例如：
   `com.googleusercontent.apps.1234567890-abc`。
6. 不要使用 Android 客户端 ID 作为桌面或 iOS 的 Client ID；三种平台客户端是独立的。

注意：Google 已不支持 Android 使用自定义 URI scheme 回调，所以 Android 不再走
`com.localmail.client://oauth2redirect`；自定义 scheme 仅保留给 Microsoft 移动端。

### 注册 Microsoft Entra 应用

1. 在 <https://entra.microsoft.com/> 的 App registrations 新建应用。
2. Supported account types 选择
   “Accounts in any organizational directory and personal Microsoft accounts”
   （代码使用 `common` authority）。
3. Authentication → Add a platform → **Mobile and desktop applications**，
   添加以下 public-client 回跳地址：
   - 移动端（Android / iOS）：`com.localmail.client://oauth2redirect`
   - 桌面端：`http://localhost/oauth2redirect`
     （代码用 `localhost` 随机端口；Microsoft 对 localhost 回环忽略端口、按路径匹配）
4. API permissions 添加 **Office 365 Exchange Online** 的委托权限：
   - `IMAP.AccessAsUser.All`
   - `SMTP.Send`
   并授予管理员/用户同意。运行时还会请求 `offline_access openid email`。
5. 不需要、也不要给移动/桌面客户端创建或内置 client secret。
6. 把 Application (client) ID 传给 `OUTLOOK_OAUTH_CLIENT_ID`。

## 授权结果的安全校验

- Gmail 登录后会调用 Google 官方 `userinfo` 接口，要求 `email` 与填写地址一致且
  `email_verified` 为 `true`；Google 官方等价的 `gmail.com` / `googlemail.com`
  域会规范化后再比较，不会随意去除点号或 `+` 标签。
- Microsoft 登录后校验 token endpoint 返回的 ID token：issuer、audience、有效期、
  nonce 和邮箱 claim 都必须匹配；`outlook.com` / `hotmail.com` / `live.com`
  **不视为等价**，同一 local-part 可能属于不同用户。使用别名时请填写登录页显示的主邮箱。
- 浏览器初次授权必须返回非空 refresh token，否则直接失败，不会保存一小时后必然失效的
  凭据；刷新响应仍会保留旧 refresh token。
- scope 必须真的包含 Gmail 的 `https://mail.google.com/` 或 Outlook 的
  `IMAP.AccessAsUser.All` + `SMTP.Send`。Outlook 的短名/百分号编码/已知
  `outlook.office.com`、`outlook.office365.com` 形式会规范化，保存和刷新时仍发送
  完整的 Outlook 资源 scope；Graph 或其它 host 的 scope 会被拒绝。
- 回调地址的 scheme/host/port/path 必须与本次请求一致，且 state（包括错误回调）校验
  通过后才处理；错误描述会清洗并截断，不把授权码或令牌拼进界面。
- token、userinfo、refresh 请求都有 30 秒超时；网络断开或超时会结束登录忙碌态并提示重试。
- Android 的 Play Services 授权在所有 Gmail 账户之间全局排队，避免多账户同时续期时
  被原生的“已有授权进行中”拒绝。

## QQ / Foxmail

此客户端使用 QQ 官方的 16 位 IMAP/SMTP 授权码流程。
QQ 网页扫码或 QQ 快速登录只代表网页会话，不等于 IMAP/SMTP 授权。
因此本应用诚实使用官方授权码流程：

1. 打开官方指南 <https://help.mail.qq.com/detail/106/985>（或从应用内按钮打开）。
2. 登录 QQ 邮箱网页版 → 设置 → 账号与安全 → 安全设置，开启 IMAP/SMTP 服务。
3. 按页面提示验证并生成 **16 位授权码**。
4. 将授权码粘贴到应用的授权码输入框；不要填写 QQ 登录密码。
5. Foxmail 邮箱使用同一套腾讯邮件服务器和授权码机制。

## 构建示例

发布构建统一走 `tool/release.dart`，它会固定使用 release、拆分符号并（Android APK）
按 ABI 拆分；OAuth 参数原样转发：

```sh
# Android：Gmail 使用 Google Play Services，不需要内置 Google Client ID
dart run tool/release.dart android

# Android 同时启用 Microsoft 登录时，只注入 Microsoft public client ID
dart run tool/release.dart android \
  --dart-define=OUTLOOK_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000

# macOS：Gmail 桌面 + Outlook
dart run tool/release.dart macos \
  --dart-define=GMAIL_OAUTH_DESKTOP_CLIENT_ID=xxxx.apps.googleusercontent.com \
  --dart-define=OUTLOOK_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000

# iOS（需要 macOS + Xcode 签名；本机尚未验证）
dart run tool/release.dart ios \
  --dart-define=GMAIL_OAUTH_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com \
  --dart-define=OUTLOOK_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000
```

也可以使用 `--dart-define-from-file=oauth.env` 保存非密钥配置；不要把
`client_secret` 放进应用，OAuth 公共客户端不需要它。符号目录和体积口径见
[`release-build.md`](release-build.md)。

兼容旧构建脚本：`GMAIL_OAUTH_CLIENT_ID` 仍作为桌面 Gmail Client ID 的备用参数读取，
但只建议新构建使用 `GMAIL_OAUTH_DESKTOP_CLIENT_ID`。

## 尚未验证的内容

- 没有真实 Google / Microsoft OAuth 应用，因此没有真实账号登录成功记录。
- Android `AuthorizationClient` 原生代码只完成编译验证，未在真机上做授权/静默续期联调。
- iOS 未在本机编译，Google iOS 的反向 scheme 需要按上文补入 Info.plist。
- QQ / Foxmail 的官方授权码页面与 16 位长度说明依据腾讯官方帮助，但未使用真实账号测试。
