#!/usr/bin/env python3
"""Debug alcohol Excel vs app for perda/sobra case."""
import bisect
from pathlib import Path

import xlrd

XLS = Path(r"c:\Users\vinic\Downloads\correção a 20 - Alcool.xls")


def load():
    wb = xlrd.open_workbook(str(XLS))
    tab = wb.sheet_by_name("Tabela")
    headers = [
        r
        for r in range(tab.nrows)
        if str(tab.cell_value(r, 0)).strip().upper() == "INPM"
    ]
    block_temps, block_rows = [], []
    for header_row in headers:
        temps = [
            round(float(tab.cell_value(header_row, c)), 1)
            for c in range(1, tab.ncols)
            if tab.cell_value(header_row, c) != ""
        ]
        rows = []
        data_row = header_row + 1
        while data_row < tab.nrows:
            v = tab.cell_value(data_row, 0)
            if v == "" or str(v).strip().upper() == "INPM":
                break
            inpm = float(v)
            dens = [
                round(float(tab.cell_value(data_row, c + 1)), 2)
                for c in range(len(temps))
            ]
            rows.append((inpm, dens))
            data_row += 1
        block_temps.append(temps)
        block_rows.append(rows)
    merged_temps = list(block_temps[0])
    for t in block_temps[1:]:
        merged_temps.extend(t[1:])
    merged_rows = []
    for i, (inpm, _) in enumerate(block_rows[0]):
        dens = list(block_rows[0][i][1])
        for block in block_rows[1:]:
            dens.extend(block[i][1][1:])
        merged_rows.append((inpm, dens))
    return wb, merged_temps, merged_rows


def row_dens(rows, temps, idx, temp):
    dens = rows[idx][1]
    if temp <= temps[0]:
        return dens[0]
    if temp >= temps[-1]:
        slope = (dens[-1] - dens[-2]) / (temps[-1] - temps[-2])
        return dens[-1] + slope * (temp - temps[-1])
    i = bisect.bisect_right(temps, temp) - 1
    f = (temp - temps[i]) / (temps[i + 1] - temps[i])
    return dens[i] + f * (dens[i + 1] - dens[i])


def rho_table(rows, temps, inpm, temp):
    inpm_vals = [r[0] for r in rows]
    if inpm <= inpm_vals[0]:
        return row_dens(rows, temps, 0, temp)
    if inpm >= inpm_vals[-1]:
        return row_dens(rows, temps, len(rows) - 1, temp)
    i = bisect.bisect_right(inpm_vals, inpm) - 1
    frac = (inpm - inpm_vals[i]) / (inpm_vals[i + 1] - inpm_vals[i])
    d0 = row_dens(rows, temps, i, temp)
    d1 = row_dens(rows, temps, i + 1, temp)
    return d0 + frac * (d1 - d0)


def find_inpm(rows, temps, rho, temp):
    inpm_vals = [r[0] for r in rows]
    lo, hi = inpm_vals[0], inpm_vals[-1]
    for _ in range(80):
        mid = (lo + hi) / 2
        if rho_table(rows, temps, mid, temp) < rho:
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2


def ctl_beta(rows, temps, inpm, tct):
    rho20 = rho_table(rows, temps, inpm, 20.0)
    dt = 0.01
    drho = (
        rho_table(rows, temps, inpm, tct + dt)
        - rho_table(rows, temps, inpm, tct - dt)
    ) / (2 * dt)
    beta = -drho / rho20
    return 1 / (1 + beta * (tct - 20))


def ctl_hyc(rows, temps, inpm, tct):
    rho20 = rho_table(rows, temps, inpm, 20.0)
    rho_ct = rho_table(rows, temps, inpm, tct)
    hy_c = 1 + 0.000036 * (tct - 20)
    return rho_ct / rho20 * hy_c


def scan_conversao(wb):
    for name in wb.sheet_names():
        if "convers" in name.lower():
            sh = wb.sheet_by_name(name)
            print(f"=== sheet {name} ({sh.nrows}x{sh.ncols}) ===")
            for r in range(min(25, sh.nrows)):
                row = [sh.cell_value(r, c) for c in range(min(12, sh.ncols))]
                if any(str(x).strip() for x in row):
                    print(r, row)


def main():
    wb, temps, rows = load()
    scan_conversao(wb)
    for rho, t, tct in [(809, 23.5, 23.5), (800, 23.5, 23.5)]:
        inpm = find_inpm(rows, temps, rho, t)
        inpm_r = round(inpm * 100) / 100
        d20 = rho_table(rows, temps, inpm_r, 20)
        cb = ctl_beta(rows, temps, inpm_r, tct)
        ch = ctl_hyc(rows, temps, inpm_r, tct)
        vol_b = 50000 * round(cb, 4)
        vol_h = 50000 * round(ch, 4)
        print(
            f"rho={rho} inpm={inpm:.4f}->{inpm_r} d20={d20:.3f} "
            f"ctl_beta={cb:.4f} vol={vol_b} var={vol_b-49600} | "
            f"ctl_hyc={ch:.4f} vol={vol_h} var={vol_h-49600}"
        )

    inpm = 93.53
    print(f"--- fixed INPM {inpm} ---")
    for t in [20, 23.5]:
        print(f"  T={t} rho={rho_table(rows, temps, inpm, t):.3f}")
    cb = ctl_beta(rows, temps, inpm, 23.5)
    ch = ctl_hyc(rows, temps, inpm, 23.5)
    print(f"ctl_beta={cb:.4f} ctl_hyc={ch:.4f}")
    for ctl in [cb, ch, 0.9901]:
        vol = 50000 * round(ctl, 4)
        print(f"  ctl={ctl:.4f} vol={vol} var={vol-49600}")

    print("find_inpm 808.28@20", find_inpm(rows, temps, 808.28, 20))
    print("find_inpm 809@20", find_inpm(rows, temps, 809, 20))


if __name__ == "__main__":
    main()
