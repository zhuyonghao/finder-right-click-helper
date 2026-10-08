# 右键助手

原生 macOS Finder 右键增强工具，使用 SwiftUI、AppKit 和 Finder Sync Extension。支持 macOS 14 及以上；无第三方依赖。

## 下载与安装

前往 [GitHub Releases](https://github.com/zhuyonghao/finder-right-click-helper/releases/latest) 下载应用。当前下载包为 Apple Silicon（arm64）版本，适用于 macOS 14 及以上。

解压后将「右键助手.app」放入「应用程序」，打开应用并按下方说明启用 Finder 扩展。发布包使用本地 ad-hoc 签名，尚未完成 Developer ID 签名与公证；需要其他架构或正式签名时，可从源码构建。

## 功能

- **新建文件**：内置 TXT、Markdown、JSON、HTML、Python、Shell、Swift 模板，可添加、编辑、导入 UTF-8 文本模板，单独启用或停用。
- **模板变量**：支持 `{{filename}}`、`{{date}}`、`{{datetime}}`；创建时输入文件名，同名文件自动添加序号。
- **自定义打开方式**：选择本机 `.app`，将它添加到右键菜单；支持多选文件、文件夹。
- **快捷操作**：复制所选项目路径、在目标文件夹打开终端，可选择系统终端、Ghostty、iTerm2、Warp 或其他支持接收文件夹的终端应用。
- **菜单设置**：控制菜单和快捷操作开关，配置出现菜单的文件夹，创建后在 Finder 中显示文件。
- **应用内操作**：也可在主窗口直接选择文件夹新建文件，或选择文件使用指定应用打开。
- **后台执行**：Finder 菜单操作不自动打开主窗口；新建文件只显示命名框。点击「设置…」或直接启动应用才显示主窗口。

模板处理文本内容，不用于伪造 DOCX、XLSX 等二进制格式。

## 构建与运行

安装 Xcode Command Line Tools 或完整 Xcode 后，在项目目录执行：

```sh
./scripts/build.sh
open "build/右键助手.app"
```

构建脚本会编译主应用和 Finder 扩展、生成应用图标、嵌入扩展并完成本地 ad-hoc 签名。产物为 `build/右键助手.app`，按当前 Mac 的 CPU 架构构建。用 `CONFIGURATION=debug ./scripts/build.sh` 可生成调试版本。

建议把应用移到「应用程序」后运行，避免后续移动导致扩展路径改变。构建脚本不会安装应用、自动启用扩展或修改系统设置。

## 启用 Finder 右键菜单

1. 打开右键助手，在应用中的扩展状态区域打开系统扩展管理界面。
2. 在系统扩展设置中启用「右键助手」的 Finder 扩展。不同 macOS 版本的设置入口略有变化，可搜索「扩展」或「Finder」。
3. 在「菜单设置」检查作用范围，打开范围内的文件夹，在空白处或文件上右键，即可使用「右键助手」。
4. 添加打开方式或修改模板后，重新打开右键菜单查看更新。

如菜单未出现，检查扩展开关、应用中的菜单开关与目录范围，关闭并重新打开 Finder 窗口。模板或打开方式修改后，重新打开右键菜单即可读取最新设置。

## 选择终端工具

打开「菜单设置 → 终端工具」，在「默认终端」下拉框选择终端。系统终端始终可选，已安装的 Ghostty、iTerm2、Warp 会自动出现在列表中；「选择其他…」可添加指定的 `.app`。使用「试用…」选择一个文件夹，确认该终端能在目标目录打开。修改后自动保存，Finder 菜单会显示「在 Ghostty 中打开」等对应名称。

系统终端、Ghostty 和 iTerm2 使用原生文件夹 URL；Warp 使用官方 [URI Scheme](https://docs.warp.dev/terminal/more-features/uri-scheme)，兼容 Warp Preview。路径通过 URL 传递，不拼接或执行 `cd` 命令，不需要自动化权限。Ghostty 的目录接收行为可见其 [官方实现](https://github.com/ghostty-org/ghostty/blob/v1.3.1/macos/Sources/App/macOS/AppDelegate.swift)。其他终端需自行支持接收文件夹，单纯启动应用不等于已进入目标目录；如不支持，可用「选择其他…」改选兼容终端。配置中的应用被移动或删除时会提示重新选择。

## 权限与配置保存

主应用使用常规桌面应用权限；Finder 扩展启用 App Sandbox。默认将设置保存在主程序的偏好域 `com.youjianzhushou.app`，扩展通过 `com.apple.security.temporary-exception.shared-preference.read-only` 仅读取该域。文件操作交给主程序执行。无需为这些功能开启完全磁盘访问或自动化权限；系统保护目录仍按 macOS 的访问规则处理。

1.0.0–1.0.2 的本地临时签名构建曾直接使用 App Group。macOS 15 起对 App Group 容器实施保护，未经有效签名授权的访问可能反复出现“想访问其他 App 的数据”提示。1.0.3 的默认构建不访问该容器。读取单个偏好域的权限遵循 Apple 的 [共享偏好域说明](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)。

升级本地旧版本时，退出主程序后执行一次：

```sh
./scripts/migrate-local-settings.sh
```

此脚本仅迁移本工具旧 App Group 中的模板、应用及菜单设置；已有新版设置时不覆盖，旧配置保留。主程序运行时不会反复尝试访问旧容器。全新使用无需迁移。

## 开发者签名与 App Group

默认的偏好域模式可用于本机开发；对外分发仍需有效的 Developer ID 签名与公证。Mac App Store 对 temporary-exception 权限有额外审核要求，正式产品可改用正确签名的 App Group。

有 Apple Developer 签名证书时，可显式选择 App Group 模式，并使用 macOS 支持的 `团队 ID.组名` 格式：

```sh
SIGNING_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)" \
TEAM_ID="XXXXXXXXXX" \
APP_GROUP_ID="XXXXXXXXXX.com.youjianzhushou.shared" \
SETTINGS_STORAGE=app-group \
./scripts/build.sh
```

请将示例中的证书名和 10 位团队 ID 替换为自己的值。脚本会同步修改两份 Info.plist 和 entitlements，移除本地模式的只读偏好域权限。脚本禁止使用 ad-hoc 签名构建 App Group 模式，以避免重复权限提示。这两种模式的配置存储独立。

如使用注册的 `group.*` 形式，需要在 Apple Developer 后台配置对应 App Group 和两个 App ID；按签名环境提供匹配的 provisioning profiles。脚本支持 `APP_PROVISIONING_PROFILE` 与 `EXTENSION_PROVISIONING_PROFILE` 两个文件路径变量。宿主 Bundle ID 为 `com.youjianzhushou.app`，扩展为 `com.youjianzhushou.app.FinderExtension`。

对外分发还需要合适的 Developer ID 签名与公证，本脚本未执行公证。相关规则见 Apple 的 [App Groups 文档](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)、[macOS App Group 访问说明](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)及 [Finder Sync 指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html)。

## 验证

```sh
./scripts/test.sh
codesign --verify --strict --deep --verbose=2 "build/右键助手.app"
```

`test.sh` 使用 Swift 编译器运行核心行为检查，只需 Command Line Tools。安装完整 Xcode 的环境还可运行 `swift test` 执行 XCTest 测试。

当前版本已通过 119 项核心及菜单回调检查，其中包括独立进程读取配置、配置刷新、拒绝扩展写入、终端配置兼容及特殊路径编码。已通过完整应用构建和签名校验。本机验证了两次退出重启无“访问其他 App 数据”提示、Finder 设置同步、实际创建 Markdown 并交给 Code 打开；迁移后的设置与旧配置完全一致。外部应用可能有自己的文件信任或格式提示，需要按该应用的规则处理。

1.0.5 增加默认终端配置和「试用…」。本机已通过 Finder 实际调用 Ghostty 1.3.1，检查其 shell 工作目录确为包含中文、空格、`&` 和 `#` 的目标文件夹；配置退出重启后保留，后台调用没有显示助手主窗口。iTerm2 与 Warp 未安装，分别核对官方接口及验证 URL 编码，没有进行本机运行验证。

1.0.4 修复右键操作自动打开主窗口：主窗口改为按需创建，Finder 请求携带后台启动标记。冷启动新建只显示命名框，复制路径和 Code 打开在后台执行；关闭设置后再操作也不重新打开窗口。直接启动应用或点击 Finder 菜单的「设置…」正常显示主窗口。后台操作失败时只显示错误对话框。

1.0.3 修复本地构建重复请求访问其他 App 数据的问题：默认使用主程序偏好域，扩展只读该配置，移除未使用的自动化权限。提供一次性旧配置迁移脚本。

1.0.2 移除了右键菜单及打开方式子菜单中的分隔项，避免它们在 Finder 中显示为大片空白。

1.0.1 修复了 Finder 菜单点击无响应：Finder 跨进程复制菜单时不会保留 `representedObject`，现在使用菜单 `tag` 查找扩展中保存的操作请求。回归检查覆盖复制后的菜单项、多个菜单上下文、缓存过期和容量淘汰；点击与主程序接收操作均有系统日志，便于定位调用问题。

重新构建后，退出并重新打开主应用以使用最新版本。已启用的 Finder 扩展若仍显示旧菜单，可先关闭并重新打开 Finder 窗口。

完整使用验证：

- 创建 Markdown 文件，检查模板内容；再次使用同名创建，确认原文件保留。
- 添加一个本机应用，选择测试文件，确认由指定应用打开。
- 启用 Finder 扩展后，在菜单作用范围内右键新建文件。
- 修改模板名称或应用列表，确认 Finder 右键菜单同步更新。
- 测试包含空格和中文的路径、多选项目、复制路径与打开终端。

前两项可以在主应用中验证；Finder 集成需要本机扩展开关已开启。App Group 模式另需匹配的签名配置。

## 代码结构

| 路径 | 内容 |
| --- | --- |
| `Sources/FinderHelper` | 主窗口、模板及应用管理、文件操作 |
| `Sources/FinderHelperCore` | 数据模型、配置存储、文件创建、URL 请求协议 |
| `Sources/FinderExtension` | Finder 菜单和扩展入口 |
| `Tests/FinderHelperCoreTests` | 核心行为测试 |
| `Resources` | 应用及扩展的 plist、entitlements |
| `scripts/build.sh` | 编译、打包和签名 |
| `scripts/test.sh` | 不依赖 XCTest 的核心行为检查 |
| `scripts/migrate-local-settings.sh` | 一次性保留旧版配置，不覆盖新版配置 |
| `scripts/generate-icon.swift` | 原生矢量应用图标生成 |
