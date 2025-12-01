WITH qualifying_posts AS (
  SELECT
    p.post_id,
    p.ndc,
    p.seller_id,
    seller_store.address_id,
    seller_addr.state AS seller_state,
    d.rxpost_drug_group AS drug_category
  FROM public.posts p
  JOIN public.stores seller_store ON p.seller_id = seller_store.store_id
  JOIN public.addresses seller_addr ON seller_store.address_id = seller_addr.address_id
  JOIN public.drugs d ON p.ndc = d.ndc_upc_hri
  WHERE p.status IN ('ACTIVE', 'SOLDOUT', 'RESERVED', 'DEACTIVATED', 'EXPIRED')
    AND p.created_at BETWEEN {{ date_selection_benchmark_markets.value.start }} AND {{ date_selection_benchmark_markets.value.end }}
),
sold_posts AS (
  SELECT
    ii.post_id,
    s.buyer_id,
    s.seller_id
  FROM public.invoice_items ii
  JOIN public.sales s ON ii.invoice_id = s.invoice_id
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status = 'INCLUDED'
),
buyers_with_state AS (
  SELECT
    st.store_id AS buyer_id,
    a.state AS buyer_state
  FROM public.stores st
  JOIN public.addresses a ON st.address_id = a.address_id
),
joined AS (
  SELECT
    qp.seller_state,
    qp.drug_category,
    qp.ndc,
    COUNT(*) AS total_posts,
    COUNT(DISTINCT sp.post_id) AS total_sold,
    COUNT(DISTINCT qp.seller_id) AS seller_stores,
    COUNT(DISTINCT CASE WHEN bws.buyer_state = qp.seller_state THEN sp.buyer_id END) AS buyer_stores
  FROM qualifying_posts qp
  LEFT JOIN sold_posts sp ON qp.post_id = sp.post_id
  LEFT JOIN buyers_with_state bws ON sp.buyer_id = bws.buyer_id
  GROUP BY qp.seller_state, qp.drug_category, qp.ndc
)
SELECT
  seller_state AS "State",
  drug_category AS "Drug Category",
  ndc AS "NDC",
  total_posts AS "Total Posts",
  total_sold AS "Total Sold",
  ROUND((total_sold::numeric / total_posts) * 100, 2) AS "STR (%)",
  seller_stores AS "Seller Stores",
  buyer_stores AS "Buyer Stores (Same State)",
  ROUND(seller_stores::numeric / NULLIF(buyer_stores, 0), 2) AS "Seller:Buyer Ratio"
FROM joined
WHERE total_posts >= 100 AND (total_sold::numeric / total_posts) >= 0.5
ORDER BY "STR (%)" DESC, "Total Posts" DESC;
