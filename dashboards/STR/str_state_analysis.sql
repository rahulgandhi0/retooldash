WITH valid_posts AS (
  SELECT 
    p.post_id,
    p.seller_id,
    p.ndc,
    p.created_at AS post_created_at,
    d.rxpost_drug_group,
    seller_addr.state AS seller_state
  FROM public.posts p
  JOIN public.drugs d ON p.ndc = d.ndc_upc_hri
  JOIN public.stores seller_store ON p.seller_id = seller_store.store_id
  JOIN public.addresses seller_addr ON seller_store.address_id = seller_addr.address_id
  WHERE p.status IN ('ACTIVE', 'SOLDOUT', 'RESERVED', 'DEACTIVATED', 'EXPIRED')
    AND p.created_at BETWEEN {{ date_selection_state_analysis.value.start }} AND {{ date_selection_state_analysis.value.end }}
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
buyer_states AS (
  SELECT
    st.store_id,
    a.state AS buyer_state
  FROM public.stores st
  JOIN public.addresses a ON st.address_id = a.address_id
),
merged AS (
  SELECT 
    vp.rxpost_drug_group,
    bs.buyer_state,
    vp.seller_state,
    vp.post_id,
    vp.post_created_at,
    cs.seller_signed_on,
    cs.subtotal,
    EXTRACT(DAY FROM cs.seller_signed_on - vp.post_created_at) AS days_to_sale
  FROM valid_posts vp
  LEFT JOIN completed_sales cs ON vp.post_id = cs.post_id
  LEFT JOIN buyer_states bs ON cs.buyer_id = bs.store_id
)
SELECT 
  rxpost_drug_group AS "Drug Category",
  buyer_state AS "Buyer State",
  seller_state AS "Seller State",
  COUNT(*) AS "Posts Made",
  COUNT(seller_signed_on) AS "Posts Sold",
  ROUND(100.0 * COUNT(seller_signed_on)::numeric / NULLIF(COUNT(*)::numeric, 0), 2) AS "STR (%)",
  ROUND(AVG(days_to_sale), 2) AS "Avg Days to Sale",
  ROUND(SUM(CASE WHEN seller_signed_on IS NOT NULL THEN subtotal ELSE 0 END), 2) AS "Total Revenue",
  ROUND(AVG(CASE WHEN seller_signed_on IS NOT NULL THEN subtotal ELSE NULL END), 2) AS "Avg Revenue Per Sale"
FROM merged
GROUP BY rxpost_drug_group, buyer_state, seller_state
HAVING COUNT(seller_signed_on) >= {{ min_sales_threshold.value }}
ORDER BY "STR (%)" DESC, "Posts Sold" DESC;
