#!/usr/bin/env bash
# Export RetailMind backend + frontend into ONE flat, student-owned GitHub repo.
#
# Why this exists: the working copy uses two independent repos (backend/ and
# frontend/) wrapped as git submodules under a superproject. The assessment
# rubric wants a single GitHub link, so this script rebuilds the tree as one
# repo and pushes it to the STUDENT GitHub account.
#
# What is copied  -> source, tests, dependency manifests, docker-compose,
#                    nginx config, .env.example, a generated root README,
#                    the assessment report, screenshots/ placeholder.
# What is NOT     -> .git/ dirs (no history/submodule pointers), node_modules,
#                    .venv, build output (.output/.output-docker/dist),
#                    data/raw|processed|extracted|uploads, artifacts/,
#                    and EVERY .env file (frontend/.env is tracked upstream
#                    and contains real API keys - it must never be copied).
#
# Prereqs: rsync, git, gh (GitHub CLI) logged in as the STUDENT account.
#
# Usage:
#   scripts/export-student-repo.sh \
#       --dest  /tmp/student/retailmind-ai \
#       --repo  "student-username/retailmind-ai" \
#       [--public] [--squash] [--dry-run] [--message "Initial commit"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$REPO_ROOT/backend"
FRONTEND_DIR="$REPO_ROOT/frontend"

DEST=""
REPO=""
VISIBILITY="--private"
SQUASH=false
DRY_RUN=false
MESSAGE="Initial commit"

usage() {
  cat <<'EOF'
Export RetailMind backend + frontend into ONE flat student-owned GitHub repo.

Usage:
  scripts/export-student-repo.sh \
      --dest  /path/to/new/repo \
      --repo  "student-username/retailmind-ai" \
      [--public] [--squash] [--dry-run] [--message "msg"]

  --dest      Local folder to build the single repo in (must be empty/absent)
  --repo      "owner/repo" to create on GitHub (must be the STUDENT account)
  --public    Create the repo as public (default: private)
  --squash    Collapse everything into a single "Initial commit"
  --dry-run   Build the full exported tree for inspection, but skip git/push
  --message   Commit message prefix (default: "Initial commit")

By default the tree is committed as a series of logical, section-based commits
(docs, backend core, backend ML, backend AI advisor, backend tests, backend
config, frontend source, frontend config) so the history reads like a real
project rather than one giant blob.
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="${2:?--dest requires a path}"; shift 2 ;;
    --repo) REPO="${2:?--repo requires owner/repo}"; shift 2 ;;
    --public) VISIBILITY="--public"; shift ;;
    --squash) SQUASH=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --message) MESSAGE="${2:?--message requires a string}"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -n "$DEST" && -n "$REPO" ]] || usage

echo "═══ Preflight ═══"
for tool in rsync git gh; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool"; exit 1; }
done

if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not logged in. Run 'gh auth login' as the STUDENT account first."
  exit 1
fi
OWNER="$(gh api user -q .login)"
echo "gh is logged in as: $OWNER"
if [[ "$REPO" != "$OWNER"/* ]]; then
  echo "WARNING: --repo owner '$REPO' does not match the gh account '$OWNER'."
  echo "         The repo will be created under '$OWNER' regardless."
fi
echo "Local git identity: $(git config user.name || echo '(unset)') <$(git config user.email || echo '(unset)')>"

if [[ -e "$DEST" && -n "$(ls -A "$DEST" 2>/dev/null)" ]]; then
  echo "ERROR: --dest '$DEST' exists and is not empty. Use a fresh directory."
  exit 1
fi
mkdir -p "$DEST"

echo ""
echo "═══ Exporting file trees (excludes heavy data, artifacts, secrets, build output) ═══"

# NOTE: rsync rules are first-match-wins. .env.example must be allowed before
# the catch-all .env* exclusion so secrets (.env, .env.local, .env.production…)
# are never exported - frontend/.env contains real API/Supabase keys upstream.
COMMON_EXCLUDES=(
  --include='.env.example'
  --exclude='.env*'
  --exclude='.git'
  --exclude='node_modules/'
  --exclude='.venv/'
  --exclude='__pycache__/'
  --exclude='.pytest_cache/'
  --exclude='.mypy_cache/'
  --exclude='.ruff_cache/'
)

echo "  backend/ -> $DEST/backend/"
mkdir -p "$DEST/backend"
rsync -a --delete --prune-empty-dirs "${COMMON_EXCLUDES[@]}" \
  --exclude='/data/raw/' \
  --exclude='/data/processed/' \
  --exclude='/data/extracted/' \
  --exclude='/data/uploads/' \
  --exclude='/artifacts/' \
  --exclude='/data/samples/' \
  "$BACKEND_DIR/" "$DEST/backend/"

echo "  frontend/ -> $DEST/frontend/"
mkdir -p "$DEST/frontend"
rsync -a --delete --prune-empty-dirs "${COMMON_EXCLUDES[@]}" \
  --exclude='/dist/' \
  --exclude='/.output/' \
  --exclude='/.output-docker/' \
  --exclude='/.lovable/' \
  --exclude='/supabase/.tmp/' \
  "$FRONTEND_DIR/" "$DEST/frontend/"

echo "  root files: docker-compose.yml, deploy/, .env.example, report, screenshots/"
mkdir -p "$DEST/deploy" "$DEST/screenshots"
: > "$DEST/screenshots/.gitkeep"
rsync -a "$REPO_ROOT/deploy/" "$DEST/deploy/"
for f in docker-compose.yml .env.example ASSESSMENT_REPORT.md; do
  [[ -f "$REPO_ROOT/$f" ]] && cp "$REPO_ROOT/$f" "$DEST/$f"
done

echo ""
echo "═══ Generating root README.md ═══"
cat > "$DEST/README.md" <<MD
# RetailMind AI

AI-powered retail analytics and decision-support platform: a FastAPI backend with
seven machine-learning domains and an AI advisor, plus a TanStack Start web app.

## Repository layout (single repo)

\`\`\`
retailmind-ai/
├── backend/     → FastAPI service (API, ML models, AI advisor, tests)
├── frontend/    → TanStack Start web app (dashboard + analytics UI)
├── deploy/      → nginx reverse-proxy config
├── docker-compose.yml
├── screenshots/ → demo screenshots
└── README.md
\`\`\`

## Features

- **Dashboard** — KPIs, sales trend, customer segments, sentiment, inventory risk, AI insights
- **Sales & Demand** — historical analytics and demand forecasting
- **Inventory Intelligence** — stock status, reorder recommendations
- **Customer Intelligence** — RFM segmentation and churn-risk prediction with
  SHAP explanations
- **Product Intelligence** — product performance, ratings and sentiment
- **Review Intelligence** — NLP sentiment analysis and topic detection
- **AI Insights** — prioritized business insights
- **AI Advisor** — conversational retail advisor (Gemini / OpenAI, free tiers)
- **Model registry** — evaluation metrics, confusion matrices, model comparisons

## Machine-learning domains (rubric coverage: 8+ of 10 topics)

| Domain | ML task | Model |
| --- | --- | --- |
| Demand forecasting | Time-series regression | Prophet / scikit-learn |
| Sales analytics | Aggregation & trend analysis | pandas / scikit-learn |
| Customer segmentation | Unsupervised clustering | K-Means (RFM) |
| Churn prediction | Binary classification | Gradient boosting / PyTorch |
| Sentiment analysis | Text classification (NLP) | DistilBERT / scikit-learn |
| Topic modeling | Unsupervised text | LDA |
| Inventory optimization | Predictive risk scoring | scikit-learn |
| Explainability | Model interpretation | SHAP |

## Getting started (Docker)

\`\`\`bash
docker compose up --build -d
# open http://localhost:8081  (app)  ·  /docs (Swagger)  ·  /health
# login: admin@retailmind.ai / ChangeMe123!
\`\`\`

The one-shot \`backend-init\` service seeds users, customers, products and demo
sales/reviews. Pre-trained model artifacts are baked into the backend image —
**no training happens at runtime**.

## Local development

\`\`\`bash
# backend — Python 3.12, requires DATABASE_URL + SECRET_KEY (>=32 chars)
cd backend && uv pip install -e ".[dev]" && uvicorn app.main:app --reload --port 8000

# frontend — bun
cd frontend && bun install && bun run dev   # http://localhost:4000 (mock data)
\`\`\`

## Training models offline

\`\`\`bash
cd backend
python scripts/process_data.py       # raw ZIPs → processed parquets
python scripts/train_all_models.py   # trains all 7 domains → artifacts/
\`\`\`

## Tests

\`\`\`bash
cd backend && API_KEY= pytest tests/ -v
\`\`\`

## AI transparency statement

- All models are trained offline on provided retail datasets; the app serves
  predictions from pre-trained artifacts and never trains at runtime.
- The AI advisor calls hosted LLM APIs (Gemini/OpenAI) on free tiers; prompts
  are grounded in the user's analytics data.
- Predictions are estimates used to *support* decisions, not to make them
  automatically. Human review is expected before acting on any recommendation.

## Screenshots

See \`screenshots/\` (add 3–4 captures: dashboard, sales, customers/churn, reviews).

## Group

- Member 1 — [Name], [Student number], contribution
- Member 2 — [Name], [Student number], contribution
- Member 3 — [Name], [Student number], contribution
MD
[[ "$DRY_RUN" == true ]] || echo "  README.md written ($(wc -l < "$DEST/README.md") lines)"

echo ""
echo "═══ Writing .gitignore ═══"
cat > "$DEST/.gitignore" <<'GI'
# secrets — never commit real keys
.env
.env.*
!.env.example

# heavy data & trained artifacts
backend/data/raw/
backend/data/processed/
backend/data/extracted/
backend/data/uploads/
backend/data/samples/
backend/artifacts/

# python
__pycache__/
*.py[cod]
.venv/
.pytest_cache/
.mypy_cache/
.ruff_cache/

# frontend / node
node_modules/
dist/
.output/
.output-docker/
.lovable/
GI

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "═══ DRY RUN — tree built for inspection; git/GitHub steps skipped ═══"
  echo "Target tree size:"
  du -sh "$DEST"
  exit 0
fi

echo ""
echo "═══ Sanity checks (must all pass) ═══"
check_absent() {
  if [[ -e "$DEST/$1" ]]; then echo "  FAIL: $1 was copied but should be excluded"; return 1; fi
  echo "  ok: $1 excluded"
}
check_absent "backend/.env"
check_absent "frontend/.env"
check_absent "backend/data"
check_absent "backend/artifacts"
check_absent "frontend/node_modules"
check_absent "backend/.venv"
check_absent "frontend/.output-docker"
check_absent "frontend/.git"
check_absent "backend/.git"
echo "  ok: .env.example present: $([[ -f "$DEST/frontend/.env.example" || -f "$DEST/.env.example" ]] && echo yes || echo no)"
echo "  repo size: $(du -sh "$DEST" | cut -f1)"

echo ""
echo "═══ git init + logical commits ═══"
cd "$DEST"
git init -b main >/dev/null

# Commit staged paths only if there is something staged; never create empty commits.
commit_if_staged() {
  if ! git diff --cached --quiet; then
    git commit -q -m "$1"
  else
    echo "  (nothing staged for: $1)"
  fi
}

# git add fails atomically if ANY pathspec is missing, so only add what exists.
add_existing() {
  local paths=()
  local p
  for p in "$@"; do
    [[ -e "$p" ]] && paths+=("$p")
  done
  [[ ${#paths[@]} -gt 0 ]] && git add -- "${paths[@]}"
}

if $SQUASH; then
  git add -A
  git commit -q -m "$MESSAGE"
else
  echo "  root docs + deployment config"
  add_existing README.md .gitignore docker-compose.yml .env.example deploy screenshots ASSESSMENT_REPORT.md
  commit_if_staged "docs: project scaffolding, README and deployment config"

  echo "  backend: core application (API routes, services, data layer)"
  add_existing backend/app/api backend/app/services backend/app/repositories backend/app/db \
    backend/app/schemas backend/app/core backend/app/config.py backend/app/dependencies.py \
    backend/app/utils backend/app/main.py
  commit_if_staged "backend: FastAPI application core"

  echo "  backend: machine-learning model domains"
  add_existing backend/app/ml
  commit_if_staged "backend: machine-learning model domains"

  echo "  backend: AI advisor"
  add_existing backend/app/ai
  commit_if_staged "backend: AI advisor (conversational retail insights)"

  echo "  backend: tests"
  add_existing backend/tests
  commit_if_staged "backend: tests"

  echo "  backend: dependency + build configuration"
  git add backend/
  commit_if_staged "backend: dependencies, Dockerfile and app configuration"

  echo "  frontend: application source"
  add_existing frontend/src frontend/public
  commit_if_staged "frontend: TanStack Start application source"

  echo "  frontend: configuration, tooling and deployment"
  git add frontend ':!frontend/src' ':!frontend/public'
  commit_if_staged "frontend: build tooling, styling and Cloudflare configuration"
fi
echo "  commits created:"
git log --oneline

echo ""
echo "═══ Creating repo + pushing (account: $OWNER) ═══"
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "  Repo '$REPO' already exists — attaching as origin and pushing."
  git remote add origin "https://github.com/$REPO.git"
  git push -u origin main
else
  echo "  Creating $VISIBILITY repo '$REPO' on $OWNER's GitHub…"
  gh repo create "$REPO" "$VISIBILITY" --source="$DEST" --push
fi

echo ""
echo "═══ Done ═══"
echo "  Repo:    https://github.com/$REPO"
echo "  Local:   $DEST"
echo "  Branch:  main (logical commit history, no heavy data, no secrets)"
