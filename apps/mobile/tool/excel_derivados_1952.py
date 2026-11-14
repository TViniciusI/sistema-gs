#!/usr/bin/env python3
import win32com.client
from pathlib import Path

XLS = Path(
    r"c:\Users\vinic\Downloads\GS- TABELA DE CONVERSÃO DOS DERIVADOS DE PETROLEO REV.01.xls"
)
xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
wb = xl.Workbooks.Open(str(XLS))
sh = wb.Sheets("1952")


def run(d, t, vol, tct, danfe=None):
    sh.Range("D6").Value = d
    sh.Range("D7").Value = t
    sh.Range("D11").Value = vol
    sh.Range("D12").Value = tct
    if danfe is not None:
        sh.Range("D19").Value = danfe
    xl.CalculateFull()
    return {
        "d20": sh.Range("D9").Value,
        "ctl": sh.Range("D14").Value,
        "vol20": sh.Range("D16").Value,
        "weight": sh.Range("D17").Value,
        "var": sh.Range("D21").Value,
    }


print("723/25", run(723, 25, 10000, 25, 9940))
print("S10", run(824.20, 32.18, 55548, 36.12, 54803.66))

# validacao case from test - 872.84 @ 36.12, base vol 55548, system 49880
print("valid base", run(872.84, 36.12, 55548, 36.12))
# system volume is separate in validacao sheet

wb.Close(False)
xl.Quit()
