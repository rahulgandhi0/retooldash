
SELECT sales_goal
FROM   monthly_sales_goal
WHERE  date_trunc('month', month_year) =
       date_trunc('month',
                  (current_timestamp AT TIME ZONE 'America/Los_Angeles')::date);
