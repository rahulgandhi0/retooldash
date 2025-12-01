const monthsCol = {{ ir_generate_months.data }};
const months = monthsCol.sale_month.map((_, i) => ({
  sale_month: monthsCol.sale_month[i],
  pretty: monthsCol.pretty[i]
}));

const rowsCol = {{ ir_buyer_spend_long.data }};
const rows = rowsCol.store_id.map((_, i) => ({
  store_id: rowsCol.store_id[i], 
  sale_month: rowsCol.sale_month[i].toString().substring(0, 10),
  value: rowsCol.value[i]
}));

const monthMap = {};
months.forEach(m => {
  monthMap[m.sale_month] = m.pretty;
});

const pivot = {};

rows.forEach(r => {
  if (!pivot[r.store_id]) {
    pivot[r.store_id] = { "Store ID": r.store_id };
    months.forEach(m => {
      pivot[r.store_id][m.pretty] = 0;
    });
  }
  
  const label = monthMap[r.sale_month];
  if (label) {
      pivot[r.store_id][label] += Number(r.value || 0);
  }
});

Object.values(pivot).forEach(row => {
  row.Total = months.reduce(
    (sum, m) => sum + Number(row[m.pretty] || 0),
    0
  );
});

return Object.values(pivot);