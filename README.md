# offline-agents — Hermes + OpenCode Offline Survival Kit

Private repo for airgap reasoning. All agent resources (skills, templates, configs, Ollama modelfiles) live here so Hermes and OpenCode can reason without a provider.

## Quick Start (offline bootstrap)

```bash
# Clone and bootstrap — symlinks everything into place
git clone https://github.com/intricos777-dot/offline-agents.git ~/offline-agents
cd ~/offline-agents
./scripts/bootstrap.sh
```

After bootstrap:
- Hermes skills load from `~/offline-agents/hermes/skills/` (symlinked to `~/.hermes/skills/`)
- OpenCode reads `~/offline-agents/opencode/agent/build.md` (symlinked to `~/.config/opencode/agent/build.md`)
- Ollama modelfiles in `~/offline-agents/ollama/modelfiles/` for reproducible local models
- Tirith MCP + uv binaries symlinked into `~/offline-agents/hermes/bin/`

## Structure

```
offline-agents/
├── hermes/
│   ├── skills/           # All Hermes skills (289 files, 13 categories)
│   ├── memories/         # Memory ledger (MEMORY.md)
│   ├── bin/              # Symlinks to tirith, uv, uvx
│   ├── agents-guides/    # AGENTS.md hierarchy (12 files)
│   ├── config.yaml.reference  # Config template (secrets redacted)
│   └── SOUL.md           # Agent personality
├── opencode/
│   ├── opencode.jsonc    # OpenCode config (Tirith MCP)
│   ├── auth.example.json # Auth structure (no real keys)
│   └── agent/build.md    # Build agent definition
├── ollama/
│   └── modelfiles/       # Modelfiles for reproducible local models
├── templates/
│   ├── skill-scaffold/   # New skill template
│   └── opencode-agent/   # New OpenCode agent template
├── scripts/
│   └── bootstrap.sh      # One-shot setup script
└── README.md             # This file
```

## Offline Reasoning

### Hermes (local model via Ollama)

```bash
# Start Ollama (if not running)
ollama serve &

# Hermes uses Ollama at localhost:4141/v1
hermes chat -q "Your prompt" -m llama3.1:8b --provider custom -t ""
```

Config: `~/.hermes/config.yaml` → `base_url: http://localhost:4141/v1`

### OpenCode (local model via Ollama)

```bash
# OpenCode can use Ollama as a provider
opencode run "Your prompt" --model ollama/llama3.1:8b
```

Config: `~/.config/opencode/opencode.jsonc` → add Ollama provider.

### Ollama Modelfiles

Create reproducible models:

```bash
ollama create my-model -f ~/offline-agents/ollama/modelfiles/llama3.1-8b.md
ollama run my-model
```

## Secrets

- `hermes/config.yaml.reference` — redacted config template
- `opencode/auth.example.json` — auth structure only
- Real secrets live in `~/.hermes/.env` and `~/.local/share/opencode/auth.json` (never committed)

## Updating

```bash
# Pull latest resources
cd ~/offline-agents && git pull

# Re-run bootstrap if new symlinks needed
./scripts/bootstrap.sh
```

## License

MIT — personal use.
