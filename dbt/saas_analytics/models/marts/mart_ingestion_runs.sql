with runs as (
    select
        ingestion_run_id,
        pipeline_name,
        status,
        run_started_at,
        run_finished_at,
        files_expected,
        files_loaded,
        files_skipped,
        files_failed,
        error_message

    from {{ source('raw', 'ops_ingestion_runs') }}
),

file_loads as (
    select
        ingestion_run_id,
        row_count,
        loaded_at,
        status

    from {{ source('raw', 'ops_ingestion_file_loads') }}
),

aggregated_file_loads as (
    select
        ingestion_run_id,
        count(*) as file_event_count,
        count(case when status = 'success' then 1 end) as successful_file_count,
        count(case when status = 'skipped' then 1 end) as skipped_file_count,
        count(case when status = 'failed' then 1 end) as failed_file_count,
        sum(row_count) as total_rows_observed,
        min(loaded_at) as first_file_event_at,
        max(loaded_at) as last_file_event_at

    from file_loads

    group by 1
)

select
    runs.ingestion_run_id,
    runs.pipeline_name,
    runs.status as run_status,
    runs.run_started_at,
    runs.run_finished_at,
    runs.files_expected,
    runs.files_loaded,
    runs.files_skipped,
    runs.files_failed,
    aggregated_file_loads.first_file_event_at,
    aggregated_file_loads.last_file_event_at,
    runs.error_message,
    datediff('second', runs.run_started_at, runs.run_finished_at)
        as run_duration_seconds,
    coalesce(aggregated_file_loads.file_event_count, 0) as file_event_count,
    coalesce(aggregated_file_loads.successful_file_count, 0)
        as successful_file_count,
    coalesce(aggregated_file_loads.skipped_file_count, 0) as skipped_file_count,
    coalesce(aggregated_file_loads.failed_file_count, 0) as failed_file_count,
    coalesce(aggregated_file_loads.total_rows_observed, 0) as total_rows_observed,
    coalesce(
        runs.files_expected = (
            runs.files_loaded
            + runs.files_skipped
            + runs.files_failed
        ),
        false
    ) as file_accounting_complete

from runs

left join aggregated_file_loads
    on runs.ingestion_run_id = aggregated_file_loads.ingestion_run_id
