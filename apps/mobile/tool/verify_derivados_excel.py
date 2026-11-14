#!/usr/bin/env python3
"""Compare derivados app logic vs GS Excel REV.01."""
import bisect
from pathlib import Path

import xlrd

XLS = Path(
    r"c:\Users\vinic\Downloads\GS- TABELA DE CONVERSÃO DOS DERIVADOS DE PETROLEO REV.01.xls"
)


def load_table(sheet_name):
    wb = xlrd.open_workbook(str(XLS))
    sheet = wb.sheet_by_name(sheet_name)
    rows = []
    for r in range(2, sheet.nrows):
        d = sheet.cell_value(r, 0)
        if d == "":
            continue
        p = [sheet.cell_value(r, c) for c in range(5, 9)]
        rows.append((float(d), [float(x) for x in p]))
    return rows


def vlookup(key, rows):
    keys = [r[0] for r in rows]
    if key < keys[0]:
        return rows[0][1]
    if key >= keys[-1]:
        return rows[-1][1]
    i = bisect.bisect_right(keys, key) - 1
    return rows[i][1]


def density20(damb, temp, dns_rows, hyc_inline=True):
    rho_g = damb / 1000
    dt = temp - 20
    p1, p2, p3, p4 = vlookup(damb, dns_rows)
    numerator = rho_g - p1 * dt - p3 * dt * dt
    denominator = 1 + p2 * dt + p4 * dt * dt
    hyc = 1 - 0.000023 * dt - 0.00000002 * dt * dt
    return (numerator / denominator) * hyc * 1000


def ctl(d20, tct, fcv_rows):
    dt = tct - 20
    p1, p2, p3, p4 = vlookup(d20, fcv_rows)
    rho20_g = d20 / 1000
    return 1 + p2 * dt + p4 * dt * dt + (p1 * dt + p3 * dt * dt) / rho20_g


def main():
    dns = load_table("DNS_20")
    fcv = load_table("FCV_20")

    cases = [
        ("723/25", 723, 25, 25, 10000, 9940),
        ("S10", 824.20, 32.18, 36.12, 55548, None),
        ("default", 723, 25, 25, 10000, 9940),
    ]
    for name, d, t, tct, vol, danfe in cases:
        d20 = density20(d, t, dns)
        c = round(ctl(d20, tct, fcv), 4)
        vol20 = vol * c
        vol20_r = round(vol * c, 0)
        print(f"{name}: d20={d20:.3f} ctl={c} vol={vol20} vol_int={vol20_r}")
        if danfe:
            print(f"  var={vol20 - danfe} var_int={vol20_r - danfe}")

    # Read sheet 2004 if exists
    wb = xlrd.open_workbook(str(XLS))
    for name in wb.sheet_names():
        if "2004" in name or name.strip() == "2004":
            sh = wb.sheet_by_name(name)
            print(f"=== {name} sample cells ===")
            for addr in [(9, 2), (9, 3), (13, 2), (13, 3), (16, 2)]:
                r, c = addr
                print(f"  ({r},{c})", sh.cell_value(r, c))

    # Try win32com for formulas on conversao derivados xlsx
    try:
        import win32com.client

        xl = win32com.client.Dispatch("Excel.Application")
        xl.Visible = False
        p = Path(r"c:\Users\vinic\Downloads\Correção volumétrica Derivados.xlsx")
        if p.exists():
            wb2 = xl.Workbooks.Open(str(p))
            for si in range(1, min(4, wb2.Sheets.Count + 1)):
                sh = wb2.Sheets(si)
                print("xlsx sheet", sh.Name)
            wb2.Close(False)
        xl.Quit()
    except Exception as e:
        print("xlsx", e)


if __name__ == "__main__":
    main()
