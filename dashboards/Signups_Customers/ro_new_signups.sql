WITH date_series AS (
  SELECT
    generate_series(
      {{ date_range_newcomers.value.start }}::date,
      {{ date_range_newcomers.value.end }}::date,
      interval '1 day'
    )::date AS signup_date
),
daily_signups AS (
  SELECT
    DATE_TRUNC('day', s.created_at)::date AS signup_date,
    COUNT(*) AS new_store_signups
  FROM public.stores AS s
  WHERE s.created_at::date BETWEEN
        {{ date_range_newcomers.value.start }}::date
        AND {{ date_range_newcomers.value.end }}::date
  GROUP BY 1
)
SELECT
  ds.signup_date,
  COALESCE(d.new_store_signups, 0) AS new_store_signups
FROM date_series ds
LEFT JOIN daily_signups d
  ON ds.signup_date = d.signup_date
ORDER BY ds.signup_date;
