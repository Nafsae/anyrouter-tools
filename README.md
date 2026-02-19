# AnyRouter Manager

macOS 原生账号管理工具，用于 [AnyRouter](https://anyrouter.top) 多账号余额监控与一键签到。

## 功能

- **多账号管理** — 添加、编辑、启用/禁用多个 AnyRouter 账号，支持邮箱备注
- **余额实时查看** — 当前余额、历史消耗、总额度一目了然，与网页端一致
- **一键签到** — 单个签到或批量全部签到
- **每日自动签到** — 自定义签到时间，到点自动执行
- **菜单栏常驻** — MenuBarExtra 快速查看总余额和各账号状态
- **WAF 自动绕过** — 纯 Swift 实现，无需 JavaScriptCore
- **Cookie 自动解析** — 从 Session Cookie 自动提取用户 ID（Go gob 格式解码）
- **定时刷新** — 可配置自动刷新间隔（5/15/30/60 分钟）
- **Keychain 安全存储** — 所有 Cookie 统一存储，只需授权一次
- **macOS 通知** — 签到结果推送通知

## 安装

从 [Releases](https://github.com/Nafsae/anyrouter-tools/releases) 下载最新 `AnyRouterManager.dmg`，打开后将 App 拖入 Applications。

> 要求 macOS 14 (Sonoma) 或更高版本。

## 使用

1. 打开 App，点击工具栏 **+** 添加账号
2. 选择 Provider，粘贴 Session Cookie
3. 点击"自动识别"，App 自动检测用户名和余额
4. 可选填写邮箱备注，方便区分多个账号
5. 在菜单栏或主窗口查看余额、执行签到

### 获取 Cookie

1. 在浏览器中登录 [anyrouter.top](https://anyrouter.top)
2. 打开开发者工具（F12）→ Application → Cookies
3. 复制 `session` 字段的值

### 自动签到

1. 打开设置（菜单栏 → AnyRouterManager → 设置）
2. 开启"每日自动签到"
3. 选择签到时间（小时:分钟）
4. App 运行期间会在设定时间自动为所有账号签到

## 项目结构

```
AnyRouterManager/
├── App/
│   └── AnyRouterManagerApp.swift        # 入口，MenuBarExtra + WindowGroup
├── Models/
│   ├── Account.swift                    # SwiftData 账号模型（含邮箱字段）
│   ├── APIModels.swift                  # API 响应模型 + 运行时状态
│   └── ProviderConfig.swift             # Provider 配置定义
├── Services/
│   ├── AnyRouterAPI.swift               # API 层：请求、WAF 绕过、Cookie 解码
│   ├── KeychainService.swift            # Keychain 统一存储所有 Cookie
│   ├── NotificationService.swift        # macOS 通知
│   └── SchedulerService.swift           # 定时刷新 + 每日自动签到调度
├── ViewModels/
│   ├── AccountListViewModel.swift       # 账号列表 + 刷新/签到逻辑
│   └── AccountFormViewModel.swift       # 添加/编辑账号表单
├── Views/
│   ├── Main/                            # 主窗口：列表、行视图、详情
│   ├── MenuBar/                         # 菜单栏下拉面板
│   ├── Forms/                           # 账号表单 + Cookie 导入
│   └── Settings/                        # 偏好设置（刷新间隔、自动签到时间）
└── Utils/
    └── Constants.swift                  # 常量定义
```

## 技术栈

| 组件 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 数据持久化 | SwiftData |
| Cookie 存储 | macOS Keychain（统一 JSON 存储） |
| 网络请求 | URLSession async/await |
| WAF 绕过 | 纯 Swift 算法（字符重排 + XOR） |
| Cookie 解析 | Base64 双层解码 + Go gob 二进制解析 |
| 并发控制 | TaskGroup + AsyncSemaphore（最大 3 并发） |

## 从源码构建

```bash
git clone https://github.com/Nafsae/anyrouter-tools.git
cd anyrouter-tools
xcodebuild -scheme AnyRouterManager -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS=""
open build/Build/Products/Debug/AnyRouterManager.app
```

## License

MIT
