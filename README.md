<p align="center">
  <img src="assets/icon/app_icon.png" width="128" height="128" alt="TerMost Logo" style="border-radius: 26px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);" />
</p>

<h1 align="center">TerMost</h1>

<p align="center">
  <strong>A modern, high-performance SSH terminal emulator and port forwarding toolkit for Android.</strong><br>
  Built with Flutter (Material Design 3) and a pure Rust asynchronous engine (russh + tokio).
</p>

<p align="center">
  <a href="https://github.com/PengweeWang/TerMost/releases"><img src="https://img.shields.io/github/v/release/PengweeWang/TerMost?color=0284c7&label=Release&style=flat-square" alt="Release"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%3E%3D%203.24-02569B?logo=flutter&style=flat-square" alt="Flutter"></a>
  <a href="https://www.rust-lang.org"><img src="https://img.shields.io/badge/Rust-2021%20Edition-black?logo=rust&style=flat-square" alt="Rust"></a>
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-5.0%2B%20(API%2021%2B)-3DDC84?logo=android&logoColor=white&style=flat-square" alt="Android"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-MIT-green.svg?style=flat-square" alt="License"></a>
</p>

---

## Overview

**TerMost** is an open-source Android SSH client designed for mobile DevOps, sysadmins, and developers. By combining the reactive fluidity of **Flutter (Material Design 3)** with the safety and speed of a **pure Rust asynchronous core (`russh` + `tokio`)**, TerMost delivers rock-solid connection reliability and a desktop-grade terminal experience right on your phone.

---

## Key Features

- ⚡ **Pure Rust Engine**: Built entirely on `russh`, `ssh-key`, and `tokio`. Memory-safe, low-latency, and free from OpenSSL C-binding issues.
- 🎨 **Material Design 3 & Nerd Font**: Clean MD3 interface with dark/light themes, embedded **JetBrains Mono Nerd Font** (Powerline & developer icon support), and real-time font scaling.
- ⌨️ **Mobile Auxiliary Keyboard**: Thumb-friendly shortcut bar (`ESC`, `TAB`, `Ctrl`, `Alt`, arrows, pipe, tilde, quick shortcuts) with soft-keyboard return key integration.
- 🖥️ **Top Sliding Console**: Access session switcher, reconnect controls, paste, and screen clearing from a smooth top-sliding panel. Disconnecting retains full scrollback history.
- 🔔 **Android Background Keep-Alive**: Native Foreground Service with persistent notifications and WakeLock prevents SSH sessions and tunnels from disconnecting when switching apps or locking the screen.
- 🔑 **SSH Key Management**: Generate Ed25519, RSA (2048/4096), and ECDSA keys with passphrase encryption. Easily copy public keys, inspect SHA-256 fingerprints, or import private keys.
- 🌐 **Tri-Mode Port Forwarding**: Supports Local (`-L`), Dynamic SOCKS5 (`-D`), and Remote (`-R`) forwarding with real-time bidirectional traffic statistics.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Flutter UI (Material 3)                   │
│   Hosts · Terminal · Key Manager · Port Forwarding Console  │
│   Accessory Keyboard Bar · Top Sliding Session Dialog       │
└──────────────────────────────┬──────────────────────────────┘
                               │
            MethodChannel      │  flutter_rust_bridge
        (KeepAlive & Service)  │     (Zero-Copy FFI)
                               │
         ┌─────────────────────┴─────────────────────┐
         ▼                                           ▼
┌─────────────────────────────────┐   ┌────────────────────────────────┐
│     Android Native Service      │   │        Rust Core Engine        │
│  - KeepAlive Foreground Service │   │  - tokio async runtime         │
│  - Ongoing Notification Status  │   │  - russh client implementation │
│  - WakeLock CPU Management      │   │  - ssh-key crypto routines     │
│  - Background Network Retention │   │  - TCP / SOCKS5 traffic relay  │
└─────────────────────────────────┘   └───────────────┬────────────────┘
                                                      │
                                                      ▼
                                       ┌───────────────────────────────┐
                                       │      Remote SSH Servers       │
                                       │   (Shells & Encrypted Tunnels)│
                                       └───────────────────────────────┘
```

---

## Download

Pre-built APKs for Android are available on the [GitHub Releases](https://github.com/PengweeWang/TerMost/releases) page:

| Architecture | Recommended Devices | Download |
| :--- | :--- | :--- |
| **arm64-v8a** | Modern 64-bit Android phones and tablets (Recommended) | [app-arm64-v8a-release.apk](https://github.com/PengweeWang/TerMost/releases/latest) |
| **armeabi-v7a** | Older 32-bit Android devices | [app-armeabi-v7a-release.apk](https://github.com/PengweeWang/TerMost/releases/latest) |
| **x86_64** | Android Emulators / ChromeOS devices | [app-x86_64-release.apk](https://github.com/PengweeWang/TerMost/releases/latest) |

---

## Building from Source

### Prerequisites
- **Flutter SDK**: `>= 3.24.0`
- **Rust Toolchain**: `>= 1.75.0`
  ```bash
  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
  ```
- **Android SDK & NDK** (`ANDROID_HOME` and `ANDROID_NDK_HOME` configured)
- **flutter_rust_bridge_codegen**:
  ```bash
  cargo install flutter_rust_bridge_codegen
  ```

### Build Steps
```bash
# Clone the repository
git clone https://github.com/PengweeWang/TerMost.git
cd TerMost

# Fetch Flutter dependencies
flutter pub get

# Generate bridge code (if modifying Rust API)
flutter_rust_bridge_codegen generate --no-auto-upgrade-dependency

# Build split APKs
flutter build apk --split-per-abi

# Output artifacts will be located in:
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check out the [issues page](https://github.com/PengweeWang/TerMost/issues).

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

Distributed under the [MIT License](./LICENSE).
