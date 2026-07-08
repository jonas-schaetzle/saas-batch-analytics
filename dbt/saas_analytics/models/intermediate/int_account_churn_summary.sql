select
    account_id,
    min(churn_date) as first_churn_date,
    count(*) as churn_event_count,
    max(reason_code) as latest_reason_code,
    sum(refund_amount_usd) as total_refund_amount_usd

from {{ ref('stg_churn_events') }}

group by account_id
