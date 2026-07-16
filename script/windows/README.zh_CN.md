# Windows 辅助脚本（`script/windows`）

> **English:** [README.md](README.md)

在 Windows MSVC 下编译、运行 `xai-grok-pager` 的 PowerShell 脚本。

- 完整指南（英文）：[`../../WINDOWS.md`](../../WINDOWS.md)
- 完整指南（中文）：[`../../WINDOWS.zh_CN.md`](../../WINDOWS.zh_CN.md)

请在**仓库根目录**执行。准备类脚本均可**反复执行**（幂等）。

---

## 典型流程

```powershell
.\script\windows\setup.ps1                  # rust + protoc + 检查
.\script\windows\setup.ps1 -InstallRustup   # 本机没有 rustup 时一并安装
.\script\windows\build.ps1 -DryRun          # 仅环境预检（不编译）
.\script\windows\build.ps1                  # debug 构建
.\script\windows\build.ps1 -Release         # release 构建
.\script\windows\run.ps1                    # cargo run -p xai-grok-pager-bin
.\script\windows\run.ps1 -DebugExe          # 已有 target\debug\...
.\script\windows\run.ps1 -ReleaseExe        # 已有 target\release\...
.\script\windows\use-api-key.ps1            # 可选：api.x.ai + XAI_API_KEY
```

裸跑 `cargo run`（须先设链接/栈环境，另见 WINDOWS.zh_CN.md §2.2）：

```powershell
.\script\windows\env.ps1; cargo run -p xai-grok-pager-bin
```

与 `env.ps1` + `cargo run` 等价的一行：

```powershell
$lld=(rustc --print sysroot).Trim()+'\lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'; $env:PROTOC="$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"; $env:CARGO_PROFILE_DEV_DEBUG='0'; $env:CARGO_INCREMENTAL='0'; $env:RUSTFLAGS="-C linker=$lld -C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0 -C link-arg=/STACK:16777216"; cargo run -p xai-grok-pager-bin
```

---

## 本目录脚本说明

### `setup.ps1`

一键准备环境。

| 步骤 | 动作 |
|------|------|
| 1 | `install-rust.ps1` |
| 2 | `install-protoc.ps1` |
| 3 | 可选 `install-cargo-config.ps1` |
| 4 | `check-tools.ps1` |

**参数**

| 开关 | 含义 |
|------|------|
| `-InstallRustup` | 没有 `rustup` 时下载并执行 `rustup-init -y` |
| `-CargoConfig` | 同时写入用户级 `%USERPROFILE%\.cargo\config.toml`（**会影响本机所有 Rust 项目**；一般更推荐只用会话级 `env.ps1`） |
| `-ForceProtoc` | 即使已安装也重新下载 protoc |

**示例**

```powershell
.\script\windows\setup.ps1
.\script\windows\setup.ps1 -InstallRustup
.\script\windows\setup.ps1 -CargoConfig
```

---

### `install-rust.ps1`

按仓库 `rust-toolchain.toml` 安装/校验工具链（channel、`rustfmt`、`clippy`）。

- 打印 `rustup show`、`rustup toolchain list`、`rustc --version`、`cargo --version`，并检查 `rust-lld`
- 可反复执行（已安装则基本为 no-op）

| 开关 | 含义 |
|------|------|
| `-InstallRustup` | `PATH` 上没有 rustup 时进行引导安装 |

```powershell
.\script\windows\install-rust.ps1
.\script\windows\install-rust.ps1 -InstallRustup
```

---

### `install-protoc.ps1`

下载 Windows 版 `protoc`（默认 **29.3**）到 `%LOCALAPPDATA%\protoc-<ver>\`，并为本会话设置 `$env:PROTOC`。

仓库内 `bin/protoc` 是 dotslash 启动器且**没有 Windows 平台**，因此需要本机原生二进制。

| 开关 / 参数 | 含义 |
|-------------|------|
| `-Version <ver>` | protoc 版本（默认 `29.3`） |
| `-Force` | 已存在也重新下载替换 |

```powershell
.\script\windows\install-protoc.ps1
.\script\windows\install-protoc.ps1 -Force
```

---

### `check-tools.ps1`

**只读**状态检查：rustup、rustc/cargo、rust-lld、protoc、VS C++ 工具（仅提示）、当前会话 `RUSTFLAGS` / `PROTOC`。

不安装任何东西，可随时执行。

```powershell
.\script\windows\check-tools.ps1
```

---

### `env.ps1`

配置**当前 PowerShell 会话**的 Windows 构建环境（不写文件）：

- `$env:PROTOC` → 若找到本机 Windows protoc
- `$env:CARGO_PROFILE_DEV_DEBUG=0`、`$env:CARGO_INCREMENTAL=0`
- `$env:RUSTFLAGS` → `rust-lld`、`+crt-static`、`debuginfo=0`、`/STACK:16777216`

由 `build.ps1` 与默认的 `run.ps1` 调用。新开终端需再跑一次（除非用过 `install-cargo-config.ps1`）。

```powershell
.\script\windows\env.ps1
.\script\windows\env.ps1; cargo run -p xai-grok-pager-bin
```

---

### `install-cargo-config.ps1`

写入**用户级** `%USERPROFILE%\.cargo\config.toml`（同样的链接器/栈/`PROTOC` 默认值）。

**注意：** 对本 Windows 用户下所有 `x86_64-pc-windows-msvc` 项目生效，不限于本仓库。会话级请用 `env.ps1`。

| 开关 | 含义 |
|------|------|
| `-Force` | 覆盖写入（先备份为 `.bak-*`） |
| `-ProtocVersion` | 需与已安装的 protoc 目录版本一致（默认 `29.3`） |

```powershell
.\script\windows\install-cargo-config.ps1
.\script\windows\install-cargo-config.ps1 -Force
```

---

### `build.ps1`

先执行 `env.ps1`，再构建 `xai-grok-pager-bin`。

| 开关 | 含义 |
|------|------|
| *（默认）* | `cargo build -p xai-grok-pager-bin` → `target\debug\xai-grok-pager.exe` |
| `-Release` | `cargo build -p xai-grok-pager-bin --release` → `target\release\xai-grok-pager.exe` |
| `-DryRun` / `-dry-run` | 仅预检：rustup/rustc/cargo/rust-lld/protoc/`RUSTFLAGS`/MSVC；**不编译**。通过 exit `0`，失败 exit `1` |

`--` 之后的参数会转发给 cargo。

```powershell
.\script\windows\build.ps1 -DryRun
.\script\windows\build.ps1
.\script\windows\build.ps1 -Release
.\script\windows\build.ps1 -- --verbose
```

---

### `run.ps1`

| 模式 | 行为 |
|------|------|
| **默认** | `env.ps1` 后执行 `cargo run -p xai-grok-pager-bin`（Cargo 可能触发编译） |
| `-DebugExe` | 只跑已有的 `target\debug\xai-grok-pager.exe`（不走 cargo；文件必须存在） |
| `-ReleaseExe` | 只跑已有的 `target\release\xai-grok-pager.exe`（不走 cargo；文件必须存在） |

请用 `build.ps1` / `build.ps1 -Release` 单独编译。`run.ps1` 上已移除旧的 `-Release` / `-Build`。

程序参数：跟在 `--` 后面，或作为剩余参数。

```powershell
.\script\windows\run.ps1
.\script\windows\run.ps1 -- --help
.\script\windows\run.ps1 "fix the bug"
.\script\windows\run.ps1 -DebugExe
.\script\windows\run.ps1 -ReleaseExe -- --help
```

---

### `use-api-key.ps1`

为本会话准备走 **API Key** 访问 `https://api.x.ai/v1`（不走 Grok Build 免费额度）。

- 需要 `$env:XAI_API_KEY`（或传 `-ApiKey`）
- 设置 `$env:GROK_MODELS_BASE_URL`（默认 `https://api.x.ai/v1`）
- 若存在 `~\.grok\auth.json` 会警告（OAuth 会话**优先于** API key）

| 开关 / 参数 | 含义 |
|-------------|------|
| `-ApiKey <key>` | 为本会话设置 `XAI_API_KEY` |
| `-ModelsBaseUrl <url>` | 覆盖 models 基址 |
| `-Logout` | 尝试 `xai-grok-pager.exe logout`；若无二进制则删除 `auth.json` |

```powershell
$env:XAI_API_KEY = "xai-..."
.\script\windows\use-api-key.ps1
.\script\windows\use-api-key.ps1 -Logout
.\script\windows\run.ps1
```

---

## 产物

| Profile | 路径 |
|---------|------|
| debug | `target\debug\xai-grok-pager.exe` |
| release | `target\release\xai-grok-pager.exe` |

在当前 `+crt-static` / rust-lld 构建下，exe 可在 64 位 Windows 上单独拷贝运行（无需旁路 DLL）。配置与登录信息在 `%USERPROFILE%\.grok\`，不在 exe 同目录。

版本号形如 `grok 0.1.220-alpha.4 (17b3be3)`：包版本来自 `Cargo.toml`，括号内为编译时的 `git rev-parse --short HEAD`（见 `xai-grok-pager-bin/build.rs`）。
