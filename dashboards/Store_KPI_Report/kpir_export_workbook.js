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

const COLUMN_FORMATS = {
  "GMV ($)": "#,##0.00",
  "GMV from New ($)": "#,##0.00",
  "GMV from Repeat ($)": "#,##0.00",
  "Avg Order Value ($)": "#,##0.00",
  "Net Revenue ($)": "#,##0.00",
  "Total Savings ($)": "#,##0.00",
  "Total Transactions": "#,##0",
  "Units Sold": "#,##0",
  "Units Bought": "#,##0",
  "Active Sellers": "#,##0",
  "Active Buyers": "#,##0",
  "New Sellers": "#,##0",
  "New Buyers": "#,##0",
  "Repeat Sellers": "#,##0",
  "Repeat Buyers": "#,##0"
};

function addSheet(name, queryData) {
  const data = queryData || [];
  const rows = Array.isArray(data) ? data : formatDataAsArray(data);

  const ws = window.XLSX.utils.json_to_sheet(rows);

  if (rows.length > 0) {
    const range = window.XLSX.utils.decode_range(ws['!ref']);
    const colWidths = [];

    for (let C = range.s.c; C <= range.e.c; ++C) {
      const headerAddress = window.XLSX.utils.encode_cell({ c: C, r: 0 });
      const headerCell = ws[headerAddress];
      const colName = headerCell ? (headerCell.v || "").toString().trim() : "";

      const explicitFormat = COLUMN_FORMATS[colName];

      let maxLen = 0;

      for (let R = range.s.r; R <= range.e.r; ++R) {
        const cellAddress = window.XLSX.utils.encode_cell({ c: C, r: R });
        const cell = ws[cellAddress];

        if (!cell) continue;

        if (cell.t === 's' && explicitFormat && !isNaN(Number(cell.v)) && cell.v.toString().trim() !== '') {
          cell.v = Number(cell.v);
          cell.t = 'n';
        }

        if (cell.t === 'n' && explicitFormat) {
          cell.z = explicitFormat;
        }

        if (!cell.s) cell.s = {};
        cell.s.alignment = { horizontal: "left" };

        let cellTextLength = 0;
        if (cell.t === 'n') {
          const val = cell.v || 0;
          const intStr = Math.floor(Math.abs(val)).toString();
          const commas = Math.floor((intStr.length - 1) / 3);
          
          cellTextLength = intStr.length + commas + 1;

          const hasDecimals = explicitFormat ? explicitFormat.includes(".00") : false;
          if (hasDecimals) {
            cellTextLength += 3;
          }
        } else {
          cellTextLength = (cell.v || "").toString().length;
        }

        if (cellTextLength > maxLen) {
          maxLen = cellTextLength;
        }
      }

      colWidths[C] = { wch: maxLen + 2 };
    }
    ws['!cols'] = colWidths;
  }

  window.XLSX.utils.book_append_sheet(wb, ws, name);
}

addSheet("Buyers KPI", kpir_buyers_kpi_long.data);
addSheet("Sellers KPI", kpir_sellers_kpi_long.data);

const formatDateForFilename = (dateString) => {
  if (!dateString) return "NA";
  const date = new Date(dateString);
  const month = date.toLocaleString("default", { month: "short" });
  const year = date.getFullYear().toString().slice(-2);
  return `${month}${year}`;
};

const startStr = formatDateForFilename(exportable_daterange5.value.start);
const endStr = formatDateForFilename(exportable_daterange5.value.end);

const filename = `Stores_KPI_Monthly_${startStr}_${endStr}.xlsx`;

const wbout = window.XLSX.write(wb, { bookType: "xlsx", type: "array" });

return {
  blob: new Blob([wbout], { type: "application/octet-stream" }),
  filename,
};