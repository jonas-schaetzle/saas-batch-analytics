select
    account_id,
    account_name,
    industry,
    country,
    cast(signup_date as date) as signup_date,
    referral_source,
    plan_tier,
    cast(seats as integer) as seats,
    cast(is_trial as boolean) as is_trial,
    cast(churn_flag as boolean) as churn_flag

from read_csv_auto('/usr/app/data/raw/accounts.csv', header=true)