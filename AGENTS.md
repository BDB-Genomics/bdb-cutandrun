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

## 🔍 Understand-Anything Integration

This repository is integrated with **Understand-Anything** by Egonex-AI, an AI-powered tool that builds interactive, visual knowledge graphs of the codebase.

The tool provides the following agent skills:
- `understand`: Run codebase analysis to extract files, functions, classes, and dependencies, storing them in `.understand-anything/knowledge-graph.json`.
- `understand-dashboard`: Run a Vite-based React dashboard to interactively inspect the graph.
- `understand-chat`: Ask natural-language questions about the codebase structure and business domains.
- `understand-diff`: Analyze the semantic impact of recent code changes.
- `understand-explain`: Deep-dive into a specific file or function.

These skills are registered directly in the agent's runtime environment. Teammates can also run the universal installer:
```bash
curl -fsSL https://raw.githubusercontent.com/Egonex-AI/Understand-Anything/main/install.sh | bash -s antigravity
```
