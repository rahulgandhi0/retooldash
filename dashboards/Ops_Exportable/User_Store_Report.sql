WITH bounds AS (
  SELECT
    date_trunc('month', {{ date_selection_user_store_report.value.start }}::date) AS start_month,
    date_trunc('month', {{ date_selection_user_store_report.value.end }}::date)   AS end_month
),

months AS (
  SELECT generate_series(
    (SELECT start_month FROM bounds),
    (SELECT end_month   FROM bounds),
    interval '1 month'
  )::date AS month_start
),

completed_invoices AS (
  SELECT *
  FROM public.sales
  WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
),

new_signups AS (
  SELECT
    date_trunc('month', s.created_at)::date AS month_start,
    COUNT(*) AS new_signups
  FROM public.stores s
  WHERE date_trunc('month', s.created_at) BETWEEN
        (SELECT start_month FROM bounds) AND (SELECT end_month FROM bounds)
  GROUP BY 1
),

new_onboards AS (
  SELECT
    date_trunc('month', s.created_at)::date AS month_start,
    COUNT(*) AS new_onboards
  FROM public.stores s
  JOIN public.funding_accounts fa ON fa.funding_id = s.funding_id
  WHERE date_trunc('month', s.created_at) BETWEEN
        (SELECT start_month FROM bounds) AND (SELECT end_month FROM bounds)
    AND date_trunc('month', s.created_at) = date_trunc('month', fa.created_at)
    AND fa.funding_status <> 'NOT_STARTED'
  GROUP BY 1
),

first_transactions AS (
  SELECT
    store_id,
    MIN(txn_month) AS first_txn_month
  FROM (
    SELECT buyer_id AS store_id,
           date_trunc('month', seller_signed_on)::date AS txn_month
    FROM completed_invoices
    WHERE buyer_id IS NOT NULL
    UNION ALL
    SELECT seller_id AS store_id,
           date_trunc('month', seller_signed_on)::date AS txn_month
    FROM completed_invoices
    WHERE seller_id IS NOT NULL
  ) t
  GROUP BY store_id
),

new_customers AS (
  SELECT
    first_txn_month AS month_start,
    COUNT(DISTINCT store_id) AS new_customers
  FROM first_transactions
  WHERE first_txn_month BETWEEN
        (SELECT start_month FROM bounds) AND (SELECT end_month FROM bounds)
  GROUP BY 1
),

store_cohorts AS (
  SELECT
    s.store_id,
    date_trunc('month', s.created_at)::date AS signup_month,
    ft.first_txn_month
  FROM public.stores s
  LEFT JOIN first_transactions ft USING (store_id)
  WHERE date_trunc('month', s.created_at) BETWEEN
        (SELECT start_month FROM bounds) AND (SELECT end_month FROM bounds)
),

cohort_activation AS (
  SELECT
    signup_month AS month_start,
    COUNT(*) AS activations
  FROM store_cohorts
  WHERE signup_month = first_txn_month
  GROUP BY 1
),

active_stores AS (
  SELECT
    date_trunc('month', seller_signed_on)::date AS month_start,
    COUNT(DISTINCT store_id) AS active_stores
  FROM (
    SELECT seller_signed_on, buyer_id AS store_id
    FROM completed_invoices
    UNION ALL
    SELECT seller_signed_on, seller_id AS store_id
    FROM completed_invoices
  ) t
  GROUP BY 1
),

active_buyers AS (
  SELECT
    date_trunc('month', seller_signed_on)::date AS month_start,
    COUNT(DISTINCT buyer_id) AS active_buyers
  FROM completed_invoices
  GROUP BY 1
),

active_sellers AS (
  SELECT
    date_trunc('month', seller_signed_on)::date AS month_start,
    COUNT(DISTINCT seller_id) AS active_sellers
  FROM completed_invoices
  GROUP BY 1
)

SELECT
  to_char(m.month_start, 'YYYY-MM') AS "Month",

  COALESCE(ns.new_signups, 0)      AS "New Sign-ups",
  COALESCE(no.new_onboards, 0)     AS "New Onboards",
  CASE
    WHEN COALESCE(ns.new_signups, 0) = 0 THEN 0
    ELSE ROUND((COALESCE(no.new_onboards, 0)::numeric / ns.new_signups) * 100, 2)
  END AS "New Onboards Percent",

  COALESCE(nc.new_customers, 0)    AS "New Customers",

  COALESCE(ca.activations, 0)      AS "Activations",
  CASE
    WHEN COALESCE(ns.new_signups, 0) = 0 THEN 0
    ELSE ROUND((COALESCE(ca.activations, 0)::numeric / ns.new_signups) * 100, 2)
  END AS "Activations Percent",

  COALESCE(ast.active_stores, 0)   AS "Active Stores",
  COALESCE(ab.active_buyers, 0)    AS "Active Buyers",
  COALESCE(asl.active_sellers, 0)  AS "Active Sellers"

FROM months m
LEFT JOIN new_signups ns       ON ns.month_start = m.month_start
LEFT JOIN new_onboards no      ON no.month_start = m.month_start
LEFT JOIN new_customers nc     ON nc.month_start = m.month_start
LEFT JOIN cohort_activation ca ON ca.month_start = m.month_start
LEFT JOIN active_stores ast    ON ast.month_start = m.month_start
LEFT JOIN active_buyers ab     ON ab.month_start = m.month_start
LEFT JOIN active_sellers asl   ON asl.month_start = m.month_start
ORDER BY m.month_start;
