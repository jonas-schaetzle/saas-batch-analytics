select
    date_trunc('month', start_date) as revenue_month,
    plan_tier,
    billing_frequency,
    count(distinct account_id) as account_count,
    count(distinct subscription_id) as subscription_count,
    sum(mrr_amount) as total_mrr_amount,
    sum(arr_amount) as total_arr_amount,
    avg(mrr_amount) as avg_mrr_amount,
    avg(seats) as avg_seats,
    sum(case when upgrade_flag then 1 else 0 end) as upgrade_count,
    sum(case when downgrade_flag then 1 else 0 end) as downgrade_count,
    sum(case when churn_flag then 1 else 0 end) as churned_subscription_count

from {{ ref('stg_subscriptions') }}

group by
    revenue_month,
    plan_tier,
    billing_frequency
