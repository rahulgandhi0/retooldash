-- New Customers Per Day (Including 0s)
WITH date_series AS (
  SELECT
    generate_series(
      {{ date_range_newcomers.value.start }}::date,
      {{ date_range_newcomers.value.end }}::date,
      interval '1 day'
    )::date AS customer_date
),

-- All store transactions (buyer + seller)
store_txns AS (
  SELECT buyer_id AS store_id, created_at::date AS tx_date
  FROM public.invoices
  WHERE dwolla_invoice_status = 'COMPLETED'

  UNION ALL

  SELECT seller_id AS store_id, created_at::date AS tx_date
  FROM public.invoices
  WHERE dwolla_invoice_status = 'COMPLETED'
),

-- First transaction date per store
first_tx_per_store AS (
  SELECT
    store_id,
    MIN(tx_date) AS first_tx_date
  FROM store_txns
  GROUP BY store_id
),

-- Count new customers by first transaction date
daily_new_customers AS (
  SELECT
    first_tx_date AS customer_date,
    COUNT(DISTINCT store_id) AS new_customers
  FROM first_tx_per_store
  WHERE first_tx_date BETWEEN
        {{ date_range_newcomers.value.start }}::date
        AND {{ date_range_newcomers.value.end }}::date
  GROUP BY 1
)

SELECT
  ds.customer_date,
  COALESCE(dnc.new_customers, 0) AS new_customers
FROM date_series ds
LEFT JOIN daily_new_customers dnc
  ON ds.customer_date = dnc.customer_date
ORDER BY ds.customer_date;
