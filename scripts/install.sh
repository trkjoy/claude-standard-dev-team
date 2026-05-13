#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_SRC="$REPO_DIR/agents"
TEMPLATES_SRC="$REPO_DIR/templates/memory"
AGENTS_DEST="$HOME/.claude/agents"
MEMORY_DEST="$HOME/.claude/team-memory/patterns"

if [ ! -d "$AGENTS_SRC" ]; then
  echo "ERROR: agents directory not found: $AGENTS_SRC" >&2
  echo "Run this script from a clone of claude-standard-dev-team." >&2
  exit 1
fi

if [ ! -d "$TEMPLATES_SRC" ]; then
  echo "ERROR: memory templates directory not found: $TEMPLATES_SRC" >&2
  echo "Run this script after templates/memory has been created." >&2
  exit 1
fi

echo "Installing standard AI development team..."

mkdir -p "$AGENTS_DEST"
cp "$AGENTS_SRC"/*.md "$AGENTS_DEST/"
agent_count="$(find "$AGENTS_SRC" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
echo "Installed $agent_count agents to $AGENTS_DEST"

mkdir -p "$MEMORY_DEST"
for pattern in backend frontend contract qa security deployment; do
  src="$TEMPLATES_SRC/${pattern}-patterns.md"
  dest="$MEMORY_DEST/${pattern}-patterns.md"
  if [ ! -f "$src" ]; then
    echo "ERROR: missing template $src" >&2
    exit 1
  fi
  if [ -f "$dest" ]; then
    echo "Keeping existing memory file: $dest"
  else
    cp "$src" "$dest"
    echo "Created memory file: $dest"
  fi
done

echo "Install complete."
echo "For each project, run: bash $REPO_DIR/scripts/team-init.sh"
