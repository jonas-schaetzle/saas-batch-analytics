from pathlib import Path

import duckdb

RAW_DATA_DIR = Path("/opt/airflow/data/raw")
DUCKDB_PATH = Path("/opt/airflow/dbt/saas_analytics/saas_analytics.duckdb")

TABLES = {
    "accounts.csv": "raw_accounts",
    "subscriptions.csv": "raw_subscriptions",
    "feature_usage.csv": "raw_feature_usage",
    "support_tickets.csv": "raw_support_tickets",
    "churn_events.csv": "raw_churn_events",
}


def load_csv_to_duckdb(file_name: str, table_name: str, con: duckdb.DuckDBPyConnection):
    file_path = RAW_DATA_DIR / file_name

    if not file_path.exists():
        raise FileNotFoundError(f"Missing source file: {file_path}")

    con.sql(f"""
        create or replace table {table_name} as
        select *
        from read_csv_auto('{file_path}', header=true)
    """)

    row_count = con.sql(f"select count(*) from {table_name}").fetchone()[0]
    print(f"Loaded {row_count} rows into {table_name}")


def main():
    DUCKDB_PATH.parent.mkdir(parents=True, exist_ok=True)

    with duckdb.connect(str(DUCKDB_PATH)) as con:
        for file_name, table_name in TABLES.items():
            load_csv_to_duckdb(file_name, table_name, con)


if __name__ == "__main__":
    main()