# SaaS Batch Analytics

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

The dbt profile currently defines two local targets:

- `dev`: builds models into the `main` schema for local development
- `prod`: builds models into the `prod` schema as a lightweight stand-in for a production target

This keeps the project locally reproducible while still demonstrating environment-aware dbt configuration.

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

## Orchestration

Airflow is included to support batch-style orchestration of ingestion and transformation workflows. The repository contains local Docker-based Airflow infrastructure for scheduling and running pipeline tasks in a reproducible development environment.

The current DAG orchestrates four main steps:

1. upload raw CSV data to S3
2. load raw source tables into DuckDB
3. run dbt transformations
4. run dbt tests

The dbt tasks are target-aware and default to `prod` inside the orchestration flow:

```bash
dbt run --profiles-dir . --target ${DBT_TARGET:-prod}
dbt test --profiles-dir . --target ${DBT_TARGET:-prod}
```

This mirrors a common data engineering pattern where local development happens against a `dev` target while scheduled pipeline execution is aligned with a production-style target.

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
  - `sqlfluff lint dbt/saas_analytics/models`
- full validation on pull requests and pushes to `main`:
  - `dbt build --profiles-dir . --target dev`

The workflow installs dbt package dependencies with `dbt deps` before SQL templating and dbt validation. This keeps the local developer workflow aligned with automated validation in version control while avoiding an unnecessarily heavy pipeline on every push.

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
- Data quality is enforced at multiple layers, starting with source and staging checks.
- Transformation logic is separated into staging, intermediate, and mart responsibilities.
- Orchestration treats ingestion, loading, transformation, and validation as distinct pipeline steps.
- Environment-aware dbt targets make the local setup closer to real deployment patterns.

## Productionization Path

If this project were extended beyond local portfolio scope, the next production-oriented steps would be:

- move from DuckDB to a shared analytical warehouse
- parameterize source freshness and runtime expectations
- add CI for `dbt build`, `sqlfluff`, and Python linting
- version and promote scheduled jobs through environment-specific deployment flows
- publish dbt docs and lineage artifacts as part of the delivery pipeline

## Trade-offs

The current implementation makes a few deliberate trade-offs:

- DuckDB keeps the project lightweight and reproducible, but does not represent a multi-user warehouse environment.
- `prod` is modeled as a separate schema rather than fully separate infrastructure to keep the setup credible without unnecessary overhead.
- Current marts prioritize explainability and maintainability over sophisticated predictive feature engineering.
- Airflow orchestration is intentionally compact and readable rather than deeply abstracted.

## Next Steps

Planned improvements include:

- a dedicated `mart_account_health`
- richer point-in-time churn risk signals
- source freshness checks and additional business-rule tests
- generated dbt docs and lineage screenshots
- a stronger README section for analytical findings and trade-offs

## Notes

This project uses fully synthetic data for educational and portfolio purposes. No real customer or personally identifiable data is included.
