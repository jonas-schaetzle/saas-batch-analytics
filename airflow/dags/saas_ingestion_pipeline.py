from datetime import timedelta

import pendulum
from airflow.providers.standard.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG
from saas_pipeline_shared import default_args

with DAG(
    dag_id="saas_ingestion_pipeline",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    default_args=default_args,
    dagrun_timeout=timedelta(minutes=20),
    max_active_runs=1,
    tags=["saas", "ingestion", "s3", "duckdb"],
    doc_md="""
    Ingestion pipeline for synthetic SaaS data.

    Scope:
    1. Upload raw files to the S3 landing zone
    2. Load raw data into DuckDB with ingestion audit logging

    This DAG owns landing and raw-ingestion concerns only.
    """,
) as dag:
    upload_raw_data_to_s3 = BashOperator(
        task_id="upload_raw_data_to_s3",
        bash_command=(
            "export INGESTION_RUN_ID='{{ run_id }}' "
            "&& python /opt/airflow/ingestion/scripts/upload_raw_data_to_s3.py"
        ),
        execution_timeout=timedelta(minutes=10),
        doc_md=(
            "Uploads local raw CSV files into the S3 landing-zone path "
            "for the current run."
        ),
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

    trigger_transformation_pipeline = TriggerDagRunOperator(
        task_id="trigger_transformation_pipeline",
        trigger_dag_id="saas_transformation_pipeline",
        wait_for_completion=False,
        conf={
            "upstream_ingestion_run_id": "{{ run_id }}",
        },
    )

    upload_raw_data_to_s3 >> load_raw_data_to_duckdb >> trigger_transformation_pipeline
