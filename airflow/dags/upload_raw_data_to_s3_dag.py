import pendulum

from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator


with DAG(
    dag_id="upload_raw_data_to_s3",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["saas", "raw", "s3"],
) as dag:

    upload_raw_data = BashOperator(
        task_id="upload_raw_data",
        bash_command="python /opt/airflow/ingestion/scripts/upload_raw_data_to_s3.py",
    )