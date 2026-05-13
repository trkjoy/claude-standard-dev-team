#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_SRC="$REPO_DIR/templates/memory"
STATE_TEMPLATES_SRC="$TEMPLATES_SRC/team-state"
PROJECT_NAME="$(basename "$PWD")"
PROJECT_NAME_ESCAPED="$(printf '%s' "$PROJECT_NAME" | sed 's/[\/&]/\\&/g')"

if [ ! -d "$TEMPLATES_SRC" ]; then
  echo "ERROR: templates directory not found: $TEMPLATES_SRC" >&2
  echo "Run this script from the installed claude-standard-dev-team clone." >&2
  exit 1
fi

echo "Initializing project for standard AI team: $PROJECT_NAME"

if [ -f "CLAUDE.md" ]; then
  echo "Keeping existing CLAUDE.md"
else
  sed "s/{{PROJECT_NAME}}/${PROJECT_NAME_ESCAPED}/g" "$TEMPLATES_SRC/project-CLAUDE.md" > CLAUDE.md
  echo "Created CLAUDE.md"
fi

mkdir -p .claude
if [ -f ".claude/settings.json" ]; then
  echo "Keeping existing .claude/settings.json"
else
  cp "$TEMPLATES_SRC/settings.json" .claude/settings.json
  echo "Created .claude/settings.json"
fi

mkdir -p .claude/team-state
for state_file in STATE.md RETRY_LOG.md DECISIONS.md LEARNINGS.md; do
  src="$STATE_TEMPLATES_SRC/$state_file"
  dest=".claude/team-state/$state_file"
  if [ ! -f "$src" ]; then
    echo "ERROR: missing state template $src" >&2
    exit 1
  fi
  if [ -f "$dest" ]; then
    echo "Keeping existing $dest"
  else
    cp "$src" "$dest"
    echo "Created $dest"
  fi
done

echo "Project initialization complete."
echo "Fill in CLAUDE.md technology stack and deployment environment before starting orchestrator."
