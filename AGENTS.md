# offline-agents — Repository Guide

This repo contains all resources for offline Hermes + OpenCode reasoning.

## Rules

1. **Never commit secrets** — `.env`, `auth.json`, real `config.yaml` are gitignored
2. **Keep paths relative** — no `/home/<user>/` hardcoded paths
3. **Test bootstrap** — run `./scripts/bootstrap.sh` after adding new symlinks
4. **Document changes** — update README.md when adding new resources

## Adding New Skills

1. Copy template: `cp -r templates/skill-scaffold hermes/skills/<category>/<name>/`
2. Edit `SKILL.md` — follow frontmatter standards
3. Run `./scripts/bootstrap.sh` to symlink into `~/.hermes/skills/`
4. Commit and push

## Adding New OpenCode Agents

1. Copy template: `cp templates/opencode-agent/build.md opencode/agent/<name>.md`
2. Edit agent definition
3. Update `opencode/opencode.jsonc` to reference the new agent
4. Commit and push

## Updating Ollama Modelfiles

1. Edit `ollama/modelfiles/<model>.md`
2. Rebuild: `ollama create <model> -f ollama/modelfiles/<model>.md`
3. Commit the updated modelfile

## Bootstrap

```bash
./scripts/bootstrap.sh
```

This symlinks all resources into their live config paths.
