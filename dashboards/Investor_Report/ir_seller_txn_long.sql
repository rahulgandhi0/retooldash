SELECT
  seller_id AS store_id,
  date_trunc('month', seller_signed_on)::date AS sale_month,
  COUNT(*)::numeric(18,2) AS value
FROM public.sales
WHERE seller_signed_on BETWEEN 
    {{ exportable_daterange4.value.start }} 
    AND 
    {{ exportable_daterange4.value.end }}
  AND dwolla_invoice_status IN ('COMPLETED', 'PENDING')
  AND invoice_id IN (
    SELECT invoice_id 
    FROM public.invoice_items 
    WHERE status IN ('INCLUDED')
  )
GROUP BY 1, 2
ORDER BY 1, 2;