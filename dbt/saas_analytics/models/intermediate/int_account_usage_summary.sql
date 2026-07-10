with feature_usage as (
    select
        subscriptions.account_id,
        usage.usage_date,
        usage.feature_name,
        usage.usage_count,
        usage.usage_duration_secs,
        usage.error_count,
        usage.is_beta_feature

    from {{ ref('stg_feature_usage') }} as usage

    inner join {{ ref('stg_subscriptions') }} as subscriptions
        on usage.subscription_id = subscriptions.subscription_id
)

select
    account_id,
    count(*) as usage_event_count,
    count(distinct usage_date) as active_usage_days,
    count(distinct feature_name) as distinct_features_used,
    sum(usage_count) as total_usage_count,
    avg(usage_count) as avg_usage_count_per_event,
    sum(usage_duration_secs) as total_usage_duration_secs,
    avg(usage_duration_secs) as avg_usage_duration_secs,
    sum(error_count) as total_error_count,
    avg(error_count) as avg_error_count_per_event,
    sum(case when is_beta_feature then 1 else 0 end) as beta_feature_event_count,
    avg(case when is_beta_feature then 1.0 else 0.0 end) as beta_feature_event_rate,
    max(usage_date) as last_usage_date

from feature_usage

group by account_id
