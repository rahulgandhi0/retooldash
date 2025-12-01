WITH base_sales AS (
    SELECT 
        s.invoice_id,
        s.seller_id,
        date_trunc('month', s.seller_signed_on)::date AS sale_month,
        s.subtotal AS invoice_value,
        COALESCE(s.rxpost_fee_percent, 0) AS fee_percent
    FROM public.sales s
    WHERE s.seller_signed_on BETWEEN {{ exportable_daterange5.value.start }} AND {{ exportable_daterange5.value.end }}
      AND s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
      AND s.invoice_id IN (SELECT invoice_id FROM public.invoice_items WHERE status = 'INCLUDED')
),

line_item_stats AS (
    SELECT
        bs.invoice_id,
        COUNT(*) AS units
    FROM base_sales bs
    JOIN public.invoice_items ii ON ii.invoice_id = bs.invoice_id
    WHERE ii.status = 'INCLUDED'
    GROUP BY bs.invoice_id
),

invoice_totals AS (
    SELECT
        bs.invoice_id,
        bs.sale_month,
        bs.seller_id,
        bs.invoice_value,
        COALESCE(lis.units, 0) AS units,
        (bs.invoice_value * (bs.fee_percent / 100.0)) AS net_revenue_usd
    FROM base_sales bs
    LEFT JOIN line_item_stats lis ON lis.invoice_id = bs.invoice_id
),

gmv_month AS (
    SELECT
        sale_month,
        SUM(invoice_value) AS gmv_usd,
        COUNT(invoice_id) AS transactions,
        SUM(units)::int AS units_sold
    FROM invoice_totals
    GROUP BY sale_month
),

active_sellers AS (
    SELECT
        sale_month,
        COUNT(DISTINCT seller_id) AS active_sellers
    FROM invoice_totals
    GROUP BY sale_month
),

first_sale AS (
    SELECT
        seller_id,
        MIN(sale_month) AS first_month
    FROM invoice_totals
    GROUP BY seller_id
),

new_sellers AS (
    SELECT
        first_month AS sale_month,
        COUNT(*) AS new_sellers
    FROM first_sale
    GROUP BY first_month
),

gmv_new AS (
    SELECT
        it.sale_month,
        SUM(it.invoice_value) AS gmv_from_new
    FROM invoice_totals it
    JOIN first_sale fs 
      ON fs.seller_id = it.seller_id
      AND fs.first_month = it.sale_month
    GROUP BY it.sale_month
),

gmv_repeat AS (
    SELECT
        it.sale_month,
        SUM(it.invoice_value) AS gmv_from_repeat
    FROM invoice_totals it
    JOIN first_sale fs 
      ON fs.seller_id = it.seller_id
      AND fs.first_month < it.sale_month
    GROUP BY it.sale_month
),

net_revenue AS (
    SELECT
        sale_month,
        SUM(net_revenue_usd) AS net_revenue_usd
    FROM invoice_totals
    GROUP BY sale_month
)

SELECT
    to_char(g.sale_month, 'Mon YYYY') AS "Month",
    ROUND(COALESCE(g.gmv_usd, 0), 2) AS "GMV ($)",
    COALESCE(g.transactions, 0) AS "Total Transactions",
    COALESCE(g.units_sold, 0) AS "Units Sold",
    ROUND(COALESCE(asl.active_sellers, 0), 2) AS "Active Sellers",
    ROUND(COALESCE(ns.new_sellers, 0), 2) AS "New Sellers",
    ROUND((COALESCE(asl.active_sellers,0) - COALESCE(ns.new_sellers,0)), 2) AS "Repeat Sellers",
    ROUND(COALESCE(gn.gmv_from_new, 0), 2) AS "GMV from New ($)",
    ROUND(COALESCE(gr.gmv_from_repeat, 0), 2) AS "GMV from Repeat ($)",
    CASE WHEN COALESCE(g.transactions,0) > 0
         THEN ROUND(g.gmv_usd / g.transactions, 2)
         ELSE 0 END AS "Avg Order Value ($)",
    ROUND(COALESCE(nr.net_revenue_usd, 0), 2) AS "Net Revenue ($)"
FROM gmv_month g
LEFT JOIN active_sellers asl ON asl.sale_month = g.sale_month
LEFT JOIN new_sellers ns     ON ns.sale_month = g.sale_month
LEFT JOIN gmv_new gn         ON gn.sale_month = g.sale_month
LEFT JOIN gmv_repeat gr      ON gr.sale_month = g.sale_month
LEFT JOIN net_revenue nr     ON nr.sale_month = g.sale_month
ORDER BY g.sale_month;