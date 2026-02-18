# AnyRouter Manager

macOS 原生账号管理工具，用于 [AnyRouter](https://anyrouter.top) 多账号余额监控与一键签到。

## 功能

- **多账号管理** — 添加、编辑、启用/禁用多个 AnyRouter 账号
- **余额实时查看** — 当前余额、历史消耗、总额度一目了然
- **一键签到** — 单个签到或批量全部签到
- **菜单栏常驻** — MenuBarExtra 快速查看总余额和各账号状态
- **WAF 自动绕过** — 纯 Swift 实现，无需 JavaScriptCore
- **Cookie 自动解析** — 从 Session Cookie 自动提取用户 ID（Go gob 格式解码）
- **定时刷新** — 可配置自动刷新间隔
- **macOS 通知** — 签到结果推送通知

## 安装

从 [Releases](https://github.com/Nafsae/anyrouter-tools/releases) 下载最新 `AnyRouterManager.dmg`，打开后将 App 拖入 Applications。

> 要求 macOS 14 (Sonoma) 或更高版本。

## 使用

1. 打开 App，点击工具栏 **+** 添加账号
2. 粘贴从浏览器复制的 Session Cookie（`session=...` 中 `=` 后面的部分）
3. App 自动检测用户名和余额
4. 在菜单栏或主窗口查看余额、执行签到

### 获取 Cookie

1. 在浏览器中登录 [anyrouter.top](https://anyrouter.top)
2. 打开开发者工具（F12）→ Application → Cookies
3. 复制 `session` 字段的值

## 项目结构

```
AnyRouterManager/
├── App/
│   └── AnyRouterManagerApp.swift        # 入口，MenuBarExtra + WindowGroup
├── Models/
│   ├── Account.swift                    # SwiftData 账号模型
│   ├── APIModels.swift                  # API 响应模型 + 运行时状态
│   └── ProviderConfig.swift             # Provider 配置定义
├── Services/
│   ├── AnyRouterAPI.swift               # API 层：请求、WAF 绕过、Cookie 解码
│   ├── KeychainService.swift            # Keychain 存取 Session Cookie
│   ├── NotificationService.swift        # macOS 通知
│   └── SchedulerService.swift           # 定时刷新调度
├── ViewModels/
│   ├── AccountListViewModel.swift       # 账号列表 + 刷新/签到逻辑
│   └── AccountFormViewModel.swift       # 添加/编辑账号表单
├── Views/
│   ├── Main/                            # 主窗口视图
│   ├── MenuBar/                         # 菜单栏面板
│   ├── Forms/                           # 账号表单 + Cookie 导入
│   └── Settings/                        # 偏好设置
└── Utils/
    └── Constants.swift                  # 常量定义
```

## 技术栈

| 组件 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 数据持久化 | SwiftData |
| Cookie 存储 | macOS Keychain |
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
