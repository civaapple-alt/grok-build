# Windows helper scripts for building and running xai-grok-pager (MSVC).
#
# Docs: ../../WINDOWS.md  |  Chinese: ../../WINDOWS.zh_CN.md
#
# Typical flow (all setup scripts are idempotent / safe to re-run):
#   .\script\windows\setup.ps1                  # rust + protoc + check
#   .\script\windows\setup.ps1 -InstallRustup   # also bootstrap rustup
#   .\script\windows\setup.ps1 -CargoConfig     # + user .cargo/config.toml
#   .\script\windows\check-tools.ps1            # read-only status
#   .\script\windows\build.ps1
#   .\script\windows\run.ps1
#   .\script\windows\use-api-key.ps1             # optional: api.x.ai + XAI_API_KEY
#
# Individual installers:
#   .\script\windows\install-rust.ps1
#   .\script\windows\install-protoc.ps1
#   .\script\windows\install-cargo-config.ps1
#   .\script\windows\env.ps1                    # session RUSTFLAGS / PROTOC
