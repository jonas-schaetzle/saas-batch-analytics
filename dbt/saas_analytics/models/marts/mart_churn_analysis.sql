with accounts as (

    select *
    from {{ ref('stg_accounts') }}

),

subscriptions as (

    select *
    from {{ ref('stg_subscriptions') }}

),

support_summary as (

    select
        account_id,
        count(*) as support_ticket_count,
        avg(resolution_time_hours) as avg_resolution_time_hours,
        avg(first_response_time_minutes) as avg_first_response_time_minutes,
        avg(satisfaction_score) as avg_satisfaction_score,
        sum(case when escalation_flag then 1 else 0 end) as escalation_count

    from {{ ref('stg_support_tickets') }}
    group by account_id

),

churn_events as (

    select
        account_id,
        min(churn_date) as first_churn_date,
        count(*) as churn_event_count,
        max(reason_code) as latest_reason_code,
        sum(refund_amount_usd) as total_refund_amount_usd

    from {{ ref('stg_churn_events') }}
    group by account_id

),

subscription_summary as (

    select
        account_id,
        count(*) as subscription_count,
        sum(mrr_amount) as total_mrr_amount,
        avg(mrr_amount) as avg_mrr_amount,
        max(mrr_amount) as max_mrr_amount,
        sum(case when upgrade_flag then 1 else 0 end) as upgrade_count,
        sum(case when downgrade_flag then 1 else 0 end) as downgrade_count

    from subscriptions
    group by account_id

)

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

    subscription_summary.subscription_count,
    subscription_summary.total_mrr_amount,
    subscription_summary.avg_mrr_amount,
    subscription_summary.max_mrr_amount,
    subscription_summary.upgrade_count,
    subscription_summary.downgrade_count,

    support_summary.support_ticket_count,
    support_summary.avg_resolution_time_hours,
    support_summary.avg_first_response_time_minutes,
    support_summary.avg_satisfaction_score,
    support_summary.escalation_count,

    churn_events.first_churn_date,
    churn_events.churn_event_count,
    churn_events.latest_reason_code,
    churn_events.total_refund_amount_usd

from accounts
left join subscription_summary
    on accounts.account_id = subscription_summary.account_id
left join support_summary
    on accounts.account_id = support_summary.account_id
left join churn_events
    on accounts.account_id = churn_events.account_id