# TerMost - Android SSH Client (Rust + Flutter)

基于 **Flutter (Material Design 3)** 与 **Rust (`russh` + `ssh-key`)** 构建的高性能 Android 现代化 SSH 终端客户端。

---

## 🌟 核心特性

- 🎨 **Material Design 3 风格**:
  - 遵循 Google MD3 规范设计，支持浅色/深色主题动态自适应。
  - 现代化卡片、底部导航栏 (`NavigationBar`)、带状态角标的会话指示器。
  - 针对移动端定制的**快捷辅助键盘工具栏**（支持 `ESC`、`TAB`、`CTRL`、`ALT`、方向键 `↑` `↓` `←` `→`、`Ctrl+C/D/Z/L`、`|`、`~` 等特殊符号）。
- 🔑 **强大的密钥生成与管理系统**:
  - **密钥生成**: 支持 **Ed25519**（推荐、高效安全）、**RSA 2048/4096**、**ECDSA (NIST P-256)**。
  - **口令保护 (Passphrase)**: 支持标准 OpenSSH 私钥加密与解密。
  - **一键部署**: 自动生成标准 OpenSSH 公钥与 SHA-256 指纹，提供一键复制功能（可直接粘贴至远程服务器 `~/.ssh/authorized_keys`）。
  - **私钥导入**: 支持从剪贴板导入 OpenSSH / PEM 格式私钥并自动识别算法与校验口令。
- 🖥️ **多会话终端仿真**:
  - 采用高性能异步管道，支持多会话标签页无缝切换。
  - 基于 `xterm.dart`，完美渲染 256 色 ANSI 及终端交互。
  - 支持 PTY 窗口自适应调整 (`window_change_request`) 与字体缩放。
- 🌐 **全功能端口转发 (SSH Tunneling)**:
  - **本地转发 (`-L local_port:remote_host:remote_port`)**: 在 Android 本地监听端口，通过 SSH 加密隧道转发至远程内网服务（如访问远程内网数据库、面板）。
  - **动态转发 (`-D local_port` SOCKS5 代理)**: 在 Android 本地启动 SOCKS5 代理，所有流量经 SSH 节点中继。
  - **远程转发 (`-R remote_port:local_host:local_port`)**: 在远程服务器监听端口并穿透至本地。
  - **实时监控面板**: 一键启停各个转发规则，实时统计上传与下载流量（B / KB / MB / GB）。

---

## 🏗️ 架构设计

```
TerMost/
├── android/                   # Android 工程配置 (支持 arm64-v8a, armeabi-v7a, x86, x86_64)
├── rust/                      # Rust 核心引擎
│   ├── Cargo.toml             # 依赖 russh, ssh-key, tokio, flutter_rust_bridge
│   └── src/
│       ├── lib.rs             # 模块导出
│       ├── keys.rs            # 密钥生成、解析、加密与指纹计算
│       ├── session.rs         # russh 异步客户端、PTY 会话与流式输入输出
│       ├── forwarding.rs      # 本地转发、SOCKS5 动态代理、远程转发及流量计数
│       └── api/simple.rs      # Flutter Rust Bridge 接口层
├── lib/                       # Flutter 前端实现 (Material 3)
│   ├── main.dart              # 应用入口、底部导航与多标签状态联动
│   ├── models/                # 主机、密钥、端口转发数据模型
│   │   ├── ssh_host.dart
│   │   ├── ssh_key_entry.dart
│   │   └── port_forward_rule.dart
│   ├── services/              # 业务逻辑与本地持久化
│   │   ├── storage_service.dart
│   │   ├── ssh_service.dart
│   │   └── tunnel_service.dart
│   ├── theme/                 # MD3 配色与终端色彩方案
│   │   └── app_theme.dart
│   ├── widgets/               # 可复用组件与对话框
│   │   ├── virtual_keyboard_bar.dart  # 移动端终端快捷按键辅助栏
│   │   ├── host_form_dialog.dart      # 添加/编辑主机对话框
│   │   ├── key_generate_dialog.dart   # 密钥生成对话框
│   │   ├── key_import_dialog.dart     # 私钥导入对话框
│   │   ├── key_detail_sheet.dart      # 密钥详情与公私钥查看抽屉
│   │   └── tunnel_form_dialog.dart    # 端口转发规则配置对话框
│   └── views/                 # 主界面视图
│       ├── hosts_view.dart            # 主机列表界面
│       ├── terminal_view.dart         # 终端仿真界面
│       ├── keys_view.dart             # 密钥管理界面
│       └── tunnels_view.dart          # 端口转发控制台
└── test/                      # 单元测试
```

---

## 🚀 编译与构建

### 1. 前置依赖
- Flutter SDK >= 3.24
- Rust 工具链 (`rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android`)
- Android NDK
- `cargo-ndk` 及 `flutter_rust_bridge_codegen`

### 2. 代码生成与测试
```bash
# 生成 Rust 与 Flutter 桥接代码
flutter_rust_bridge_codegen generate --no-auto-upgrade-dependency

# 运行 Rust 核心单元测试（密钥生成、加密、解密与解析）
cd rust && cargo test --lib keys::tests

# 运行 Flutter 模型测试
flutter test test/termost_test.dart
```

### 3. 构建 Android 安装包 (APK)
```bash
flutter build apk --debug
# 或构建发布版本
flutter build apk --release
```
编译产物位于 `build/app/outputs/flutter-apk/app-debug.apk`。
