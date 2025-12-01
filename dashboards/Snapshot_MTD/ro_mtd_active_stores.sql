WITH current_mtd AS (
  SELECT COUNT(DISTINCT store_id)::numeric AS active_stores_now
  FROM (
    SELECT buyer_id AS store_id
    FROM public.sales
    WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
      AND seller_signed_on >= date_trunc('month', CURRENT_DATE)
      AND seller_signed_on <= CURRENT_DATE

    UNION

    SELECT seller_id AS store_id
    FROM public.sales
    WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
      AND seller_signed_on >= date_trunc('month', CURRENT_DATE)
      AND seller_signed_on <= CURRENT_DATE
  ) AS all_stores
),
last_month_same_period AS (
  SELECT COUNT(DISTINCT store_id)::numeric AS active_stores_last_month
  FROM (
    SELECT buyer_id AS store_id
    FROM public.sales
    WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
      AND seller_signed_on >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
      AND seller_signed_on < date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
                        + (CURRENT_DATE - date_trunc('month', CURRENT_DATE))

    UNION

    SELECT seller_id AS store_id
    FROM public.sales
    WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
      AND seller_signed_on >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
      AND seller_signed_on < date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
                        + (CURRENT_DATE - date_trunc('month', CURRENT_DATE))
  ) AS all_stores
)
SELECT 
  current_mtd.active_stores_now,
  last_month_same_period.active_stores_last_month,
  ROUND(
    CASE 
      WHEN last_month_same_period.active_stores_last_month = 0 THEN 0
      ELSE 
        (current_mtd.active_stores_now - last_month_same_period.active_stores_last_month)
        / last_month_same_period.active_stores_last_month::numeric
    END, 4
  ) AS current_vs_last_month_pct
FROM current_mtd, last_month_same_period;