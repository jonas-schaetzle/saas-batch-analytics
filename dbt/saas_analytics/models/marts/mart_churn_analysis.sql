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

        usage.usage_event_count,
        usage.active_usage_days,
        usage.distinct_features_used,
        usage.total_usage_count,
        usage.avg_usage_count_per_event,
        usage.total_usage_duration_secs,
        usage.avg_usage_duration_secs,
        usage.total_error_count,
        usage.avg_error_count_per_event,
        usage.beta_feature_event_count,
        usage.beta_feature_event_rate,
        usage.last_usage_date,

        churn.first_churn_date,
        churn.churn_event_count,
        churn.latest_reason_code,
        churn.total_refund_amount_usd

    from {{ ref('stg_accounts') }} as accounts

    left join {{ ref('int_account_subscription_summary') }} as subscriptions
        on accounts.account_id = subscriptions.account_id

    left join {{ ref('int_account_support_summary') }} as support
        on accounts.account_id = support.account_id

    left join {{ ref('int_account_usage_summary') }} as usage
        on accounts.account_id = usage.account_id

    left join {{ ref('int_account_churn_summary') }} as churn
        on accounts.account_id = churn.account_id
)

select
    *,
    case
        when seats > 0 then total_mrr_amount / seats
        else null
    end as mrr_per_seat,
    case
        when subscription_count > 0 then support_ticket_count::double / subscription_count
        else null
    end as support_tickets_per_subscription,
    case
        when subscription_count > 0 then usage_event_count::double / subscription_count
        else null
    end as usage_events_per_subscription,
    case
        when active_usage_days > 0 then total_usage_count::double / active_usage_days
        else null
    end as usage_intensity_per_day,
    case
        when total_usage_count > 0 then total_error_count::double / total_usage_count
        else null
    end as error_rate_per_usage,
    case
        when last_usage_date is not null and first_churn_date is not null
            then date_diff('day', last_usage_date, first_churn_date)
        else null
    end as days_from_last_usage_to_churn,
    case
        when signup_date is not null and first_churn_date is not null
            then date_diff('day', signup_date, first_churn_date)
        else null
    end as account_lifetime_days,
    case
        when beta_feature_event_rate >= 0.2 then true
        when beta_feature_event_rate is not null then false
        else null
    end as beta_feature_adopter_flag

from account_metrics
