#!/usr/bin/env python3
import win32com.client
from pathlib import Path

XLS = Path(
    r"c:\Users\vinic\Downloads\GS- TABELA DE CONVERSÃO DOS DERIVADOS DE PETROLEO REV.01.xls"
)
xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
wb = xl.Workbooks.Open(str(XLS))

for name in ["1952", "DERIVADO DE PETRÓLEO", "DERIVADO DE PETROLEO"]:
    try:
        sh = wb.Sheets(name)
        print(f"=== {name} ({sh.UsedRange.Rows.Count}x{sh.UsedRange.Columns.Count}) ===")
        for r in range(1, min(25, sh.UsedRange.Rows.Count + 1)):
            row = []
            for c in range(1, min(8, sh.UsedRange.Columns.Count + 1)):
                cell = sh.Cells(r, c)
                v = cell.Value
                if v is not None and str(v).strip():
                    f = cell.Formula if cell.HasFormula else ""
                    row.append(f"{v}|{f[:40] if f else ''}")
            if row:
                print(r, row)
    except Exception as e:
        print(name, e)

wb.Close(False)
xl.Quit()
