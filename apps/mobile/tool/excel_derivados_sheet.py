#!/usr/bin/env python3
"""Read GS derivados Excel formulas and compare cases."""
import win32com.client
from pathlib import Path

XLS = Path(
    r"c:\Users\vinic\Downloads\GS- TABELA DE CONVERSÃO DOS DERIVADOS DE PETROLEO REV.01.xls"
)

xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
wb = xl.Workbooks.Open(str(XLS))

for i in range(1, wb.Sheets.Count + 1):
    print(i, wb.Sheets(i).Name)

# Sheet 2004 - conversion UI
sh = wb.Sheets("2004")
print("=== 2004 key cells ===")
for label, addr in [
    ("damb", "C6"),
    ("temp", "C7"),
    ("d20", "C10"),
    ("vol", "C12"),
    ("tct", "C13"),
    ("ctl", "C15"),
    ("vol20", "C17"),
    ("danfe", "C20"),
    ("var", "C22"),
]:
    c = sh.Range(addr)
    print(label, addr, "val=", c.Value, "formula=", c.Formula if c.HasFormula else "")

# Run test cases
def run(d, t, vol, tct, danfe):
    sh.Range("C6").Value = d
    sh.Range("C7").Value = t
    sh.Range("C12").Value = vol
    sh.Range("C13").Value = tct
    if danfe is not None:
        sh.Range("C20").Value = danfe
    xl.CalculateFull()
    return {
        "d20": sh.Range("C10").Value,
        "ctl": sh.Range("C15").Value,
        "vol20": sh.Range("C17").Value,
        "var": sh.Range("C22").Value,
    }

print("723/25", run(723, 25, 10000, 25, 9940))
print("S10", run(824.20, 32.18, 55548, 36.12, 54803.66))

wb.Close(False)
xl.Quit()
