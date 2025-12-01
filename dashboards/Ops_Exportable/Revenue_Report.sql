WITH months AS (
  SELECT date_trunc('month', dd)::date AS month_start
  FROM generate_series(
    date_trunc('month', {{ date_selection_revenue_report.value.start }}::date),
    date_trunc('month', {{ date_selection_revenue_report.value.end }}::date),
    interval '1 month'
  ) dd
),

invoice_base AS (
  SELECT
    s.invoice_id,
    s.seller_id,
    s.rxpost_fee_percent,
    date_trunc('month', s.seller_signed_on)::date AS month_start,
    s.subtotal AS invoice_total
  FROM public.sales s
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
  GROUP BY 1,2,3,4,5
),

gmv AS (
  SELECT month_start, SUM(invoice_total) AS gmv
  FROM invoice_base
  GROUP BY 1
),

revenue AS (
  SELECT month_start,
         SUM(invoice_total * rxpost_fee_percent / 100.0) AS net_revenue
  FROM invoice_base
  GROUP BY 1
),

weighted_take_rate AS (
  SELECT
    r.month_start,
    CASE WHEN g.gmv = 0 THEN 0
         ELSE ROUND((r.net_revenue / g.gmv) * 100, 2)
    END AS weighted_take_rate
  FROM revenue r
  JOIN gmv g ON g.month_start = r.month_start
),

seller_first_sales AS (
  SELECT
    seller_id,
    MIN(date_trunc('month', seller_signed_on)::date) AS first_sale_month
  FROM public.sales
  WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
  GROUP BY 1
),

new_seller_revenue AS (
  SELECT
    b.month_start,
    SUM(b.invoice_total * b.rxpost_fee_percent / 100.0) AS new_seller_revenue
  FROM invoice_base b
  JOIN seller_first_sales fs ON fs.seller_id = b.seller_id
  WHERE fs.first_sale_month = b.month_start
  GROUP BY 1
),

old_seller_revenue AS (
  SELECT
    b.month_start,
    SUM(b.invoice_total * b.rxpost_fee_percent / 100.0) AS old_seller_revenue
  FROM invoice_base b
  JOIN seller_first_sales fs ON fs.seller_id = b.seller_id
  WHERE fs.first_sale_month < b.month_start
  GROUP BY 1
),

seller_gmv AS (
  SELECT
    b.seller_id,
    b.month_start,
    SUM(b.invoice_total) AS gmv
  FROM invoice_base b
  GROUP BY 1, 2
),

gmv_retention AS (
  SELECT
    curr.month_start,
    ROUND(
      CASE WHEN prev.total_prev_gmv = 0 THEN 0
           ELSE (curr.total_curr_gmv / prev.total_prev_gmv) * 100
      END,
      2
    ) AS gmv_retention_pct
  FROM (
    SELECT
      sg2.month_start,
      SUM(sg2.gmv) AS total_curr_gmv
    FROM seller_gmv sg2
    JOIN seller_gmv sg1
      ON sg1.seller_id = sg2.seller_id
     AND sg1.month_start = (sg2.month_start - interval '1 month')
    GROUP BY 1
  ) curr
  JOIN (
    SELECT
      sg1.month_start + interval '1 month' AS month_start,
      SUM(sg1.gmv) AS total_prev_gmv
    FROM seller_gmv sg1
    GROUP BY 1
  ) prev
    ON prev.month_start = curr.month_start
),

avg_order_value AS (
  SELECT
    b.month_start,
    ROUND(SUM(b.invoice_total) / COUNT(DISTINCT b.invoice_id), 2) AS avg_order_value
  FROM invoice_base b
  GROUP BY 1
),

invoice_counts AS (
  SELECT
    date_trunc('month', seller_signed_on)::date AS month_start,
    COUNT(*) AS total_invoices
  FROM public.sales
  WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
  GROUP BY 1
)

SELECT
  to_char(m.month_start, 'YYYY-MM') AS "Month",
  TO_CHAR(COALESCE(g.gmv, 0)::numeric, 'FM999999999.00') AS "GMV ($)",
  TO_CHAR(COALESCE(r.net_revenue, 0)::numeric, 'FM999999999.00') AS "Net Revenue ($)",
  TO_CHAR(COALESCE(w.weighted_take_rate, 0)::numeric, 'FM999999999.00') AS "Weighted Take Rate (%)",
  TO_CHAR(COALESCE(n.new_seller_revenue, 0)::numeric, 'FM999999999.00') AS "Revenue from New Sellers ($)",
  TO_CHAR(COALESCE(o.old_seller_revenue, 0)::numeric, 'FM999999999.00') AS "Revenue from Existing Sellers ($)",
  TO_CHAR(COALESCE(gr.gmv_retention_pct, 0)::numeric, 'FM999999999.00') AS "GMV Retention (%)",
  TO_CHAR(COALESCE(a.avg_order_value, 0)::numeric, 'FM999999999.00') AS "Avg Order Value ($)",
  COALESCE(ic.total_invoices, 0) AS "Total Invoices"
FROM months m
LEFT JOIN gmv g ON g.month_start = m.month_start
LEFT JOIN revenue r ON r.month_start = m.month_start
LEFT JOIN weighted_take_rate w ON w.month_start = m.month_start
LEFT JOIN new_seller_revenue n ON n.month_start = m.month_start
LEFT JOIN old_seller_revenue o ON o.month_start = m.month_start
LEFT JOIN gmv_retention gr ON gr.month_start = m.month_start
LEFT JOIN avg_order_value a ON a.month_start = m.month_start
LEFT JOIN invoice_counts ic ON ic.month_start = m.month_start
ORDER BY m.month_start;
