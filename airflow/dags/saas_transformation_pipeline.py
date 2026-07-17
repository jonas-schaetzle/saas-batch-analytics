from datetime import timedelta

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG
from saas_pipeline_shared import (
    DBT_COMMAND_PREFIX,
    DBT_PROJECT_DIR,
    DBT_TARGET,
    default_args,
)

with DAG(
    dag_id="saas_transformation_pipeline",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    default_args=default_args,
    dagrun_timeout=timedelta(minutes=35),
    max_active_runs=1,
    tags=["saas", "transformation", "dbt", "quality"],
    doc_md="""
    Transformation pipeline for synthetic SaaS data.

    Scope:
    1. Validate raw source freshness
    2. Build dbt models and run dbt tests

    This DAG owns analytics transformation and validation concerns only.
    It can be triggered independently or by the ingestion DAG.
    """,
) as dag:
    dbt_source_freshness = BashOperator(
        task_id="dbt_source_freshness",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} "
            f"&& {DBT_COMMAND_PREFIX} "
            f"&& dbt source freshness --profiles-dir . --target {DBT_TARGET}"
        ),
        execution_timeout=timedelta(minutes=10),
        doc_md=(
            "Fails fast when raw sources are stale before transformations "
            "are executed."
        ),
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} "
            f"&& {DBT_COMMAND_PREFIX} "
            f"&& dbt build --profiles-dir . --target {DBT_TARGET}"
        ),
        execution_timeout=timedelta(minutes=25),
        doc_md=(
            "Builds dbt models and executes dbt tests for the configured "
            "target environment."
        ),
    )

    dbt_source_freshness >> dbt_build
