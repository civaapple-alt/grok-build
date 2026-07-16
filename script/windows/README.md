# Windows helper scripts for building and running xai-grok-pager (MSVC).
#
# Docs: ../../WINDOWS.md  |  Chinese: ../../WINDOWS.zh_CN.md
#
# Typical flow:
#   .\script\windows\install-protoc.ps1
#   .\script\windows\build.ps1
#   .\script\windows\run.ps1
#   .\script\windows\use-api-key.ps1   # optional: api.x.ai + XAI_API_KEY
#
# Persist Cargo settings (user profile, not committed):
#   .\script\windows\install-cargo-config.ps1
