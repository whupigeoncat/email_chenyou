# 本地邮箱

个人使用的 Flutter 多账号邮箱客户端，设备直接连接服务商 IMAP / SMTP，不经过自建邮件服务器。

支持聚合收件箱、历史邮件分页、已读/星标同步、按需下载正文与附件、本地搜索、草稿和发件队列。凭据保存在系统安全存储中；远程图片默认拦截。

## 使用说明

- 收件箱首次缓存最近 50 封邮件，滚动到底部或点击“加载更早邮件”可继续从服务器获取历史邮件。
- 同步会分批核对所有已缓存邮件的状态和删除情况。服务器重建 UID 索引时，会阻止对旧 UID 的下载和修改；刷新邮箱后重试即可。
- 搜索仅覆盖本地缓存，正文下载后才能被检索。草稿、发件队列和信任名单仅保存在当前设备。
- “账户管理 → 保存已发送副本”：服务商不自动保存 SMTP 邮件时开启。自定义服务器默认开启，内置服务商默认由服务器保存。保存前按 Message-ID 检查已有副本，避免重复添加。
- SMTP 已接受的邮件不会因 IMAP 副本保存失败而自动重发。副本待保存时保留本地正文和附件，可在发件箱点击“补存已发送副本”；启动时也会重新核对。只有确认服务器副本存在或成功保存后才清理暂存附件。
- 投递结果不确定的邮件会暂停自动重试，需要在发件箱人工核对。

## Gmail / Outlook / QQ 登录

普通使用者无需填写 OAuth Client ID：

- Gmail：Android 使用 Google Play 服务官方设备授权；桌面使用系统浏览器 + PKCE。
- Outlook：系统浏览器 + PKCE，移动端使用固定回跳 scheme，桌面使用本机回环地址。
- QQ / Foxmail：此客户端使用 QQ 官方 16 位 IMAP/SMTP 授权码流程，打开官方页验证并生成授权码后返回粘贴，不是 QQ 密码。

开发者需要一次性注册 Google / Microsoft OAuth 应用，并通过构建参数注入 Client ID。
注册步骤、签名 SHA-1、回跳地址、scope 和平台构建示例见
[`docs/oauth-setup.md`](docs/oauth-setup.md)。未配置时应用会显示“此构建未配置 … 登录”。

## 开发与验证

```sh
flutter pub get
dart run build_runner build
flutter analyze --no-pub
flutter test --no-pub
flutter build macos --debug --no-pub
```

数据库版本为 6，支持从旧版本保留数据升级。原生构建还需要对应平台的 SDK；iOS 真机安装需要签名，Windows 构建需要 Windows 环境。

Android 安装 Android Studio、Android SDK 和 Command-line Tools 后，在项目根目录执行：

```sh
flutter pub get
dart run tool/release.dart android
```

发布构建默认按 ABI 拆分 APK，输出到 `build/app/outputs/flutter-apk/`：

- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

设备只需安装对应 ABI 的一个包。商店包使用 `dart run tool/release.dart appbundle`。
脚本同时把 Dart 符号写到 `build/symbols/<target>/<UTC 时间戳>/`，该目录必须随
版本归档；不要只保留构建产物。所有平台的命令、体积口径、split versionCode 覆盖
更新风险和符号保存方式见 [`docs/release-build.md`](docs/release-build.md)。

首次构建会下载 Gradle、NDK 和插件所需的 SDK 组件；缺少许可时运行 `flutter doctor --android-licenses`。当前 release 使用本机 debug 密钥签名，可用于个人安装；正式分发前需配置自己的签名密钥，并保留该密钥以支持后续覆盖更新。不要发布旧 universal APK：它的 versionCode 低于 split 包，会被已安装 split 包的设备视为降级。

邮件正文数据库未加密，隐私保护依赖设备与操作系统。移动端后台释放连接后，不提供持续后台推送提醒。
