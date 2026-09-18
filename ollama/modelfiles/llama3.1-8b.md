# Ollama Modelfile — llama3.1:8b base
# Usage: ollama create llama3.1-8b -f this-file.md

FROM llama3.1:8b

# System prompt for offline reasoning
SYSTEM """You are a local AI agent running offline via Ollama. You reason without external API access. Be direct, precise, and resourceful."""

# Parameters
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 4096

# Template
TEMPLATE """{{ .System }}
{{ .Prompt }}"""
