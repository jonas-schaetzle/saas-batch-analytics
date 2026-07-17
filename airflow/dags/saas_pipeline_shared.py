from datetime import timedelta

DBT_PROJECT_DIR = "/usr/app/dbt/saas_analytics"
DBT_TARGET = "${DBT_TARGET:-prod}"
DBT_COMMAND_PREFIX = "set -euo pipefail"

default_args = {
    "owner": "portfolio-data-platform",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}
