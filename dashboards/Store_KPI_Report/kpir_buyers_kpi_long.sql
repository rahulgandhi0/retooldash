WITH base_sales AS (
    SELECT 
        s.invoice_id,
        s.buyer_id,
        date_trunc('month', s.seller_signed_on)::date AS sale_month,
        s.subtotal AS invoice_value
    FROM public.sales s
    WHERE s.seller_signed_on BETWEEN {{ exportable_daterange5.value.start }} AND {{ exportable_daterange5.value.end }}
      AND s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
      AND s.invoice_id IN (SELECT invoice_id FROM public.invoice_items WHERE status = 'INCLUDED')
),

line_item_stats AS (
    SELECT
        bs.invoice_id,
        COUNT(*) AS units,
        SUM(
            CASE
                WHEN p.partial_quantity IS NULL
                    THEN COALESCE(d.package_price,0) - COALESCE(p.price,0)
                ELSE (COALESCE(p.partial_quantity,0) * COALESCE(d.unit_price,0)) - COALESCE(p.price,0)
            END
        ) AS savings_value
    FROM base_sales bs
    JOIN public.invoice_items ii ON ii.invoice_id = bs.invoice_id
    JOIN public.posts p ON p.post_id = ii.post_id
    LEFT JOIN public.drugs d ON p.ndc = d.ndc_upc_hri
    WHERE ii.status = 'INCLUDED'
    GROUP BY bs.invoice_id
),

invoice_totals AS (
    SELECT
        bs.invoice_id,
        bs.sale_month,
        bs.buyer_id,
        bs.invoice_value,
        COALESCE(lis.units, 0) AS units,
        COALESCE(lis.savings_value, 0) AS savings_value
    FROM base_sales bs
    LEFT JOIN line_item_stats lis ON lis.invoice_id = bs.invoice_id
),

gmv_month AS (
    SELECT
        sale_month,
        SUM(invoice_value) AS gmv_usd,
        COUNT(invoice_id) AS transactions,
        SUM(units)::int AS units_bought
    FROM invoice_totals
    GROUP BY sale_month
),

active_buyers AS (
    SELECT
        sale_month,
        COUNT(DISTINCT buyer_id) AS active_buyers
    FROM invoice_totals
    GROUP BY sale_month
),

first_purchase AS (
    SELECT
        buyer_id,
        MIN(sale_month) AS first_month
    FROM invoice_totals
    GROUP BY buyer_id
),

new_buyers AS (
    SELECT
        first_month AS sale_month,
        COUNT(*) AS new_buyers
    FROM first_purchase
    GROUP BY first_month
),

gmv_new AS (
    SELECT
        it.sale_month,
        SUM(it.invoice_value) AS gmv_from_new
    FROM invoice_totals it
    JOIN first_purchase fp 
      ON fp.buyer_id = it.buyer_id 
      AND fp.first_month = it.sale_month
    GROUP BY it.sale_month
),

gmv_repeat AS (
    SELECT
        it.sale_month,
        SUM(it.invoice_value) AS gmv_from_repeat
    FROM invoice_totals it
    JOIN first_purchase fp 
      ON fp.buyer_id = it.buyer_id
      AND fp.first_month < it.sale_month
    GROUP BY it.sale_month
),

savings AS (
    SELECT
        sale_month,
        SUM(savings_value) AS total_savings_usd
    FROM invoice_totals
    GROUP BY sale_month
)

SELECT
    to_char(g.sale_month, 'Mon YYYY') AS "Month",
    ROUND(COALESCE(g.gmv_usd, 0), 2) AS "GMV ($)",
    COALESCE(g.transactions, 0) AS "Total Transactions",
    COALESCE(g.units_bought, 0) AS "Units Bought",
    COALESCE(ab.active_buyers, 0) AS "Active Buyers",
    COALESCE(nb.new_buyers, 0) AS "New Buyers",
    (COALESCE(ab.active_buyers,0) - COALESCE(nb.new_buyers,0)) AS "Repeat Buyers",
    ROUND(COALESCE(gn.gmv_from_new, 0), 2) AS "GMV from New ($)",
    ROUND(COALESCE(gr.gmv_from_repeat, 0), 2) AS "GMV from Repeat ($)",
    CASE WHEN COALESCE(g.transactions,0) > 0
         THEN ROUND(g.gmv_usd / g.transactions, 2)
         ELSE 0 END AS "Avg Order Value ($)",
    ROUND(COALESCE(s.total_savings_usd, 0), 2) AS "Total Savings ($)"
FROM gmv_month g
LEFT JOIN active_buyers ab ON ab.sale_month = g.sale_month
LEFT JOIN new_buyers nb ON nb.sale_month = g.sale_month
LEFT JOIN gmv_new gn ON gn.sale_month = g.sale_month
LEFT JOIN gmv_repeat gr ON gr.sale_month = g.sale_month
LEFT JOIN savings s ON s.sale_month = g.sale_month
ORDER BY g.sale_month;