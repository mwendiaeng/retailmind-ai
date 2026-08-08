#!/usr/bin/env bash
# Build ONE submission ZIP for RetailMind: backend + frontend in a single flat
# tree (no submodules, no git history).
#
# Unlike scripts/export-student-repo.sh (which pushes to GitHub and strips .env):
#   - .env files ARE included  (backend/.env, frontend/.env — real keys)
#   - pre-trained artifacts ARE included (backend/artifacts/)
#   - docs are excluded        — only README files are kept, no *.md/*.docx docs
#   - Claude items are stripped — CLAUDE.md, AGENTS.md, .claude/ dirs
#   - invalid scripts stripped — train_models.py (stub), train_all_models.py (dup)
#   - output is ONE zip file   — no git init, no gh, no push
#
# Usage:
#   scripts/build-submission-zip.sh [--dest DIR] [--out FILE] [--dry-run]
#
#   --dest     staging directory where the flat tree is built
#              (default: ${TMPDIR:-/tmp}/retailmind-ai-submission)
#   --out      output .zip path (default: ./retailmind-ai-submission.zip)
#   --dry-run  build + sanity-check the tree, print a file listing, skip zipping

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$REPO_ROOT/backend"
FRONTEND_DIR="$REPO_ROOT/frontend"

DEST="${TMPDIR:-/tmp}/retailmind-ai-submission"
OUT="$REPO_ROOT/retailmind-ai-submission.zip"
DRY_RUN=false

usage() {
  cat <<'EOF'
Build ONE submission ZIP for RetailMind (backend + frontend, flat tree).

Usage:
  scripts/build-submission-zip.sh [--dest DIR] [--out FILE] [--dry-run]

  --dest      Staging directory for the flat tree
              (default: ${TMPDIR:-/tmp}/retailmind-ai-submission)
  --out       Output .zip path (default: ./retailmind-ai-submission.zip)
  --dry-run   Build + sanity-check the tree and print a listing, but skip zipping

Notes:
  - .env files ARE included (backend/.env, frontend/.env).
  - Docs are excluded — only README files are kept.
  - Claude items are stripped (CLAUDE.md, AGENTS.md, .claude/).
  - No git / gh / push: output is a single zip file.
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="${2:?--dest requires a path}"; shift 2 ;;
    --out) OUT="${2:?--out requires a file path}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) usage ;;
  esac
done

echo "═══ Preflight ═══"
for tool in rsync zip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool (try: sudo apt install rsync zip)"; exit 1; }
done

if [[ -e "$DEST" ]]; then
  echo "  removing old staging dir $DEST"
  rm -rf "$DEST"
fi
if [[ -f "$OUT" ]]; then
  echo "  removing old zip $OUT"
  rm -f "$OUT"
fi

echo ""
echo "═══ Exporting file trees (no data/artifacts/build output/secrets-dirs, .env kept) ═══"

# rsync filters are first-match-wins. Directory-level excludes come first so the
# --include='*/' traversal rule below can never drag them back in. The final
# '*.md'/'*.docx' rules drop every doc EXCEPT README.md (matched earlier).
EXCLUDES=(
  --exclude='.git'
  --exclude='.gitmodules'
  --exclude='.vscode/'
  --exclude='.claude/'
  --exclude='node_modules/'
  --exclude='.venv/'
  --exclude='__pycache__/'
  --exclude='*.pyc'
  --exclude='*.egg-info/'
  --exclude='.pytest_cache/'
  --exclude='.mypy_cache/'
  --exclude='.ruff_cache/'
  --exclude='.wrangler/'
  --exclude='.tanstack/'
  --exclude='.lovable/'
  --exclude='.output/'
  --exclude='.output-docker/'
  --exclude='dist/'
  --exclude='data/'
  --exclude='test.db'
  --exclude='*.backup'
  --exclude='supabase_export.sql'
  --exclude='CLAUDE.md'
  --exclude='AGENTS.md'
  --exclude='scripts/train_all_models.py'
  --exclude='scripts/train_models.py'
  --include='*/'
  --include='README.md'
  --exclude='*.md'
  --exclude='*.docx'
)

mkdir -p "$DEST"

echo "  backend/ -> $DEST/backend/"
mkdir -p "$DEST/backend"
rsync -a --delete --prune-empty-dirs "${EXCLUDES[@]}" "$BACKEND_DIR/" "$DEST/backend/"

echo "  frontend/ -> $DEST/frontend/"
mkdir -p "$DEST/frontend"
rsync -a --delete --prune-empty-dirs "${EXCLUDES[@]}" "$FRONTEND_DIR/" "$DEST/frontend/"

echo "  root files -> $DEST/"
mkdir -p "$DEST/deploy" "$DEST/screenshots"
: > "$DEST/screenshots/.gitkeep"
rsync -a "$REPO_ROOT/deploy/" "$DEST/deploy/"
for f in docker-compose.yml .env.example .env; do
  [[ -f "$REPO_ROOT/$f" ]] && cp "$REPO_ROOT/$f" "$DEST/$f"
done

echo ""
echo "═══ Generating root README.md ═══"
cat > "$DEST/README.md" <<'MD'
# RetailMind AI

AI-powered retail analytics and decision-support platform: a FastAPI backend with
seven machine-learning domains and an AI advisor, plus a TanStack Start web app.

## Repository layout (single repo)

```
retailmind-ai/
├── backend/     → FastAPI service (API, ML models, AI advisor, tests)
├── frontend/    → TanStack Start web app (dashboard + analytics UI)
├── deploy/      → nginx reverse-proxy config
├── docker-compose.yml
├── screenshots/ → demo screenshots
└── README.md
```

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

```bash
docker compose up --build -d
# open http://localhost:8081  (app)  ·  /docs (Swagger)  ·  /health
# login: admin@retailmind.ai / ChangeMe123!
```

Environment files (`.env`) and pre-trained model artifacts (`backend/artifacts/`)
are included in this submission; the one-shot `backend-init` service seeds users,
customers, products and demo sales/reviews — **no training happens at runtime**.

## Local development

```bash
# backend — Python 3.12, requires DATABASE_URL + SECRET_KEY (>=32 chars)
cd backend && uv pip install -e ".[dev]" && uvicorn app.main:app --reload --port 8000

# frontend — bun
cd frontend && bun install && bun run dev   # http://localhost:4000 (mock data)
```

## Training models offline

```bash
cd backend
python scripts/process_data.py       # raw ZIPs → processed parquets
python scripts/train_all.py          # trains all 7 domains → artifacts/
```

## Tests

```bash
cd backend && API_KEY= pytest tests/ -v
```

## AI transparency statement

- All models are trained offline on provided retail datasets; the app serves
  predictions from pre-trained artifacts and never trains at runtime.
- The AI advisor calls hosted LLM APIs (Gemini/OpenAI) on free tiers; prompts
  are grounded in the user's analytics data.
- Predictions are estimates used to *support* decisions, not to make them
  automatically. Human review is expected before acting on any recommendation.

## Screenshots

See `screenshots/` (add 3–4 captures: dashboard, sales, customers/churn, reviews).

## Group

- Member 1 — [Name], [Student number], contribution
- Member 2 — [Name], [Student number], contribution
- Member 3 — [Name], [Student number], contribution
MD
echo "  README.md written ($(wc -l < "$DEST/README.md") lines)"

echo ""
echo "═══ Writing .gitignore ═══"
cat > "$DEST/.gitignore" <<'GI'
# secrets — keep .env local (a copy ships with this submission)
.env
.env.local

# heavy data (regenerated via scripts/process_data.py + scripts/train_all.py)
backend/data/raw/
backend/data/processed/
backend/data/extracted/
backend/data/uploads/
backend/data/samples/

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

echo ""
echo "═══ Sanity checks (must all pass) ═══"
check_absent() {
  if [[ -e "$DEST/$1" ]]; then echo "  FAIL: $1 was copied but should be excluded"; return 1; fi
  echo "  ok: $1 excluded"
}
check_absent "backend/data"
check_absent "backend/test.db"
check_absent "backend/.venv"
check_absent "frontend/node_modules"
check_absent "frontend/.output"
check_absent "frontend/.output-docker"
check_absent "frontend/.lovable"
check_absent "frontend/.wrangler"
check_absent "frontend/.tanstack"
check_absent "frontend/.git"
check_absent "backend/.git"
check_absent ".gitmodules"
check_absent ".vscode"
check_absent "CLAUDE.md"
check_absent "backend/CLAUDE.md"
check_absent "frontend/CLAUDE.md"
check_absent "frontend/AGENTS.md"
check_absent "APP_TESTING_GUIDE.md"
check_absent "ASSESSMENT_REPORT.md"
check_absent "ASSESSMENT_REPORT.docx"
check_absent "PRESENTATION_GUIDE.md"
check_absent "PRESENTATION_VIDEO_SCRIPT.md"
check_absent "backend/plan.md"
check_absent "frontend/plan.md"
check_absent "supabase_export.sql"
check_absent "backend/scripts/train_models.py"
check_absent "backend/scripts/train_all_models.py"
echo "  ok: artifacts present:    $([[ -d "$DEST/backend/artifacts" ]] && echo yes || echo no)"
echo "  ok: .env present:      $([[ -f "$DEST/.env" && -f "$DEST/backend/.env" && -f "$DEST/frontend/.env" ]] && echo yes || echo no)"
echo "  ok: READMEs present:   $([[ -f "$DEST/README.md" && -f "$DEST/backend/README.md" && -f "$DEST/frontend/README.md" ]] && echo yes || echo no)"
if [[ -n "$(find "$DEST" \( -name '__pycache__' -o -name '*.pyc' \) -print -quit)" ]]; then
  echo "  FAIL: __pycache__ or .pyc files were copied into the submission"
  exit 1
fi
echo "  ok: no __pycache__ / .pyc in tree"
echo "  tree size: $(du -sh "$DEST" | cut -f1)"

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "═══ DRY RUN — zip skipped; showing exported tree ═══"
  (cd "$(dirname "$DEST")" && find "$(basename "$DEST")" -type f | sort)
  exit 0
fi

echo ""
echo "═══ Building ZIP ═══"
mkdir -p "$(dirname "$OUT")"
(cd "$(dirname "$DEST")" && zip -r -q "$OUT" "$(basename "$DEST")")
echo "  created: $OUT"
echo "  size:    $(du -h "$OUT" | cut -f1)"
echo "  entries: $(unzip -l "$OUT" | tail -1 | awk '{print $2}')"

echo ""
echo "═══ Done ═══"
echo "  Zip:   $OUT"
echo "  Unzip  →  retailmind-ai-submission/ (flat single repo, .env included, no docs beyond README, no Claude files)"
