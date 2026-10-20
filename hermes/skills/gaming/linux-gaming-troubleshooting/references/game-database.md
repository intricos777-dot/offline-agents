<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
---
name: game-database
description: Game-specific fixes discovered through crash logs and testing
---
# Game-Specific Fixes Database

## Helldivers 2 (AppID 553850)

### Launch Options (Hybrid GPU)
```
PROTON_ENABLE_NVAPI=1 VK_ICD_FILENAMES=nvidia_icd.json DXVK_ASYNC=1 STEAM_SHADER_CACHE_MAXSIZE=536870912 STEAM_SHADER_CACHE_SIZE=536870912 %command%
```
- `VK_ICD_FILENAMES=nvidia_icd.json` — relative path, Steam resolves to system ICD (absolute path `/usr/share/vulkan/icd.d/nvidia_icd.json` can fail under Steam runtime)
- `PROTON_ENABLE_NVAPI=1` — enables NVIDIA NVAPI for ray tracing
- `DXVK_ASYNC=1` — async shader compilation
- Shader cache env vars prevent recompilation on every launch
- **Remove `--use-d3d11`** if present — conflicts with vkd3d-proton's D3D11 implementation, causes 0xc0000005

### GameGuard nProtect Quirks
- `NxStorage_*.txt` logs in game dir are diagnostic, not crash reports.
- `Unable to query trim descriptor on volume` in NxStorage log is benign GameGuard artifact.
- GameGuard uses ports 28910:28919. If auth fails, check firewall.
- **nProtect auth hang (Error 122)**: Create `GameGuard.des.disabled/` directory in game's `DATA/Win64/` path — some nProtect versions skip auth when this directory exists. Comment out `api.gameguard.net` and `update.gameguard.net` in `/etc/hosts` as backup.

### Crash Dump Analysis
- 5/6 dumps showing `0xc0000005 ACCESS_VIOLATION` = deterministic crash, likely vkd3d-proton multi-GPU enum bug (Proton#7486)
- Check `compatdata/553850/pfx/drive_c/users/steamuser/AppData/Roaming/Arrowhead/Helldivers2/dumps/` for pattern consistency
- If mixed error codes, the crash is environmental (anti-cheat, firewall, Proton version) not GPU-related

### Shader Cache Status
- config.vdf shows ShaderCacheSize=0 for appid 553850 — first launch always recompiles. Normal.
- Shader cache manager tracks 553850; trim script runs every 30min via cron.

## Once Human (No AppID — not in library)

### Symptoms
- Game files exist at `steamapps/common/Once Human/` but no appmanifest.
- Game uses `ccmini/` directory with audio models (`*.model` files).
- `stderror.txt` empty = no crashes yet.

### Fix
- Game was likely installed outside Steam or appmanifest deleted.
- Reinstall via Steam or restore appmanifest from backup.

## RuneScape (AppID 1343400)

### Launcher Architecture
- `bin/win64/rs2client.exe` — actual game binary (Proton/Wine)
- `launcher/rs2client.exe` — native launcher (Steam Runtime)
- `launcher/preferences.cfg` — launcher settings
- `RuneScape/` directory contains js5 cache files (game assets)

### Common Failure Mode
- Empty `bin/win64/` directory = game files never downloaded.
- Launcher will attempt to download from CDN on launch.
- Overlay log shows stuck web auth redirects (`Just a moment...`) = CDN blocked by DNS/proxy.

### Fix
1. Verify game files in Steam (if appmanifest present)
2. If empty, uninstall + reinstall
3. Verify DNS can resolve `content.runescape.com` and `www.runescape.com`

## Old School RuneScape (AppID 1343370)

### Structure
- `bin/win64/` — game binary location (empty = corrupt install)
- Java-based game wrapped in Proton

### Fix
- Empty bin = full reinstall required.

## Undertale (AppID 391540)

### Binary Architecture
- `runner` is **32-bit ELF** (`Intel i386`) — NOT a Windows exe
- `run.sh` sets `LD_LIBRARY_PATH=./lib` and executes `./runner`
- `lib/libsteam_api.so` is 64-bit (Steam integration)
- Game uses `assets/` directory (not `.exe`)

### Required 32-bit Libraries
```
lib32-libX11
lib32-libglvnd
lib32-alsa-lib
lib32-libpulse
lib32-gdk-pixbuf2
lib32-libxi
lib32-libxrandr
lib32-libxrender
lib32-libxtst
```

### Why It Fails
- Steam Runtime provides most libs, but system 32-bit libs may be missing on Arch/Garuda.
- Game silently fails to launch when any 32-bit lib is missing.

## .hack//G.U. Last Recode (AppID 525480)

### Symptoms
- AppID in library but `steamapps/common/hackGU/` directory missing.

### Fix
- Full reinstall via Steam. Saves may exist in `compatdata/525480/pfx/`.

## Buckshot Roulette (AppID 2835570)

### Structure
- Native Linux game: `Buckshot Roulette_linux/Buckshot Roulette.x86_64`
- 64-bit ELF, dynamically linked
- No Proton needed — runs directly

### Verification
- `file` confirms ELF 64-bit LSB executable
- Should launch without Proton/Steam Linux Runtime

## Valheim (AppID 892970)

### Structure
- Native Linux: `valheim.x86_64`
- Uses `valheim_Data/Plugins/` for native libs
- `libsteam_api.so` for Steam integration
- `libparty.so` for multiplayer

### Common Issues
- Missing 32-bit libs don't affect it (native 64-bit)
- If it fails to launch, check Steam Runtime and Vulkan.

## Palia (AppID 2707930)

### Structure
- Windows exe: `PaliaClientSteam.exe`
- Requires Proton
- Large shader cache (~2.8GB) in config.vdf — normal for UE4 games.

## RetroArch (AppID 1118310)

### Structure
- Native Linux: `retroarch` binary
- `cores/` directory with `.so` core files
- `autoconfig/` for controller profiles

### Verification
- `file retroarch` confirms ELF 64-bit
- Cores listed as `.so` shared objects
- Should launch without Proton.