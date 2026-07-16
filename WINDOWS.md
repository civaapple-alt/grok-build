# Windows 从源码编译与运行指南

上游 README 写明：macOS / Linux 是正式支持的构建主机，**Windows 为 best-effort**。本文整理在 Windows（MSVC）上把本仓库编出 `xai-grok-pager`、配置环境，以及用 `XAI_API_KEY` 走 [x.ai Chat Completions](https://docs.x.ai/developers/rest-api-reference/inference/chat#chat-completions) 的完整步骤。

适用环境示例：Windows 10/11、PowerShell、Visual Studio 2022 Community（含 MSVC）、`rustup` 工具链。

---

## 1. 前置依赖

| 依赖 | 说明 |
|------|------|
| **Rust** | 由根目录 [`rust-toolchain.toml`](rust-toolchain.toml) 固定版本；`rustup` 首次构建会自动安装 |
| **MSVC 链接器** | Visual Studio 2022（或 Build Tools）+ “使用 C++ 的桌面开发” |
| **protoc（Windows 原生）** | 仓库内 [`bin/protoc`](bin/protoc) 是 [dotslash](https://dotslash-cli.com) 启动器，且**当前未声明 Windows 平台**；本机需自行安装 Windows `protoc.exe` |

### 1.1 安装 Windows `protoc`（建议与仓库锁定版本一致：29.3）

在 PowerShell 中：

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

之后每次构建前设置（或写入用户级环境变量 / `.cargo/config.toml`，见下文）：

```powershell
$env:PROTOC = "$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"
```

解析顺序（见 `xai-proto-build`）：`$PROTOC` → `bin/protoc` → `PATH` 上的 `protoc`。

### 1.2 本仓库对 Windows 的源码修补

`crates/build/xai-proto-build` 在依赖扫描时原先使用 `/dev/stdout`、`/dev/null`（仅 Unix）。本 fork 已改为临时文件，并正确解析 Windows 盘符路径（`C:\...`）下的 makefile 依赖行。没有该修补时，proto codegen 会在 Windows 上失败。

---

## 2. 构建时常见坑与对策

### 2.1 `LNK1318: Unexpected PDB error; LIMIT (12)`

不是业务逻辑错误。大二进制 + MSVC `link.exe` 写 PDB 时容易触发。用 **`rust-lld`**，并关闭 debuginfo：

```powershell
$lld = (rustc --print sysroot) + "\lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe"
$env:CARGO_PROFILE_DEV_DEBUG = "0"
$env:CARGO_INCREMENTAL = "0"
$env:RUSTFLAGS = "-C linker=$lld -C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0"
```

偶发 PDB 问题时可先杀服务再试（大体量项目往往仍不够，优先 rust-lld）：

```powershell
Stop-Process -Name mspdbsrv -Force -ErrorAction SilentlyContinue
cargo clean -p xai-grok-pager-bin
```

### 2.2 启动时 `STATUS_STACK_OVERFLOW`（`0xC00000FD`）

默认主线程栈对当前二进制偏小。链接时加大栈（例如 16MB）：

```powershell
# 追加到 RUSTFLAGS
-C link-arg=/STACK:16777216
```

---

## 3. 一键构建 / 运行脚本（推荐）

在仓库根目录 PowerShell：

```powershell
$lld = (rustc --print sysroot) + "\lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe"
$env:PROTOC = "$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"
$env:CARGO_PROFILE_DEV_DEBUG = "0"
$env:CARGO_INCREMENTAL = "0"
$env:RUSTFLAGS = "-C linker=$lld -C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0 -C link-arg=/STACK:16777216"

# 仅构建
cargo build -p xai-grok-pager-bin

# 构建并启动 TUI
cargo run -p xai-grok-pager-bin

# Release（产物更适合日常使用）
cargo build -p xai-grok-pager-bin --release
```

产物路径：

| Profile | 路径 |
|---------|------|
| debug | `target\debug\xai-grok-pager.exe` |
| release | `target\release\xai-grok-pager.exe` |

官方安装包里的命令名是 `grok`；从源码编出的文件名是 `xai-grok-pager.exe`。

---

## 4. 持久化本机 Cargo 配置（勿提交到 git）

写入 `%USERPROFILE%\.cargo\config.toml`（用户级，默认不进仓库）：

```toml
[target.x86_64-pc-windows-msvc]
linker = "rust-lld"
rustflags = [
  "-C", "force-unwind-tables=yes",
  "-C", "target-feature=+crt-static",
  "-C", "debuginfo=0",
  "-C", "link-arg=/STACK:16777216",
]

[env]
PROTOC = { value = "C:\\Users\\<你的用户名>\\AppData\\Local\\protoc-29.3\\bin\\protoc.exe", force = true }
```

也可把 `linker` 写成 `rust-lld.exe` 的绝对路径。设好后可直接：

```powershell
cargo build -p xai-grok-pager-bin
cargo run -p xai-grok-pager-bin
```

---

## 5. 直接运行已编译二进制

环境变量（`RUSTFLAGS` 等）只影响**编译**；运行 exe 不需要再设链接相关变量：

```powershell
cd <仓库根目录>
.\target\debug\xai-grok-pager.exe
.\target\debug\xai-grok-pager.exe --help
.\target\debug\xai-grok-pager.exe "fix the bug"
.\target\debug\xai-grok-pager.exe --cwd D:\some\project
```

请在 **Windows Terminal / PowerShell / cmd** 中运行（全屏 TUI）；不要依赖双击 exe。

---

## 6. 认证：避开免费额度，改走 `XAI_API_KEY` / api.x.ai

### 6.1 为什么会提示 free usage limit？

默认 `grok login`（浏览器 OAuth）会写入 `~/.grok/auth.json`，请求走 **Grok Build / grok.com** 订阅与免费额度。  
文档约定：**已登录会话优先于 `XAI_API_KEY`**。因此即使用户环境里配了 key，只要 `auth.json` 还在，仍可能撞免费额度。

参见用户指南：[Authentication](crates/codegen/xai-grok-pager/docs/user-guide/02-authentication.md)。

### 6.2 切换到 API Key

1. 退出登录（任选其一）：

```powershell
.\target\debug\xai-grok-pager.exe logout
# 或在 TUI 中输入 /logout
# 或: Remove-Item $env:USERPROFILE\.grok\auth.json
```

2. 在**同一个**运行终端确认 key 可见：

```powershell
# 若为空，说明当前进程没继承到用户/系统环境变量，需本会话显式设置
$env:XAI_API_KEY = "xai-你的key"   # 从 https://console.x.ai 获取
echo $env:XAI_API_KEY
```

3. 启动：

```powershell
.\target\debug\xai-grok-pager.exe
```

### 6.3 明确指向 `https://api.x.ai/v1`（Chat Completions）

```powershell
$env:XAI_API_KEY = "xai-你的key"
$env:GROK_MODELS_BASE_URL = "https://api.x.ai/v1"
.\target\debug\xai-grok-pager.exe
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

更多自定义模型说明：[Custom Models](crates/codegen/xai-grok-pager/docs/user-guide/11-custom-models.md)。

---

## 7. 故障速查

| 现象 | 处理 |
|------|------|
| `LNK1318` / PDB LIMIT | 改用 `rust-lld` + `debuginfo=0`（见 §2.1） |
| `bin/protoc` … 不是有效的 Win32 应用程序 / `protoc not found` | 安装 Windows `protoc`，设置 `$env:PROTOC`（见 §1.1） |
| proto build 使用 `/dev/stdout` 失败 | 确认已包含本 fork 对 `xai-proto-build` 的修补 |
| 启动即栈溢出 `0xC00000FD` | `RUSTFLAGS` 加 `-C link-arg=/STACK:16777216` 后重新链接 |
| hit free usage limit，但已设 `XAI_API_KEY` | `logout` / 删除 `auth.json`；在**同一终端**确认 `$env:XAI_API_KEY` 非空 |
| 本终端 `echo $env:XAI_API_KEY` 为空 | 在用户环境变量里配置后重开终端，或本会话 `$env:XAI_API_KEY = "..."` |

---

## 8. 取舍说明

| 设置 | 影响 |
|------|------|
| `rust-lld` | 绕过 MSVC PDB 限制，大二进制链接更稳 |
| `debuginfo=0` | 调试符号变少，日常跑 TUI 通常足够；需要完整调试可尝试 `--release` 或仅对小 crate 用 MSVC + debug |
| `/STACK:16777216` | 增大主线程栈，避免启动栈溢出 |
| `XAI_API_KEY` + logout | 按 x.ai API 用量计费，不再走 Grok Build 免费额度 |

---

## 9. 相关上游说明

- 官方安装（预编译）：`irm https://x.ai/cli/install.ps1 | iex`
- 本仓库源码构建入口：`cargo … -p xai-grok-pager-bin`
- 上游声明 Windows best-effort：见根目录 [README.md](README.md)「Building from source」
