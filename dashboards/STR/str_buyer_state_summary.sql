
WITH valid_posts AS (
  SELECT 
    p.post_id,
    p.created_at
  FROM public.posts p
  WHERE p.status IN ('ACTIVE', 'SOLDOUT', 'RESERVED', 'DEACTIVATED', 'EXPIRED')
    AND p.created_at BETWEEN {{ date_selection_state_summary.value.start }} AND {{ date_selection_state_summary.value.end }}
),
completed_sales AS (
  SELECT 
    ii.post_id,
    s.buyer_id,
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
    cs.subtotal,
    cs.seller_signed_on,
    cs.buyer_id,
    bs.state AS buyer_state
  FROM valid_posts vp
  JOIN completed_sales cs ON vp.post_id = cs.post_id
  JOIN public.stores bstore ON cs.buyer_id = bstore.store_id
  JOIN public.addresses bs ON bstore.address_id = bs.address_id
)
SELECT
  buyer_state AS "Buyer State",
  COUNT(*) AS "Total Purchases",
  COUNT(DISTINCT buyer_id) AS "Unique Buyer Stores",
  ROUND(SUM(subtotal), 2) AS "Total Purchase Revenue"
FROM merged
GROUP BY buyer_state
ORDER BY "Total Purchases" DESC;
