from datetime import datetime

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

with DAG(
    dag_id="upload_raw_data_to_s3",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    tags=["saas", "ingestion", "s3"],
) as dag:

    upload_raw_data = BashOperator(
        task_id="upload_raw_data",
        bash_command="python /opt/airflow/ingestion/scripts/upload_raw_data_to_s3.py",
    )
