#!/usr/bin/env bash
set -euo pipefail

worktree="${WORKSPACE_FOLDER:-/workspaces/default}"
project_codex="${worktree}/.codex"
dest="$HOME/.codex"

if [[ ! -d "$project_codex" ]]; then
  echo "[ai-devcontainer-template] No project .codex directory found; skipping sync."
  exit 0
fi

mkdir -p "$dest"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --ignore-existing "${project_codex}/" "$dest/"
else
  cp -an "${project_codex}/." "$dest/" || true
fi

echo "[ai-devcontainer-template] Synced project .codex into $dest without overwriting existing files."
