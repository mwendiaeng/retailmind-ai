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

PUSH_BRANCH="${1:-main}"

cd "$REPO_ROOT"

# ── Step 1: Sync & push frontend submodule ──
if git -C "$FRONTEND_DIR" rev-parse --git-dir &>/dev/null; then
  echo "═══ Syncing frontend submodule ═══"
  cd "$FRONTEND_DIR"

  # Ensure all remotes exist
  for i in "${!FRONTEND_REMOTES[@]}"; do
    remote="${FRONTEND_REMOTES[$i]}"
    url="${FRONTEND_REMOTE_URLS[$i]}"
    if ! git remote get-url "$remote" &>/dev/null; then
      echo "Adding remote '$remote' -> $url"
      git remote add "$remote" "$url"
    fi
  done

  # Ensure we're on main
  git checkout "$PUSH_BRANCH" 2>/dev/null || git checkout -b "$PUSH_BRANCH"

  echo "Fetching from all remotes..."
  git fetch --all

  # Check if this is the first merge (no common ancestor)
  MERGE_FLAGS="--no-edit"
  if ! git merge-base "$PUSH_BRANCH" "retail-insights-hub-0dbdb1d3/$PUSH_BRANCH" &>/dev/null; then
    MERGE_FLAGS="--no-edit --allow-unrelated-histories"
  fi

  # Merge from retail-insights-hub-0dbdb1d3 (source)
  echo "Merging from retail-insights-hub-0dbdb1d3..."
  git merge "retail-insights-hub-0dbdb1d3/$PUSH_BRANCH" $MERGE_FLAGS || {
    echo "Warning: Merge from retail-insights-hub-0dbdb1d3 had conflicts"
    echo "Please resolve conflicts manually, then run: git merge --continue"
    cd "$REPO_ROOT"
    exit 1
  }

  # Merge from retail-insights-hub
  echo "Merging from retail-insights-hub..."
  git merge "retail-insights-hub/$PUSH_BRANCH" --no-edit || {
    echo "Warning: Merge from retail-insights-hub had conflicts"
    echo "Please resolve conflicts manually, then run: git merge --continue"
    cd "$REPO_ROOT"
    exit 1
  }

  # Merge from origin
  echo "Merging from origin..."
  git merge "origin/$PUSH_BRANCH" --no-edit || {
    echo "Warning: Merge from origin had conflicts"
    echo "Please resolve conflicts manually, then run: git merge --continue"
    cd "$REPO_ROOT"
    exit 1
  }

  # Push to all remotes
  echo ""
  echo "Pushing to all frontend remotes..."
  for remote in "${FRONTEND_REMOTES[@]}"; do
    echo "  Pushing to $remote..."
    git push "$remote" "$PUSH_BRANCH" 2>/dev/null || \
      echo "  Warning: Push to $remote failed"
  done

  cd "$REPO_ROOT"
  echo ""
  echo "═══ Frontend submodule synced and pushed ═══"
else
  echo "Warning: frontend directory is not a git submodule, skipping frontend sync"
fi

# ── Step 2: Push main repo ──
echo ""
echo "═══ Pushing main repo (retailmind-ai) ═══"
cd "$REPO_ROOT"
git push origin "$PUSH_BRANCH"
echo ""
echo "═══ All done! ═══"
