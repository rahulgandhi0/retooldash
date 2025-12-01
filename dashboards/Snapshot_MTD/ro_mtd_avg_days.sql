WITH current_mtd AS (
  SELECT 
    ROUND(
      AVG(
        EXTRACT(
          DAY FROM (s.seller_signed_on - p.created_at)
        )
      )::numeric, 
      2
    ) AS avg_days_to_sell_now
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  JOIN public.posts p ON p.post_id = ii.post_id
  WHERE 
    ii.status = 'INCLUDED'
    AND s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND s.seller_signed_on >= date_trunc('month', CURRENT_DATE)
    AND s.seller_signed_on <= CURRENT_DATE
),

last_month_same_period AS (
  SELECT 
    ROUND(
      AVG(
        EXTRACT(
          DAY FROM (s.seller_signed_on - p.created_at)
        )
      )::numeric, 
      2
    ) AS avg_days_to_sell_last_month
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  JOIN public.posts p ON p.post_id = ii.post_id
  WHERE 
    ii.status = 'INCLUDED'
    AND s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND s.seller_signed_on >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
    AND s.seller_signed_on < date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
                          + (CURRENT_DATE - date_trunc('month', CURRENT_DATE))
)

SELECT 
  current_mtd.avg_days_to_sell_now,
  last_month_same_period.avg_days_to_sell_last_month,
  ROUND(
    CASE 
      WHEN last_month_same_period.avg_days_to_sell_last_month = 0 THEN 0
      ELSE 
        (current_mtd.avg_days_to_sell_now - last_month_same_period.avg_days_to_sell_last_month)
        / last_month_same_period.avg_days_to_sell_last_month
    END,
    4
  ) AS avg_days_to_sell_change_pct
FROM current_mtd, last_month_same_period;