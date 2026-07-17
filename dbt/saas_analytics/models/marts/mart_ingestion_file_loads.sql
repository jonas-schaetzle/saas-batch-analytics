with file_loads as (
    select
        ingestion_run_id,
        table_name,
        source_file_name,
        source_file_size_bytes,
        source_last_modified_at,
        source_file_sha256,
        row_count,
        loaded_at,
        status as file_status,
        error_message
    from {{ source('raw', 'ops_ingestion_file_loads') }}
),

runs as (
    select
        ingestion_run_id,
        pipeline_name,
        status as run_status,
        run_started_at,
        run_finished_at
    from {{ source('raw', 'ops_ingestion_runs') }}
)

select
    file_loads.ingestion_run_id,
    file_loads.table_name,
    file_loads.source_file_name,
    file_loads.source_file_size_bytes,
    file_loads.source_last_modified_at,
    file_loads.source_file_sha256,
    file_loads.row_count,
    file_loads.loaded_at,
    file_loads.file_status,
    file_loads.error_message,
    runs.pipeline_name,
    runs.run_status,
    runs.run_started_at,
    runs.run_finished_at,
    datediff('second', runs.run_started_at, file_loads.loaded_at)
        as seconds_from_run_start_to_file_event,
    case
        when file_loads.source_file_size_bytes > 0
            then round(
                file_loads.row_count::double / file_loads.source_file_size_bytes,
                6
            )
    end as rows_per_byte
from file_loads
left join runs
    on file_loads.ingestion_run_id = runs.ingestion_run_id
