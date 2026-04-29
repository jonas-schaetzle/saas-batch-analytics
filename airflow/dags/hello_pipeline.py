from datetime import datetime

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG

with DAG(
    dag_id="hello_pipeline",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["learning"],
) as dag:

    say_hello = BashOperator(
        task_id="say_hello",
        bash_command="echo 'Hello from Airflow'",
    )
