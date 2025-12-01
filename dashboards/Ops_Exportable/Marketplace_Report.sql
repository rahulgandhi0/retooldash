WITH bounds AS (
  SELECT
    date_trunc('month', {{ date_selection_marketplace_report.value.start }}::date) AS start_month,
    date_trunc('month', {{ date_selection_marketplace_report.value.end }}::date)   AS end_month
),

months AS (
  SELECT generate_series(
    (SELECT start_month FROM bounds),
    (SELECT end_month   FROM bounds),
    interval '1 month'
  )::date AS month_start
),

invoice_counts AS (
  SELECT
    date_trunc('month', seller_signed_on)::date AS month_start,
    COUNT(*) AS invoice_count
  FROM public.sales
  WHERE dwolla_invoice_status IN ('COMPLETED', 'PENDING')
  GROUP BY 1
),

days_to_sale AS (
  SELECT
    date_trunc('month', s.seller_signed_on)::date AS month_start,
    ROUND(
      AVG(EXTRACT(DAY FROM (s.seller_signed_on - p.created_at))),
      2
    ) AS avg_days_to_sale
  FROM public.posts p
  JOIN public.invoice_items ii ON ii.post_id = p.post_id
  JOIN public.sales s ON s.invoice_id = ii.invoice_id
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status = 'INCLUDED'
  GROUP BY 1
),

new_posts AS (
  SELECT
    date_trunc('month', created_at)::date AS month_start,
    COUNT(*) AS new_posts
  FROM public.posts
  WHERE date_trunc('month', created_at) BETWEEN
        (SELECT start_month FROM bounds) AND (SELECT end_month FROM bounds)
  GROUP BY 1
),

items_sold AS (
  SELECT
    date_trunc('month', s.seller_signed_on)::date AS month_start,
    COUNT(DISTINCT ii.invoice_item_id) AS items_sold
  FROM public.sales s
  JOIN public.invoice_items ii ON ii.invoice_id = s.invoice_id
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status = 'INCLUDED'
  GROUP BY 1
)

SELECT
  to_char(m.month_start, 'YYYY-MM') AS "Month",
  COALESCE(p.new_posts, 0)         AS "New Posts",
  COALESCE(s.items_sold, 0)        AS "Items Sold",
  COALESCE(d.avg_days_to_sale, 0)  AS "Avg Days to Sale",
  COALESCE(ic.invoice_count, 0)    AS "Invoice Count"
FROM months m
LEFT JOIN new_posts p      ON p.month_start = m.month_start
LEFT JOIN items_sold s     ON s.month_start = m.month_start
LEFT JOIN days_to_sale d   ON d.month_start = m.month_start
LEFT JOIN invoice_counts ic ON ic.month_start = m.month_start
ORDER BY m.month_start;
