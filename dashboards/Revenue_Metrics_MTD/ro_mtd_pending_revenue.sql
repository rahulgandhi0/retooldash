SELECT
  TO_CHAR(DATE_TRUNC('month', CURRENT_DATE), 'Month') AS month_name,
  ROUND(
    SUM(
      COALESCE(s.rxpost_fee_percent, 0) / 100.0
      * COALESCE(s.subtotal, 0)
    ),
    2
  )::float AS total_platform_revenue_pending
FROM public.sales s
WHERE s.dwolla_invoice_status = 'PENDING'
  AND s.seller_signed_on >= DATE_TRUNC('month', CURRENT_DATE)
  AND s.seller_signed_on < (CURRENT_DATE + INTERVAL '1 day');
