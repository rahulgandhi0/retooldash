WITH valid_posts AS (
  SELECT 
    p.post_id,
    p.seller_id,
    p.created_at
  FROM public.posts p
  WHERE p.status IN ('ACTIVE', 'SOLDOUT', 'RESERVED', 'DEACTIVATED', 'EXPIRED')
    AND p.created_at BETWEEN {{ date_selection_state_summary.value.start }} AND {{ date_selection_state_summary.value.end }}
),
completed_sales AS (
  SELECT 
    ii.post_id,
    s.seller_id,
    s.seller_signed_on,
    s.subtotal
  FROM public.invoice_items ii
  JOIN public.sales s ON ii.invoice_id = s.invoice_id
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status = 'INCLUDED'
),
merged AS (
  SELECT 
    vp.post_id,
    vp.seller_id,
    cs.subtotal,
    cs.seller_signed_on,
    seller_store.address_id,
    seller_addr.state AS seller_state
  FROM valid_posts vp
  JOIN completed_sales cs ON vp.post_id = cs.post_id
  JOIN public.stores seller_store ON vp.seller_id = seller_store.store_id
  JOIN public.addresses seller_addr ON seller_store.address_id = seller_addr.address_id
)
SELECT
  seller_state AS "Seller State",
  COUNT(*) AS "Total Sales",
  COUNT(DISTINCT seller_id) AS "Unique Seller Stores",
  ROUND(SUM(subtotal), 2) AS "Total Sales Revenue"
FROM merged
GROUP BY seller_state
ORDER BY "Total Sales" DESC;
