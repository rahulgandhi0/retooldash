WITH buyer_invoices AS (
  SELECT
    s.buyer_id,
    st.doing_business_as,
    a.state,
    ii.post_id,
    p.price AS post_price,
    p.partial_quantity,
    d.package_price,
    d.unit_price,
    COALESCE(s.seller_signed_on, s.created_at) AS purchase_date
  FROM public.invoice_items ii
  JOIN public.sales s ON ii.invoice_id = s.invoice_id
  JOIN public.posts p ON ii.post_id = p.post_id
  JOIN public.drugs d ON p.ndc = d.ndc_upc_hri
  JOIN public.stores st ON s.buyer_id = st.store_id
  LEFT JOIN public.addresses a ON st.address_id = a.address_id
  WHERE s.dwolla_invoice_status IN ('COMPLETED', 'PENDING')
    AND ii.status = 'INCLUDED'
    AND p.price IS NOT NULL
    AND COALESCE(s.seller_signed_on, s.created_at) BETWEEN {{ date_selection_buyer_stores.value.start }} AND {{ date_selection_buyer_stores.value.end }}
),
buyer_summary AS (
  SELECT
    buyer_id,
    doing_business_as,
    state,
    COUNT(*) AS posts_bought,
    SUM(CASE
      WHEN partial_quantity IS NOT NULL AND partial_quantity > 0 THEN (unit_price * partial_quantity - post_price)
      ELSE (package_price - post_price)
    END) AS total_savings,
    AVG(CASE
      WHEN partial_quantity IS NOT NULL AND partial_quantity > 0 THEN (unit_price * partial_quantity - post_price)
      ELSE (package_price - post_price)
    END) AS avg_saving_per_post,
    MIN(purchase_date) AS first_purchase,
    MAX(purchase_date) AS last_purchase,
    EXTRACT(EPOCH FROM (MAX(purchase_date) - MIN(purchase_date))) / (60 * 60 * 24 * 30.44) AS active_months
  FROM buyer_invoices
  GROUP BY buyer_id, doing_business_as, state
)
SELECT
  buyer_id AS "Buyer ID",
  doing_business_as AS "Store Name",
  state AS "State",
  posts_bought AS "Posts Bought",
  ROUND(avg_saving_per_post, 2) AS "Avg Savings Per Post",
  ROUND(total_savings, 2) AS "Total Savings",
  first_purchase AS "First Purchase",
  last_purchase AS "Last Purchase",
  ROUND(CASE
    WHEN active_months IS NULL OR active_months = 0 THEN NULL
    ELSE total_savings / active_months
  END, 2) AS "Avg Monthly Savings"
FROM buyer_summary
WHERE posts_bought >= {{ min_sales_threshold.value }}
ORDER BY total_savings DESC;
