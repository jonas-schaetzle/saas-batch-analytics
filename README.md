# SaaS Batch Analytics

[![CI](https://github.com/jonas-schaetzle/saas-batch-analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/jonas-schaetzle/saas-batch-analytics/actions/workflows/ci.yml)

An end-to-end analytics engineering project for a synthetic SaaS business, built with `dbt`, `DuckDB`, `Apache Airflow`, and `Docker Compose`.

This repository models raw SaaS operational data into curated analytics layers for churn, revenue, support, and product usage analysis. It is designed as a portfolio project that demonstrates practical analytics engineering, layered data modeling, schema testing, and orchestration-ready pipelines.

## Start Here

If you only spend five minutes with the repository, this is the highest-signal path:

1. run `make demo`
2. inspect `mart_pipeline_health`, `mart_churn_analysis`, and `mart_revenue_by_month`
3. scan the Airflow DAG split between ingestion and transformation
4. review the dbt layering from `sources` to marts

The quickest files to inspect are:

- [airflow/dags/saas_ingestion_pipeline.py](/Users/jonasschaetzle/Documents/01_Jonas/01_Dev/01_PortfolioProjects/saas-batch-analytics/airflow/dags/saas_ingestion_pipeline.py)
- [airflow/dags/saas_transformation_pipeline.py](/Users/jonasschaetzle/Documents/01_Jonas/01_Dev/01_PortfolioProjects/saas-batch-analytics/airflow/dags/saas_transformation_pipeline.py)
- [dbt/saas_analytics/models/marts/mart_pipeline_health.sql](/Users/jonasschaetzle/Documents/01_Jonas/01_Dev/01_PortfolioProjects/saas-batch-analytics/dbt/saas_analytics/models/marts/mart_pipeline_health.sql)
- [dbt/saas_analytics/models/marts/mart_churn_analysis.sql](/Users/jonasschaetzle/Documents/01_Jonas/01_Dev/01_PortfolioProjects/saas-batch-analytics/dbt/saas_analytics/models/marts/mart_churn_analysis.sql)

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

After that, the most useful follow-up commands are:

```bash
make demo-preview
make source-freshness
make ci-local
```

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

The orchestration layer is now split into two DAGs with a clear boundary:

1. `saas_ingestion_pipeline`
   - upload raw CSV data to S3
   - load raw source tables into DuckDB
   - trigger the transformation DAG after raw ingestion succeeds

2. `saas_transformation_pipeline`
   - validate raw source freshness
   - run dbt transformations and tests

The dbt tasks are target-aware and default to `prod` inside the orchestration flow:

```bash
dbt run --profiles-dir . --target ${DBT_TARGET:-prod}
dbt test --profiles-dir . --target ${DBT_TARGET:-prod}
```

This mirrors a more production-like data engineering pattern where ingestion and transformation can evolve independently while local development still happens against a `dev` target and scheduled execution can stay aligned with a production-style target.

In the current local setup, the ingestion DAG explicitly triggers the transformation DAG after a successful raw load. That keeps the boundary between responsibilities clear while still preserving an end-to-end batch workflow.

The DAG layer also includes a few production-leaning controls for local realism:

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

### Airflow Demo

For a reviewer who wants to inspect orchestration behavior in the Airflow UI:

1. start the local Airflow stack
2. trigger `saas_ingestion_pipeline`
3. observe that it lands raw files, loads DuckDB, and then triggers `saas_transformation_pipeline`
4. inspect `mart_pipeline_health` or `mart_ingestion_runs` after completion

This demonstrates a cleaner production-style separation than a single monolithic DAG while still preserving a simple local walkthrough.

## Reviewer Walkthrough

For a hiring manager, tech lead, or interviewer, the project is easiest to evaluate in this order:

1. `make demo` for a clean reproducible run
2. inspect pipeline state in `mart_pipeline_health`
3. inspect business-facing output in `mart_churn_analysis`
4. inspect operational auditability in `mart_ingestion_runs` and `mart_ingestion_file_loads`
5. inspect orchestration boundaries in the two Airflow DAGs

This makes the project legible from three angles that usually matter in data engineering interviews:

- can the system run end to end?
- is the transformation layer modeled cleanly?
- is pipeline behavior observable when something goes wrong?

## Example Queries

The following queries are useful for a quick review of the modeled outputs.

### Pipeline health snapshot

```bash
docker compose run --rm dbt -lc "cd saas_analytics && dbt show --profiles-dir . --target dev --inline \"select * from main.mart_pipeline_health order by source_name\""
```

### Highest-risk churn accounts

```bash
docker compose run --rm dbt -lc "cd saas_analytics && dbt show --profiles-dir . --target dev --inline \"select account_id, account_name, churn_risk_flag, support_ticket_count, usage_events_last_30d, days_since_last_usage from main.mart_churn_analysis where churn_risk_flag = true order by support_ticket_count desc, usage_events_last_30d asc limit 10\""
```

### Revenue mix by month

```bash
docker compose run --rm dbt -lc "cd saas_analytics && dbt show --profiles-dir . --target dev --inline \"select revenue_month, plan_tier, billing_frequency, monthly_recurring_revenue from main.mart_revenue_by_month order by revenue_month desc, monthly_recurring_revenue desc limit 12\""
```

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

## Failure Modes And Recovery

The project is intentionally opinionated about a few common operational failure modes:

- stale raw data blocks transformations through a dedicated source freshness gate before dbt runs
- repeated raw file loads are deduplicated by checksum and recorded as `skipped`
- task retries and execution timeouts reduce the chance of silent hangs in orchestration
- ingestion and transformation are separated so reruns can target the failed stage instead of replaying the whole pipeline
- operational marts expose run- and file-level status in SQL, so debugging is not trapped inside scheduler logs

That matters for portfolio quality because it shows not just how data is modeled, but how the system behaves under imperfect operating conditions.

## Productionization Path

If this project were extended beyond local portfolio scope, the next production-oriented steps would be:

- move from DuckDB to a shared analytical warehouse
- load landed files directly from object storage instead of local demo paths
- parameterize source freshness and runtime expectations
- emit pipeline health signals to a dedicated monitoring system
- version and promote scheduled jobs through environment-specific deployment flows
- publish dbt docs and lineage artifacts as part of the delivery pipeline
- split ingestion further into dataset-aware assets or pipelines if source breadth grows
- add deployment automation for Airflow and dbt job promotion across environments

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
- point-in-time snapshots for historically correct churn-risk analysis
- warehouse-backed ingestion from landed object-store files instead of local raw paths
- published dbt docs, lineage screenshots, and curated demo artifacts
- deployment automation for environment promotion and scheduled production execution

## Notes

This project uses fully synthetic data for educational and portfolio purposes. No real customer or personally identifiable data is included.
