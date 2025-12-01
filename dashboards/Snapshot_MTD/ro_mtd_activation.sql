WITH this_month AS (
  SELECT date_trunc('month', CURRENT_DATE)::date AS month_start
),

sales_activity AS (
  SELECT
    buyer_id,
    seller_id,
    date_trunc('month', seller_signed_on)::date AS invoice_month
  FROM public.sales
  WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
),

first_transactions AS (
  SELECT
    store_id,
    MIN(invoice_month) AS first_txn_month
  FROM (
    SELECT buyer_id AS store_id, invoice_month
    FROM sales_activity
    WHERE buyer_id IS NOT NULL

    UNION ALL

    SELECT seller_id AS store_id, invoice_month
    FROM sales_activity
    WHERE seller_id IS NOT NULL
  ) t
  GROUP BY store_id
),

new_stores AS (
  SELECT
    store_id,
    date_trunc('month', created_at)::date AS signup_month
  FROM public.stores
  WHERE date_trunc('month', created_at) = (SELECT month_start FROM this_month)
),

cohort_activation AS (
  SELECT
    COUNT(*) AS activations
  FROM new_stores ns
  LEFT JOIN first_transactions ft USING (store_id)
  WHERE ns.signup_month = ft.first_txn_month
)

SELECT
  (SELECT COUNT(*) FROM new_stores) AS total_new_stores,

  (SELECT activations FROM cohort_activation) AS activated_stores,

  CASE
    WHEN (SELECT COUNT(*) FROM new_stores) = 0 THEN 0
    ELSE ROUND(
      (SELECT activations FROM cohort_activation)::numeric
      / (SELECT COUNT(*) FROM new_stores),
      4
    )
  END AS activation_rate;