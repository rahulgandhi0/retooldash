WITH valid_posts AS (
  SELECT 
    p.post_id,
    p.seller_id,
    p.ndc,
    p.created_at AS post_created_at,
    d.rxpost_drug_group,
    st.doing_business_as,
    a.state AS seller_state
  FROM public.posts p
  JOIN public.drugs d ON p.ndc = d.ndc_upc_hri
  JOIN public.stores st ON p.seller_id = st.store_id
  JOIN public.addresses a ON st.address_id = a.address_id
  WHERE p.status IN ('ACTIVE', 'SOLDOUT', 'RESERVED', 'DEACTIVATED', 'EXPIRED')
    AND p.created_at BETWEEN {{ date_selection_seller_stores.value.start }} AND {{ date_selection_seller_stores.value.end }}
),
completed_sales AS (
  SELECT 
    ii.post_id,
    s.seller_signed_on,
    s.subtotal,
    s.buyer_id
  FROM public.invoice_items ii
  JOIN public.sales s ON ii.invoice_id = s.invoice_id
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status = 'INCLUDED'
),
merged AS (
  SELECT 
    vp.seller_id,
    vp.doing_business_as,
    vp.seller_state,
    vp.post_id,
    vp.post_created_at,
    cs.seller_signed_on,
    cs.subtotal,
    EXTRACT(DAY FROM cs.seller_signed_on - vp.post_created_at) AS days_to_sale
  FROM valid_posts vp
  LEFT JOIN completed_sales cs ON vp.post_id = cs.post_id
),
seller_agg AS (
  SELECT 
    seller_id,
    doing_business_as,
    seller_state AS state,
    COUNT(*) AS total_posts,
    COUNT(seller_signed_on) AS posts_sold,
    ROUND(100.0 * COUNT(seller_signed_on)::numeric / NULLIF(COUNT(*)::numeric, 0), 2) AS raw_str,
    ROUND(AVG(days_to_sale), 2) AS avg_days_to_sale,
    ROUND(AVG(subtotal), 2) AS avg_revenue_per_sale,
    ROUND(SUM(COALESCE(subtotal, 0)), 2) AS total_revenue,
    MIN(post_created_at) AS first_post_date,
    MAX(post_created_at) AS last_post_date
  FROM merged
  GROUP BY seller_id, doing_business_as, seller_state
  HAVING COUNT(seller_signed_on) >= {{ min_sales_threshold.value }}
)
SELECT
  seller_id AS "Seller ID",
  doing_business_as AS "Store Name",
  state AS "State",
  total_posts AS "Posts Made",
  posts_sold AS "Posts Sold",
  raw_str AS "STR (%)",
  avg_days_to_sale AS "Avg Days to Sale",
  avg_revenue_per_sale AS "Avg Revenue Per Sale",
  total_revenue AS "Total Revenue",
  ROUND(
    total_revenue / NULLIF(
      EXTRACT(EPOCH FROM (last_post_date - first_post_date)) / (60 * 60 * 24 * 30.44),
      0
    ),
    2
  ) AS "Avg Monthly Revenue",
  first_post_date AS "First Post Date",
  last_post_date AS "Last Post Date"
FROM seller_agg
ORDER BY raw_str DESC, posts_sold DESC;
