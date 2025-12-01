WITH current_mtd AS (
  SELECT COUNT(DISTINCT s.invoice_id)::numeric AS mtd_completed_invoices
  FROM public.sales s
  WHERE 
    s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND s.seller_signed_on >= date_trunc('month', CURRENT_DATE)
    AND s.seller_signed_on <= CURRENT_DATE
),
last_month_same_period AS (
  SELECT COUNT(DISTINCT s.invoice_id)::numeric AS last_month_completed_invoices
  FROM public.sales s
  WHERE 
    s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND s.seller_signed_on >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
    AND s.seller_signed_on <  date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
                       + (CURRENT_DATE - date_trunc('month', CURRENT_DATE))
)
SELECT 
  current_mtd.mtd_completed_invoices,
  last_month_same_period.last_month_completed_invoices,
  ROUND(
    CASE 
      WHEN last_month_same_period.last_month_completed_invoices = 0 THEN 0
      ELSE (current_mtd.mtd_completed_invoices - last_month_same_period.last_month_completed_invoices)
           / last_month_same_period.last_month_completed_invoices
    END, 4
  ) AS current_vs_last_month_pct
FROM current_mtd, last_month_same_period;