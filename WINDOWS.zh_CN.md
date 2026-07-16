# Windows 从源码编译与运行指南

> **English:** [WINDOWS.md](WINDOWS.md)

上游 README 写明：macOS / Linux 是正式支持的构建主机，**Windows 为 best-effort**。本文整理在 Windows（MSVC）上把本仓库编出 `xai-grok-pager`、配置环境，以及用 `XAI_API_KEY` 走 [x.ai Chat Completions](https://docs.x.ai/developers/rest-api-reference/inference/chat#chat-completions) 的完整步骤。

**适用环境示例：** Windows 10/11、PowerShell、Visual Studio 2022 Community（含 MSVC）、`rustup`。

**辅助脚本：** [`script/windows/`](script/windows/)（见 [§3](#3-辅助脚本推荐)）。

---

## 1. 前置依赖

| 依赖 | 说明 |
|------|------|
| **Rust / rustup** | 由 [`rust-toolchain.toml`](rust-toolchain.toml) 固定 channel（如 `1.92.0` + `rustfmt` / `clippy`） |
| **MSVC 工具链** | Visual Studio 2022（或 Build Tools）+ “使用 C++ 的桌面开发”（头文件/CRT；链接走 `rust-lld`） |
| **protoc（Windows 原生）** | 仓库内 [`bin/protoc`](bin/protoc) 是 [dotslash](https://dotslash-cli.com) 启动器，且**当前未声明 Windows 平台**；本机需自行安装 Windows `protoc.exe` |

### 1.0 一键准备（Rust + protoc）

```powershell
# 本机还没有 rustup：
.\script\windows\setup.ps1 -InstallRustup

# 已有 rustup：
.\script\windows\setup.ps1

# 同时写入用户级 Cargo 配置（持久化链接参数）：
.\script\windows\setup.ps1 -CargoConfig
```

### 1.1 Rust 工具链（`rustup` / `rustc` / `cargo`）

```powershell
.\script\windows\install-rust.ps1
# 首次、没有 rustup：
.\script\windows\install-rust.ps1 -InstallRustup

# 只检查、不安装（可随时重复执行）：
.\script\windows\check-tools.ps1
```

等价手动命令：

```powershell
# 从 https://rustup.rs/ （或 win.rustup.rs）安装 rustup，然后：
rustup toolchain install 1.92.0          # 与 rust-toolchain.toml 中 channel 一致
rustup component add rustfmt clippy --toolchain 1.92.0
rustup toolchain list
rustup show
rustc --version
cargo --version
rustc --print sysroot                    # 其下应有 rust-lld.exe
```

进入仓库目录后，rustup 会按 `rust-toolchain.toml` 自动选用固定工具链。

### 1.2 安装 Windows `protoc`（建议与仓库锁定版本一致：29.3）

```powershell
.\script\windows\install-protoc.ps1
```

或手动安装：

```powershell
$protocDir = "$env:LOCALAPPDATA\protoc-29.3"
$zip = "$env:TEMP\protoc-29.3-win64.zip"
Invoke-WebRequest `
  -Uri "https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-win64.zip" `
  -OutFile $zip
New-Item -ItemType Directory -Force -Path $protocDir | Out-Null
Expand-Archive -Path $zip -DestinationPath $protocDir -Force
& "$protocDir\bin\protoc.exe" --version
# 期望输出: libprotoc 29.3
```

之后每次构建前设置（或写入用户级环境变量 / Cargo 配置）：

```powershell
$env:PROTOC = "$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"
```

解析顺序（见 `xai-proto-build`）：`$PROTOC` → `bin/protoc` → `PATH` 上的 `protoc`。

### 1.3 本仓库对 Windows 的源码修补

`crates/build/xai-proto-build` 在依赖扫描时原先使用 `/dev/stdout`、`/dev/null`（仅 Unix）。本 fork 已改为临时文件，并正确解析 Windows 盘符路径（`C:\...`）下的 makefile 依赖行。没有该修补时，proto codegen 会在 Windows 上失败。

---

## 2. 构建时常见坑与对策

### 2.1 `LNK1318: Unexpected PDB error; LIMIT (12)`

不是业务逻辑错误。大二进制 + MSVC `link.exe` 写 PDB 时容易触发。用 **`rust-lld`**，并关闭 debuginfo：

```powershell
.\script\windows\env.ps1   # 为本会话设置 RUSTFLAGS / PROTOC
```

偶发 PDB 问题时可先杀服务再试（大体量项目往往仍不够，优先 rust-lld）：

```powershell
Stop-Process -Name mspdbsrv -Force -ErrorAction SilentlyContinue
cargo clean -p xai-grok-pager-bin
```

### 2.2 启动时 `STATUS_STACK_OVERFLOW`（`0xC00000FD`）

默认主线程栈对当前二进制偏小。链接时加大栈（例如 16MB）。`script/windows/env.ps1` 已包含：

```text
-C link-arg=/STACK:16777216
```

不要把 `-C` 直接传给 `cargo`（`cargo run -C ...` 会报错）。应写入 `$env:RUSTFLAGS`，或用脚本 / 下面的一行命令。

**不用脚本时裸跑 `cargo run`** — 最短（与 `env.ps1` 同效）：

```powershell
.\script\windows\env.ps1; cargo run -p xai-grok-pager-bin
```

**与 `env.ps1` + `cargo run` 等价的一行：**

```powershell
$lld=(rustc --print sysroot).Trim()+'\lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'; $env:PROTOC="$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"; $env:CARGO_PROFILE_DEV_DEBUG='0'; $env:CARGO_INCREMENTAL='0'; $env:RUSTFLAGS="-C linker=$lld -C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0 -C link-arg=/STACK:16777216"; cargo run -p xai-grok-pager-bin
```

仅加大栈（protoc/`rust-lld` 已就绪时往往够用，仍建议用上面完整一行）：

```powershell
$env:RUSTFLAGS="-C link-arg=/STACK:16777216"; cargo run -p xai-grok-pager-bin
```

若之前已用小栈链接过 exe，设好 `RUSTFLAGS` 后需重新链接一次（`cargo clean -p xai-grok-pager-bin` 再 build/run）。

---

## 3. 辅助脚本（推荐）

在仓库根目录 PowerShell。各脚本详细说明见 [`script/windows/README.md`](script/windows/README.md) · [中文](script/windows/README.zh_CN.md)。

| 脚本 | 作用 |
|------|------|
| [`script/windows/setup.ps1`](script/windows/setup.ps1) | 一键：Rust + protoc（+ 可选 Cargo 配置）+ `check-tools` |
| [`script/windows/install-rust.ps1`](script/windows/install-rust.ps1) | 安装/校验 rustup 与锁定工具链；打印 `toolchain list` / 版本 |
| [`script/windows/check-tools.ps1`](script/windows/check-tools.ps1) | 只读检查：rustup、rustc、cargo、rust-lld、protoc、VS |
| [`script/windows/install-protoc.ps1`](script/windows/install-protoc.ps1) | 下载并安装 `protoc` 29.3 到 `%LOCALAPPDATA%` |
| [`script/windows/env.ps1`](script/windows/env.ps1) | 为本会话设置 `PROTOC`、`RUSTFLAGS`（rust-lld、无 debuginfo、大栈） |
| [`script/windows/install-cargo-config.ps1`](script/windows/install-cargo-config.ps1) | 写入用户级 `%USERPROFILE%\.cargo\config.toml`（持久化；勿提交） |
| [`script/windows/build.ps1`](script/windows/build.ps1) | `cargo build -p xai-grok-pager-bin`（`-Release`，`-DryRun` / `-dry-run` 环境预检） |
| [`script/windows/run.ps1`](script/windows/run.ps1) | 默认：`cargo run -p xai-grok-pager-bin`；`-DebugExe` / `-ReleaseExe` 跑已编译 exe |
| [`script/windows/use-api-key.ps1`](script/windows/use-api-key.ps1) | 本会话指向 api.x.ai，并提示先退出 OAuth 登录 |

示例：

```powershell
.\script\windows\setup.ps1
.\script\windows\check-tools.ps1
.\script\windows\build.ps1
.\script\windows\build.ps1 -DryRun
.\script\windows\build.ps1 -Release
.\script\windows\run.ps1
.\script\windows\run.ps1 -- --help
.\script\windows\run.ps1 -DebugExe
.\script\windows\run.ps1 -ReleaseExe
.\script\windows\use-api-key.ps1   # 然后在同一 shell 中 run.ps1
```

产物路径：

| Profile | 路径 |
|---------|------|
| debug | `target\debug\xai-grok-pager.exe` |
| release | `target\release\xai-grok-pager.exe` |

官方安装包命令名是 `grok`；源码编出的文件名是 `xai-grok-pager.exe`。

---

## 4. 持久化本机 Cargo 配置（勿提交到 git）

```powershell
.\script\windows\install-cargo-config.ps1
```

会写入 `%USERPROFILE%\.cargo\config.toml`（含 rust-lld、栈大小、`PROTOC`）。之后可直接 `cargo build` / `cargo run`，不必每次手动设环境变量。

---

## 5. 运行

```powershell
# 默认：cargo run（设环境，可能触发编译）
.\script\windows\run.ps1
.\script\windows\run.ps1 "fix the bug"
.\script\windows\run.ps1 -- --cwd D:\some\project

# 只跑已编译 exe（不走 cargo；先用 build.ps1 编好）
.\script\windows\run.ps1 -DebugExe
.\script\windows\run.ps1 -ReleaseExe -- --help
.\target\release\xai-grok-pager.exe
```

请在 **Windows Terminal / PowerShell / cmd** 中运行（全屏 TUI）；不要依赖双击 exe。

---

## 6. 认证：避开免费额度，改走 `XAI_API_KEY` / api.x.ai

### 6.1 为什么会提示 free usage limit？

默认 `grok login`（浏览器 OAuth）会写入 `~/.grok/auth.json`，请求走 **Grok Build / grok.com** 订阅与免费额度。  
文档约定：**已登录会话优先于 `XAI_API_KEY`**。因此即使用户环境里配了 key，只要 `auth.json` 还在，仍可能撞免费额度。

参见：[Authentication](crates/codegen/xai-grok-pager/docs/user-guide/02-authentication.md)。

### 6.2 切换到 API Key

```powershell
.\target\debug\xai-grok-pager.exe logout
# 或在 TUI 中输入 /logout，或删除 $env:USERPROFILE\.grok\auth.json

$env:XAI_API_KEY = "xai-..."   # 从 https://console.x.ai 获取
echo $env:XAI_API_KEY          # 确认启动 exe 的同一终端能看到 key

.\script\windows\run.ps1
```

### 6.3 明确指向 `https://api.x.ai/v1`（Chat Completions）

```powershell
.\script\windows\use-api-key.ps1
.\script\windows\run.ps1
```

或写入 `%USERPROFILE%\.grok\config.toml`：

```toml
[endpoints]
models_base_url = "https://api.x.ai/v1"

[model.grok-4]
model = "grok-4"
base_url = "https://api.x.ai/v1"
env_key = "XAI_API_KEY"
```

模型名以 [console.x.ai](https://console.x.ai) / [Chat Completions 文档](https://docs.x.ai/developers/rest-api-reference/inference/chat#chat-completions) 为准（例如 `grok-4`）；默认的 `grok-build` 不一定适用于纯 API 计费路径。

更多：[Custom Models](crates/codegen/xai-grok-pager/docs/user-guide/11-custom-models.md)。

---

## 7. 故障速查

| 现象 | 处理 |
|------|------|
| `LNK1318` / PDB LIMIT | 用 `env.ps1` / Cargo 配置启用 rust-lld + `debuginfo=0` |
| `rustup` / `rustc` 缺失 | `install-rust.ps1 -InstallRustup` 或 `setup.ps1 -InstallRustup` |
| 工具链版本不对/过旧 | `install-rust.ps1`（按 `rust-toolchain.toml` 安装 channel） |
| `bin/protoc` … 不是有效的 Win32 应用程序 / `protoc not found` | `install-protoc.ps1` + `$env:PROTOC` |
| proto build 使用 `/dev/stdout` 失败 | 确认已包含本 fork 对 `xai-proto-build` 的修补 |
| 启动即栈溢出 `0xC00000FD` | 用 `/STACK:16777216` 重新链接（`env.ps1`） |
| hit free usage limit，但已设 `XAI_API_KEY` | `logout` / 删除 `auth.json`；在**同一终端**确认 key 非空 |
| 本终端 `$env:XAI_API_KEY` 为空 | 配置用户环境变量后重开终端，或本会话显式赋值 |

---

## 8. 取舍说明

| 设置 | 影响 |
|------|------|
| `rust-lld` | 绕过 MSVC PDB 限制，大二进制链接更稳 |
| `debuginfo=0` | 调试符号变少，日常跑 TUI 通常足够 |
| `/STACK:16777216` | 增大主线程栈，避免启动栈溢出 |
| `XAI_API_KEY` + logout | 按 x.ai API 用量计费，不再走 Grok Build 免费额度 |

---

## 9. 相关说明

- 官方预编译安装：`irm https://x.ai/cli/install.ps1 | iex`
- 源码构建入口：`cargo … -p xai-grok-pager-bin`
- 上游 Windows best-effort：见 [README.md](README.md)「Building from source」
- 英文版：[WINDOWS.md](WINDOWS.md)
