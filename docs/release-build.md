# 发布包瘦身与构建

本文只描述**发布构建**。普通开发构建（`flutter run`、`flutter build macos --debug` 等）
没有被修改；发布脚本也不会改变 Debug/Profile 配置。

## 快速使用

在项目根目录执行：

```sh
# Android：默认按 ABI 拆分 APK（armv7 / arm64 / x64）
dart run tool/release.dart android

# Android 商店包
dart run tool/release.dart appbundle

# macOS universal .app
dart run tool/release.dart macos

# iOS IPA（需要 macOS + Xcode 签名）
dart run tool/release.dart ios

# Windows release bundle
dart run tool/release.dart windows
```

目标之后的所有参数原样转发给 Flutter，包括 OAuth 配置、版本号和其他构建选项：

```sh
dart run tool/release.dart android \
  --dart-define=OUTLOOK_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000

dart run tool/release.dart macos \
  --dart-define=GMAIL_OAUTH_DESKTOP_CLIENT_ID=xxxx.apps.googleusercontent.com \
  --dart-define=OUTLOOK_OAUTH_CLIENT_ID=00000000-0000-0000-0000-000000000000

dart run tool/release.dart appbundle \
  --dart-define-from-file=oauth.env \
  --build-name=1.0.1 --build-number=2

dart run tool/release.dart android --no-pub
```

脚本固定添加：

```text
--release
--split-debug-info=build/symbols/<target>/<UTC 时间戳>/
```

Android APK 另加 `--split-per-abi`。不启用 `--obfuscate`，Dart 标识符不会改名，
`runtimeType` 等运行时行为不变。

脚本不会删除任何已有 APK/AAB/符号目录；重复构建用新的 UTC 时间戳目录，因此不会
覆盖历史符号。`--dry-run` 只打印命令、符号目录和预期产物：

```sh
dart run tool/release.dart android --dry-run
```

会覆盖发布策略的参数（`--debug`、`--profile`、`--release`、`--split-debug-info`、
`--obfuscate`、`--analyze-size` 等）会被拒绝；其余参数不解析、不重写，直接交给
Flutter。日志只打印固定的发布参数，不回显 `--dart-define` 的值。

## 实际结果

| 项目 | 基线 | 优化后 | 变化 |
| --- | --- | --- | --- |
| Android universal APK | 71,091,700 bytes | 不再作为默认发布物 | — |
| Android split APK（armv7 / arm64 / x64） | — | 约 21.1 / 23.6 / 25.1 MB | 每台设备只装一套 ABI |
| macOS `.app`（去重 symlink） | 68,879,197 bytes | 59,300,921 bytes | −13.9% |
| macOS `ditto` zip | 27,602,536 bytes | 24,927,904 bytes | −9.7% |

macOS universal 架构完整保留，`codesign --verify --deep --strict` 通过，Runner
两个架构的 dSYM UUID 与二进制吻合。

### 安装体积 vs 下载体积

- Android：split APK 的文件大小接近单 ABI 的下载体积；安装后占用还包含 dex 优化、
  资源和应用数据，不能用 APK 大小直接等同。当前 `useLegacyPackaging` 没有改动：
  native 库保持未压缩、页对齐，下载包会略大，但安装时不需要再解压一份，避免
  “下载变小、安装变大”。不要为了压缩 APK 改这个开关。
- AAB：上传大小不等于用户下载大小。Play 会按设备 ABI、屏幕密度和语言生成 split，
  应以 Play Console 的下载大小为准。
- macOS：`.app` 大小接近安装后的磁盘占用；`ditto` zip 是下载压缩体积。两者不能
  混为一谈。

### Android split APK 的 versionCode 风险

Flutter 对 split APK 使用：

```text
versionCode = ABI 编号 * 1000 + pubspec 的 build number
ABI 编号：armeabi-v7a=1，arm64-v8a=2，x86_64=4
```

例如 `version: 1.0.0+1` 时，universal 是 `1`，split 分别为 `1001`、`2001`、`4001`。
因此 split APK 的版本码**高于** universal APK：

- 已安装 split 包的设备，继续更新时应使用同 ABI、同签名的 split 包，并递增
  build number；**不要卸载**，卸载会丢失本地草稿、发件队列和信任名单。
- 如确需切换到 universal 包，必须保证新包的 versionCode 高于已安装的 split 包，
  不能同版本覆盖，也不要安装后再降级；否则系统会拒绝。不要为了“降级”而卸载。
- 不要为了“统一版本码”使用 `-P force-version-code-ignoring-abi=true`；那会破坏
  多 ABI 分发和商店更新判断。
- 覆盖更新必须继续使用同一个签名密钥（当前 release 仍是本机 debug 密钥，正式分发
  前应换成自己的密钥并长期保存）。

### 预期产物路径仅作参考

脚本打印的是 Flutter 的标准默认输出路径。使用 `--flavor`、`--target-platform`、
自定义 Gradle 输出目录或未来 Flutter 版本时，实际文件名/目录可能不同；以 Flutter
本次构建日志和实际输出为准。Android 不要把旧 universal `app-release.apk` 当成
本次产物；脚本列出的是三个 split APK 的标准路径。

## macOS：Release strip

`macos/Runner.xcodeproj/project.pbxproj` 只在 Runner target 的 **Release** 配置增加：

```text
DEPLOYMENT_POSTPROCESSING = YES
STRIP_INSTALLED_PRODUCT = YES
```

没有改 Debug/Profile，也没有把设置写进 `Release.xcconfig`，因为该 xcconfig 同时被
Profile 引用。`COPY_PHASE_STRIP` 只作用于 copy phase，不会 strip Runner 可执行文件；
真正 strip Runner 的是 `STRIP_INSTALLED_PRODUCT`，而它需要
`DEPLOYMENT_POSTPROCESSING=YES` 才会执行。

约束：

- strip 发生在 Xcode 签名之前；**不要**对已经签名的 `.app` 手工运行 `strip`，
  否则签名失效。
- 保留 `dwarf-with-dsym`。Runner 的 `local_mail_client.app.dSYM` 以及各 framework
  dSYM 仍在 `build/macos/Build/Products/Release/`，必须和对应版本一起归档。
- 保留 universal 架构，不要为了瘦身删除 arm64 或 x86_64。
- 不要删除 `Contents/Frameworks/libswiftCompatibilitySpan.dylib` 等 Swift 动态库；
  Flutter/Xcode 已按部署目标决定是否嵌入，手工删除可能导致启动失败。
- 分发压缩包用 `ditto -c -k --keepParent local_mail_client.app out.zip`，保留
  symlink、扩展属性和签名结构；不要用会解引用 symlink 的普通 zip。

## 符号文件必须随版本保存

Dart 符号在：

```text
build/symbols/<target>/<UTC 时间戳>/
```

每次构建都是独立目录（例如 `build/symbols/android/20261109T101530123Z/`），
同名构建不会覆盖。`build/` 被 git 忽略，也可能被 `flutter clean` 删除；只保留
构建目录不算保存。每次发布后应把目录复制到持久位置，并记录它对应的版本号、
build number、平台和提交/签名信息，例如：

```text
~/Library/Application Support/local-mail/symbols/1.0.0+1/android/20261109T101530123Z/
~/Library/Application Support/local-mail/symbols/1.0.0+1/macos/20261109T101530456Z/
```

解析崩溃栈（`-d` 指向本次构建的单个 `app.<arch>.symbols` 文件，不是目录）：

```sh
flutter symbolize -i crash.txt \
  -d /path/to/symbols/android/20261109T101530123Z/app.android-arm64.symbols
```

符号文件与二进制必须来自同一次构建；同一版本号重新构建也要使用对应时间戳目录。
macOS/iOS 还需要同时保存 Xcode 生成的 `.dSYM`（在 `build/macos/.../Release/` 或
iOS archive 中），Dart 符号不能替代原生 dSYM。

## 未使用依赖

`cupertino_icons` 在整个工程中没有 `CupertinoIcons` 引用，但依赖本身会把
`CupertinoIcons.ttf`（约 252KB）打进每个包的 asset bundle。它已从 `pubspec.yaml`
移除。Material Icons 的 tree-shaking 正常生效（基线构建中约 10KB），不要关闭
`--tree-shake-icons`；本次也没有启用 obfuscation。

## 平台现状

- **Android**：split APK 已验证 release 构建；AAB 脚本已配置，本次未实际构建。
- **macOS**：Release strip 已验证；universal/dSYM/签名均保留。
- **iOS**：脚本已配置 `flutter build ipa --release`；需要 macOS、Xcode 和签名。
  当前仓库没有可用的 iOS 发布签名；未签名编译因缺少 iOS 26.2 platform component
  未完成（`Found no destinations for scheme Runner action build`），体积尚未测量。
- **Windows**：脚本已配置 `flutter build windows --release`，Windows 上通过
  `Process.start(..., runInShell: true)` 兼容 `flutter.bat`；本次未做 native build，
  体积尚未测量。产物是整个 `Release/` 目录（`.exe`、`flutter_windows.dll`、
  插件 DLL、`data/`），必须整体打包分发，不能只发 `.exe`。Windows 的 zip 下载
  体积和安装后占用也不同，应分别测量。
- **Linux**：当前仓库**没有 `linux/` 目录，未配置 Linux 平台**。脚本对
  `dart run tool/release.dart linux` 会明确报错，不会创建平台或猜测工具链。
  如果以后用 `flutter create --platforms=linux .` 增加平台，再使用
  `flutter build linux --release` 并同样加 `--split-debug-info`；那是未来工作，
  当前不可用。Linux 产物同样是整个 `bundle/` 目录，不能只分发可执行文件。

## 验证清单

```sh
flutter pub get          # 由构建负责人统一执行，避免并发

# Android
dart run tool/release.dart android
ls -l build/app/outputs/flutter-apk/
# 可选：aapt dump badging 每个 APK，确认 versionCode/ABI

# macOS
dart run tool/release.dart macos
lipo -archs build/macos/Build/Products/Release/local_mail_client.app/Contents/MacOS/local_mail_client
codesign --verify --deep --strict --verbose=2 \
  build/macos/Build/Products/Release/local_mail_client.app
dwarfdump --uuid \
  build/macos/Build/Products/Release/local_mail_client.app/Contents/MacOS/local_mail_client \
  build/macos/Build/Products/Release/local_mail_client.app.dSYM

# 符号
find build/symbols -maxdepth 4 -type f -print
```

脚本自检（不需要 Flutter SDK，不会执行真实构建）：

```sh
dart run tool/release_test.dart
```
