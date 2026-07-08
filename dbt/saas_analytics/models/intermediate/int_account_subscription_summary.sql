select
    account_id,
    count(*) as subscription_count,
    sum(mrr_amount) as total_mrr_amount,
    avg(mrr_amount) as avg_mrr_amount,
    max(mrr_amount) as max_mrr_amount,
    sum(case when upgrade_flag then 1 else 0 end) as upgrade_count,
    sum(case when downgrade_flag then 1 else 0 end) as downgrade_count

from {{ ref('stg_subscriptions') }}

group by account_id
