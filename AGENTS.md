# Agent Documentation Entrypoint

Welcome, AI Agent! This repository utilizes **OpenWiki** to generate and maintain documentation specifically tailored for coding agents.

## 📖 How to Navigate

1. **System Overview**: Read the root [README.md](README.md) for the architecture diagram, setup guidelines, and quick start instructions.
2. **Detailed Script Flowcharts**: Refer to [rules/scripts/README.md](rules/scripts/README.md) to inspect Mermaid logic flowcharts and fail-safe designs for all R and Python helper scripts.
3. **Living Wiki (OpenWiki)**: If available, check the `openwiki/` directory in the repository root for the auto-generated documentation updated daily via GitHub Actions.

## 🤖 OpenWiki Integration

OpenWiki is configured to run automatically using GitHub Actions. It monitors changes, parses git diffs, and keeps the agent-facing wiki fresh.

* **Workflow Location**: [.github/workflows/openwiki-update.yml](.github/workflows/openwiki-update.yml)
* **Frequency**: Daily at 08:00 UTC
* **Model Used**: `z-ai/glm-5.2` (via OpenRouter)
