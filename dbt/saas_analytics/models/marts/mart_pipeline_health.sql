with source_health as (
    select
        'raw_accounts' as source_table,
        max(loaded_at) as latest_loaded_at,
        count(*) as raw_record_count
    from {{ source('raw', 'raw_accounts') }}

    union all

    select
        'raw_subscriptions' as source_table,
        max(loaded_at) as latest_loaded_at,
        count(*) as raw_record_count
    from {{ source('raw', 'raw_subscriptions') }}

    union all

    select
        'raw_feature_usage' as source_table,
        max(loaded_at) as latest_loaded_at,
        count(*) as raw_record_count
    from {{ source('raw', 'raw_feature_usage') }}

    union all

    select
        'raw_support_tickets' as source_table,
        max(loaded_at) as latest_loaded_at,
        count(*) as raw_record_count
    from {{ source('raw', 'raw_support_tickets') }}

    union all

    select
        'raw_churn_events' as source_table,
        max(loaded_at) as latest_loaded_at,
        count(*) as raw_record_count
    from {{ source('raw', 'raw_churn_events') }}
),

latest_file_events as (
    select
        ingestion_run_id,
        table_name,
        source_file_name,
        source_file_sha256,
        row_count,
        loaded_at,
        file_status,
        row_number() over (
            partition by table_name
            order by loaded_at desc, ingestion_run_id desc
        ) as row_num
    from {{ ref('mart_ingestion_file_loads') }}
),

latest_runs as (
    select
        ingestion_run_id,
        pipeline_name,
        run_status,
        run_started_at,
        run_finished_at,
        run_duration_seconds,
        files_loaded,
        files_skipped,
        files_failed
    from {{ ref('mart_ingestion_runs') }}
)

select
    source_health.source_table,
    source_health.latest_loaded_at,
    source_health.raw_record_count,
    latest_file_events.ingestion_run_id as latest_ingestion_run_id,
    latest_runs.pipeline_name,
    latest_runs.run_status as latest_run_status,
    latest_runs.run_started_at as latest_run_started_at,
    latest_runs.run_finished_at as latest_run_finished_at,
    latest_runs.run_duration_seconds as latest_run_duration_seconds,
    latest_runs.files_loaded as latest_run_files_loaded,
    latest_runs.files_skipped as latest_run_files_skipped,
    latest_runs.files_failed as latest_run_files_failed,
    latest_file_events.source_file_name as latest_source_file_name,
    latest_file_events.source_file_sha256 as latest_source_file_sha256,
    latest_file_events.row_count as latest_file_row_count,
    latest_file_events.file_status as latest_file_status,
    latest_file_events.loaded_at as latest_file_event_at,
    datediff('hour', source_health.latest_loaded_at, current_timestamp)
        as hours_since_last_load,
    case
        when datediff('hour', source_health.latest_loaded_at, current_timestamp) <= 36
            then 'fresh'
        when datediff('hour', source_health.latest_loaded_at, current_timestamp) <= 72
            then 'warning'
        else 'stale'
    end as freshness_status,
    case
        when
            latest_runs.run_status = 'success'
            and latest_file_events.file_status in ('success', 'skipped')
            and datediff(
                'hour',
                source_health.latest_loaded_at,
                current_timestamp
            ) <= 36
            then 'healthy'
        when
            latest_runs.run_status = 'failed'
            or latest_file_events.file_status = 'failed'
            or datediff('hour', source_health.latest_loaded_at, current_timestamp) > 72
            then 'critical'
        else 'monitor'
    end as pipeline_health_status
from source_health
left join latest_file_events
    on
        source_health.source_table = latest_file_events.table_name
        and latest_file_events.row_num = 1
left join latest_runs
    on latest_file_events.ingestion_run_id = latest_runs.ingestion_run_id
