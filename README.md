# SaaS Batch Analytics

[![CI](https://github.com/jonas-schaetzle/saas-batch-analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/jonas-schaetzle/saas-batch-analytics/actions/workflows/ci.yml)

An end-to-end analytics engineering project for a synthetic SaaS business, built with `dbt`, `DuckDB`, `Apache Airflow`, and `Docker Compose`.

This repository models raw SaaS operational data into curated analytics layers for churn, revenue, support, and product usage analysis. It is designed as a portfolio project that demonstrates practical analytics engineering, layered data modeling, schema testing, and orchestration-ready pipelines.

## Project Goals

This project is built around three core questions:

1. Which customer, revenue, support, and product usage signals are associated with churn?
2. How can raw SaaS entity and event data be transformed into reliable analytics models?
3. What does a clean, reproducible local analytics stack look like for batch-oriented workflows?

## Dataset

The project uses a synthetic multi-table SaaS dataset with the following core entities:

- `accounts`
- `subscriptions`
- `feature_usage`
- `support_tickets`
- `churn_events`

The dataset simulates a SaaS business with realistic relationships, temporal behavior, upgrades, downgrades, support escalations, beta feature usage, and churn outcomes.

Raw data lives in [data/raw](/Users/jonasschaetzle/Documents/01_Jonas/01_Dev/01_PortfolioProjects/saas-batch-analytics/data/raw).

## Tech Stack

- `dbt` for transformations, testing, and model documentation
- `DuckDB` as the analytical warehouse
- `Apache Airflow` for orchestration
- `Docker Compose` for local execution
- `sqlfluff` and `ruff` for code quality

## Architecture

The dbt project follows a layered modeling approach:

### 1. Staging

Raw tables are standardized, typed, and lightly cleaned.

Examples:

- `stg_accounts`
- `stg_subscriptions`
- `stg_feature_usage`
- `stg_support_tickets`
- `stg_churn_events`

### 2. Intermediate

Account-level summaries are created to simplify downstream business logic.

Examples:

- `int_account_subscription_summary`
- `int_account_support_summary`
- `int_account_churn_summary`
- `int_account_usage_summary`

### 3. Marts

Business-facing analytics models expose curated views for decision-making and analysis.

Examples:

- `mart_churn_analysis`
- `mart_revenue_by_month`

## Model Flow

```text
raw_accounts ---------> stg_accounts -------------------------------+
                                                                  |
raw_subscriptions ----> stg_subscriptions --> int_account_subscription_summary --+
                                   |                                             |
raw_feature_usage ----> stg_feature_usage --> int_account_usage_summary ---------+--> mart_churn_analysis
                                                                                 |
raw_support_tickets -> stg_support_tickets -> int_account_support_summary -------+
                                                                                 |
raw_churn_events ----> stg_churn_events ---> int_account_churn_summary ----------+

raw_subscriptions ----> stg_subscriptions ---------------------------------------> mart_revenue_by_month
```

## Key Models

### `mart_churn_analysis`

An account-level churn mart that combines:

- account attributes
- subscription and revenue metrics
- support signals
- product usage signals
- churn outcomes

It includes derived health and churn indicators such as:

- `mrr_per_seat`
- `support_tickets_per_subscription`
- `usage_events_per_subscription`
- `usage_intensity_per_day`
- `error_rate_per_usage`
- `days_from_last_usage_to_churn`
- `account_lifetime_days`
- `beta_feature_adopter_flag`

### `mart_revenue_by_month`

A monthly revenue mart aggregated by:

- `revenue_month`
- `plan_tier`
- `billing_frequency`

It supports recurring revenue analysis across customer mix, subscription behavior, and plan structure.

## Data Quality

The project includes dbt schema tests for:

- primary key uniqueness
- non-null constraints
- foreign key relationships
- accepted values for categorical fields
- composite uniqueness constraints in marts

Examples of protected assumptions:

- valid `plan_tier`, `billing_frequency`, `priority`, and `referral_source`
- account and subscription key integrity
- valid mart grain for monthly revenue aggregation

## Running the Project

### Quickstart

For a clean local setup, the recommended flow is:

1. create a local `.env` from `.env.example`
2. build the dbt container image
3. install dbt packages
4. run local validation

```bash
cp .env.example .env
make bootstrap
make ci-local
```

For the fastest reviewer-friendly end-to-end walkthrough, use:

```bash
make demo
```

This flow:

1. rebuilds local dbt prerequisites
2. resets the local DuckDB warehouse state
3. reloads the synthetic raw files
4. runs source freshness and local CI validation
5. prints a small preview from `mart_pipeline_health`

The dbt profile currently defines two local targets:

- `dev`: builds models into the `main` schema for local development
- `prod`: builds models into the `prod` schema as a lightweight stand-in for a production target

This keeps the project locally reproducible while still demonstrating environment-aware dbt configuration.

The local DuckDB warehouse file lives under `dbt/saas_analytics/.local/saas_analytics.duckdb` and is intentionally ignored by Git. That keeps generated warehouse state out of version control while preserving a reproducible local setup.

### Build models and run tests

```bash
docker compose run --rm dbt -lc "cd saas_analytics && dbt build --profiles-dir . --target dev"
```

### Run tests only

```bash
docker compose run --rm dbt -lc "cd saas_analytics && dbt test --profiles-dir . --target dev"
```

### Run dbt models only

```bash
docker compose run --rm dbt -lc "cd saas_analytics && dbt run --profiles-dir . --target dev"
```

### Build against the production-style target

```bash
docker compose run --rm dbt -lc "cd saas_analytics && dbt build --profiles-dir . --target prod"
```

### Common developer commands

For a shorter local workflow, the repository also includes a `Makefile`:

```bash
make dbt-build
make lint
make ci-local
```

Useful targets include:

- `make bootstrap`
- `make demo-reset`
- `make load-raw`
- `make demo-preview`
- `make demo`
- `make dbt-image-build`
- `make dbt-deps`
- `make dbt-build`
- `make dbt-build-prod`
- `make dbt-run`
- `make dbt-test`
- `make lint`
- `make ci-local`

## Orchestration

Airflow is included to support batch-style orchestration of ingestion and transformation workflows. The repository contains local Docker-based Airflow infrastructure for scheduling and running pipeline tasks in a reproducible development environment.

The ingestion layer now propagates a shared `INGESTION_RUN_ID` across the S3 landing step and the DuckDB raw-load step. Each load also records operational metadata in `ops_ingestion_runs` and `ops_ingestion_file_loads`, including file checksums, file sizes, row counts, load timestamps, and run status. Repeated loads of the same raw file are detected by checksum and marked as `skipped` instead of being reloaded again. This keeps the local demo setup simple while still showing a lightweight idempotency pattern.

The current DAG orchestrates five main steps:

1. upload raw CSV data to S3
2. load raw source tables into DuckDB
3. validate raw source freshness
4. run dbt transformations
5. run dbt tests

The dbt tasks are target-aware and default to `prod` inside the orchestration flow:

```bash
dbt run --profiles-dir . --target ${DBT_TARGET:-prod}
dbt test --profiles-dir . --target ${DBT_TARGET:-prod}
```

This mirrors a common data engineering pattern where local development happens against a `dev` target while scheduled pipeline execution is aligned with a production-style target.

The DAG also includes a few production-leaning controls for local realism:

- bounded task execution timeouts
- task retries with retry delays
- `max_active_runs=1` to avoid overlapping batch executions
- a dedicated source freshness gate before dbt transformations

The S3 upload step is included to represent a lightweight landing-zone pattern: raw files are first staged in object storage and then loaded into the analytical store. In this local portfolio setup, the DuckDB load still reads from the local raw dataset, but the architecture intentionally separates file landing, raw ingestion, and transformation concerns.

Additional dbt ops marts, `mart_ingestion_runs`, `mart_ingestion_file_loads`, and `mart_pipeline_health` surface run-level, file-level, and source-level operational state directly from DuckDB audit tables so that load behavior can be inspected with normal analytics workflows instead of only through Python logs.

### Operational Monitoring

The project includes three lightweight operational marts:

- `mart_ingestion_runs` for run-level monitoring, including loaded, skipped, and failed file counts
- `mart_ingestion_file_loads` for file-level inspection, including checksums, row counts, timing, and status
- `mart_pipeline_health` for a condensed source-by-source view of freshness and latest ingestion status

Example questions they support:

- which runs loaded new data versus skipped already-seen files?
- which file events were slow, failed, or unusually small?
- do expected file counts reconcile with actual file-level outcomes?

## Repository Structure

```text
.
├── airflow/
├── data/
│   └── raw/
├── dbt/
│   └── saas_analytics/
│       ├── models/
│       │   ├── staging/
│       │   ├── intermediate/
│       │   └── marts/
│       ├── dbt_project.yml
│       ├── packages.yml
│       └── profiles.yml
├── docker-compose.yml
├── Dockerfile.airflow
└── Dockerfile.dbt
```

## What This Project Demonstrates

This project is intended to demonstrate:

- layered analytics engineering with dbt
- business-facing data modeling for SaaS metrics
- schema-driven data quality practices
- reproducible local execution with Docker
- orchestration readiness with Airflow
- CI-driven validation for transformations, SQL quality, and Python pipeline code

## Continuous Integration

The repository includes a GitHub Actions workflow that validates the project on pushes and pull requests. The CI pipeline currently runs:

- fast checks on pushes to `dev` and `main`:
  - `ruff check .`
  - Python syntax validation for the Airflow DAG
  - `sqlfluff lint models`
- full validation on pull requests and pushes to `main`:
  - `dbt build --profiles-dir . --target dev`

The workflow installs dbt package dependencies with `dbt deps` before SQL templating and dbt validation. This keeps the local developer workflow aligned with automated validation in version control while avoiding an unnecessarily heavy pipeline on every push.

The workflow can also be started manually through GitHub Actions via `workflow_dispatch`, which is useful for validating CI changes without creating an extra push or pull request.

## Pre-push Checklist

Before pushing changes, the quickest high-signal local validation path is:

```bash
make ci-local
```

For source freshness checks after reloading raw data:

```bash
make source-freshness
```

## Environment Configuration

The repository includes a `.env.example` file that documents the expected local environment variables for Airflow and S3-related ingestion steps. The real `.env` file is intentionally ignored by Git.

## Current Status

Current functionality includes:

- typed staging models for all core raw entities
- intermediate account-level summaries for subscriptions, support, churn, and usage
- marts for churn analysis and monthly revenue analysis
- derived health and churn indicators in the churn mart
- schema tests across staging, intermediate, and mart layers

## Design Notes

A few modeling choices in this project are deliberate:

- The current structure prioritizes clarity and layered transformation over premature abstraction.
- Intermediate models are account-centered because the primary analytical focus is churn and health analysis.
- Health indicators in `mart_churn_analysis` are intentionally simple and explainable rather than optimized for predictive modeling.
- DuckDB was chosen to keep the project lightweight, fast, and locally reproducible.
- `dev` and `prod` targets are separated at the schema level to demonstrate environment-aware configuration without adding unnecessary infrastructure overhead.

## System Design Considerations

This project is intentionally designed to look more like a small, reliable data system than a one-off analytics notebook.

- Raw data lineage is explicit through dbt `sources`.
- Raw source freshness is tracked using a technical `loaded_at` field created during ingestion.
- Data quality is enforced at multiple layers, starting with source and staging checks.
- Transformation logic is separated into staging, intermediate, and mart responsibilities.
- Orchestration treats ingestion, loading, transformation, and validation as distinct pipeline steps.
- Environment-aware dbt targets make the local setup closer to real deployment patterns.
- Generated local warehouse state is kept outside version control in a dedicated `.local` path.

## Productionization Path

If this project were extended beyond local portfolio scope, the next production-oriented steps would be:

- move from DuckDB to a shared analytical warehouse
- load landed files directly from object storage instead of local demo paths
- parameterize source freshness and runtime expectations
- emit pipeline health signals to a dedicated monitoring system
- version and promote scheduled jobs through environment-specific deployment flows
- publish dbt docs and lineage artifacts as part of the delivery pipeline

## Trade-offs

The current implementation makes a few deliberate trade-offs:

- DuckDB keeps the project lightweight and reproducible, but does not represent a multi-user warehouse environment.
- `prod` is modeled as a separate schema rather than fully separate infrastructure to keep the setup credible without unnecessary overhead.
- Current marts prioritize explainability and maintainability over sophisticated predictive feature engineering.
- Airflow orchestration is intentionally compact and readable rather than deeply abstracted.
- Operational monitoring is deliberately lightweight: enough to demonstrate engineering judgment without overwhelming the portfolio with platform scaffolding.

## Next Steps

Planned improvements include:

- a dedicated `mart_account_health`
- richer point-in-time churn risk signals
- source freshness checks and additional business-rule tests
- generated dbt docs and lineage screenshots
- a stronger README section for analytical findings and trade-offs

## Notes

This project uses fully synthetic data for educational and portfolio purposes. No real customer or personally identifiable data is included.
