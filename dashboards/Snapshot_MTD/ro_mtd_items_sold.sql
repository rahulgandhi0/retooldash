WITH current_mtd AS (
  SELECT COUNT(ii.invoice_item_id)::numeric AS items_sold_now
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  WHERE s.seller_signed_on >= date_trunc('month', CURRENT_DATE)
    AND s.seller_signed_on <= CURRENT_DATE
    AND s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status IN ('INCLUDED')
),

last_month_same_period AS (
  SELECT COUNT(ii.invoice_item_id)::numeric AS items_sold_last_month
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  WHERE s.seller_signed_on >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
    AND s.seller_signed_on < date_trunc('month', CURRENT_DATE - INTERVAL '1 month') 
                             + (CURRENT_DATE - date_trunc('month', CURRENT_DATE))
    AND s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status IN ('INCLUDED')
)

SELECT 
  current_mtd.items_sold_now,
  last_month_same_period.items_sold_last_month,
  ROUND(
    CASE 
      WHEN last_month_same_period.items_sold_last_month = 0 THEN 0
      ELSE (current_mtd.items_sold_now - last_month_same_period.items_sold_last_month)
           / last_month_same_period.items_sold_last_month
    END, 
    4
  ) AS current_vs_last_month_pct
FROM current_mtd, last_month_same_period;