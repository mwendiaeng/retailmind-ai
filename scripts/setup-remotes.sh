#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$REPO_ROOT/frontend"

if ! git -C "$FRONTEND_DIR" rev-parse --git-dir &>/dev/null; then
  echo "Error: frontend directory is not a git repo or submodule"
  exit 1
fi

cd "$FRONTEND_DIR"

echo "Adding remotes to frontend submodule..."

git remote add retail-insights-hub-0dbdb1d3 https://github.com/mwendiaeng/retail-insights-hub-0dbdb1d3.git 2>/dev/null || \
  echo "Remote 'retail-insights-hub-0dbdb1d3' already exists"

git remote add retail-insights-hub https://github.com/mwendiaeng/retail-insights-hub.git 2>/dev/null || \
  echo "Remote 'retail-insights-hub' already exists"

echo "Fetching all remotes..."
git fetch --all

echo ""
echo "Current remotes:"
git remote -v
echo ""
echo "Setup complete!"
