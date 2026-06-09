select
    ticket_id,
    account_id,
    cast(submitted_at as timestamp) as submitted_at,
    cast(closed_at as timestamp) as closed_at,
    cast(resolution_time_hours as double) as resolution_time_hours,
    priority,
    cast(first_response_time_minutes as integer) as first_response_time_minutes,
    cast(satisfaction_score as integer) as satisfaction_score,
    cast(escalation_flag as boolean) as escalation_flag

from read_csv_auto('/usr/app/data/raw/support_tickets.csv', header=true)