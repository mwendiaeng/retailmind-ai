# RetailMind AI — Presentation Video Script (10 min)

**Module:** Programming for AI (55-710266) · Level 7 · Group Project
**Submission:** MP4 < 250 MB (or unlisted YouTube/Panopto), **max 10:00** — markers only watch the first 10 minutes.
**Team:** Prithvi Roshan (35047112) · Srikanth Aadi (35055958) · Akhil Kurumidde Andrews (35054589)

> Before filming: build the app (`docker compose up --build -d`), log in as
> `admin@retailmind.ai` / `ChangeMe123!`, and run through the app once so every
> widget on screen is loaded (no blank charts). Total runtime target: **9:40–9:55**.
> Keep a Google Gemini API key set in the environment so the AI advisor answers live.

---

## Roles (match what you actually say in the Q&A)

| Member | Owns in the demo | Code you walk through |
|---|---|---|
| **Prithvi Roshan** | Data pipeline + ML: data upload/processing, churn, segmentation, forecasting, inventory, SHAP | `backend/scripts/process_data.py`, `backend/app/ml/churn/train.py`, `app/ml/explainability/shap_explainer.py` |
| **Srikanth Aadi** | Backend services + AI advisor: reviews/sentiment, prompt engineering, business + ethics | `backend/app/ai/` (context builder, provider), `app/services/review_service.py` |
| **Akhil Kurumidde Andrews** | Auth, stack/config, frontend, deployment, testing: intro, sign-in, how to run | `frontend/src/features/sales/api.ts`, `docker-compose.yml`, `tests/conftest.py` |

---

## Timing map (overview)

| Time | Who | Screen / page | Covers |
|---|---|---|---|
| 0:00 | Akhil | `/auth` → Dashboard | Intro + **sign in (auth)** |
| 0:25 | Akhil | Terminal / nginx | **How to run + config** (Docker, env, repo) |
| 1:10 | Prithvi | Data Sources `/data` | **Data upload & processing** (ingest, validate, preview) |
| 2:15 | Prithvi | Customers → customer detail | Classification (churn) + **SHAP advanced feature** |
| 3:25 | Prithvi | Customers | Clustering (KMeans/RFM) |
| 4:05 | Prithvi | Sales | Regression (forecasting) |
| 4:55 | Prithvi | Inventory | Classification (inventory risk) |
| 5:30 | Srikanth | Reviews | NLP + sentiment + topics |
| 6:35 | Srikanth | AI Insights | Prompt engineering + AI advisor (RAG) |
| 7:40 | Akhil | Code (frontend + backend) | Technical capability + **automated tests** |
| 8:30 | Srikanth | Models page | Business benefits + ethics/legal/environment |
| 9:20 | Prithvi | Models page | Wrap-up + AI transparency (AITS 3) |

---

## 0:00–0:25 — Akhil — Intro & sign in (auth)

**On screen:** browser → http://localhost:8081 → the sign-in page (`/auth`) → type `admin@retailmind.ai` / `ChangeMe123!` → Dashboard.

> "Hi, we're **RetailMind AI** — I'm Akhil, and this is Prithvi and Srikanth. RetailMind is a retail-intelligence platform: a FastAPI backend with **seven machine-learning domains** and an **AI advisor**, and a React dashboard that visualises all of them. We cover **eight of the ten** topic areas from the brief — classification, clustering, regression, NLP, sentiment, neural networks, prompt engineering and explainable AI — plus an advanced element."

**On screen:** submit the form, land on the Dashboard.

> "Access is JWT-authenticated — every user signs in with email and password against the backend."

**Handover cue:** "Let's show you how it runs."

## 0:25–1:10 — Akhil — How to run & configuration

**On screen:** terminal with `docker compose up --build -d` output showing the 5 containers, then http://localhost:8081. Optionally the architecture slide (nginx → frontend → /api/v1 backend → PostgreSQL).

> "One command runs the whole stack — PostgreSQL, the FastAPI backend, a one-shot seeder that loads customers, products, five hundred sales and two hundred reviews, the frontend, and an nginx reverse proxy so everything lives on one URL. **Configuration is optional** — every service has safe defaults; you can override the shared API key, the DB password, and add a free Gemini key for the advisor. The code is **public on GitHub with the full commit history**, and the models are **pre-trained and baked into the image — nothing trains at runtime**."

**Handover cue:** "Prithvi will start with the data."

---

## 1:10–2:15 — Prithvi — Data upload & processing

**On screen:** Data Sources (`/data`) — dataset cards; drag a CSV onto the upload card; open the detail sheet (rows, columns, missing values, duplicates, warnings, schema table, preview table); then delete it. Cut to `backend/scripts/process_data.py` in the editor.

> "Everything starts with the data. RetailMind ingests CSV datasets through a REST endpoint — the backend **validates the schema, counts missing values and duplicates, and returns a preview** before the data is used. Watch: we upload a file, and the detail sheet shows the column schema and the first rows."

**On screen:** point at the validation results.

> "Underneath, `scripts/process_data.py` turns raw datasets into processed parquet files that train the models. So the pipeline is: **ingest → validate → preview → process → train** — and this is where we verify the data is fit before any model sees it."

**Handover cue:** "Now the models themselves."

## 2:15–3:25 — Prithvi — Classification (churn) + SHAP advanced feature

**On screen:** Customers (`/customers`) — segment donut, churn-risk column. Click a customer → customer detail (`/customers/<id>`) — churn probability bar + SHAP chart.

> "**Classification — churn prediction.** Rather than trusting one algorithm, we trained five — XGBoost, LightGBM, RandomForest, GradientBoosting and LogisticRegression — on the same folds, picked the best by F1, then tuned it with Optuna. Every customer gets a churn-risk score."

**On screen:** click a customer, point at the probability bar.

> "This customer is at high risk. And this is our **advanced element** — **SHAP explainability**. This chart shows exactly *why*: which features pushed the risk up or down, per customer. Global and per-customer explanations through a live endpoint — that's explainable AI taken beyond what we covered in the module."

**Handover cue:** "Next, clustering."

## 3:25–4:05 — Prithvi — Clustering (segmentation)

**On screen:** Customers (`/customers`) — segment distribution donut.

> "**Clustering** — customer segmentation. KMeans over RFM features — recency, frequency and monetary value. We deliberately don't hardcode the number of segments: silhouette score picks *k* automatically, so the segmentation is data-driven."

**Handover cue:** "Let's look at forecasting."

## 4:05–4:55 — Prithvi — Regression (forecasting)

**On screen:** Sales & Demand (`/sales`) — forecast chart with confidence band; change the horizon selector (7 → 30); open the "How is this calculated?" dialog.

> "**Regression** — demand forecasting. Walk-forward regression with more than sixty features — lags, rolling averages, Fourier terms for seasonality, holiday effects — producing a forecast with a confidence interval. You can change the horizon from seven to thirty days, and the dialog shows the real model metrics — MAE, RMSE and R²."

**Handover cue (optional):** "And the same pattern powers inventory."

## 4:55–5:30 — Prithvi — Classification (inventory risk)

**On screen:** Inventory (`/inventory`) — Critical/Low/Healthy/Overstock tiles, forecast/safety columns, recommended order; open one row's "Review" sheet.

> "One more classifier, for operations — **inventory risk**. Stock is scored into critical, low, healthy or overstock, with a forecast-driven recommended reorder quantity and the reasoning behind it — the platform turns a model output into an actionable decision, not just a number."

**Handover cue:** "I'll hand over to Srikanth for the language side."

---

## 5:30–6:35 — Srikanth — NLP, sentiment & topics

**On screen:** Reviews (`/reviews`) — sentiment KPI cards, trend chart, distribution donut, common topics bars, a review row.

> "Now the language side. **Sentiment analysis** — we clean the review text, vectorise it with TF-IDF and classify with a logistic-regression model. The KPI cards, trend and donut all come from that live endpoint. Below, **topic modelling with LDA** gives the common themes, with positive and negative breakdowns — so reviews become a product and support backlog, not noise."

**On screen:** point at the topics.

> "And for the **neural networks / deep learning** topic there's an optional DistilBERT transformer through HuggingFace and PyTorch — a distilled model that keeps inference cheap."

**Handover cue:** "Now the AI advisor."

## 6:35–7:40 — Srikanth — Prompt engineering & AI advisor

**On screen:** AI Insights (`/insights`) — insight cards, then the "Ask RetailMind" chat; type *"Which products are at risk of stock-out?"* and show the answer + sources used.

> "The AI advisor is our **prompt engineering** piece. We build a system prompt and feed it **live context from the database** — KPIs, stock alerts, sentiment, high-risk customers — so the model answers about *our* data, RAG-style. It calls the **Gemini free tier**, falls back to OpenAI, and as a last resort to a local-data answer — the demo works even with no paid API key."

**On screen:** type the question, wait for the answer, point at the response and sources.

> "You can see it names the sources it used — a real LLM grounded in the current dataset."

**Handover cue:** "Akhil will cover the engineering and quality."

---

## 7:40–8:30 — Akhil — Technical capability, code & automated tests

**On screen:** code editor with `frontend/src/features/sales/api.ts` (or `src/lib/api.ts`), then `backend/app/api/v1/` + `services/` layering, then a terminal running `pytest tests/ -v`.

> "My part is the frontend and the engineering around it. TanStack Start with React 19 and TypeScript — every feature has a small API module that calls the backend, with a mock fallback for development. The backend follows a strict layered design — **routes → services → repositories → models**, one direction only — which keeps it testable."

**On screen:** `pytest tests/ -v` finishing green.

> "Quality is part of the pitch: **43 backend tests** run fully offline against an isolated database, and the frontend is type-checked, linted and built clean. One Docker Compose file runs everything, and the frontend is ready to deploy serverless to Cloudflare Workers."

**Handover cue:** "Over to Srikanth for the business and ethics side."

---

## 8:30–9:20 — Srikanth — Business benefits + ethics/legal/environment

**On screen:** Models (`/models`) card grid, or a slide.

> "Why would a business buy this? Demand forecasting cuts stock-outs and overstock — that's revenue and working capital. Churn scoring with explanations lets retention teams prioritise the right customers *and say why*. Sentiment and topics turn reviews into a product backlog. For IntelliGen specifically, every ML domain is a self-contained module behind a generic model API, so it can be **white-labelled** for different retail customers, running on free tiers with near-zero marginal cost."

> "On **ethics**: we avoid protected attributes in training and SHAP makes every decision inspectable. On **law**: we store personal data under GDPR — lawful basis, minimisation, retention limits — and keeping a human in the loop on churn decisions aligns with Article 22. On **environment**: training is offline and batched, we chose a distilled model, and serverless serving scales to zero."

**Handover cue:** "Prithvi will close."

---

## 9:20–9:50 — Prithvi — Wrap-up + AI transparency

**On screen:** Models (`/models`) — grid with metrics/features/confusion matrices.

> "The Models page ties it together — all seven domains registered with their metrics, features and confusion matrices, served by one metadata API. And for transparency: we used AI-assisted development tools for **tests, debugging, and code documentation**, but every output was reviewed by a human, type-checked, and is visible in the public commit history — our AITS level is 3. Thank you — we're happy to take questions."

---

## Delivery tips (marks)

- **First 10 minutes only** — never run past 10:00; script targets ~9:50.
- **Audio**: record in a quiet room; test that all three voices are clearly audible.
- **Code legibility**: enlarge the editor font when walking through code; keep the cursor visible.
- **Each member talks** — all three must appear and speak; the split above is balanced.
- **Live data, not mock**: every chart must come from the running API — run the app before recording so nothing loads blank.
- **Auth is part of the demo** — sign in live at the start (JWT against the backend), don't skip it.
- **Config is optional** — if time is short, drop the env-variable detail but keep the `docker compose up` run.
- **Fallback if the advisor fails**: if no Gemini key is set, it returns a local-data answer — still show it and explain the fallback chain (Gemini → OpenAI → local).
- **Q&A readiness**: markers may ask about your own part — know the code behind your section (see the Roles table) and the architecture layering.
