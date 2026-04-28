from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="upload_raw_data_to_s3",
    start_date=datetime(2026, 1, 1),
    schedule_interval=None,
    catchup=False,
    tags=["saas", "ingestion", "s3"],
) as dag:

    upload_raw_data = BashOperator(
        task_id="upload_raw_data",
        bash_command="python /opt/airflow/ingestion/scripts/upload_raw_data_to_s3.py",
    )