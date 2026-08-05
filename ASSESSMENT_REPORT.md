# RetailMind AI — Group Project Report

**Module:** Programming for Artificial Intelligence (55-710266) · Level 7
**Assessment:** Group Project · Weighting 100% · Due 20 August 2026
**Team:** RetailMind AI

---

> **IMPORTANT — complete before submission**
> Replace every `[PLACEHOLDER]` below, add your screenshots, and review the
> AI Transparency statement (Appendix) so it matches exactly how your team
> used AI. Keep this document's structure; submit as a Word file as required.

## 1. Team members and contributions (criterion: report requirement a)

| Member | Student number | Primary contributions |
|---|---|---|
| `[Name]` | `[Number]` | `[e.g. ML training pipeline, churn + forecasting domains]` |
| `[Name]` | `[Number]` | `[e.g. FastAPI services, API design, AI advisor]` |
| `[Name]` | `[Number]` | `[e.g. Frontend dashboards, deployment/Docker, testing]` |

*Adjust the split to reflect reality — each member must be able to discuss
their part in the Q&A session.*

## 2. Code repository (criterion: report requirement b)

Public on GitHub with full commit history:

- Monorepo (documentation, docker-compose, this report): **https://github.com/mwendiaeng/retailmind-ai**
- Backend (FastAPI + ML): **https://github.com/mwendiaeng/retailmind-backend**
- Frontend (TanStack Start app): **https://github.com/mwendiaeng/retailmind-frontend**

The code is organised in clean layers (see section 5), commented, and
accompanied by 43 automated tests (`pytest tests/ -v`, all passing offline).

## 3. Project overview

**RetailMind AI** is a retail-intelligence platform: a FastAPI backend with
**eight machine-learning domains** and an **AI advisor**, and a React
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
| — | **Advanced element** | **Per-customer SHAP explanations** and a **retrieval-augmented AI advisor** with a free-tier Gemini fallback. *(Confirm suitability with lab tutor as required.)* |

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

## 7. Business benefits (mark criterion 4)

- **Demand forecasting** reduces stock-outs and overstocking — directly tied
  to revenue and working capital.
- **Churn scoring with explanations** lets retention teams prioritise the
  right customers and *say why*, improving ROI on retention campaigns.
- **Inventory risk classification** automates reorder decisions.
- **Sentiment and topic analysis** turns reviews into product/UX backlogs.
- **For IntelliGen:** every ML domain is an independent, self-contained module
  exposed through a generic model API, so it could be white-labelled for
  different retail customers; the platform already runs on the free tiers of
  Cloudflare and cloud LLM providers.

## 8. Ethical, legal and environmental issues (mark criterion 5)

- **Fairness and bias:** clustering and churn labels derived from
  transactional data must be audited to avoid proxy discrimination; SHAP makes
  model decisions inspectable, supporting accountability.
- **Privacy and law:** the platform stores personal data (names, emails,
  hashed passwords) — GDPR requires a lawful basis, data minimisation,
  retention limits, and the "right to explanation" (relevant to Article 22).
- **Environmental impact:** training runs are CPU-only and batched; DistilBERT
  is a distilled model chosen to keep inference cheap; serverless deployment
  scales to zero — reducing the carbon footprint of serving AI.

## 9. Testing summary

```bash
cd backend
API_KEY= pytest tests/ -v        # 43 passed (isolated SQLite, no network)
```

Frontend:

```bash
cd frontend
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
