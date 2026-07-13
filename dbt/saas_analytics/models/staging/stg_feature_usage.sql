select
    usage_id,
    subscription_id,
    cast(usage_date as date) as usage_date,
    feature_name,
    cast(usage_count as integer) as usage_count,
    cast(usage_duration_secs as integer) as usage_duration_secs,
    cast(error_count as integer) as error_count,
    cast(is_beta_feature as boolean) as is_beta_feature

from {{ source('raw', 'raw_feature_usage') }}
