# Building and Running on Windows

> **中文版 / Chinese:** [WINDOWS.zh_CN.md](WINDOWS.zh_CN.md)

Upstream documents macOS and Linux as supported build hosts; **Windows is best-effort**. This guide covers building `xai-grok-pager` on Windows (MSVC), local setup, and using `XAI_API_KEY` with [x.ai Chat Completions](https://docs.x.ai/developers/rest-api-reference/inference/chat#chat-completions).

**Typical environment:** Windows 10/11, PowerShell, Visual Studio 2022 (MSVC), `rustup`.

**Helper scripts:** [`script/windows/`](script/windows/) (see [§3](#3-helper-scripts-recommended)).

---

## 1. Prerequisites

| Dependency | Notes |
|------------|--------|
| **Rust** | Pinned by [`rust-toolchain.toml`](rust-toolchain.toml); `rustup` installs it on first build |
| **MSVC linker** | Visual Studio 2022 (or Build Tools) with “Desktop development with C++” |
| **Native Windows `protoc`** | Repo [`bin/protoc`](bin/protoc) is a [dotslash](https://dotslash-cli.com) launcher and **does not declare a Windows platform**; install a real `protoc.exe` |

### 1.1 Install Windows `protoc` (29.3, matches the repo pin)

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

### 1.2 Windows source fix in this tree

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

---

## 3. Helper scripts (recommended)

From the repo root in PowerShell:

| Script | Purpose |
|--------|---------|
| [`script/windows/install-protoc.ps1`](script/windows/install-protoc.ps1) | Download/install `protoc` 29.3 under `%LOCALAPPDATA%` |
| [`script/windows/env.ps1`](script/windows/env.ps1) | Set `PROTOC`, `RUSTFLAGS` (rust-lld, no debuginfo, large stack) for the current session |
| [`script/windows/install-cargo-config.ps1`](script/windows/install-cargo-config.ps1) | Write user `%USERPROFILE%\.cargo\config.toml` (persistent; not committed) |
| [`script/windows/build.ps1`](script/windows/build.ps1) | `cargo build -p xai-grok-pager-bin` (supports `-Release`) |
| [`script/windows/run.ps1`](script/windows/run.ps1) | Run the built exe, or `cargo run` with `-Build` |
| [`script/windows/use-api-key.ps1`](script/windows/use-api-key.ps1) | Point this session at api.x.ai + remind to logout of OAuth |

Examples:

```powershell
.\script\windows\install-protoc.ps1
.\script\windows\build.ps1
.\script\windows\build.ps1 -Release
.\script\windows\run.ps1
.\script\windows\run.ps1 -Build -- --help
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

## 5. Running a prebuilt binary

Linker env vars only affect **compilation**. To run:

```powershell
.\target\debug\xai-grok-pager.exe
.\target\debug\xai-grok-pager.exe --help
.\script\windows\run.ps1 "fix the bug"
.\script\windows\run.ps1 -- --cwd D:\some\project
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
