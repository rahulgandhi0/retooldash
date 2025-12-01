WITH RECURSIVE months AS (
    SELECT date_trunc(
        'month',
        {{ exportable_daterange4.value.start }}::timestamp
    )::date AS month_start

    UNION ALL

    SELECT (month_start + INTERVAL '1 month')::date
    FROM months
    WHERE month_start + INTERVAL '1 month'
          <= date_trunc(
                'month',
                {{ exportable_daterange4.value.end }}::timestamp
             )
)
SELECT
    month_start AS sale_month,
    to_char(month_start, 'Mon YYYY') AS pretty
FROM months
ORDER BY month_start;
