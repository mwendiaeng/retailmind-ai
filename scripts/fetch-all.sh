#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$REPO_ROOT/frontend"

FRONTEND_REMOTES=(
  "retail-insights-hub-0dbdb1d3"
  "retail-insights-hub"
  "origin"
)

FRONTEND_REMOTE_URLS=(
  "https://github.com/mwendiaeng/retail-insights-hub-0dbdb1d3.git"
  "https://github.com/mwendiaeng/retail-insights-hub.git"
  "https://github.com/mwendiaeng/retailmind-frontend.git"
)

cd "$REPO_ROOT"

# Fetch main repo
echo "═══ Fetching main repo ═══"
git fetch origin

# Fetch frontend submodule
if git -C "$FRONTEND_DIR" rev-parse --git-dir &>/dev/null; then
  echo ""
  echo "═══ Fetching frontend submodule ═══"
  cd "$FRONTEND_DIR"

  # Ensure all remotes exist
  for i in "${!FRONTEND_REMOTES[@]}"; do
    remote="${FRONTEND_REMOTES[$i]}"
    url="${FRONTEND_REMOTE_URLS[$i]}"
    if ! git remote get-url "$remote" &>/dev/null; then
      git remote add "$remote" "$url"
    fi
  done

  # Fetch all remotes (no pull to avoid detached HEAD)
  git fetch --all

  # Ensure we're on main
  git checkout main 2>/dev/null || git checkout -b main

  cd "$REPO_ROOT"
fi

echo ""
echo "═══ Fetch complete ═══"
