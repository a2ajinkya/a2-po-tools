#!/usr/bin/env bash
# export.sh — copy current skills & extensions from ~/.pi/agent into this repo
# Run this after making changes on your laptop, then commit & push.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_DIR="${HOME}/.pi/agent"

echo "→ Syncing skills..."
rsync -avL --delete "${AGENT_DIR}/skills/" "${REPO_DIR}/skills/"

echo "→ Syncing extensions..."
rsync -avL --delete "${AGENT_DIR}/extensions/" "${REPO_DIR}/extensions/"

echo ""
echo "Done. Review changes with: git diff --stat"
echo "Then commit and push."
