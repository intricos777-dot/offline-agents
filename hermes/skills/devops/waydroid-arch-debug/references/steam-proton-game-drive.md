<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
# Steam / Proton Game Drive Errors

## Symptom

`Proton: Error: unable to use parent for game drive, path `

Steam starts but games fail to launch or crash immediately with an empty game drive path.

## Root Cause

The Wine/Proton compatibility data prefix has a broken `libraryfolders.vdf` pointing to a phantom drive letter (`S:\`) instead of the host's actual Steam installation path. Proton can't resolve where game files live.

## Diagnosis

```bash
# Check the problematic Wine prefix libraryfolders
cat ~/.local/share/Steam/steamapps/compatdata/<APPID>/pfx/drive_c/Program\ Files\ \(x86\)/Steam/steamapps/libraryfolders.vdf

# Correct host-side library folders (should point to actual path)
cat ~/.local/share/Steam/steamapps/libraryfolders.vdf
```

If the compatdata version shows `S:\` while the host shows `/home/<user>/.local/share/Steam`, that's the problem.

## Fix

Overwrite the Wine prefix libraryfolders.vdf:
```
"LibraryFolders"
{
    "0"
    {
        "path"    "C:\\Program Files (x86)\\Steam"
    }
}
```

## Additional Steam Overlay Issues

### LD_PRELOAD wrong ELF class

Symptoms: `ERROR: ld.so: object '.../gameoverlayrenderer.so' from LD_PRELOAD cannot be preloaded (wrong ELF class: ELFCLASS32/ELFCLASS64)`

Cause: Stale or architecture-mismatched overlay renderer files in `ubuntu12_32/` and `ubuntu12_64/`.

Fix:
```bash
rm -f ~/.local/share/Steam/ubuntu12_32/gameoverlayrenderer.so
rm -f ~/.local/share/Steam/ubuntu12_64/gameoverlayrenderer.so
```
Then restart Steam and let it redownload the correct overlay binaries.

## Verification

After fixes, launch the game. Confirm:
1. No "unable to use parent for game drive" error in `~/.steam/logs/console-linux.txt`
2. `ld.so` errors about wrong ELF class are gone
3. Game process starts and remains running