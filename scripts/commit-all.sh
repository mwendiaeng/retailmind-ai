#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
FRONTEND_DIR="$REPO_ROOT/frontend"

COMMIT_MSG="${1:?Usage: commit-all.sh \"commit message\"}"
PUSH_BRANCH="${2:-main}"

cd "$REPO_ROOT"

# Stage and commit frontend submodule changes first
if git -C "$FRONTEND_DIR" rev-parse --git-dir &>/dev/null; then
  echo "═══ Committing frontend submodule ═══"
  cd "$FRONTEND_DIR"
  git checkout "$PUSH_BRANCH" 2>/dev/null || git checkout -b "$PUSH_BRANCH"
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "$COMMIT_MSG"
    echo "Committed in frontend submodule"
    # Push to all frontend remotes
    for remote in origin retail-insights-hub-0dbdb1d3 retail-insights-hub; do
      echo "  Pushing frontend to $remote..."
      git push "$remote" "$PUSH_BRANCH" 2>/dev/null || \
        echo "  Warning: Push frontend to $remote failed"
    done
  else
    echo "No frontend changes to commit"
  fi
  cd "$REPO_ROOT"
fi

# Stage and commit main repo
echo ""
echo "═══ Committing main repo ═══"
git add -A
if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG"
  git push origin "$PUSH_BRANCH"
  echo "Committed and pushed main repo"
else
  echo "No main repo changes to commit"
fi

echo ""
echo "═══ All done! ═══"
