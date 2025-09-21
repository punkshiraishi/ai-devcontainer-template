# AI Devcontainer Template

Reusable devcontainer configuration that preinstalls Anthropic Claude Code, Cursor CLI, and OpenAI Codex CLI. Clone this repository once and reuse the `.devcontainer/` folder across any project.

## Features
- Ubuntu-based image with Node.js 22, Python 3, Ripgrep, GitHub CLI, and other common tools.
- Preconfigured CLI tools: Claude Code CLI, Cursor CLI, Codex CLI, plus zsh and history persistence.
- VS Code customization with useful extensions and consistent terminal profiles.
- Optional project-level `.codex` directory synced into the container user home.

## Getting Started
1. Clone this repository somewhere accessible: `git clone https://github.com/punkshiraishi/ai-devcontainer-template.git`.
2. Copy the `.devcontainer/` directory into your project (or add this repo as a Git submodule).
3. Open the project in VS Code and run **Dev Containers: Reopen in Container** or use `devcontainer up` from the CLI.

## Customization Tips
- Update the `TZ` build argument in `devcontainer.json` to use your local timezone.
- Add project-specific VS Code extensions or settings under `customizations.vscode`.
- Extend the Dockerfile with additional package managers or language runtimes as needed.
- If you keep prompts or config for Codex, store them under `<project>/.codex`; they will be merged into `~/.codex` in the container.

## Verification
After the container starts, confirm the CLIs are available:

```bash
claude --version
cursor --help | head -n 1
codex --version
```

Each command should respond without requiring extra installation steps.
