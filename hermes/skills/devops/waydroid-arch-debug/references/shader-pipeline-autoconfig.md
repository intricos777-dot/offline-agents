<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
# Shader Pipeline Auto-Config & Self-Healing Scripts

## Scripts

Three scripts live in `~/games/waydroid-issues/scripts/`:

| Script | Purpose | Modes |
|---|---|---|
| `auto_config.sh` | Bash auto-configurator for local game builds | diagnose, heal, recode, full |
| `self_debug.py` | Python wrapper with GameProfile, crash monitoring, self-recode | --diagnose, --heal, --launch, --status |
| `shader_cache_manager.py` | Proton shader cache manager | --diagnose, --heal, --launch, --recode |

## auto_config.sh Usage

```bash
bash auto_config.sh <game> [mode]
# Games: 2ship2harkinian twilight-elysium loz-majoras-mask
# Modes: full (default) | diagnose | heal | recode
```

## self_debug.py Usage

```bash
python3 self_debug.py <game> --diagnose|--heal|--launch|--recode|--status
python3 self_debug.py --list          # known games
python3 self_debug.py --status        # all game states
```

## shader_cache_manager.py Usage

```bash
python3 shader_cache_manager.py <game> --diagnose|--heal|--launch
python3 shader_cache_manager.py --list-games
```

## Per-Game Adaptation

### 2ship2harkinian
- Detects missing `tinyxml2`, `opusfile` packages → auto-installs
- Detects stale CMake cache with `Projects/` path mismatch → regenerates
- Requires `ninja` (installs if missing)
- Rebuilds with `ninja` if `build.ninja` exists, `make` if `Makefile`, else `cmake --build`

### Twilight Elysium
- Creates `assets/shaders/` with default GLSL `.vert`/`.frag` if missing
- Sets `TE_SHADER_PATH` and `TE_SHADER_CACHE` env vars
- Rebuilds with cmake + ninja

### LoZ Majora's Mask
- Detects stale CMake cache with `Projects/` path mismatch → regenerates
- Rebuilds with ninja

### Steam/Proton Games
- Creates per-appid shader cache dirs in `~/.local/share/Steam/steamapps/shadercache/`
- Writes `user_settings.py` with `PROTON_ENABLE_SHADER_CACHE=1`
- Sets `DXVK_STATE_CACHE`, `VKD3D_SHADER_CACHE` env vars

## Self-Healing Patterns

1. **Stale CMake cache**: `CMakeCache.txt` references old `Projects/` path → delete cache, reconfigure with correct source path
2. **Missing build tools**: `ninja` not installed → `sudo pacman -Sy --needed ninja`
3. **Missing shared libs**: `ldd` shows `not found` → `sudo pacman -Sy --needed <pkg>`
4. **Missing shader assets**: `assets/shaders/` absent → create dir + default GLSL passthrough shaders
5. **Stale build.ninja**: Delete `CMakeCache.txt` and `CMakeFiles/`, reconfigure

## Pitfalls

- **CMake generator mismatch**: If `build.ninja` exists but `ninja` is not installed, `cmake --build` fails with "No rule to make target 'Makefile'". Fix: install ninja or delete cache and reconfigure with `-G Unix Makefiles`.
- **nlohmann_json missing**: 2ship2harkinian's libultraship deps require `nlohmann-json` AUR package. If cmake fails with "Could not find nlohmann_json", install it first.
- **Proton Experimental user_settings.py**: Must be named exactly `user_settings.py` (not `.sample`) and placed in the Proton tools dir. Content is Python dict assigned to `user_settings` variable.
- **Shader cache dirs are per-appid**: Steam creates them on first launch. Pre-creating them avoids first-launch delays but sizes remain 0 until shaders compile.
- **self_debug.py `_load_profiles` / `_load_persisted_profiles`**: Two separate methods — the first creates default GameProfiles, the second loads persisted crash/launch data from JSON. Do not merge into one method or the defaults get overwritten by stale JSON.