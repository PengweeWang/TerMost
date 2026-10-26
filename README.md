<p align="center">
  <img src="assets/icon/app_icon.png" width="128" height="128" alt="TerMost Logo" style="border-radius: 26px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);" />
</p>

<h1 align="center">TerMost</h1>

<p align="center">
  <strong>现代化、高性能的 Android SSH 终端仿真器与全功能端口转发工具箱</strong><br>
  <i>A modern, high-performance SSH client and port forwarding powerhouse for Android, built with Flutter & pure Rust.</i>
</p>

<p align="center">
  <a href="https://github.com/PengweeWang/TerMost/releases"><img src="https://img.shields.io/github/v/release/PengweeWang/TerMost?color=0284c7&label=Release&style=flat-square" alt="Release"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D%203.24-02569B?logo=flutter&style=flat-square" alt="Flutter"></a>
  <a href="https://www.rust-lang.org"><img src="https://img.shields.io/badge/Rust-2021%20Edition-black?logo=rust&style=flat-square" alt="Rust"></a>
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-5.0%2B%20(API%2021%2B)-3DDC84?logo=android&logoColor=white&style=flat-square" alt="Android"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.style=flat-square" alt="License"></a>
</p>

---

## 📖 简介 / Introduction

**TerMost** 是一款为 Android 平台量身打造的开源 SSH 终端与网络穿透利器。采用 **Flutter (Material Design 3)** 表现层与 **纯 Rust 异步引擎 (`russh` + `tokio`)** 深度结合的现代化跨语言架构。

针对移动端运维、远程开发、跳板机管理及内网穿透等高频场景，TerMost 摒弃了传统终端工具在移动设备上的卡顿、掉线与输入体验不适，提供了极佳的连接稳定性与桌面级的终端操控体验。

---

## 🌟 核心特性 / Features

### ⚡ 纯 Rust 协议核心 (Pure Rust Engine)
- **内存安全与超强性能**：完全基于异步 `russh`、`ssh-key`、`tokio` 打造，摆脱对 OpenSSL / libssh2 的传统 C 动态库绑定依赖。
- **低延迟高吞吐**：流式管道通信，支持瞬时大量终端字符滚屏而不卡顿 UI。
- **心跳守护**：原生集成 15 秒客户端心跳保活检测，防止 NAT 超时静默断链。

### 🎨 Material Design 3 沉浸式终端视界
- **MD3 规范设计**：自适应浅色与深色主题，流畅优雅的交互反馈。
- **内置 Nerd Font 字体**：集成嵌入 **JetBrains Mono Nerd Font**，完美显示各种开发图标、Git 分支分支符、Powerline 箭头及 Zsh 主题符号。
- **自定义终端字号**：可在控制台中实时动态无极缩放字号（9~24 pt）。
- **优化行末格式**：主动向远程 PTY 宣告终端精准行列数与 POSIX 终端模式，消除 zsh 等 shell 常见的末尾 `%` 换行标记问题。

### ⌨️ 移动端专属辅助键盘栏 & 顶部控制台
- **底部辅助键盘栏**：
  - 针对大拇指触控优化，高频支持 `ESC`、`TAB`、`CTRL`、`ALT`、方向键（`↑` `↓` `←` `→`）、`Ctrl+C/D/Z/L`、`|`、`~`、`/`、`-`、`_`、`:`、`$`、`;` 及收起键盘。
  - 深度本地化定制输入引擎，彻底规避国产 ROM（HyperOS / MIUI / ColorOS 等）安全键盘的错误唤起，支持软键盘回车键自然提交。
- **顶部下滑控制台 (Top Sheet)**：
  - 辅助键盘栏左侧常驻【控制台】按键，集成会话连接状态指示灯（🟢已连接 / 🟡连接中 / 🔴已断开）与多会话数字徽标；
  - 点击后从屏幕上方优雅滑出控制面板，支持多会话水平切换、一键清屏、文本粘贴及新建连接。
  - **断网保留历史**：网络中断或主动断开时，屏幕文字历史与回滚缓冲区完整保留；控制台智能切换为【重新连接】与【关闭会话标签页】按键。

### 🔔 Android 原生前台保活服务 (Background Keep-Alive)
- **切屏/息屏防断连**：内置 Android 原生 `Foreground Service`，持有部分轻量唤醒锁（WakeLock）。
- **活动感知常驻通知**：当存在活跃的 SSH 会话或后台端口转发隧道时，系统通知栏显示常驻服务，切入其他 App 或息屏挂起任务时网络与 CPU 绝不被系统挂起中断。
- **自动资源回收**：当全部会话与端口转发关闭后，保活服务与通知自动平滑退出。

### 🔑 全功能 SSH 密钥中心
- **多算法密钥生成**：
  - **Ed25519**（推荐：现代极速、极小尺寸、军工级安全性）；
  - **RSA 2048 / 4096**（传统兼容性最佳）；
  - **ECDSA (NIST P-256)**。
- **口令加密保护 (Passphrase)**：支持基于标准 OpenSSH KDF 派生加密私钥。
- **一键部署公钥**：自动计算 OpenSSH 标准公钥字符串与 SHA-256 指纹，提供一键复制功能，可直接写入目标机 `~/.ssh/authorized_keys`。
- **私钥导入**：支持从剪贴板一键导入已有私钥并校验口令。

### 🌐 三合一全能端口转发 (SSH Tunneling)
- **本地端口转发 (`-L local_port:remote_host:remote_port`)**：
  - 在 Android 设备监听本地端口，安全穿透访问内网 Web 控制台、MySQL/Redis 等私有数据库。
- **动态代理转发 (`-D local_port` SOCKS5)**：
  - 在手机端启动轻量级标准 RFC 1928 SOCKS5 代理服务，所有网络请求通过 SSH 远程节点中继。
- **远程反向转发 (`-R remote_port:local_host:local_port`)**：
  - 将手机本地或局域网服务反向暴露到远程服务器的指定端口。
- **实时流量监控面板**：实时精准统计各隧道上传与下载的物理字节数，支持单规则一键独立启停。

---

## 🏗️ 架构概览 / Architecture

```
                   ┌──────────────────────────────────────────────┐
                   │           Flutter UI (Material 3)            │
                   │  Hosts · TerminalView · Keys · Tunnels       │
                   │  VirtualKeyboardBar · Top Console Dialog     │
                   └──────────────────────┬───────────────────────┘
                                          │
                         MethodChannel    │  flutter_rust_bridge
                    (KeepAlive & Service) │     (Zero-Copy FFI)
                                          │
               ┌──────────────────────────┴──────────────────────────┐
               ▼                                                     ▼
┌───────────────────────────────┐         ┌─────────────────────────────────────┐
│    Android Native Platform    │         │          Rust Core Engine           │
│  - KeepAliveService           │         │  - tokio 异步多任务运行时            │
│  - Ongoing Notification       │         │  - russh SSH 2.0 客户端实现         │
│  - PowerManager WakeLock      │         │  - ssh-key 密钥算法生成/加解密       │
│  - Network State Keeper       │         │  - TCP / SOCKS5 双向数据中继中枢    │
└───────────────────────────────┘         └──────────────────┬──────────────────┘
                                                             │
                                                             ▼
                                                ┌─────────────────────────┐
                                                │   Remote SSH Servers    │
                                                │  (Interactive Shells    │
                                                │   & Encrypted Tunnels)  │
                                                └─────────────────────────┘
```

---

## 📱 界面预览 / Screenshots

| 主机列表与连接管理 | 沉浸式终端与辅助键盘 | 顶部滑出式会话控制台 |
| :---: | :---: | :---: |
| 现代化卡片、搜索筛选、一键连接 | JetBrains Mono 字体、快捷辅助栏 | 会话无缝切换、字号调节、重连断开 |

| SSH 密钥生成与管理 | 密钥详情与指纹展示 | 三合一端口转发控制台 |
| :---: | :---: | :---: |
| Ed25519 / RSA / ECDSA 算法 | 一键复制公钥、Passphrase 解密 | 本地/动态SOCKS5/远程转发、流量监控 |

---

## 📥 下载安装 / Download

访问 [GitHub Releases 页面](https://github.com/PengweeWang/TerMost/releases) 下载最新版本的 APK：

| 架构 / ABI | 推荐设备 | 下载链接 |
| :--- | :--- | :--- |
| **arm64-v8a** | 现代绝大多数 64 位 Android 手机与平板（推荐） | [app-arm64-v8a-release.apk](https://github.com/PengweeWang/TerMost/releases/latest) |
| **armeabi-v7a** | 老旧 32 位 Android 设备 | [app-armeabi-v7a-release.apk](https://github.com/PengweeWang/TerMost/releases/latest) |
| **x86_64** | Android 模拟器 / ChromeOS / x86 平板 | [app-x86_64-release.apk](https://github.com/PengweeWang/TerMost/releases/latest) |

---

## 🛠️ 本地编译与构建 / Building from Source

### 1. 前置依赖环境
- **Flutter SDK**：`>= 3.24.0`
- **Rust 工具链**：`>= 1.75.0`
  ```bash
  # 安装 Android 目标交叉编译架构
  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
  ```
- **Android SDK & NDK**：已配置好 `ANDROID_HOME` 与 `ANDROID_NDK_HOME`
- **代码生成工具**：
  ```bash
  cargo install flutter_rust_bridge_codegen
  ```

### 2. 获取代码与生成绑定
```bash
# 克隆仓库
git clone https://github.com/PengweeWang/TerMost.git
cd TerMost

# 安装 Flutter 依赖
flutter pub get

# 生成 Rust 与 Flutter 桥接代码 (如有修改 Rust API)
flutter_rust_bridge_codegen generate --no-auto-upgrade-dependency
```

### 3. 运行测试
```bash
# 运行 Rust 底层密钥测试
cd rust && cargo test --lib keys::tests && cd ..

# 运行 Flutter 单元测试
flutter test
```

### 4. 构建 Release 安装包
```bash
# 推荐：构建架构独立分割包 (APK 体积更小)
flutter build apk --split-per-abi

# 产物输出路径：
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🤝 贡献指南 / Contributing

欢迎提交 Issue 与 Pull Request！

1. Fork 本仓库并新建分支（如 `feature/amazing-feature`）；
2. 提交您的修改，并确保遵循代码风格（运行 `flutter analyze lib/` 及 `cargo check`）；
3. 发起 Pull Request 并详细说明变更背景与测试情况。

---

## 📄 开源许可证 / License

本项目采用 [MIT License](./LICENSE) 开源许可证。欢迎自由使用、学习与商业化。
