WITH first_tx_date AS (
  SELECT
    seller_id,
    DATE_TRUNC('month', MIN(seller_signed_on))::date AS first_tx_month
  FROM public.sales
  WHERE dwolla_invoice_status = 'COMPLETED'
  GROUP BY seller_id
),
mtd_revenue AS (
  SELECT
    s.seller_id,
    SUM(COALESCE(s.rxpost_fee_percent, 0) / 100.0 * COALESCE(s.subtotal, 0)) AS revenue,
    f.first_tx_month
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  LEFT JOIN first_tx_date f ON s.seller_id = f.seller_id
  WHERE s.dwolla_invoice_status = 'COMPLETED'
    AND ii.status = 'INCLUDED'
    AND s.seller_signed_on >= DATE_TRUNC('month', CURRENT_DATE)
    AND s.seller_signed_on < (CURRENT_DATE + INTERVAL '1 day')
  GROUP BY s.seller_id, f.first_tx_month
),
revenue_by_type AS (
  SELECT
    CASE
      WHEN first_tx_month = DATE_TRUNC('month', CURRENT_DATE)::date THEN 'New'
      ELSE 'Existing'
    END AS seller_type,
    SUM(revenue) AS revenue_mtd
  FROM mtd_revenue
  GROUP BY 1
)
SELECT
  TO_CHAR(DATE_TRUNC('month', CURRENT_DATE), 'Month') AS month_name,
  t.seller_type,
  ROUND(COALESCE(r.revenue_mtd, 0), 2)::float AS revenue_mtd,
  ROUND(
    100.0 * COALESCE(r.revenue_mtd, 0)
    / NULLIF(SUM(COALESCE(r.revenue_mtd, 0)) OVER (), 0),
    2
  )::float AS pct_of_total
FROM (VALUES ('Existing'), ('New')) AS t(seller_type)
LEFT JOIN revenue_by_type r ON t.seller_type = r.seller_type
ORDER BY revenue_mtd DESC;
