select
    account_id,
    count(*) as support_ticket_count,
    avg(resolution_time_hours) as avg_resolution_time_hours,
    avg(first_response_time_minutes) as avg_first_response_time_minutes,
    avg(satisfaction_score) as avg_satisfaction_score,
    sum(case when escalation_flag then 1 else 0 end) as escalation_count

from {{ ref('stg_support_tickets') }}

group by account_id
