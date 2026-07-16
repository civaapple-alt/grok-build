# Building and Running on Windows

> **中文版 / Chinese:** [WINDOWS.zh_CN.md](WINDOWS.zh_CN.md)

Upstream documents macOS and Linux as supported build hosts; **Windows is best-effort**. This guide covers building `xai-grok-pager` on Windows (MSVC), local setup, and using `XAI_API_KEY` with [x.ai Chat Completions](https://docs.x.ai/developers/rest-api-reference/inference/chat#chat-completions).

**Typical environment:** Windows 10/11, PowerShell, Visual Studio 2022 (MSVC), `rustup`.

**Helper scripts:** [`script/windows/`](script/windows/) (see [§3](#3-helper-scripts-recommended)).

---

## 1. Prerequisites

| Dependency | Notes |
|------------|--------|
| **Rust / rustup** | Channel pinned by [`rust-toolchain.toml`](rust-toolchain.toml) (e.g. `1.92.0` + `rustfmt` / `clippy`) |
| **MSVC toolchain** | Visual Studio 2022 (or Build Tools) with “Desktop development with C++” (headers/CRT; linking uses `rust-lld`) |
| **Native Windows `protoc`** | Repo [`bin/protoc`](bin/protoc) is a [dotslash](https://dotslash-cli.com) launcher and **does not declare a Windows platform**; install a real `protoc.exe` |

### 1.0 One-shot setup (Rust + protoc)

```powershell
# If rustup is not installed yet:
.\script\windows\setup.ps1 -InstallRustup

# If rustup already works:
.\script\windows\setup.ps1

# Also write user Cargo config (persistent linker flags):
.\script\windows\setup.ps1 -CargoConfig
```

### 1.1 Rust toolchain (`rustup` / `rustc` / `cargo`)

```powershell
.\script\windows\install-rust.ps1
# first-time machine without rustup:
.\script\windows\install-rust.ps1 -InstallRustup

# read-only status (safe anytime):
.\script\windows\check-tools.ps1
```

Equivalent manual commands:

```powershell
# Install rustup from https://rustup.rs/  (or win.rustup.rs), then:
rustup toolchain install 1.92.0          # match rust-toolchain.toml channel
rustup component add rustfmt clippy --toolchain 1.92.0
rustup toolchain list
rustup show
rustc --version
cargo --version
rustc --print sysroot                    # should contain rust-lld.exe under ...\bin\
```

Entering the repo directory makes rustup auto-select the pinned toolchain via `rust-toolchain.toml`.

### 1.2 Install Windows `protoc` (29.3, matches the repo pin)

```powershell
.\script\windows\install-protoc.ps1
```

Or manually:

```powershell
$protocDir = "$env:LOCALAPPDATA\protoc-29.3"
$zip = "$env:TEMP\protoc-29.3-win64.zip"
Invoke-WebRequest `
  -Uri "https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-win64.zip" `
  -OutFile $zip
New-Item -ItemType Directory -Force -Path $protocDir | Out-Null
Expand-Archive -Path $zip -DestinationPath $protocDir -Force
& "$protocDir\bin\protoc.exe" --version
# Expected: libprotoc 29.3
```

Set before each build (or persist via user env / Cargo config):

```powershell
$env:PROTOC = "$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"
```

Resolution order (`xai-proto-build`): `$PROTOC` → `bin/protoc` → `protoc` on `PATH`.

### 1.3 Windows source fix in this tree

`crates/build/xai-proto-build` previously used `/dev/stdout` and `/dev/null` (Unix-only) when scanning proto dependencies. This fork uses temp files and correctly parses makefile dep lines that start with a Windows drive letter (`C:\...`). Without that patch, proto codegen fails on Windows.

---

## 2. Common build failures

### 2.1 `LNK1318: Unexpected PDB error; LIMIT (12)`

Not a Rust logic bug. Large binaries + MSVC `link.exe` PDB generation often hit this limit. Use **`rust-lld`** and disable debuginfo:

```powershell
.\script\windows\env.ps1   # sets RUSTFLAGS / PROTOC for this session
```

For intermittent PDB issues (often insufficient on this repo; prefer rust-lld):

```powershell
Stop-Process -Name mspdbsrv -Force -ErrorAction SilentlyContinue
cargo clean -p xai-grok-pager-bin
```

### 2.2 Startup `STATUS_STACK_OVERFLOW` (`0xC00000FD`)

Default main-thread stack is too small. Link with a larger stack (e.g. 16MB). `script/windows/env.ps1` already adds:

```text
-C link-arg=/STACK:16777216
```

Do **not** pass `-C` to `cargo` itself (`cargo run -C ...` fails). Put flags in `$env:RUSTFLAGS`, or use the scripts / one-liners below.

**Bare `cargo run` without scripts** — shortest (same effect as `env.ps1`):

```powershell
.\script\windows\env.ps1; cargo run -p xai-grok-pager-bin
```

**One-liner equivalent to `env.ps1` + `cargo run`:**

```powershell
$lld=(rustc --print sysroot).Trim()+'\lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'; $env:PROTOC="$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"; $env:CARGO_PROFILE_DEV_DEBUG='0'; $env:CARGO_INCREMENTAL='0'; $env:RUSTFLAGS="-C linker=$lld -C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0 -C link-arg=/STACK:16777216"; cargo run -p xai-grok-pager-bin
```

Stack-only (often enough if protoc/`rust-lld` are already OK, but prefer the full line above):

```powershell
$env:RUSTFLAGS="-C link-arg=/STACK:16777216"; cargo run -p xai-grok-pager-bin
```

If an older small-stack binary is already linked, re-link once after setting `RUSTFLAGS` (`cargo clean -p xai-grok-pager-bin` then build/run again).

---

## 3. Helper scripts (recommended)

From the repo root in PowerShell. Per-script details: [`script/windows/README.md`](script/windows/README.md) · [中文](script/windows/README.zh_CN.md).

| Script | Purpose |
|--------|---------|
| [`script/windows/setup.ps1`](script/windows/setup.ps1) | One-shot: Rust + protoc (+ optional Cargo config) + `check-tools` |
| [`script/windows/install-rust.ps1`](script/windows/install-rust.ps1) | Install/verify rustup + pinned toolchain; print `toolchain list` / versions |
| [`script/windows/check-tools.ps1`](script/windows/check-tools.ps1) | Read-only probe: rustup, rustc, cargo, rust-lld, protoc, VS |
| [`script/windows/install-protoc.ps1`](script/windows/install-protoc.ps1) | Download/install `protoc` 29.3 under `%LOCALAPPDATA%` |
| [`script/windows/env.ps1`](script/windows/env.ps1) | Set `PROTOC`, `RUSTFLAGS` (rust-lld, no debuginfo, large stack) for the current session |
| [`script/windows/install-cargo-config.ps1`](script/windows/install-cargo-config.ps1) | Write user `%USERPROFILE%\.cargo\config.toml` (persistent; not committed) |
| [`script/windows/build.ps1`](script/windows/build.ps1) | `cargo build -p xai-grok-pager-bin` (`-Release`, `-DryRun` / `-dry-run` preflight) |
| [`script/windows/run.ps1`](script/windows/run.ps1) | Default: `cargo run -p xai-grok-pager-bin`; `-DebugExe` / `-ReleaseExe` run a prebuilt exe |
| [`script/windows/use-api-key.ps1`](script/windows/use-api-key.ps1) | Point this session at api.x.ai + remind to logout of OAuth |

Examples:

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
.\script\windows\use-api-key.ps1   # then run.ps1 in the same shell
```

Artifacts:

| Profile | Path |
|---------|------|
| debug | `target\debug\xai-grok-pager.exe` |
| release | `target\release\xai-grok-pager.exe` |

Official installs ship as `grok`; the source-built binary is `xai-grok-pager.exe`.

---

## 4. Persistent local Cargo config (do not commit)

```powershell
.\script\windows\install-cargo-config.ps1
```

This writes `%USERPROFILE%\.cargo\config.toml` with `rust-lld`, stack size, and `PROTOC`. After that you can use plain `cargo build` / `cargo run` without re-setting env each time.

---

## 5. Running

```powershell
# Default: cargo run (sets env, may compile)
.\script\windows\run.ps1
.\script\windows\run.ps1 "fix the bug"
.\script\windows\run.ps1 -- --cwd D:\some\project

# Prebuilt exe only (no cargo; build first with build.ps1)
.\script\windows\run.ps1 -DebugExe
.\script\windows\run.ps1 -ReleaseExe -- --help
.\target\release\xai-grok-pager.exe
```

Use **Windows Terminal / PowerShell / cmd** (fullscreen TUI). Do not rely on double-clicking the exe.

---

## 6. Auth: free usage limit vs `XAI_API_KEY` / api.x.ai

### 6.1 Why “free usage limit”?

`grok login` (browser OAuth) stores `~/.grok/auth.json` and uses **Grok Build / grok.com** quotas.  
**A signed-in session takes precedence over `XAI_API_KEY`.** If `auth.json` exists, the API key may be ignored.

See [Authentication](crates/codegen/xai-grok-pager/docs/user-guide/02-authentication.md).

### 6.2 Switch to API key

```powershell
.\target\debug\xai-grok-pager.exe logout
# or /logout in the TUI, or remove $env:USERPROFILE\.grok\auth.json

$env:XAI_API_KEY = "xai-..."   # from https://console.x.ai
# ensure the same shell that launches the binary can see the key:
echo $env:XAI_API_KEY

.\script\windows\run.ps1
```

### 6.3 Target `https://api.x.ai/v1` (Chat Completions)

```powershell
.\script\windows\use-api-key.ps1
.\script\windows\run.ps1
```

Or set manually / in `%USERPROFILE%\.grok\config.toml`:

```toml
[endpoints]
models_base_url = "https://api.x.ai/v1"

[model.grok-4]
model = "grok-4"
base_url = "https://api.x.ai/v1"
env_key = "XAI_API_KEY"
```

Model IDs follow [console.x.ai](https://console.x.ai) / the [Chat Completions docs](https://docs.x.ai/developers/rest-api-reference/inference/chat#chat-completions) (e.g. `grok-4`). Default `grok-build` may not apply on a pure API billing path.

More: [Custom Models](crates/codegen/xai-grok-pager/docs/user-guide/11-custom-models.md).

---

## 7. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `LNK1318` / PDB LIMIT | Use rust-lld + `debuginfo=0` via `env.ps1` / Cargo config |
| `rustup` / `rustc` missing | `install-rust.ps1 -InstallRustup` or `setup.ps1 -InstallRustup` |
| Wrong/old toolchain | `install-rust.ps1` (installs channel from `rust-toolchain.toml`) |
| `bin/protoc` not a valid Win32 app / `protoc not found` | `install-protoc.ps1` + `$env:PROTOC` |
| Proto build fails on `/dev/stdout` | Ensure the `xai-proto-build` Windows patch is present |
| Immediate stack overflow `0xC00000FD` | Relink with `/STACK:16777216` (`env.ps1`) |
| Free usage limit despite `XAI_API_KEY` | Logout / delete `auth.json`; verify key in the **same** shell |
| `$env:XAI_API_KEY` empty in this terminal | Re-open terminal after setting user env, or set it in-session |

---

## 8. Trade-offs

| Setting | Effect |
|---------|--------|
| `rust-lld` | Avoids MSVC PDB limits; more reliable linking for large binaries |
| `debuginfo=0` | Fewer debug symbols; fine for daily TUI use |
| `/STACK:16777216` | Larger main stack; avoids startup overflow |
| `XAI_API_KEY` + logout | Bill against x.ai API usage instead of Grok Build free quota |

---

## 9. Related

- Official prebuilt install: `irm https://x.ai/cli/install.ps1 | iex`
- Source package: `cargo … -p xai-grok-pager-bin`
- Upstream Windows note: [README.md](README.md) “Building from source”
- Chinese guide: [WINDOWS.zh_CN.md](WINDOWS.zh_CN.md)
