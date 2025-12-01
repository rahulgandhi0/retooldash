WITH counts AS (
  SELECT
    COUNT(*) FILTER (WHERE status = 'ACTIVE') AS active_now,
    COUNT(*) FILTER (WHERE status = 'ACTIVE' AND created_at >= date_trunc('month', CURRENT_DATE)) AS created_this_month
  FROM public.posts
)
SELECT
  active_now,
  (active_now - created_this_month) AS active_last_month,
  ROUND(
    CASE
      WHEN (active_now - created_this_month) <= 0 THEN 0
      ELSE (created_this_month::numeric / (active_now - created_this_month))
    END, 4
  ) AS current_vs_last_month_pct
FROM counts;