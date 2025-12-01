WITH current_month AS (
  SELECT date_trunc('month', CURRENT_DATE)::date AS m
),
previous_month AS (
  SELECT (date_trunc('month', CURRENT_DATE)::date - interval '1 month') AS m
),
seller_gmv AS (
  SELECT
    s.seller_id,
    date_trunc('month', s.seller_signed_on)::date AS month_start,
    SUM(COALESCE(s.subtotal, 0)) AS gmv
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  WHERE s.dwolla_invoice_status = 'COMPLETED'
    AND ii.status = 'INCLUDED'
  GROUP BY s.seller_id, date_trunc('month', s.seller_signed_on)::date
),
curr AS (
  SELECT
    SUM(sg2.gmv) AS total_curr_gmv
  FROM seller_gmv sg2
  JOIN seller_gmv sg1
    ON sg1.seller_id = sg2.seller_id
   AND sg1.month_start = (SELECT m FROM previous_month)
  WHERE sg2.month_start = (SELECT m FROM current_month)
),
prev AS (
  SELECT
    SUM(gmv) AS total_prev_gmv
  FROM seller_gmv
  WHERE month_start = (SELECT m FROM previous_month)
)
SELECT
  ROUND(
    CASE
      WHEN prev.total_prev_gmv = 0 THEN 0
      ELSE (curr.total_curr_gmv / prev.total_prev_gmv)
    END,
    4
  ) AS gmv_retention_pct_current_month
FROM curr, prev;
