SET TIME ZONE 'America/Los_Angeles';

SELECT 
    (SELECT COALESCE(SUM(subtotal), 0)
        FROM public.sales
        WHERE date_trunc('month', created_at) = date_trunc('month', CURRENT_DATE) AND dwolla_invoice_status IN ('PENDING', 'COMPLETED')
    ) as total_sales,

    ( SELECT COALESCE(SUM(subtotal), 0)
        FROM sales
        WHERE date_trunc('month', created_at) = date_trunc('month', CURRENT_DATE) AND dwolla_invoice_status = 'NOT_STARTED'
    ) as pending_sales,

    ( SELECT COALESCE(SUM(c.subtotal), 0)
        FROM carts c
    ) as pending_carts,
    
    ( SELECT COUNT(DISTINCT id)
        FROM auth.users
        WHERE last_sign_in_at IS NOT NULL
        AND email NOT ILIKE '%@rx-post.com'
        AND date_trunc('month', last_sign_in_at) = date_trunc('month', CURRENT_DATE)
    ) as active_users,
    
    ( SELECT COUNT(DISTINCT ii.invoice_item_id)
        FROM public.invoice_items ii
        JOIN public.invoices i ON ii.invoice_id = i.invoice_id
        WHERE date_trunc('month', ii.created_at) = date_trunc('month', CURRENT_DATE) AND i.dwolla_invoice_status = 'COMPLETED'
    )  as posts_sold,

    (SELECT COALESCE(SUM(subtotal), 0)
        FROM public.sales
        WHERE date_trunc('month', created_at) = date_trunc('month', CURRENT_DATE - INTERVAL '1 month') AND dwolla_invoice_status IN ('PENDING', 'COMPLETED')
    ) as prev_total_sales,
    
    ( SELECT COUNT(DISTINCT ii.invoice_item_id)
        FROM public.invoice_items ii
        JOIN public.invoices i ON ii.invoice_id = i.invoice_id
        WHERE date_trunc('month', ii.created_at) = date_trunc('month', CURRENT_DATE - INTERVAL '1 month') AND i.dwolla_invoice_status = 'COMPLETED'
    )  as prev_posts_sold;
