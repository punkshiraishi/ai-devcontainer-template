# AI Devcontainer Template

Reusable devcontainer configuration that preinstalls Anthropic Claude Code, Cursor CLI, and OpenAI Codex CLI. Clone this repository once and reuse the `.devcontainer/` folder across any project.

## Features
- Ubuntu-based image with Node.js 22, Python 3, Ripgrep, GitHub CLI, and other common tools.
- Preconfigured CLI tooling: Claude Code, Cursor Agent, Codex, zsh, and persistent shell history volumes.
- Network egress locked down by `init-firewall.sh`, combining the allowlists from the Claude Code setup.
- VS Code customization with useful extensions and consistent terminal profiles.

## Getting Started
1. Clone this repository somewhere accessible: `git clone https://github.com/punkshiraishi/ai-devcontainer-template.git`.
2. Copy the `.devcontainer/` directory into your project (or add this repo as a Git submodule).
3. Open the project in VS Code and run **Dev Containers: Reopen in Container** or, from the terminal, run `devcontainer up --workspace-folder <project>`.

## Customization Tips
- Update the `TZ` build argument in `devcontainer.json` to use your local timezone.
- Add project-specific VS Code extensions or settings under `customizations.vscode`.
- Extend `init-firewall.sh` with additional domains/IP ranges if new tooling needs outbound access.
- Install extra language runtimes or OS packages by editing the Dockerfile.

## Verification
After the container starts, confirm the CLIs are available:

```bash
devcontainer exec --workspace-folder <project> -- claude --version
devcontainer exec --workspace-folder <project> -- cursor-agent --help | head -n 1
devcontainer exec --workspace-folder <project> -- codex --version
```

Each command should respond without requiring extra installation steps.
