WITH params AS (
  SELECT 
    CURRENT_DATE - ({{ churn_window_input.value }} - 1) * INTERVAL '1 day' AS current_start,
    CURRENT_DATE - (2 * {{ churn_window_input.value }} - 1) * INTERVAL '1 day' AS past_start
),
seller_stats AS (
  SELECT 
    seller_id,
    MAX(CASE WHEN seller_signed_on >= (SELECT past_start FROM params) AND seller_signed_on < (SELECT current_start FROM params) THEN 1 ELSE 0 END) as had_past_sale,
    COUNT(DISTINCT CASE WHEN seller_signed_on >= (SELECT current_start FROM params) THEN invoice_id END) as window_sales
  FROM public.sales
  WHERE dwolla_invoice_status = 'COMPLETED' 
    AND seller_signed_on >= (SELECT past_start FROM params)
  GROUP BY seller_id
),
buyer_stats AS (
  SELECT 
    buyer_id,
    MAX(CASE WHEN seller_signed_on >= (SELECT past_start FROM params) AND seller_signed_on < (SELECT current_start FROM params) THEN 1 ELSE 0 END) as had_past_purchase,
    COUNT(DISTINCT CASE WHEN seller_signed_on >= (SELECT current_start FROM params) THEN invoice_id END) as window_purchases
  FROM public.sales
  WHERE dwolla_invoice_status = 'COMPLETED'
    AND seller_signed_on >= (SELECT past_start FROM params)
  GROUP BY buyer_id
),
poster_stats AS (
  SELECT 
    seller_id,
    MAX(CASE WHEN created_at >= (SELECT past_start FROM params) AND created_at < (SELECT current_start FROM params) THEN 1 ELSE 0 END) as had_past_post,
    COUNT(DISTINCT CASE WHEN created_at >= (SELECT current_start FROM params) THEN post_id END) as window_posts
  FROM public.posts
  WHERE created_at >= (SELECT past_start FROM params)
  GROUP BY seller_id
)
SELECT
    ROUND(100.0 * COUNT(CASE WHEN COALESCE(s_stats.had_past_sale, 0) = 1 
                             AND COALESCE(p_stats.window_posts, 0) = 0 
                             AND COALESCE(s_stats.window_sales, 0) = 0 THEN 1 END) / 
        NULLIF(COUNT(CASE WHEN COALESCE(s_stats.had_past_sale, 0) = 1 THEN 1 END), 0)
    , 2) AS "Seller Churn (%)",

    ROUND(100.0 * COUNT(CASE WHEN COALESCE(b_stats.had_past_purchase, 0) = 1 
                             AND COALESCE(b_stats.window_purchases, 0) = 0 THEN 1 END) / 
        NULLIF(COUNT(CASE WHEN COALESCE(b_stats.had_past_purchase, 0) = 1 THEN 1 END), 0)
    , 2) AS "Buyer Churn (%)",

    ROUND(100.0 * COUNT(CASE WHEN (COALESCE(b_stats.had_past_purchase, 0) = 1 OR COALESCE(s_stats.had_past_sale, 0) = 1 OR COALESCE(p_stats.had_past_post, 0) = 1)
                             AND (COALESCE(b_stats.window_purchases, 0) + COALESCE(s_stats.window_sales, 0) + COALESCE(p_stats.window_posts, 0)) = 0 THEN 1 END) / 
        NULLIF(COUNT(CASE WHEN (COALESCE(b_stats.had_past_purchase, 0) = 1 OR COALESCE(s_stats.had_past_sale, 0) = 1 OR COALESCE(p_stats.had_past_post, 0) = 1) THEN 1 END), 0)
    , 2) AS "Overall Churn (%)",

    ROUND(100.0 * COUNT(CASE WHEN (COALESCE(b_stats.had_past_purchase, 0) = 1 OR COALESCE(s_stats.had_past_sale, 0) = 1 OR COALESCE(p_stats.had_past_post, 0) = 1)
                             AND (COALESCE(b_stats.window_purchases, 0) + COALESCE(s_stats.window_sales, 0)) = 1 THEN 1 END) / 
        NULLIF(COUNT(CASE WHEN (COALESCE(b_stats.had_past_purchase, 0) = 1 OR COALESCE(s_stats.had_past_sale, 0) = 1 OR COALESCE(p_stats.had_past_post, 0) = 1) THEN 1 END), 0)
    , 2) AS "One-timer (%)",

    ROUND(100.0 * COUNT(CASE WHEN COALESCE(b_stats.had_past_purchase, 0) = 1 
                             AND COALESCE(b_stats.window_purchases, 0) = 1 THEN 1 END) / 
        NULLIF(COUNT(CASE WHEN COALESCE(b_stats.had_past_purchase, 0) = 1 THEN 1 END), 0)
    , 2) AS "One-time Buyer (%)",

    ROUND(100.0 * COUNT(CASE WHEN (COALESCE(s_stats.had_past_sale, 0) = 1 OR COALESCE(p_stats.had_past_post, 0) = 1) 
                             AND COALESCE(s_stats.window_sales, 0) = 1 THEN 1 END) / 
        NULLIF(COUNT(CASE WHEN (COALESCE(s_stats.had_past_sale, 0) = 1 OR COALESCE(p_stats.had_past_post, 0) = 1) THEN 1 END), 0)
    , 2) AS "One-time Seller (%)"

FROM public.stores s
LEFT JOIN seller_stats s_stats ON s.store_id = s_stats.seller_id
LEFT JOIN buyer_stats b_stats ON s.store_id = b_stats.buyer_id
LEFT JOIN poster_stats p_stats ON s.store_id = p_stats.seller_id;