WITH current_mtd AS (
  SELECT 
    COUNT(invoice_id) AS invoice_count,
    COALESCE(SUM(subtotal), 0) AS total_revenue
  FROM public.sales
  WHERE 
    seller_signed_on >= date_trunc('month', CURRENT_DATE)
    AND seller_signed_on < CURRENT_DATE + INTERVAL '1 day'
    AND dwolla_invoice_status IN ('COMPLETED', 'PENDING')
),

last_month_mtd AS (
  SELECT 
    COUNT(invoice_id) AS invoice_count,
    COALESCE(SUM(subtotal), 0) AS total_revenue
  FROM public.sales
  WHERE 
    seller_signed_on >= date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
    AND seller_signed_on < (date_trunc('month', CURRENT_DATE - INTERVAL '1 month') + (CURRENT_DATE - date_trunc('month', CURRENT_DATE))) + INTERVAL '1 day'
    AND dwolla_invoice_status IN ('COMPLETED', 'PENDING')
)

SELECT
    ROUND(
        CASE WHEN c.invoice_count = 0 THEN 0 
             ELSE c.total_revenue / c.invoice_count 
        END, 2
    ) AS aov_current,
    
    ROUND(
        CASE WHEN l.invoice_count = 0 THEN 0 
             ELSE l.total_revenue / l.invoice_count 
        END, 2
    ) AS aov_last_month,

    ROUND(
        CASE 
            WHEN (CASE WHEN l.invoice_count = 0 THEN 0 ELSE l.total_revenue / l.invoice_count END) = 0 THEN 0
            ELSE (
                (CASE WHEN c.invoice_count = 0 THEN 0 ELSE c.total_revenue / c.invoice_count END) - 
                (CASE WHEN l.invoice_count = 0 THEN 0 ELSE l.total_revenue / l.invoice_count END)
            ) / (CASE WHEN l.invoice_count = 0 THEN 0 ELSE l.total_revenue / l.invoice_count END)
        END, 4
    ) AS growth_pct
FROM current_mtd c, last_month_mtd l;

