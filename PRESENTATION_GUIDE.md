# RetailMind AI — Test & Presentation Guide

**Module:** Programming for AI (55-710266) · Level 7 · Group Project · Due 20 Aug 2026

This guide explains how to run the project, how to test it, what the markers are
looking for, and a step-by-step demo script. Everything can be run with a single
`docker compose` command.

---

## 1. What the project is

**RetailMind AI** is a retail intelligence platform with two halves:

| Half | Stack | What it does |
|---|---|---|
| `backend/` | FastAPI (Python 3.12), PostgreSQL, SQLAlchemy 2.0, scikit-learn, LightGBM, XGBoost, PyTorch/transformers, SHAP | 7 independent ML domains + an AI advisor (Gemini/OpenAI) exposed through a REST API |
| `frontend/` | TanStack Start (React 19), TypeScript, Tailwind v4, Recharts, Cloudflare Workers | Interactive dashboards for every ML domain |

The two are wired together through a single reverse proxy (nginx) so the whole
thing runs as one application on one URL.

---

## 2. How it maps to the assessment ("at least 3 of the 10 topics")

The project covers **8 of the 10** topic areas, plus an advanced element:

| # | Assessment topic | Where it lives in RetailMind |
|---|---|---|
| 1 | **Classification** | Customer churn (`app/ml/churn/`) — compares XGBoost vs LightGBM vs RandomForest vs GradientBoosting vs LogisticRegression, tunes with Optuna. Inventory stock-out risk (`app/ml/inventory/`) — RandomForest/GradientBoosting on velocity/recency features. |
| 2 | **Clustering** | Customer segmentation (`app/ml/segmentation/`) — KMeans on RFM (recency/frequency/monetary), automatic `k` via silhouette score. |
| 3 | **Regression** | Demand forecasting (`app/ml/forecasting/`) — walk-forward, 60+ lag/rolling/Fourier/holiday features, confidence intervals. Sales revenue + product performance (`app/ml/sales/`) — LightGBM/GradientBoosting. |
| 4 | **Natural Language Processing** | Review text cleaning + TF-IDF vectorisation; topic modelling with LDA and NMF (`app/ml/sentiment/`). |
| 5 | **Sentiment analysis** | Review sentiment (`app/ml/sentiment/`) — LogisticRegression on TF-IDF (rating-derived labels). |
| 6 | **Neural networks / deep learning** | Optional `TransformerSentimentAnalyzer` — a DistilBERT transformer loaded from HuggingFace via `transformers` + `torch`. |
| 7 | **Cloud services for AI** | Frontend deploys to Cloudflare Workers (`wrangler deploy`); the whole stack runs on Docker; the AI advisor calls cloud LLMs (Gemini free tier, OpenAI fallback). |
| 8 | **Prompt engineering** | AI Advisor (`app/ai/`) — a tuned system prompt fed a **live, RAG-style context** built from the database (KPIs, stock alerts, sentiment, high-risk customers). |
| 9 | Evolutionary algorithms | *(not used — 3+ topics already exceeded)* |
| 10 | **Explainable AI (XAI)** | SHAP `TreeExplainer` for churn — global feature importance **and** per-customer explanations (`app/ml/explainability/`). |

**Advanced element** (something not covered in module teaching): SHAP-based
per-customer churn explanations, and the retrieval-augmented AI advisor with a
free-tier Gemini fallback (no paid API required).

---

## 3. Architecture

```
                   http://localhost:8081
                          │
                     ┌────▼────┐
                     │  nginx  │   (single origin → no CORS)
                     └────┬────┘
          ┌───────────────┼────────────────┐
          │               │                │
   ┌──────▼─────┐   ┌────▼──────┐   ┌─────▼──────┐
   │ frontend   │   │  /api/v1  │   │ /docs      │
   │ Node SSR   │   │ backend   │   │ Swagger    │
   │ port 3000  │   │ port 8000 │   └────────────┘
   └────────────┘   └────┬──────┘
                         │
                 ┌───────▼───────┐
                 │ PostgreSQL 17 │   port 5433 (host)
                 │ port 5432 int │
                 └───────────────┘

Backend layering (one direction only):
  api/v1/* (routes) → services/* (business logic) → repositories/* (DB) → db/models/*
  app/ml/<domain>/   pre-trained models, loaded lazily on first request
  app/ai/            Gemini/OpenAI advisor
```

Model artefacts are **pre-trained and baked into the Docker image** (11 MB).
The application never trains when it runs.

---

## 4. Run everything with Docker (the demo path)

Requires Docker with the Compose plugin.

```bash
# from the repo root (retailmind-ai/)
docker compose up --build -d
```

Optional configuration — a root `.env` is included with working values; every
variable also has a safe default, so you can override or omit it:

```bash
API_KEY=retailmind-demo-api-key        # shared secret between frontend + backend
SECRET_KEY=...                         # must be ≥ 32 chars
GOOGLE_API_KEY=...                     # free AI advisor (https://aistudio.google.com/apikey)
OPENAI_API_KEY=...                     # fallback advisor provider
POSTGRES_PASSWORD=...                  # DB password (default retail_dev_password)
```

What it brings up:

| Container | Purpose |
|---|---|
| `retailmind-db` | PostgreSQL 17, health-checked (host port **5433** to avoid conflicts) |
| `retailmind-backend` | FastAPI API + ML inference (host port **8000** for direct access) |
| `retailmind-backend-init` | One-shot idempotent seed: 5 users, customers, products, inventory, model runs + 500 demo sales + 200 reviews |
| `retailmind-frontend` | TanStack Start SSR app (internal port 3000) |
| `retailmind-nginx` | Reverse proxy — everything on **http://localhost:8081** |

Then open:

- **App:** http://localhost:8081
- **Login:** `admin@retailmind.ai` / `ChangeMe123!`
  (other seeded users: `analyst@`, `manager@`, `viewer@` @retailmind.ai — same password)
- **API docs (Swagger):** http://localhost:8081/docs (also http://localhost:8000/docs)
- **Health:** http://localhost:8081/health

> **First build** takes several minutes: the backend image installs the ML
> stack (torch, transformers, shap, xgboost…) and the frontend bundles with
> Vite. Later builds are cached.

---

## 5. Run without Docker (local development)

**Backend** (from `backend/`):

```bash
python3.12 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env        # set DATABASE_URL and SECRET_KEY (≥32 chars)
uvicorn app.main:app --reload --port 8000
```

**Seed data** (once, before the first demo):

```bash
python scripts/seed.py                # users, customers, products, inventory, model runs
python scripts/generate_demo_data.py  # 500 sales + 200 reviews
```

**Frontend** (from `frontend/`, package manager is `bun`):

```bash
bun install
VITE_API_BASE_URL=http://localhost:8000/api/v1 VITE_API_KEY=<your-key> VITE_USE_MOCKS=false bun run dev
# → http://localhost:4000
```

> **Mock mode:** the frontend defaults to **hardcoded mock data** unless
> `VITE_USE_MOCKS=false` is set. That mode needs no backend at all — handy for
> a quick screenshot, but the live demo should use the real API.

---

## 6. Testing — and why no training ever happens during testing

**Short answer: yes, no training is done during testing or demoing.** Model
training is a completely separate, explicit step that never runs automatically.

### How training is kept out of the running app

1. **Nothing trains at app startup.** The FastAPI `lifespan` handler only
   checks that `SECRET_KEY` is ≥ 32 chars (`backend/app/main.py`). No data is
   loaded, no model is fitted, no database is created at boot.
2. **Nothing trains on any HTTP request.** Every inference endpoint *loads* a
   pre-trained `.joblib` artefact lazily on first use (`services/*.py` →
   `app/ml/<domain>/*.load()`). If an artefact is missing, endpoints degrade
   gracefully (forecast → 503, churn/segments/sentiment → sensible defaults) —
   they never start training to fill the gap.
3. **Training only happens via explicit scripts** run by a developer:

   ```bash
   python scripts/process_data.py      # raw ZIPs → processed parquets
   python scripts/train_all.py         # trains all 7 ML domains → artifacts/
   ```
4. **In Docker, artefacts are baked into the image at build time** and mounted
   read-only in use. Starting the containers performs zero training.

> The only place training appears "during a test" is inside the **pytest ML
> unit tests**, which fit tiny synthetic models on CPU (100 rows) to verify the
> training code works. That is the test suite, not the running application.

### Backend tests

```bash
cd backend
pytest tests/ -v          # ~runs offline, no network needed
```

- `tests/api/*` — endpoint tests against an isolated SQLite DB with
  dependency overrides (see `tests/conftest.py`).
- `tests/ml/*` — train/infer on small synthetic in-memory datasets (CPU only).
- Two things to know:
  - `test_models.py` (metrics/features) and `test_forecasts.py` need the
    pre-trained artefacts (`artifacts/`) to pass. They're present on this
    machine and baked into the Docker image.
  - If a local `.env` sets `API_KEY`, the global `X-API-Key` middleware is
    active and plain `pytest` calls get 401s. Run tests with `API_KEY` unset
    (e.g. `API_KEY= pytest tests/ -v`) — that is a pre-existing local quirk,
    not a code bug.

### Frontend checks

```bash
cd frontend
bun run lint
bun run build             # production bundle
bun run wrangler:deploy   # optional: deploy the UI to Cloudflare Workers
```

There is **no configured test runner** in `frontend/package.json` — don't
assume `bun test` exists.

---

## 7. Demo script (10-minute video / live walkthrough)

Each stop proves an assessment topic. Suggested pacing:

| Time | Stop | What to show and say |
|---|---|---|
| 0:30 | **Dashboard** (`/dashboard`) | 8 KPIs, revenue trend, segment donut, live forecast, inventory-risk table, AI insights. "This is the executive view that pulls from all 7 ML domains." |
| 1:30 | **Churn classification** (`/customers`, `/customers/<id>`) | Segment donut + churn-risk column. Open a customer → churn probability + **SHAP feature-impact chart**. "A classifier (XGBoost/LightGBM/RF compared, Optuna-tuned) plus SHAP to explain *why* — that's our Explainable AI element." |
| 3:00 | **Segmentation clustering** (`/customers`) | "KMeans over RFM features; the number of segments is chosen by silhouette score, so it's data-driven." |
| 4:00 | **Demand forecasting regression** (`/sales`) | Product + horizon (7/14/30 days) selector, forecast line with confidence band, model-explainer dialog. "Walk-forward regression with rolling/holiday features and prediction intervals." |
| 5:00 | **Inventory classification** (`/inventory`) | Critical/low/healthy/overstock tiles + recommended-reorder rationale. "Stock-out risk classifier gives actionable reorder suggestions." |
| 6:00 | **Sentiment + NLP + topics** (`/reviews`) | Sentiment KPIs, trend, donut, common topics (LDA/NMF), "top customer issues". "TF-IDF + LogisticRegression sentiment; optionally a DistilBERT transformer for deeper analysis." |
| 7:00 | **AI insights + advisor** (`/insights`) | Rule-based insight cards, then "Ask RetailMind" → **live advisor** powered by the **Gemini free tier** with a RAG-style context of the current data. "Prompt engineering: we build a system prompt and feed it live business context." |
| 8:00 | **Models page** (`/models`) | Card grid with metrics, features, confusion matrix, candidate comparisons. "All 8 models registered, trained offline, served via one metadata API." |
| 8:30 | **Cloud / ops** | Show `docker compose up` (5 containers, nginx reverse proxy), and `wrangler deploy` for Cloudflare Workers. "Containerised + serverless-ready." |
| 9:00 | **Code walkthrough** | Open `app/ml/churn/train.py` and `app/ai/advisor.py` — explain layers (routes → services → ML), lazy model loading, and the graceful degradation. |
| 9:30 | **Business + ethics + AI transparency** | 60 seconds of talking points (section 8) + your AITS transparency statement. |

### Good things to mention unprompted (marks)

- **Layered architecture** — strict one-way flow, tests with dependency
  overrides, isolated ML domains that are self-contained.
- **Graceful degradation** — the app still runs (with local fallbacks) if a
  model or API key is missing. Robustness the markers can see.
- **AI advisor fallback chain** — Gemini (free tier) → OpenAI → local-data
  answer. No paid key needed to demo the advisor.
- **Not just mock data** — the demo runs against real PostgreSQL with real
  seeded transactional data, and every chart is driven by the live API.

---

## 8. Rubric alignment & talking points

| Criterion (weight) | Evidence in this project |
|---|---|
| 1. Effective use of ≥3 AI/ML areas (30%) | 8 areas listed in section 2 — complex, integrated, live-demoable. |
| 2. Technical capability / coding skills (20%) | Layered FastAPI + TanStack app, 8 ML domains, Optuna tuning, model comparison, unit tests, Docker/CI-ready. |
| 3. Advanced feature (10%) | SHAP per-customer explainability + RAG-style Gemini advisor (free tier). |
| 4. Business benefits (20%) | See below. |
| 5. Ethics, legal, environment (20%) | See below. |

**Business benefits (IntelliGen angle):**
- Revenue: forecast-driven demand planning cuts stock-outs and overstock.
- Retention: churn scores + *explanations* let staff intervene on the right
  customers ("why is this customer at risk?").
- Efficiency: automated inventory reorder recommendations, sentiment-driven
  product feedback loops.
- Extensibility: IntelliGen could white-label it — every ML domain is an
  independent module with a generic model API.

**Ethics / legal / environment:**
- Fairness & bias: RFM/clustering and churn labels must be audited for
  protected-attribute leakage; SHAP makes decisions inspectable (helps GDPR
  Article 22 "right to explanation").
- Privacy: PII (names, emails, hashed passwords) requires lawful basis,
  minimisation, retention limits.
- Environment: training runs offline on CPU for demos; DistilBERT is a
  distilled, far cheaper-to-run model; serverless Cloudflare deployment scales
  to zero — good talking points on AI's carbon footprint.

**AI transparency (AITS):** declare the level you're using (see appendix) and
describe how AI-assisted **tests, debugging, and code documentation** were
reviewed by humans. Include the statement as a report appendix.

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `docker compose up` port errors | Ports 8081/5433/8000 taken on your machine → change the `ports:` lines in `docker-compose.yml` (or use a fresh machine). |
| API calls return `401 Invalid or missing API key` | `VITE_API_KEY` (frontend build arg) must equal backend `API_KEY`. Default is `retailmind-demo-api-key`. |
| Charts empty / no data | The `backend-init` seeder must run: `docker compose up backend-init` (it is idempotent, safe to re-run). |
| Forecast page returns 503 | `artifacts/demand_forecaster/demand_forecaster.joblib` missing from the image. Rebuild from a machine that has `backend/artifacts/`, or retrain: `docker compose run --rm backend python scripts/train_all.py`. |
| Frontend shows fake data | `VITE_USE_MOCKS` must be `"false"` at build time (it is, by default, in compose). |
| Advisor answers without AI | No `GOOGLE_API_KEY` / `OPENAI_API_KEY` → the advisor falls back to a local-data answer (by design). Add a free Gemini key: https://aistudio.google.com/apikey |
| `pytest` fails with 401s | Local `.env` has `API_KEY` set → run with `API_KEY= pytest tests/ -v`. |
| Wrangler deploy | `cd frontend && bun run wrangler:deploy` — the Cloudflare build (`.output`) is unchanged by the Docker setup. |

### (Re)training models

```bash
# one-off inside Docker
docker compose run --rm backend python scripts/process_data.py
docker compose run --rm backend python scripts/train_all.py

# or locally (from backend/)
python scripts/process_data.py
python scripts/train_all.py          # writes backend/artifacts/
```

New artefacts are picked up by the next `docker compose build backend`.

---

## 10. Submission checklist

- [ ] Video (MP4 < 250 MB or unlisted YouTube/Panopto), all members audible, code legible — max 10 minutes.
- [ ] Report (Word): names + student numbers + contributions; **public GitHub link with full commit history**; run instructions + screenshots; AI usage description + **AITS transparency statement** (appendix).
- [ ] Peer assessment form per member.
- [ ] Repo hygiene: the two submodules commit independently (`backend/`, `frontend/`); never force-push the frontend branch (Lovable sync).
