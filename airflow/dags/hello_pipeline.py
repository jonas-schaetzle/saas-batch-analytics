from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="hello_pipeline",
    start_date=datetime(2024, 1, 1),
    schedule_interval=None,
    catchup=False,
    tags=["learning"],
) as dag:

    say_hello = BashOperator(
        task_id="say_hello",
        bash_command="echo 'Hello from Airflow'",
    )