# RetailMind AI — Group Project Report

**Module:** Programming for Artificial Intelligence (55-710266) · Level 7
**Assessment:** Group Project · Weighting 100% · Due 20 August 2026
**Team:** RetailMind AI

---

> **IMPORTANT — complete before submission**
> Replace every `[Screenshot: …]` placeholder with real captures, confirm the
> GitHub link in §2 points to the exported single student repo (must be the
> account the repo was pushed from), and review the AI Transparency statement
> (Appendix) so it matches exactly how your team used AI. Keep this document's
> structure; submit as a Word file as required.

## 1. Team members and contributions (criterion: report requirement a)

| Member | Student number | Primary contributions |
|---|---|---|
| Prithvi Roshan | 35047112 | ML training pipeline — churn prediction, demand forecasting, inventory risk, customer segmentation; SHAP explainability; model evaluation/tuning. |
| Srikanth Aadi | 35055958 | FastAPI services and API design (routes → services → repositories), AI advisor + prompt engineering/RAG context, review/sentiment/topic models. |
| Akhil Kurumidde Andrews | 35054589 | Frontend dashboards and pages, data-viz charts, Docker/nginx full-stack stack, Cloudflare deployment, backend test suite. |

*Each member presents their own part in the video and can discuss it in the Q&A
session; this split reflects who led each area — everyone reviewed the others' work.*

## 2. Code repository (criterion: report requirement b)

Public on GitHub as a **single repository** with full commit history:

- **https://github.com/mwendiaeng/retailmind-ai**

The repository contains the whole project in one tree — `backend/` (FastAPI +
ML), `frontend/` (TanStack Start web app), `deploy/` (nginx), `docker-compose.yml`
and this report. The history is committed in logical, section-based commits
(docs → backend core → ML domains → AI advisor → tests → frontend → config) so
reviewers can follow how the application was built. Code is organised in clean
layers (see section 5), commented, and accompanied by 43 automated tests
(`pytest tests/ -v`, all passing offline).

## 3. Project overview

**RetailMind AI** is a retail-intelligence platform: a FastAPI backend with
**seven machine-learning domains** and an **AI advisor**, and a React
(TanStack Start) frontend that visualises every domain. It answers business
questions such as *which customers will churn and why*, *how much demand to
expect next month*, *which stock items are at risk*, and *what the market is
saying about our products*.

The assessment asks for at least 3 AI/ML topic areas; this project covers
**8 of the 10**, plus an advanced element:

| # | Topic area | Implementation in RetailMind |
|---|---|---|
| 1 | Classification | Customer churn (`app/ml/churn/`) — XGBoost/LightGBM/RandomForest/GradientBoosting/LogisticRegression compared, then Optuna-tuned; inventory stock-out risk (`app/ml/inventory/`). |
| 2 | Clustering | Customer segmentation (`app/ml/segmentation/`) — KMeans on RFM features, cluster count chosen automatically by silhouette score. |
| 3 | Regression | Demand forecasting (`app/ml/forecasting/`) — walk-forward regression with lag/rolling/Fourier/holiday features and confidence intervals; sales and product-performance models. |
| 4 | Natural language processing | Review text cleaning, TF-IDF vectorisation, topic modelling with LDA and NMF. |
| 5 | Sentiment analysis | Review sentiment classifier (LogisticRegression over TF-IDF). |
| 6 | Neural networks / deep learning | Optional `TransformerSentimentAnalyzer` using DistilBERT via HuggingFace `transformers` + PyTorch. |
| 7 | Cloud services for AI | Frontend deploys to Cloudflare Workers; whole stack containerised with Docker; advisor calls cloud LLMs (Gemini free tier / OpenAI fallback). |
| 8 | Prompt engineering | AI advisor built on a tuned system prompt fed live, RAG-style database context. |
| 9 | Explainable AI | SHAP `TreeExplainer` — global feature importance and per-customer churn explanations. |
| — | **Advanced element** | **Per-customer SHAP explanations** and a **retrieval-augmented AI advisor** with a free-tier Gemini fallback. See §5.2 for why these go beyond the module teaching. |

## 4. How to run the application and expected output (criterion: report requirement c)

### 4.1 Quickest path — Docker (recommended for demo)

```bash
git clone https://github.com/mwendiaeng/retailmind-ai.git
cd retailmind-ai
docker compose up --build -d
```

This starts five containers — PostgreSQL, the FastAPI backend, a one-shot
seeder (5 users, customers, products, inventory, 500 sales, 200 reviews), the
frontend, and an nginx reverse proxy. Pre-trained models are baked into the
image; **nothing is trained at runtime**.

| URL | Purpose |
|---|---|
| http://localhost:8081 | The application (frontend via nginx) |
| http://localhost:8081/docs | Interactive API documentation (Swagger) |
| http://localhost:8000/docs | Backend docs directly |
| http://localhost:8081/health | Health check |

**Login:** `admin@retailmind.ai` / `ChangeMe123!`
(other seeded users: `analyst@`, `manager@`, `viewer@` @retailmind.ai, same password)

**Expected output:** the Dashboard opens with KPI cards, a revenue trend
chart, customer-segment donut, demand forecast with confidence band,
inventory-risk table and AI insights — all driven by the live API against
seeded data. The Models page lists all trained models with metrics and
features. AI/ML pages behave as shown in the screenshots below.

*[Screenshot: Dashboard]*
*[Screenshot: Customer detail with SHAP explanation]*
*[Screenshot: Sales demand forecast]*
*[Screenshot: AI advisor response]*

### 4.2 Local development

Backend:

```bash
cd backend
python3.12 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env            # set DATABASE_URL and SECRET_KEY (≥32 chars)
python scripts/seed.py
python scripts/generate_demo_data.py
uvicorn app.main:app --reload --port 8000
```

Frontend:

```bash
cd frontend
bun install
VITE_API_BASE_URL=http://localhost:8000/api/v1 VITE_USE_MOCKS=false bun run dev
# → http://localhost:4000
```

(Training is an explicit, separate step only needed when models are rebuilt:
`python scripts/process_data.py && python scripts/train_all_models.py`.)

## 5. Technical architecture and key code explained (criterion: report requirement b/c)

Strict layering, one direction only:

```
api/v1/* (routes) → services/* (business logic) → repositories/* (DB access) → db/models/*
app/ml/<domain>/    seven independent ML modules, pre-trained artifacts loaded lazily
app/ai/             Gemini/OpenAI advisor with RAG-style context
```

Key design decisions:

- **Models are never trained at runtime.** The FastAPI `lifespan` handler only
  validates `SECRET_KEY`; inference endpoints lazily `load()` pre-trained
  `.joblib` artifacts. If an artifact is missing the endpoints degrade
  gracefully (e.g. forecast returns 503, churn falls back to stored
  probabilities) rather than crashing — a deliberate robustness choice.
- **Model comparison and tuning** (`app/ml/churn/train.py`): five algorithms
  are trained on the same folds and the best by F1 is selected, then
  hyper-parameters are tuned with Optuna. This demonstrates understanding of
  the ML workflow, not just one fixed algorithm.
- **Explainable AI** (`app/ml/explainability/shap_explainer.py`): SHAP
  `TreeExplainer` produces both global feature importance and per-customer
  breakdowns shown in the UI as "why is this customer at risk".
- **Prompt engineering / RAG** (`app/ai/`): the advisor builds a context block
  from live database aggregates (KPIs, stock alerts, sentiment, high-risk
  customers), wraps it in a system prompt, and calls Gemini (free tier) with
  OpenAI as fallback and a local-data answer as last resort.
- **Tests** isolate the database (SQLite + dependency overrides in
  `tests/conftest.py`) and run fully offline — `43 passed`.

### 5.1 Advanced feature justification (mark criterion 3)

The two advanced elements were chosen because they go beyond the module teaching:

- **Per-customer SHAP explanations** (`app/ml/explainability/shap_explainer.py`).
  XAI is introduced at module level conceptually; here we implement an *operational*
  integration — a `TreeExplainer` that produces both global feature importance and a
  per-customer feature breakdown, exposed via a dedicated REST endpoint
  (`GET /explanations/churn/{customer_id}`) and rendered interactively in the customer
  detail page ("why is this customer at risk?"). This moves explainability from a
  notebook exercise into a production feature that a retailer actually uses in
  decision-making — beyond the taught material.
- **Retrieval-augmented AI advisor** (`app/ai/`). Prompt engineering is one of the
  listed topic areas, but the advisor extends it into a RAG-style system: it assembles a
  *live* context block from database aggregates (KPIs, stock alerts, sentiment, high-risk
  customers), wraps it in a tuned system prompt, and calls a hosted LLM (Gemini free tier)
  with an OpenAI fallback and a local-data answer as last resort. It also returns the
  sources it used. This couples an LLM to the app's own data in a way not covered in the
  module.

Both are also practically useful to IntelliGen's retail customers, not just demos.

### 5.2 Libraries and platforms (mark criterion 2)

| Layer | Libraries / platforms | Why |
|---|---|---|
| Web framework | FastAPI + Uvicorn, Pydantic v2, SQLAlchemy 2.0 + Alembic | Typed, async-capable REST API with auto-generated OpenAPI/Swagger docs |
| Data | pandas, NumPy, PyArrow/Parquet | Data pipeline and feature engineering (`scripts/process_data.py`) |
| ML | scikit-learn, XGBoost, LightGBM, Optuna, PyTorch + HuggingFace `transformers` | 5-algorithm comparison with tuning; optional DistilBERT classifier |
| Time series | custom walk-forward regression with lag/rolling/Fourier/holiday features | Produces forecasts with confidence intervals without external forecasting services |
| Explainability | SHAP (`TreeExplainer`) | Global + per-customer feature attributions |
| NLP | TF-IDF, LDA/NMF topic modelling | Review sentiment + topic detection |
| LLM / cloud | Google Gemini API (free tier), OpenAI fallback, HTTPX | AI advisor with RAG-style context |
| Frontend | TanStack Start (React 19), TypeScript, Tailwind v4, shadcn/Radix, Recharts | SSR-capable dashboard app |
| Deployment | Docker Compose + nginx, Cloudflare Workers (Wrangler) | One-command full stack; free-tier serverless frontend hosting |
| Testing/quality | pytest, mypy, ESLint, Prettier | 43 offline tests; static type checks in CI-style workflow |

All services run on free tiers or local infrastructure — no purchased cloud
services (per the assessment note).

## 6. How AI was used in the development of this project (criterion: report requirement d)

This section is the required disclosure. We used AI-assisted development
tools (interactive coding agents and IDE assistants) extensively:

- **Code generation and scaffolding:** AI assistants drafted route handlers,
  services, ML pipelines, database models, frontend pages, and Docker
  configuration. Every generated block was reviewed by a team member,
  type-checked, and covered by tests; significant parts were rewritten.
- **Debugging and refactoring:** AI was used to trace failing tests (e.g.
  graceful-degradation behaviour when artifacts are absent) and to restructure
  the advisor's provider abstraction to support Gemini.
- **Testing:** AI helped author the pytest suite (API, ML, and service tests).
  The suite is run by the team and all 43 tests pass.
- **Documentation:** this report, the presentation guide, and commit messages
  were drafted with AI assistance and then reviewed and edited by the team.
- **The product itself** also contains AI features (ML models and an LLM
  advisor) — those are the deliverable, not part of this disclosure.

Nothing was submitted as if it were purely human work; the full commit history
is public on GitHub and every contribution was critically reviewed.

### 6.1 Development environment and code-generation tools

The team works both **with and without an IDE**, deliberately:

- **With IDE (VS Code / JetBrains + extensions):** language servers give live
  type-checking, navigation and refactoring, integrated testing, and Git tooling.
  This is where most backend and frontend development happened. The trade-off is a
  heavier toolchain and some team members using different setups.
- **Without IDE:** quick edits, debugging, and CI-style checks are done from the
  terminal (Vim/CLI + `git`). This keeps the workflow reproducible and lets anyone
  run the project in any environment — important because the video shows code being
  run, not just edited.

**Code-generation tools** (interactive AI coding agents) were used as accelerators —
drafting route handlers, services, ML pipelines, and frontend pages. We judged them
**helpful** for boilerplate, API-shape alignment between backend and frontend, and
rapid iteration. We also hit **real limitations**: generated code sometimes imports
modules that don't exist or ignores a project's conventions, so every block had to be
reviewed against the codebase, type-checked (`mypy`/`tsc`), and often rewritten; the
tools also produce confident but wrong results without sufficient context. Our rule
was: *an AI draft is never shipped until a team member reads it and the tests pass.*

## 7. Business benefits (mark criterion 4)

### 7.1 Benefits of RetailMind

- **Demand forecasting** reduces stock-outs and overstocking — directly tied
  to revenue and working capital.
- **Churn scoring with explanations** lets retention teams prioritise the
  right customers and *say why*, improving ROI on retention campaigns.
- **Inventory risk classification** automates reorder decisions.
- **Sentiment and topic analysis** turns reviews into product/UX backlogs.

### 7.2 For an IntelliGen customer

RetailMind is architected so an IntelliGen consultant could white-label it: every ML
domain is an independent, self-contained module exposed through a generic model API
(`app/ml/<domain>` + `services/model_service.py`), so a customer's data can be dropped
in and new models trained offline with the same pipeline. Because it runs on free tiers
(Cloudflare Workers, Gemini/OpenAI free-tier), it can be deployed for a small retailer
with near-zero marginal cost, then scaled as the customer grows.

**Alternatives considered:** a rule-based BI dashboard (cheap but no prediction), a
single off-the-shelf forecasting SaaS (simpler but proprietary, monthly fees, no
explainability, no churn/sentiment), and a spreadsheet-driven process (zero integration
with live data). RetailMind wins on integration and explainability but is heavier to
maintain — the realistic recommendation is to pair it with an analyst for a mid-size
retailer rather than replace existing tools.

### 7.3 Critical review — advantages and disadvantages of AI/ML for business

**Advantages:** automation of routine analysis; predictions that beat human
judgement on high-volume, pattern-heavy decisions; consistent, auditable
decisioning; the ability to surface problems (churn, stock-outs) before they
happen.

**Disadvantages:** models are only as good as their data — bias and drift can
silently degrade decisions; explanations add cost and complexity; results must
be communicated to non-technical stakeholders; dependency on data quality,
infrastructure, and (here) free-tier API limits.

**Current and potential developments:** fine-tuned domain LLMs and agentic
assistants that act on analytics rather than only describing it; on-device
serving reducing latency and privacy exposure; synthetic data for rare events.
Potential limits include regulatory pressure, energy costs of large models, and
the need for human accountability when automated decisions affect people.

### 7.4 Skills and techniques needed to maximise benefit

Business-side staff need data literacy — how to frame a question as a prediction
problem, read an explanation, and challenge a model. Technical staff need
feature engineering, evaluation discipline (honest hold-out metrics), MLOps
(versioning, monitoring, drift detection), and enough explainability tooling to
make outputs trustworthy. For IntelliGen, this means the value of RetailMind is
only unlocked if it ships with the people who can interpret it — which is part
of the pitch.

## 8. Ethical, legal and environmental issues (mark criterion 5)

### 8.1 Fairness and bias

Clustering and churn labels are derived from transactional data; if that data
reflects historic inequality (e.g. under-served customer groups), the model can
reproduce it as a self-fulfilling prediction — e.g. scoring a postcode as
"at-risk" because of where people live. Mitigations here: features are limited
to purchase behaviour rather than demographics, and SHAP makes every churn
decision inspectable so a human can challenge a proxy. We do **not** use
protected attributes in training, and we recommend regular fairness audits
before any automated retention campaign.

### 8.2 Privacy and law

The platform stores personal data (names, emails, hashed passwords). Under
**UK GDPR**: a lawful basis is required (here, legitimate interest for
business analytics, subject to a balancing test); data minimisation and
retention limits should be applied (e.g. deleting or anonymising customer
records on request); and individuals have rights of access and erasure.
Article 22 restricts decisions based *solely* on automated processing — churn
scoring with SHAP explanations is designed to be human-reviewed, which is
exactly the kind of meaningful human involvement the law expects. The code
also uses the Consumer Rights Act / trade-descriptions angle only insofar as
product data is the customer's own.

### 8.3 Environmental impact

Training runs are CPU-only and batched; DistilBERT (a distilled model) is used
to keep inference cheap; and serverless deployment scales to zero, so energy
use tracks demand. The largest environmental cost in production would be the
hosted LLM calls in the advisor — mitigated by the free-tier caps and by
falling back to local-data answers when the LLM is unavailable. A fuller
review would compare model size vs accuracy to justify every deployment.

### 8.4 Impact on IntelliGen

For IntelliGen these issues are both **risk and opportunity**: a defensible
ethics position (auditable models, GDPR-ready data handling, energy-conscious
serving) is a sales differentiator when pitching to retailers, but a model that
is biased, unexplained, or leaks data would damage IntelliGen's reputation and
expose it to regulatory action. Our recommendation to any IntelliGen client:
publish a short AI use policy, keep a human in the loop for any decision that
affects a person, and log model outputs for audit.

## 9. Testing summary

```bash
cd backend
API_KEY= pytest tests/ -v        # 43 passed (isolated SQLite, no network)
```

Frontend:

```bash
cd frontend
bun install
bunx tsc --noEmit      # static type check, clean
bun run lint
bun run build
```

## 10. Appendix — AI Transparency Statement (AITS)

> **Statement level used: 3 — AI for Developing** (see the AI Transparency
> Scale in the assessment brief; adjust if your usage differs).
>
> We declare that AI tools were used to assist with detailed development of
> many aspects of this project (code generation, debugging, tests, and
> documentation) as described in section 6. A human team member directed,
> reviewed, and critically edited all AI-generated outputs, and the final
> submission — the application, its tests, and this report — was verified and
> curated by the team. No AI output was submitted without human review.

---

*End of report.*
