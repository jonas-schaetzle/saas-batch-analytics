with account_metrics as (
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

        subscription_metrics.subscription_count,
        subscription_metrics.total_mrr_amount,
        subscription_metrics.avg_mrr_amount,
        subscription_metrics.max_mrr_amount,
        subscription_metrics.upgrade_count,
        subscription_metrics.downgrade_count,

        support_metrics.support_ticket_count,
        support_metrics.avg_resolution_time_hours,
        support_metrics.avg_first_response_time_minutes,
        support_metrics.avg_satisfaction_score,
        support_metrics.escalation_count,

        usage_metrics.usage_event_count,
        usage_metrics.active_usage_days,
        usage_metrics.distinct_features_used,
        usage_metrics.total_usage_count,
        usage_metrics.avg_usage_count_per_event,
        usage_metrics.total_usage_duration_secs,
        usage_metrics.avg_usage_duration_secs,
        usage_metrics.total_error_count,
        usage_metrics.avg_error_count_per_event,
        usage_metrics.beta_feature_event_count,
        usage_metrics.beta_feature_event_rate,
        usage_metrics.last_usage_date,

        churn_metrics.first_churn_date,
        churn_metrics.churn_event_count,
        churn_metrics.latest_reason_code,
        churn_metrics.total_refund_amount_usd

    from {{ ref('stg_accounts') }} as accounts

    left join {{ ref('int_account_subscription_summary') }} as subscription_metrics
        on accounts.account_id = subscription_metrics.account_id

    left join {{ ref('int_account_support_summary') }} as support_metrics
        on accounts.account_id = support_metrics.account_id

    left join {{ ref('int_account_usage_summary') }} as usage_metrics
        on accounts.account_id = usage_metrics.account_id

    left join {{ ref('int_account_churn_summary') }} as churn_metrics
        on accounts.account_id = churn_metrics.account_id
)

select
    *,
    case
        when seats > 0 then total_mrr_amount / seats
    end as mrr_per_seat,
    case
        when subscription_count > 0
            then support_ticket_count::double / subscription_count
    end as support_tickets_per_subscription,
    case
        when subscription_count > 0 then usage_event_count::double / subscription_count
    end as usage_events_per_subscription,
    case
        when active_usage_days > 0 then total_usage_count::double / active_usage_days
    end as usage_intensity_per_day,
    case
        when total_usage_count > 0 then total_error_count::double / total_usage_count
    end as error_rate_per_usage,
    case
        when last_usage_date is not null and first_churn_date is not null
            then date_diff('day', last_usage_date, first_churn_date)
    end as days_from_last_usage_to_churn,
    case
        when signup_date is not null and first_churn_date is not null
            then date_diff('day', signup_date, first_churn_date)
    end as account_lifetime_days,
    case
        when beta_feature_event_rate >= 0.2 then true
        when beta_feature_event_rate is not null then false
    end as beta_feature_adopter_flag

from account_metrics
