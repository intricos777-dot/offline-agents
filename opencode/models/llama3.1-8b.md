---
model: llama3.1:8b
provider: ollama
---

# llama3.1:8b

Local Llama 3.1 8B model served via Ollama at `http://localhost:4141/v1`.

## Capabilities

- Tool calling: yes
- Image input: no
- Context length: 131072

## Usage in OpenCode

```bash
opencode run "Your prompt" --model ollama/llama3.1:8b
```

## Notes

- Requires Ollama running on localhost:4141 (local reverse proxy)
- Slow on first load via proxy — allow 120s+ for cold starts
