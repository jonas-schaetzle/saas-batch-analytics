.PHONY: help bootstrap demo-reset load-raw demo-preview demo dbt-build dbt-build-prod dbt-run dbt-test dbt-deps source-freshness lint lint-python lint-sql dag-check ci-local dbt-image-build

DBT_SERVICE := dbt
DBT_WORKDIR := saas_analytics
DBT_SHELL := docker compose run --rm $(DBT_SERVICE) -lc
LOCAL_DUCKDB_PATH := dbt/saas_analytics/.local/saas_analytics.duckdb

help:
	@echo "Available targets:"
	@echo "  make bootstrap        Build the dbt image and install dbt packages"
	@echo "  make demo-reset       Remove the local DuckDB warehouse and dbt build artifacts"
	@echo "  make load-raw         Load the synthetic raw CSV files into DuckDB"
	@echo "  make demo-preview     Show the pipeline health mart after a demo run"
	@echo "  make demo             Run the end-to-end local demo flow"
	@echo "  make dbt-image-build  Build the dbt container image"
	@echo "  make dbt-deps         Install dbt packages inside the dbt project"
	@echo "  make dbt-build        Run dbt build against the dev target"
	@echo "  make dbt-build-prod   Run dbt build against the prod target"
	@echo "  make dbt-run          Run dbt models against the dev target"
	@echo "  make dbt-test         Run dbt tests against the dev target"
	@echo "  make source-freshness Check dbt source freshness against the dev target"
	@echo "  make lint-python      Run Ruff in the dbt container"
	@echo "  make lint-sql         Run SQLFluff in the dbt container"
	@echo "  make dag-check        Validate Airflow DAG Python syntax in the dbt container"
	@echo "  make lint             Run Python lint, DAG syntax check, and SQL lint"
	@echo "  make ci-local         Run the main local checks that mirror CI"

dbt-image-build:
	docker compose build $(DBT_SERVICE)

bootstrap: dbt-image-build dbt-deps

demo-reset:
	rm -f $(LOCAL_DUCKDB_PATH)
	rm -rf dbt/saas_analytics/target

dbt-deps:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt deps --profiles-dir ."

load-raw:
	$(DBT_SHELL) "export INGESTION_RUN_ID=demo_manual RAW_DATA_DIR=/usr/app/data/raw && python /usr/app/ingestion/scripts/load_raw_data_to_duckdb.py"

dbt-build:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt build --profiles-dir . --target dev"

dbt-build-prod:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt build --profiles-dir . --target prod"

dbt-run:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt run --profiles-dir . --target dev"

dbt-test:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt test --profiles-dir . --target dev"

source-freshness:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt source freshness --profiles-dir . --target dev"

demo-preview:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt show --profiles-dir . --target dev --inline \"select source_table, freshness_status, pipeline_health_status, latest_file_status, raw_record_count from {{ ref('mart_pipeline_health') }} order by source_table\""

lint-python:
	$(DBT_SHELL) "python -m ruff check --cache-dir /tmp/ruff-cache /usr/app/airflow /usr/app/ingestion"

lint-sql:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt deps --profiles-dir . && sqlfluff lint models"

dag-check:
	$(DBT_SHELL) "python -m py_compile /usr/app/airflow/dags/saas_pipeline_shared.py /usr/app/airflow/dags/saas_ingestion_pipeline.py /usr/app/airflow/dags/saas_transformation_pipeline.py /usr/app/ingestion/scripts/ingestion_utils.py /usr/app/ingestion/scripts/upload_raw_data_to_s3.py /usr/app/ingestion/scripts/load_raw_data_to_duckdb.py"

lint: lint-python dag-check lint-sql

ci-local: lint dbt-build

demo: bootstrap demo-reset load-raw source-freshness ci-local demo-preview
