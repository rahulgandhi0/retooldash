WITH revenue_and_gmv AS (
  SELECT
    SUM(COALESCE(s.rxpost_fee_percent, 0) / 100.0 * COALESCE(s.subtotal, 0)) AS platform_revenue,
    SUM(COALESCE(s.subtotal, 0)) AS total_gmv
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status = 'INCLUDED'
    AND s.seller_signed_on >= DATE_TRUNC('month', CURRENT_DATE)
    AND s.seller_signed_on < (CURRENT_DATE + INTERVAL '1 day')
)
SELECT
  TO_CHAR(DATE_TRUNC('month', CURRENT_DATE), 'Month') AS month_name,
  ROUND(
    platform_revenue / NULLIF(total_gmv, 0),
    4
  )::float AS weighted_take_rate_mtd
FROM revenue_and_gmv;
