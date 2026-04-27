#!/usr/bin/env bash
# install.sh — copy skills & extensions from this repo into ~/.pi/agent
# Run this on a new machine (e.g., Termux) after cloning the repo.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_DIR="${HOME}/.pi/agent"

mkdir -p "${AGENT_DIR}/skills"
mkdir -p "${AGENT_DIR}/extensions"

echo "→ Installing skills to ${AGENT_DIR}/skills ..."
rsync -avL --delete "${REPO_DIR}/skills/" "${AGENT_DIR}/skills/"

echo "→ Installing extensions to ${AGENT_DIR}/extensions ..."
rsync -avL --delete "${REPO_DIR}/extensions/" "${AGENT_DIR}/extensions/"

echo ""
echo "Done. Restart pi to pick up new skills & extensions."
