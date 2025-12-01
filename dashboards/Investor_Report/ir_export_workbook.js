async function loadXLSX() {
  return new Promise(resolve => {
    if (window.XLSX) return resolve();
    const script = document.createElement("script");
    script.src = "https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js";
    script.onload = resolve;
    document.head.appendChild(script);
  });
}

await loadXLSX();

const wb = window.XLSX.utils.book_new();

function addSheet(name, queryData) {
  const data = queryData || [];
  const rows = Array.isArray(data) ? data : formatDataAsArray(data);

  const ws = window.XLSX.utils.json_to_sheet(rows);

  if (rows.length > 0) {
    const range = window.XLSX.utils.decode_range(ws['!ref']);
    const colWidths = [];

    for (let C = range.s.c; C <= range.e.c; ++C) {
      let maxLen = 0;

      for (let R = range.s.r; R <= range.e.r; ++R) {
        const cellAddress = window.XLSX.utils.encode_cell({ c: C, r: R });
        const cell = ws[cellAddress];

        if (!cell) continue;

        if (cell.t === 'n') {
          if (Number.isInteger(cell.v)) {
            cell.z = '#,##0';
          } else {
            cell.z = '#,##0.00';
          }
        }

        if (!cell.s) cell.s = {};
        cell.s.alignment = { horizontal: "left" };

        let cellTextLength = 0;

        if (cell.t === 'n') {
          const val = cell.v || 0;
          const intStr = Math.floor(Math.abs(val)).toString();
          const commas = Math.floor((intStr.length - 1) / 3);
          cellTextLength = intStr.length + commas + 1;
          if (!Number.isInteger(val)) {
            cellTextLength += 3;
          }
        } else {
          cellTextLength = (cell.v || "").toString().length;
        }

        if (cellTextLength > maxLen) {
          maxLen = cellTextLength;
        }
      }

      colWidths[C] = { wch: maxLen + 0.5 };
    }
    ws['!cols'] = colWidths;
  }

  window.XLSX.utils.book_append_sheet(wb, ws, name);
}

addSheet("RxPost Rev by Buyer", buyer_revenue_transformer.value);
addSheet("RxPost Rev by Seller", seller_revenue_transformer.value);
addSheet("Buyer Spend", buyer_spend_transformer.value);
addSheet("Seller Earnings", seller_earnings_transformer.value);
addSheet("Buyer Transactions", buyer_txn_transformer.value);
addSheet("Seller Transactions", seller_txn_transformer.value);

const formatDateForFilename = (dateString) => {
  if (!dateString) return "NA";
  const date = new Date(dateString);
  const month = date.toLocaleString('default', { month: 'short' });
  const year = date.getFullYear().toString().slice(-2);
  return `${month}${year}`;
};

const startStr = formatDateForFilename(exportable_daterange4.value.start);
const endStr = formatDateForFilename(exportable_daterange4.value.end);

const filename = `Investor_Report_Monthly_${startStr}_${endStr}.xlsx`;

const wbout = window.XLSX.write(wb, { bookType: "xlsx", type: "array" });

return { 
  blob: new Blob([wbout], { type: "application/octet-stream" }),
  filename
};