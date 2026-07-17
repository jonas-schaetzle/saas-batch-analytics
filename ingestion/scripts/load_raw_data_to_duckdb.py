import os
from datetime import UTC, datetime
from pathlib import Path

import duckdb
from ingestion_utils import compute_file_sha256, resolve_raw_data_dir, resolve_run_id

RAW_DATA_DIR = resolve_raw_data_dir()
DUCKDB_PATH = Path(
    os.getenv("DUCKDB_PATH", "/usr/app/dbt/saas_analytics/saas_analytics.duckdb")
)

TABLES = {
    "accounts.csv": "raw_accounts",
    "subscriptions.csv": "raw_subscriptions",
    "feature_usage.csv": "raw_feature_usage",
    "support_tickets.csv": "raw_support_tickets",
    "churn_events.csv": "raw_churn_events",
}


def ensure_audit_tables(con: duckdb.DuckDBPyConnection) -> None:
    con.sql("""
        create table if not exists ops_ingestion_runs (
            ingestion_run_id varchar primary key,
            pipeline_name varchar,
            run_started_at timestamp,
            run_finished_at timestamp,
            status varchar,
            files_expected integer,
            files_loaded integer,
            files_skipped integer,
            files_failed integer,
            error_message varchar
        )
    """)
    con.sql("""
        alter table ops_ingestion_runs
        add column if not exists files_skipped integer
    """)

    con.sql("""
        create table if not exists ops_ingestion_file_loads (
            ingestion_run_id varchar,
            table_name varchar,
            source_file_name varchar,
            source_file_size_bytes bigint,
            source_last_modified_at timestamp,
            source_file_sha256 varchar,
            row_count bigint,
            loaded_at timestamp,
            status varchar,
            error_message varchar
        )
    """)


def register_run_start(
    con: duckdb.DuckDBPyConnection, run_id: str, files_expected: int
) -> None:
    con.execute(
        """
        insert or replace into ops_ingestion_runs (
            ingestion_run_id,
            pipeline_name,
            run_started_at,
            status,
            files_expected,
            files_loaded,
            files_skipped,
            files_failed
        )
        values (?, ?, current_timestamp, ?, ?, ?, ?, ?)
        """,
        [run_id, "saas_batch_pipeline", "running", files_expected, 0, 0, 0],
    )


def finalize_run(
    con: duckdb.DuckDBPyConnection,
    run_id: str,
    files_loaded: int,
    files_skipped: int,
    files_failed: int,
    status: str,
    error_message: str | None = None,
) -> None:
    con.execute(
        """
        update ops_ingestion_runs
        set
            run_finished_at = current_timestamp,
            status = ?,
            files_loaded = ?,
            files_skipped = ?,
            files_failed = ?,
            error_message = ?
        where ingestion_run_id = ?
        """,
        [status, files_loaded, files_skipped, files_failed, error_message, run_id],
    )


def log_file_load(
    con: duckdb.DuckDBPyConnection,
    run_id: str,
    table_name: str,
    file_path: Path,
    row_count: int,
    file_sha256: str,
    status: str,
    error_message: str | None = None,
) -> None:
    con.execute(
        """
        insert into ops_ingestion_file_loads (
            ingestion_run_id,
            table_name,
            source_file_name,
            source_file_size_bytes,
            source_last_modified_at,
            source_file_sha256,
            row_count,
            loaded_at,
            status,
            error_message
        )
        values (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, ?)
        """,
        [
            run_id,
            table_name,
            file_path.name,
            file_path.stat().st_size,
            datetime.fromtimestamp(file_path.stat().st_mtime, UTC),
            file_sha256,
            row_count,
            status,
            error_message,
        ],
    )


def load_csv_to_duckdb(
    file_name: str,
    table_name: str,
    con: duckdb.DuckDBPyConnection,
    run_id: str,
) -> str:
    file_path = RAW_DATA_DIR / file_name

    if not file_path.exists():
        raise FileNotFoundError(f"Missing source file: {file_path}")

    file_sha256 = compute_file_sha256(file_path)
    already_loaded = con.execute(
        """
        select 1
        from ops_ingestion_file_loads
        where table_name = ?
          and source_file_sha256 = ?
          and status = 'success'
        limit 1
        """,
        [table_name, file_sha256],
    ).fetchone()

    if already_loaded:
        print(f"Skipping {table_name}: file already loaded for checksum {file_sha256}")
        log_file_load(
            con=con,
            run_id=run_id,
            table_name=table_name,
            file_path=file_path,
            row_count=0,
            file_sha256=file_sha256,
            status="skipped",
            error_message="Skipped because the same file checksum was already loaded",
        )
        return "skipped"

    con.sql(f"""
        create or replace table {table_name} as
        select *
            , current_timestamp as loaded_at
            , '{file_path.name}' as source_file_name
            , '{run_id}' as ingestion_run_id
            , {file_path.stat().st_size} as source_file_size_bytes
            , '{file_sha256}' as source_file_sha256
        from read_csv_auto('{file_path}', header=true)
    """)

    row_count = con.sql(f"select count(*) from {table_name}").fetchone()[0]
    print(f"Loaded {row_count} rows into {table_name}")
    log_file_load(
        con=con,
        run_id=run_id,
        table_name=table_name,
        file_path=file_path,
        row_count=row_count,
        file_sha256=file_sha256,
        status="success",
    )
    return "loaded"


def main():
    DUCKDB_PATH.parent.mkdir(parents=True, exist_ok=True)
    run_id = resolve_run_id()
    files_loaded = 0
    files_skipped = 0
    files_failed = 0

    with duckdb.connect(str(DUCKDB_PATH)) as con:
        ensure_audit_tables(con)
        register_run_start(con, run_id=run_id, files_expected=len(TABLES))

        try:
            for file_name, table_name in TABLES.items():
                try:
                    load_status = load_csv_to_duckdb(
                        file_name=file_name,
                        table_name=table_name,
                        con=con,
                        run_id=run_id,
                    )
                    if load_status == "loaded":
                        files_loaded += 1
                    else:
                        files_skipped += 1
                except Exception as exc:
                    files_failed += 1
                    file_path = RAW_DATA_DIR / file_name
                    if file_path.exists():
                        log_file_load(
                            con=con,
                            run_id=run_id,
                            table_name=table_name,
                            file_path=file_path,
                            row_count=0,
                            file_sha256=compute_file_sha256(file_path),
                            status="failed",
                            error_message=str(exc),
                        )
                    raise

        except Exception as exc:
            finalize_run(
                con,
                run_id=run_id,
                files_loaded=files_loaded,
                files_skipped=files_skipped,
                files_failed=files_failed,
                status="failed",
                error_message=str(exc),
            )
            raise

        finalize_run(
            con,
            run_id=run_id,
            files_loaded=files_loaded,
            files_skipped=files_skipped,
            files_failed=files_failed,
            status="success",
        )


if __name__ == "__main__":
    main()
