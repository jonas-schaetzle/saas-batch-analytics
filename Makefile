.PHONY: help bootstrap dbt-build dbt-build-prod dbt-run dbt-test dbt-deps source-freshness lint lint-python lint-sql dag-check ci-local dbt-image-build

DBT_SERVICE := dbt
DBT_WORKDIR := saas_analytics
DBT_SHELL := docker compose run --rm $(DBT_SERVICE) -lc

help:
	@echo "Available targets:"
	@echo "  make bootstrap       Build the dbt image and install dbt packages"
	@echo "  make dbt-image-build  Build the dbt container image"
	@echo "  make dbt-deps         Install dbt packages inside the dbt project"
	@echo "  make dbt-build        Run dbt build against the dev target"
	@echo "  make dbt-build-prod   Run dbt build against the prod target"
	@echo "  make dbt-run          Run dbt models against the dev target"
	@echo "  make dbt-test         Run dbt tests against the dev target"
	@echo "  make source-freshness Check dbt source freshness against the dev target"
	@echo "  make lint-python      Run Ruff locally"
	@echo "  make lint-sql         Run SQLFluff in the dbt container"
	@echo "  make dag-check        Validate Airflow DAG Python syntax locally"
	@echo "  make lint             Run Python lint, DAG syntax check, and SQL lint"
	@echo "  make ci-local         Run the main local checks that mirror CI"

dbt-image-build:
	docker compose build $(DBT_SERVICE)

bootstrap: dbt-image-build dbt-deps

dbt-deps:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt deps --profiles-dir ."

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

lint-python:
	python3 -m ruff check .

lint-sql:
	$(DBT_SHELL) "cd $(DBT_WORKDIR) && dbt deps --profiles-dir . && sqlfluff lint models"

dag-check:
	python3 -m py_compile airflow/dags/saas_batch_pipeline.py

lint: lint-python dag-check lint-sql

ci-local: lint dbt-build
