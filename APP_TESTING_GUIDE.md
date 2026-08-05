# RetailMind AI — Live App Testing & Backend Wiring Guide

How to run the app end-to-end, what every page does, and exactly which widgets are
backed by real backend endpoints versus mock/placeholder data.

> Last verified against the code at HEAD (frontend `src/routes/*`, `src/features/*/api.ts`,
> backend `app/api/v1/*` + `app/services/*`). Statuses below are for **REAL mode**
> (`VITE_USE_MOCKS=false`).

---

## 1. How the app runs

### Full stack (Docker + nginx) — recommended for the demo

```bash
docker compose up --build -d
```

| URL | What it is |
| --- | --- |
| http://localhost:8081 | Frontend app (nginx) |
| http://localhost:8081/docs | Backend Swagger UI |
| http://localhost:8081/health | Backend health check |
| http://localhost:8000 | Backend direct (bypasses nginx) |

Login: **`admin@retailmind.ai` / `ChangeMe123!`**

The `backend-init` one-shot service runs `scripts/seed.py` (users, customers, products,
inventory) + `scripts/generate_demo_data.py` (demo sales + reviews), so the app boots with
real data. Pre-trained ML artifacts are baked into the backend image — **nothing trains at
runtime**.

### Local dev (backend + frontend, live API)

```bash
# backend (port 8000) — needs DATABASE_URL + SECRET_KEY (>=32 chars) in backend/.env
cd backend
uv sync                      # install deps into .venv (or: pip install -e ".[dev]")
uv run uvicorn app.main:app --reload --port 8000

# frontend (port 4000) — Vite dev
cd frontend
bun install
bun run dev                  # MOCK mode by default (see below)
```

### Mock mode vs real mode — important

The frontend switches between **mock** and **real** data via `VITE_USE_MOCKS`
(`src/lib/api.ts`: `USE_MOCKS = import.meta.env.VITE_USE_MOCKS !== "false"`).

- **`bun run dev`** (default) → **MOCK mode**. Every page is fully populated with synthetic
  data (forecast charts, SHAP, purchase history, etc.).
- **Docker build** sets `VITE_USE_MOCKS="false"` → **REAL mode** against the FastAPI backend.

To run the local dev servers against the live backend instead:

```bash
# in frontend/.env.local (do not commit) — copy the values from the root .env.example
VITE_API_BASE_URL=http://localhost:8000/api/v1
VITE_API_KEY=retailmind-dev-api-key   # must match backend/.env API_KEY when that gate is on
VITE_USE_MOCKS=false
```

The Docker demo shows the *real* state of the wiring — which is what you want for the
assessment.

---

## 2. Legend

| Status | Meaning |
| --- | --- |
| **Wired** | Reads real data from a backend endpoint |
| **Partial** | Real endpoint, but some fields are blank/zero because the mapper doesn't fill them (or the endpoint returns empty) |
| **Mock-only** | No backend call — data is hardcoded client-side or the chart receives an empty array |
| **Cosmetic** | UI works but doesn't talk to the backend at all (buttons/toasts/static badges) |

---

## 3. Page-by-page

### Auth — Sign in / Sign up (`/auth`, `/`)

| Feature | Status | Backend call |
| --- | --- | --- |
| Sign in with email + password | **Wired** | `POST /api/v1/auth/login` → JWT stored in localStorage |
| Create account (name, company, email, password) | **Wired** | `POST /api/v1/auth/register` |
| Restore session on reload | **Wired** | `GET /api/v1/auth/me` |
| Route guard (redirects to `/auth` when logged out, to `/dashboard` when logged in) | **Wired** | localStorage `retailmind_token` |
| Update profile (name, company) | **Wired** | `PUT /api/v1/auth/me` (Account page) |
| Change password | **Wired** | `POST /api/v1/auth/change-password` (Account page) |
| Forgot / reset password (`/forgot-password`, `/reset-password`) | **Cosmetic** | Backend JWT system has no email-reset flow — these are informational pages. Don't demo them. |

**How to test:** wrong password → toast error; correct login → dashboard; refresh → still
logged in; sign out (sidebar or user menu) → back to `/auth`.

### App shell (sidebar + top header)

| Feature | Status |
| --- | --- |
| Sidebar navigation (Dashboard, Data, Sales & Demand, Inventory, Customers, Products, Reviews, AI Insights, Models, Account, Settings) | **Wired** (routes) |
| Date-range selector in header (7/30/90 days, YTD) | **Wired** — drives `useDateRange`, which feeds the Sales page queries |
| Light/dark theme toggle | **Wired** (client-side) |
| Breadcrumb | **Wired** (client-side) |
| Notifications bell | **Wired** — alerts built from `useInsights` (high/medium severity), links to `/insights` |
| User menu (account, settings, sign out) | Sign out **Wired** (clears JWT) |

### Dashboard (`/dashboard`)

| Widget | Status | Backend call |
| --- | --- | --- |
| KPI cards: Total Revenue, Total Orders, Total Customers, Avg Order Value | **Wired** | `GET /dashboard/` → `kpis` |
| Secondary KPIs: Total Products, Inventory Alerts | **Wired** | `GET /dashboard/` → `kpis` |
| Sales performance chart | **Wired** | `GET /sales/trends?start_date=…&end_date=…&aggregation=daily` |
| Customer segments donut | **Wired** (only if segmentation artifact loads) | `GET /segments/` |
| **Demand forecast chart** | **Wired** | `POST /forecasts/` `{horizon_days: 14}` → predictions (14-day aggregate forecast) |
| Sentiment overview bars | **Wired** (only if reviews exist) | `GET /reviews/sentiment/summary` |
| Inventory risk table | **Wired** | `GET /inventory/` (first 6) |
| AI insights list (top 4) | **Wired** | `GET /insights/` → `insights` |
| Top products table | **Wired** | `GET /sales/products` |

### Data Sources (`/data`)

| Feature | Status | Backend call |
| --- | --- | --- |
| Dataset cards (name, rows, columns, type, status, uploaded) | **Wired** | `GET /datasets/` |
| Dataset detail sheet | **Wired** | `GET /datasets/{id}` + `GET /datasets/{id}/preview` → rows/columns, missing/duplicates/warnings/schema table, preview table |
| **Drag & drop / click to upload CSV** | **Wired** | `POST /datasets/` (multipart `file` + `name` + `type`) — real upload, then detail sheet refreshes |
| **Delete dataset** | **Wired** | `DELETE /datasets/{id}` (204) — removes the card, then invalidates the query |

### Sales & Demand (`/sales`)

| Widget | Status | Backend call |
| --- | --- | --- |
| KPI cards (Revenue, Units Sold, Avg Daily Sales) | **Wired** | `GET /sales/summary` + `GET /sales/trends` |
| "Forecast Growth" KPI | **Cosmetic** | hardcoded |
| Sales trend chart (Revenue/Units toggle, 7/30/90d) | **Wired** | `GET /sales/trends?aggregation=daily` |
| Category performance bar chart | **Wired** | `GET /sales/categories` |
| Top products table | **Wired** | `GET /sales/products` |
| **Demand forecast chart** | **Wired** | `POST /forecasts/` `{horizon_days}` (per selected horizon) — historical actuals + forecast tail |
| Product selector + 7/14/30-day horizon | **Wired** | horizon drives the forecast call |
| Predicted demand / Expected change / Status mini-stats | **Wired** | from the forecast response `predictions` + `predicted_total` |
| "How is this calculated?" model dialog | **Wired** | `GET /models/forecasting` + forecast `model_metrics` → algorithm, records, MAE/RMSE/R² |

### Inventory (`/inventory`)

| Feature | Status | Backend call |
| --- | --- | --- |
| KPI tiles (Critical / Low / Healthy / Overstock) | **Wired** (computed client-side from list) | `GET /inventory/` |
| Table with status filter tabs + search | **Wired** | `GET /inventory/` |
| Predicted demand / Safety stock columns | **Wired** | forecast-derived (`POST /forecasts/` per product when available, share-based default otherwise) |
| Recommended order | **Wired** | `reorder_quantity` (or `reorder_point − quantity`) |
| Review side sheet ("Why this recommendation") | **Wired** | real stock/reorder/forecast values in the explanation |

### Customers (`/customers`)

| Feature | Status | Backend call |
| --- | --- | --- |
| KPI cards (Total, High Value, At Risk, Avg Value) | **Wired** | `GET /customers/` + `GET /segments/` |
| Segment distribution donut | **Wired** | `GET /segments/` |
| Segment + churn-risk filters | **Wired** (client-side) | — |
| Table (name, email, orders, total spend, avg order, segment, churn risk, last purchase) | **Wired** | `GET /customers/` |

### Customer detail (`/customers/$id`)

| Feature | Status | Backend call |
| --- | --- | --- |
| Header stats (spend, orders, avg order, last purchase, tenure) | **Wired** | `GET /customers/{id}` |
| **Purchase history chart** | **Wired** | `GET /customers/{id}/history` |
| RFM analysis | **Wired** | recency/frequency/monetary from `GET /customers/{id}` |
| Churn prediction (probability bar + risk badge) | **Wired** | `churn_probability` from `GET /customers/{id}` |
| **"Explaining this prediction" SHAP chart** | **Wired** | `GET /explanations/churn/{customer_id}` |
| Not-found handling | **Wired** | 404 → "Customer not found." |

### Products (`/products`)

| Feature | Status | Backend call |
| --- | --- | --- |
| KPI cards (Products, Top Performers, Underperforming, Low Stock) | **Wired** | from `GET /products/` (aggregates revenue/performance) |
| Table (name, category, stock, revenue, units, growth, rating, sentiment, forecast) | **Wired** | `GET /products/` |

### Product detail (`/products/$id`)

| Feature | Status | Backend call |
| --- | --- | --- |
| Header mini-stats (revenue, units, growth, stock, forecast, rating) | **Wired** | `GET /products/{id}` + `GET /products/{id}/performance` |
| **Sales history chart** | **Wired** | `GET /products/{id}/performance` → `history` |
| **Demand forecast chart** | **Wired** | `POST /forecasts/` `{product_id}` |
| Inventory status card (stock / forecast / safety / reorder) | **Wired** | stock real; forecast/safety from the forecast call |
| Recent reviews (up to 6, star rating, sentiment, text, product, date) | **Wired** | `GET /reviews/?product_id={id}&limit=6` |
| "No reviews yet" empty state | **Wired** | — |

### Reviews (`/reviews`)

| Feature | Status | Backend call |
| --- | --- | --- |
| KPI cards (Reviewed, Positive/Neutral/Negative %) | **Wired** | `GET /reviews/sentiment/summary` |
| Sentiment trend chart | **Wired** | `GET /reviews/sentiment/trends` |
| Sentiment distribution donut | **Wired** | from summary |
| Common topics bars | **Wired** | `GET /reviews/topics` — topic + mentions + positive/negative % |
| Top customer issues | **Wired** | derived from topics |
| Reviews table (text, rating, sentiment, confidence, product, date, topics) | **Wired** | `GET /reviews/` |
| Review detail sheet (confidence progress, topics, model note) | **Wired** | same payload |

### AI Insights (`/insights`)

| Feature | Status | Backend call |
| --- | --- | --- |
| Insight cards grouped by Priority + category tabs (severity badge, evidence, recommendation) | **Wired** | `GET /insights/` (real, generated from DB state) |
| "View details" button | **Cosmetic** | no-op |
| **"Ask RetailMind" chat** | **Wired** | `POST /advisor/ask` `{question}` → real Gemini/OpenAI answer, sources used, generated-at |

### Models (`/models`)

| Feature | Status | Backend call |
| --- | --- | --- |
| Model cards (name, type, status, description, top-3 metrics) | **Wired** | `GET /models/` |
| Detail sheet (algorithm, trained date, dataset, training records, full metrics, features, confusion matrix, model comparison table) | **Wired** | `GET /models/{id}`, `GET /models/{id}/metrics`, `GET /models/{id}/features` |
| Status reflects trained/not-trained from artifact metadata | **Wired** | — |

### Settings (`/settings`)

| Feature | Status |
| --- | --- |
| Default date range | **Cosmetic** — a Select that changes nothing (the real range picker is in the header) |
| Theme (light/dark/system) | **Wired** (client-side) |
| Advisor status "Connected" badge | **Cosmetic** — hardcoded |
| "Enable AI Advisor" switch | **Cosmetic** — does nothing |
| Model information list | **Wired** | `GET /models/` |
| "Delete all uploaded datasets" | **Wired** | iterates `GET /datasets/` + `DELETE /datasets/{id}` for each |

### Account (`/account`)

| Feature | Status | Backend call |
| --- | --- | --- |
| Profile form (name, company) | **Wired** | `GET /auth/me` (load) + `PUT /auth/me` (save) |
| Change password | **Wired** | `POST /auth/change-password` |
| Sign out | **Wired** | clears JWT via auth context |

---

## 4. Summary table

| Page | Wired | Partial | Mock-only / cosmetic |
| --- | --- | --- | --- |
| Sign in / Sign up | ✔ login, register, me, guards, profile, change password | — | forgot/reset password (info pages) |
| App shell | ✔ nav, date range, theme, sign-out, notifications | — | breadcrumb |
| Dashboard | ✔ KPIs, sales trend, segments, forecast, sentiment, inventory, insights, top products | — | — |
| Data Sources | ✔ list, detail sheet, upload, delete | — | — |
| Sales & Demand | ✔ trends, categories, products, forecast, horizon, mini-stats, model dialog | — | "Forecast Growth" KPI |
| Inventory | ✔ list, KPIs, reorder, forecast/safety columns, sheet | — | — |
| Customers | ✔ list, segments, filters, last purchase | — | — |
| Customer detail | ✔ churn probability, history, SHAP, RFM | — | — |
| Products | ✔ list incl. revenue/units/growth/rating | — | — |
| Product detail | ✔ performance, forecast, history, reviews | — | — |
| Reviews | ✔ summary, trends, topics, list, sheet | — | — |
| AI Insights | ✔ insight cards, Ask RetailMind chat | — | "View details" button |
| Models | ✔ list + full detail | — | — |
| Settings | ✔ model info, theme, delete-all datasets | — | date range, advisor toggle, connected badge |
| Account | ✔ profile, change password, sign out | — | — |

---

## 5. Developer verification

Run these before any demo or submission (each repo is independent — see `CLAUDE.md`).

```bash
# backend — tests + type check (from backend/)
uv run pytest tests/ -v           # currently 43 passing
uv run mypy app/                  # clean on the edited modules

# frontend — types + build + lint (from frontend/)
bun install
bunx tsc --noEmit                 # exit 0
bun run build                     # exit 0
bun run lint                      # only pre-existing @typescript-eslint/no-explicit-any in src/features/*/api.ts
```

---

## 6. Recommended demo script (~10–12 min, Docker build / real mode)

1. `docker compose up --build -d` → wait for `backend-init` to finish (`docker compose logs backend-init`).
2. Open http://localhost:8081 → sign in with `admin@retailmind.ai` / `ChangeMe123!`.
3. **Dashboard** — real KPIs, sales trend, segments donut, **demand forecast chart**, sentiment
   bars, inventory risk table, AI insights, notifications bell.
4. **Sales & Demand** — real trend + category charts, top products, forecast chart with
   horizon selector, "How is this calculated?" model dialog with MAE/RMSE/R².
5. **Inventory** — filter tabs, search, forecast/safety columns, "Review" sheet.
6. **Customers** — segment donut, segment/risk filters, open a customer → churn probability,
   **purchase history** and **SHAP explanation** charts.
7. **Products** — open a product → real performance, forecast, history + real reviews.
8. **Reviews** — summary KPIs, sentiment trend, topics with positive/negative %, detail sheet.
9. **AI Insights** — real insight cards, then ask the **Advisor** a question and show the
   Gemini/OpenAI answer.
10. **Data Sources** — real list; upload a CSV and watch the detail sheet populate (rows,
    missing, duplicates, schema, preview); delete it.
11. **Models** — all 7 domains with real metrics/features/confusion matrix.
12. **Account / Settings** — edit profile, change password, delete-all datasets.
13. End with **Swagger** at http://localhost:8081/docs → show the live endpoints; explain
    that training is offline (artifacts baked in).

---

## 7. Troubleshooting

- **Login fails / 401 on every API call** → the global `X-API-Key` gate is active; the Docker
  stack sets `API_KEY=retailmind-demo-api-key` and the frontend sends it via `VITE_API_KEY`.
  For local dev, the frontend must use the same `VITE_API_KEY` as `backend/.env` `API_KEY`
  (see the root `.env.example`).
- **Empty tables** → demo data not loaded: run `docker compose run --rm backend python scripts/generate_demo_data.py`
  (idempotent) and refresh.
- **Segments donut empty** → the K-Means artifact must be present; it's baked into the
  backend image under `/app/artifacts` (`MODEL_PATH`).
- **Advisor answers "unavailable"** → no `GOOGLE_API_KEY`/`OPENAI_API_KEY` is set; the
  endpoint degrades gracefully. Set one in `backend/.env` for the demo.
- **Ports** → this machine already uses 5432/8080/3000; compose maps db→5433 and nginx→8081.
- **Frontend build in Docker** → `VITE_USE_MOCKS="false"` is set by compose; if you want the
  fully-populated mock UI for screenshots, run `bun run dev` locally instead.
- **Backend won't start** → `SECRET_KEY` must be ≥32 characters (`main.py` lifespan check).
