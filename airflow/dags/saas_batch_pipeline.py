import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

DBT_PROJECT_DIR = "/usr/app/dbt/saas_analytics"
DBT_TARGET = "${DBT_TARGET:-prod}"

with DAG(
    dag_id="saas_batch_pipeline",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["saas", "batch", "s3", "duckdb", "dbt"],
) as dag:
    upload_raw_data_to_s3 = BashOperator(
        task_id="upload_raw_data_to_s3",
        bash_command=(
            "export INGESTION_RUN_ID='{{ run_id }}' "
            "&& python /opt/airflow/ingestion/scripts/upload_raw_data_to_s3.py"
        ),
    )

    load_raw_data_to_duckdb = BashOperator(
        task_id="load_raw_data_to_duckdb",
        bash_command=(
            "export INGESTION_RUN_ID='{{ run_id }}' "
            "&& python /opt/airflow/ingestion/scripts/load_raw_data_to_duckdb.py"
        ),
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} "
            f"&& dbt run --profiles-dir . --target {DBT_TARGET}"
        ),
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} "
            f"&& dbt test --profiles-dir . --target {DBT_TARGET}"
        ),
    )

    upload_raw_data_to_s3 >> load_raw_data_to_duckdb >> dbt_run >> dbt_test
