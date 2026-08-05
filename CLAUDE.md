# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository structure

This is a monorepo wrapping two independent repos as **git submodules**:

- `backend/` → FastAPI service (`retailmind-backend`)
- `frontend/` → TanStack Start web app (`retailmind-frontend`)

Each has its own `.git`, README, and dependency lockfile — treat them as separate projects that happen to live side by side. When making changes, `cd` into the relevant submodule; commits are made inside that submodule's own repo, not the monorepo root.

## Backend (`backend/`)

FastAPI + PostgreSQL (SQLite for local dev) + SQLAlchemy 2.0/Alembic + scikit-learn/PyTorch ML models + OpenAI-backed AI advisor. Python 3.12, managed with `uv` (see `uv.lock`) or plain `pip`/`venv`.

### Commands

```bash
cd backend

# Local dev server
uvicorn app.main:app --reload --port 8000

# Tests
pytest tests/ -v
pytest tests/api/test_dashboard.py -v              # single file
pytest tests/ml/test_churn.py::test_train_churn -v # single test
pytest tests/ -v --cov=app --cov-report=term-missing

# Type checking
mypy app/

# Migrations (after changing a model in app/db/models/)
alembic revision --autogenerate -m "description of changes"
alembic upgrade head

# ML training / data pipeline
python scripts/process_data.py    # raw ZIPs -> extracted -> processed parquets
python scripts/train_all.py       # trains all 7 ML domains
python scripts/seed.py            # seed users/customers/products
python scripts/generate_demo_data.py
```

Docker (from monorepo root): `docker compose up --build -d` — runs Postgres + backend together.

### Architecture

Layered, request flows one direction: `api/v1/*.py` (route handlers) → `services/*.py` (business logic) → `repositories/*.py` (DB access) → `db/models/*.py` (SQLAlchemy models). Pydantic schemas for request/response live in `schemas/`. Don't let routes touch repositories directly or services touch the DB session directly — follow the existing layer for whatever module you're editing.

`app/ml/` holds seven independent ML domains, each self-contained: `forecasting`, `segmentation`, `sales`, `inventory`, `churn`, `sentiment` (+ topic modeling), `explainability` (SHAP). `app/ml/common/` has shared path/IO/metrics helpers used across all of them. Trained model artifacts are written to `artifacts/<domain>/` (path configurable via `MODEL_PATH`); `services/model_service.py` and `api/v1/models.py` expose them generically.

`app/ai/` is a separate concern from `app/ml/`: it's the OpenAI-backed advisor (chat-style retail insights), not a trained model. `context_builder.py` assembles the prompt context from DB/service data, `provider.py` wraps the OpenAI call, `advisor.py`/`services/advisor_service.py` tie it together.

Auth is JWT (PyJWT) + Argon2 password hashing; protected endpoints expect `Authorization: Bearer <token>`. There's also a global `X-API-Key` middleware gate in `main.py` (active only when `API_KEY` env var is set) applied to all `/api/*` paths, independent of per-user JWT auth.

`main.py` wires custom exception handlers for `NotFoundError`/`UnauthorizedError`/`ForbiddenError`/`ValidationError`/`ConflictError` (from `core/exceptions.py`) — raise these from services rather than returning HTTP responses directly, so the mapping to status codes stays centralized.

Required env vars: `DATABASE_URL`, `SECRET_KEY` (must be ≥32 chars — the app fails to start otherwise, see `main.py` lifespan check). See `backend/README.md` for the full env var table and API endpoint list.

Tests use an isolated SQLite file (`tests/conftest.py`) with `get_db`/`get_current_user` dependency overrides and a pre-created `test_user` fixture — new API tests should follow this pattern rather than hitting the real configured database.

## Frontend (`frontend/`)

TanStack Start (React 19 + file-based routing) + TypeScript + Tailwind v4 + shadcn/Radix UI, built with Vite, deployed to Cloudflare Workers via Wrangler. Package manager is **bun** (`bunfig.toml`, `bun.lock`) — a `pnpm-lock.yaml` also exists but bun is the one actually configured (`.lovable/project.json`). Originally scaffolded by Lovable; the project stays synced to a connected Lovable branch — **never force-push, rebase, or amend/squash already-pushed commits** on that branch, since it rewrites history on Lovable's side.

### Commands

```bash
cd frontend

bun install
bun run dev            # vite dev, port 4000
bun run build           # production build
bun run lint             # eslint .
bun run format            # prettier --write .

bun run wrangler:dev     # run against Cloudflare Workers runtime locally
bun run wrangler:deploy  # deploy to Cloudflare Workers
```

There is no configured test runner in this package — don't assume `bun test` / vitest is wired up without checking `package.json` first.

### Architecture

Routes live in `src/routes/` using TanStack Router's **flat file-based convention** (`_app.dashboard.tsx`, `_app.customers.$id.tsx`, etc. — dots encode nesting, `$param` encodes dynamic segments); `routeTree.gen.ts` is generated, don't hand-edit it. `src/router.tsx` and `src/start.ts`/`src/server.ts` wire up the TanStack Start SSR entry (`server.ts` is a custom SSR error wrapper referenced by `vite.config.ts`'s `tanstackStart.server.entry`).

Feature modules live in `src/features/<domain>/` (dashboard, sales, inventory, customers, products, reviews, insights, models, datasets), each following the same three-file shape:
- `api.ts` — real fetch calls via `apiGet`/`apiPost` from `src/lib/api.ts`
- `mock-data.ts` — hardcoded mock implementation of the same functions
- `index.ts` — picks one based on `USE_MOCKS` (`src/lib/api.ts`, driven by `VITE_USE_MOCKS` env var, defaults to **mocked**)

`src/services/index.ts` re-exports every feature's selected (mock-or-real) fetch function as a single `services` object — this is the intended call surface for pages/components, rather than importing feature APIs directly.

`vite.config.ts` wraps `@lovable.dev/vite-tanstack-config`, which already registers TanStack devtools, `tanstackStart`, `viteReact`, `tailwindcss`, `tsConfigPaths`, the `@` path alias, and Nitro (Cloudflare target). Do not re-add any of these plugins manually — the comment at the top of the file is explicit that duplicating them breaks the app.

The app also has a separate **Supabase** integration (`src/integrations/supabase/`, `supabase/migrations/`) alongside the RetailMind backend API client in `src/lib/api.ts` — these are two distinct backends; check which one a given feature actually uses before assuming.

## Cross-cutting notes

- Backend and frontend are versioned independently; there is no single top-level test/build command that covers both.
- `scripts/` at the monorepo root (`fetch-all.sh`, `commit-all.sh`, `sync-and-push.sh`, `setup-remotes.sh`) operate across both submodules for repo/remote maintenance — read them before use since they iterate git operations across `backend/` and `frontend/`.

## Student submission repo (single GitHub repo)

The assessment rubric wants **one** GitHub link, but this workspace is a superproject with
two independent sub-repos. `scripts/export-student-repo.sh` rebuilds the apps as a **single
flat repo** owned by the student account — no submodules, no history.

How it works:

- **Export, not clone.** It rsyncs the `backend/` and `frontend/` file trees into a fresh
  directory (dropping every `.git/`), so no submodule pointers or commit history carry over.
- **Rubric-basics only — it intentionally excludes:** all `.env` files (the tracked
  `frontend/.env` contains real API/Supabase keys), `backend/data/*` and `backend/artifacts/`
  (heavy raw data + trained models — regenerated via `scripts/process_data.py` +
  `scripts/train_all_models.py`), `node_modules`, `.venv`, build output, and `.lovable/`.
- **What it keeps:** source, tests, dependency manifests (`pyproject.toml`/`requirements.txt`,
  `package.json`/`bun.lock`), `docker-compose.yml` + `deploy/nginx`, `.env.example`, a generated
  root `README.md` (setup, features, ML-topic rubric table, AI transparency statement), the
  assessment report, and an empty `screenshots/` dir.
- **Push:** uses `gh repo create <owner>/<repo> --source=<dest> --push` (or attaches an
  existing repo). **`gh` must be logged into the STUDENT account** (`gh auth status` /
  `gh auth switch`) — the repo is created under whatever account `gh` is authenticated as.

```bash
# inspect the exported tree without touching GitHub
scripts/export-student-repo.sh --dest /tmp/student/retailmind-ai \
  --repo "student-username/retailmind-ai" --dry-run

# real run (public repo, logical per-section commits), then push
scripts/export-student-repo.sh --dest /tmp/student/retailmind-ai \
  --repo "student-username/retailmind-ai" --public
```

Afterwards, fill in the README group section and drop screenshots into `screenshots/`.
