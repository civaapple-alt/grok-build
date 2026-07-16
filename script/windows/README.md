# Windows helper scripts (`script/windows`)

> **中文版 / Chinese:** [README.zh_CN.md](README.zh_CN.md)

PowerShell helpers for building and running `xai-grok-pager` on Windows MSVC.

- Full guide (English): [`../../WINDOWS.md`](../../WINDOWS.md)
- Full guide (中文): [`../../WINDOWS.zh_CN.md`](../../WINDOWS.zh_CN.md)

Run all commands from the **repo root**. Setup scripts are **idempotent** (safe to re-run).

---

## Typical flow

```powershell
.\script\windows\setup.ps1                  # rust + protoc + check
.\script\windows\setup.ps1 -InstallRustup   # also bootstrap rustup if missing
.\script\windows\build.ps1 -DryRun          # preflight only (no compile)
.\script\windows\build.ps1                  # debug build
.\script\windows\build.ps1 -Release         # release build
.\script\windows\run.ps1                    # cargo run -p xai-grok-pager-bin
.\script\windows\run.ps1 -DebugExe          # prebuilt target\debug\...
.\script\windows\run.ps1 -ReleaseExe        # prebuilt target\release\...
.\script\windows\use-api-key.ps1            # optional: api.x.ai + XAI_API_KEY
```

Bare `cargo run` (must set linker/stack env first — see also WINDOWS.md §2.2):

```powershell
.\script\windows\env.ps1; cargo run -p xai-grok-pager-bin
```

One-liner equivalent to `env.ps1` + `cargo run`:

```powershell
$lld=(rustc --print sysroot).Trim()+'\lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'; $env:PROTOC="$env:LOCALAPPDATA\protoc-29.3\bin\protoc.exe"; $env:CARGO_PROFILE_DEV_DEBUG='0'; $env:CARGO_INCREMENTAL='0'; $env:RUSTFLAGS="-C linker=$lld -C force-unwind-tables=yes -C target-feature=+crt-static -C debuginfo=0 -C link-arg=/STACK:16777216"; cargo run -p xai-grok-pager-bin
```

---

## Scripts in this directory

### `setup.ps1`

One-shot environment prep.

| Step | Action |
|------|--------|
| 1 | `install-rust.ps1` |
| 2 | `install-protoc.ps1` |
| 3 | optional `install-cargo-config.ps1` |
| 4 | `check-tools.ps1` |

**Parameters**

| Switch | Meaning |
|--------|---------|
| `-InstallRustup` | If `rustup` is missing, download/run `rustup-init -y` |
| `-CargoConfig` | Also write user `%USERPROFILE%\.cargo\config.toml` (**affects all Rust projects** on this machine — prefer session `env.ps1` unless you want that) |
| `-ForceProtoc` | Re-download protoc even if already installed |

**Examples**

```powershell
.\script\windows\setup.ps1
.\script\windows\setup.ps1 -InstallRustup
.\script\windows\setup.ps1 -CargoConfig
```

---

### `install-rust.ps1`

Install/verify the toolchain pinned by repo `rust-toolchain.toml` (channel, `rustfmt`, `clippy`).

- Prints `rustup show`, `rustup toolchain list`, `rustc --version`, `cargo --version`, and checks for `rust-lld`
- Safe to re-run (no-op if already installed)

| Switch | Meaning |
|--------|---------|
| `-InstallRustup` | Bootstrap rustup when it is not on `PATH` |

```powershell
.\script\windows\install-rust.ps1
.\script\windows\install-rust.ps1 -InstallRustup
```

---

### `install-protoc.ps1`

Download Windows `protoc` (default **29.3**) into `%LOCALAPPDATA%\protoc-<ver>\` and set `$env:PROTOC` for this session.

Repo `bin/protoc` is a dotslash launcher **without a Windows platform** — you need this native binary.

| Switch / param | Meaning |
|----------------|---------|
| `-Version <ver>` | protoc release (default `29.3`) |
| `-Force` | Re-download/replace even if present |

```powershell
.\script\windows\install-protoc.ps1
.\script\windows\install-protoc.ps1 -Force
```

---

### `check-tools.ps1`

**Read-only** status dump: rustup, rustc/cargo, rust-lld, protoc, VS C++ tools (advisory), current session `RUSTFLAGS` / `PROTOC`.

Does not install anything. Safe anytime.

```powershell
.\script\windows\check-tools.ps1
```

---

### `env.ps1`

Configure **this PowerShell session** for Windows builds (does not write files):

- `$env:PROTOC` → local Windows protoc if found
- `$env:CARGO_PROFILE_DEV_DEBUG=0`, `$env:CARGO_INCREMENTAL=0`
- `$env:RUSTFLAGS` → `rust-lld`, `+crt-static`, `debuginfo=0`, `/STACK:16777216`

Used by `build.ps1` and default `run.ps1`. New terminals need to run it again (unless you used `install-cargo-config.ps1`).

```powershell
.\script\windows\env.ps1
.\script\windows\env.ps1; cargo run -p xai-grok-pager-bin
```

---

### `install-cargo-config.ps1`

Write **user-level** `%USERPROFILE%\.cargo\config.toml` (same linker/stack/`PROTOC` defaults).

**Warning:** applies to **all** `x86_64-pc-windows-msvc` crates for this Windows user, not only this repo. Prefer `env.ps1` for session-only setup.

| Switch | Meaning |
|--------|---------|
| `-Force` | Overwrite (backs up existing file to `.bak-*`) |
| `-ProtocVersion` | Must match installed protoc folder (default `29.3`) |

```powershell
.\script\windows\install-cargo-config.ps1
.\script\windows\install-cargo-config.ps1 -Force
```

---

### `build.ps1`

Build `xai-grok-pager-bin` after applying `env.ps1`.

| Switch | Meaning |
|--------|---------|
| *(default)* | `cargo build -p xai-grok-pager-bin` → `target\debug\xai-grok-pager.exe` |
| `-Release` | `cargo build -p xai-grok-pager-bin --release` → `target\release\xai-grok-pager.exe` |
| `-DryRun` / `-dry-run` | Preflight only: check rustup/rustc/cargo/rust-lld/protoc/`RUSTFLAGS`/MSVC; **no compile**. Exit `0` if OK, `1` if not |

Extra args after `--` are forwarded to cargo.

```powershell
.\script\windows\build.ps1 -DryRun
.\script\windows\build.ps1
.\script\windows\build.ps1 -Release
.\script\windows\build.ps1 -- --verbose
```

---

### `run.ps1`

| Mode | Behavior |
|------|----------|
| **Default** | `env.ps1` then `cargo run -p xai-grok-pager-bin` (Cargo may compile) |
| `-DebugExe` | Run existing `target\debug\xai-grok-pager.exe` only (no cargo; must exist) |
| `-ReleaseExe` | Run existing `target\release\xai-grok-pager.exe` only (no cargo; must exist) |

Build separately with `build.ps1` / `build.ps1 -Release`. Do not use old `-Release` / `-Build` on `run.ps1` (removed).

App args: after `--`, or as remaining arguments.

```powershell
.\script\windows\run.ps1
.\script\windows\run.ps1 -- --help
.\script\windows\run.ps1 "fix the bug"
.\script\windows\run.ps1 -DebugExe
.\script\windows\run.ps1 -ReleaseExe -- --help
```

---

### `use-api-key.ps1`

Prepare this session for **API key** auth against `https://api.x.ai/v1` (not Grok Build free quota).

- Requires `$env:XAI_API_KEY` (or pass `-ApiKey`)
- Sets `$env:GROK_MODELS_BASE_URL` (default `https://api.x.ai/v1`)
- Warns if `~\.grok\auth.json` exists (OAuth session **overrides** the API key)

| Switch / param | Meaning |
|----------------|---------|
| `-ApiKey <key>` | Set `XAI_API_KEY` for this session |
| `-ModelsBaseUrl <url>` | Override models base URL |
| `-Logout` | Try `xai-grok-pager.exe logout`, or delete `auth.json` if no binary |

```powershell
$env:XAI_API_KEY = "xai-..."
.\script\windows\use-api-key.ps1
.\script\windows\use-api-key.ps1 -Logout
.\script\windows\run.ps1
```

---

## Artifacts

| Profile | Path |
|---------|------|
| debug | `target\debug\xai-grok-pager.exe` |
| release | `target\release\xai-grok-pager.exe` |

The exe is portable on 64-bit Windows (no sidecar DLLs with the current `+crt-static` / rust-lld build). Config/auth live under `%USERPROFILE%\.grok\`, not next to the exe.
