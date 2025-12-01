SELECT
  TO_CHAR(DATE_TRUNC('month', CURRENT_DATE), 'Month') AS month_name,
  ROUND(SUM(COALESCE(s.subtotal, 0)), 2)::float AS gmv_mtd
FROM public.sales s
WHERE s.dwolla_invoice_status = 'COMPLETED'
  AND s.seller_signed_on >= DATE_TRUNC('month', CURRENT_DATE)
  AND s.seller_signed_on < (CURRENT_DATE + INTERVAL '1 day');