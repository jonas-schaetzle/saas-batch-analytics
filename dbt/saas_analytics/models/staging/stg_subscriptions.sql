select
    subscription_id,
    account_id,
    cast(start_date as date) as start_date,
    cast(end_date as date) as end_date,
    plan_tier,
    cast(seats as integer) as seats,
    cast(mrr_amount as double) as mrr_amount,
    cast(arr_amount as double) as arr_amount,
    cast(is_trial as boolean) as is_trial,
    cast(upgrade_flag as boolean) as upgrade_flag,
    cast(downgrade_flag as boolean) as downgrade_flag,
    cast(churn_flag as boolean) as churn_flag,
    billing_frequency,
    cast(auto_renew_flag as boolean) as auto_renew_flag

from {{ source('raw', 'raw_subscriptions') }}
