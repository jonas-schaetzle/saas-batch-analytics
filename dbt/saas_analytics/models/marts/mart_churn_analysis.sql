select
    accounts.account_id,
    accounts.account_name,
    accounts.industry,
    accounts.country,
    accounts.signup_date,
    accounts.referral_source,
    accounts.plan_tier,
    accounts.seats,
    accounts.churn_flag,

    subscriptions.subscription_count,
    subscriptions.total_mrr_amount,
    subscriptions.avg_mrr_amount,
    subscriptions.max_mrr_amount,
    subscriptions.upgrade_count,
    subscriptions.downgrade_count,

    support.support_ticket_count,
    support.avg_resolution_time_hours,
    support.avg_first_response_time_minutes,
    support.avg_satisfaction_score,
    support.escalation_count,

    churn.first_churn_date,
    churn.churn_event_count,
    churn.latest_reason_code,
    churn.total_refund_amount_usd

from {{ ref('stg_accounts') }} as accounts

left join {{ ref('int_account_subscription_summary') }} as subscriptions
    on accounts.account_id = subscriptions.account_id

left join {{ ref('int_account_support_summary') }} as support
    on accounts.account_id = support.account_id

left join {{ ref('int_account_churn_summary') }} as churn
    on accounts.account_id = churn.account_id
