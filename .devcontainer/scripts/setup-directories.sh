#!/usr/bin/env bash
set -euo pipefail

worktree="${WORKSPACE_FOLDER:-/workspaces/default}"

mkdir -p \
  "$HOME/.claude" \
  "$HOME/.cursor" \
  "$HOME/.codex"

if [[ ! -d "$worktree" ]]; then
  mkdir -p "$worktree"
fi
