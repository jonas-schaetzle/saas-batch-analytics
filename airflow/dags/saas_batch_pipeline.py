from datetime import timedelta

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

DBT_PROJECT_DIR = "/usr/app/dbt/saas_analytics"
DBT_TARGET = "${DBT_TARGET:-prod}"
DBT_COMMAND_PREFIX = "set -euo pipefail"

default_args = {
    "owner": "portfolio-data-platform",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="saas_batch_pipeline",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    default_args=default_args,
    dagrun_timeout=timedelta(minutes=45),
    max_active_runs=1,
    tags=["saas", "batch", "s3", "duckdb", "dbt"],
    doc_md="""
    Batch pipeline for synthetic SaaS data.

    Flow:
    1. Upload raw files to the S3 landing zone
    2. Load raw data into DuckDB with ingestion audit logging
    3. Validate raw freshness before transformations
    4. Run dbt transformations and tests
    """,
) as dag:
    upload_raw_data_to_s3 = BashOperator(
        task_id="upload_raw_data_to_s3",
        bash_command=(
            "export INGESTION_RUN_ID='{{ run_id }}' "
            "&& python /opt/airflow/ingestion/scripts/upload_raw_data_to_s3.py"
        ),
        execution_timeout=timedelta(minutes=10),
        doc_md="Uploads local raw CSV files into the S3 landing-zone path for the current run.",
    )

    load_raw_data_to_duckdb = BashOperator(
        task_id="load_raw_data_to_duckdb",
        bash_command=(
            "export INGESTION_RUN_ID='{{ run_id }}' "
            "&& python /opt/airflow/ingestion/scripts/load_raw_data_to_duckdb.py"
        ),
        execution_timeout=timedelta(minutes=10),
        doc_md=(
            "Loads raw CSV files into DuckDB, records file-level and run-level audit "
            "metadata, and skips files already loaded with the same checksum."
        ),
    )

    dbt_source_freshness = BashOperator(
        task_id="dbt_source_freshness",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} "
            f"&& {DBT_COMMAND_PREFIX} "
            f"&& dbt source freshness --profiles-dir . --target {DBT_TARGET}"
        ),
        execution_timeout=timedelta(minutes=10),
        doc_md="Fails fast when raw sources are stale before transformations are executed.",
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} "
            f"&& {DBT_COMMAND_PREFIX} "
            f"&& dbt run --profiles-dir . --target {DBT_TARGET}"
        ),
        execution_timeout=timedelta(minutes=20),
        doc_md="Runs dbt models against the configured target environment.",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} "
            f"&& {DBT_COMMAND_PREFIX} "
            f"&& dbt test --profiles-dir . --target {DBT_TARGET}"
        ),
        execution_timeout=timedelta(minutes=15),
        doc_md="Executes dbt tests after transformations complete.",
    )

    (
        upload_raw_data_to_s3
        >> load_raw_data_to_duckdb
        >> dbt_source_freshness
        >> dbt_run
        >> dbt_test
    )
