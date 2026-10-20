#!/usr/bin/env bash
# Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work
# offline-agents bootstrap — symlinks all resources into live config paths
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HERMES_HOME="${HOME}/.hermes"
OPENCODE_HOME="${HOME}/.config/opencode"

echo "=== offline-agents bootstrap ==="
echo "Repo: $REPO"

# Hermes skills — symlink each category
echo "[1/5] Hermes skills..."
mkdir -p "$HERMES_HOME/skills"
for dir in "$REPO"/hermes/skills/*/; do
    name=$(basename "$dir")
    target="$HERMES_HOME/skills/$name"
    if [ -L "$target" ]; then
        echo "  symlink exists: $name"
    elif [ -d "$target" ]; then
        echo "  WARNING: $name exists as real dir, skipping (merge manually)"
    else
        ln -s "$dir" "$target"
        echo "  linked: $name"
    fi
done

# Hermes memories
echo "[2/5] Hermes memories..."
mkdir -p "$HERMES_HOME/memories"
if [ ! -e "$HERMES_HOME/memories/MEMORY.md" ]; then
    ln -s "$REPO/hermes/memories/MEMORY.md" "$HERMES_HOME/memories/MEMORY.md"
    echo "  linked: MEMORY.md"
fi

# Hermes bin (tirith, uv, uvx) — only link real, local binaries; never
# follow dangling or cross-user symlinks into another home directory.
echo "[3/5] Hermes bin..."
mkdir -p "$HERMES_HOME/bin"
for bin in tirith uv uvx; do
    src="$REPO/hermes/bin/$bin"
    if [ ! -e "$src" ]; then
        echo "  skip: $bin (missing or dangling — install locally and re-run)"
    elif [ -L "$src" ]; then
        real=$(readlink -f "$src" 2>/dev/null || true)
        case "$real" in
            "$HOME"/*|"$REPO"/*) ;;
            *) echo "  skip: $bin (symlink escapes home: $real)"; continue ;;
        esac
        [ ! -e "$HERMES_HOME/bin/$bin" ] && ln -s "$src" "$HERMES_HOME/bin/$bin" && echo "  linked: $bin"
    else
        [ ! -e "$HERMES_HOME/bin/$bin" ] && ln -s "$src" "$HERMES_HOME/bin/$bin" && echo "  linked: $bin"
    fi
done

# OpenCode config + agent
echo "[4/5] OpenCode config..."
mkdir -p "$OPENCODE_HOME/agent"
if [ ! -e "$OPENCODE_HOME/opencode.jsonc" ]; then
    ln -s "$REPO/opencode/opencode.jsonc" "$OPENCODE_HOME/opencode.jsonc"
    echo "  linked: opencode.jsonc"
fi
if [ ! -e "$OPENCODE_HOME/agent/build.md" ]; then
    ln -s "$REPO/opencode/agent/build.md" "$OPENCODE_HOME/agent/build.md"
    echo "  linked: agent/build.md"
fi

# Ollama modelfiles
echo "[5/5] Ollama modelfiles..."
mkdir -p "${HOME}/.ollama/modelfiles"
if [ ! -e "${HOME}/.ollama/modelfiles/README.md" ]; then
    ln -s "$REPO/ollama/modelfiles" "${HOME}/.ollama/modelfiles/repo"
    echo "  linked: modelfiles"
fi

echo ""
echo "=== bootstrap complete ==="
echo "Hermes skills: $HERMES_HOME/skills/"
echo "OpenCode: $OPENCODE_HOME/"
echo "Ollama: ${HOME}/.ollama/modelfiles/"
echo ""
echo "Restart Hermes gateway to pick up new skills:"
echo "  hermes gateway restart"
