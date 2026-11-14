#!/usr/bin/env python3
"""Compare Excel INPM table vs Dart exported data."""
import base64
import bisect
import re
import struct
import zlib
from pathlib import Path

import xlrd

XLS = Path(r"c:\Users\vinic\Downloads\correção a 20 - Alcool.xls")
DART = Path(__file__).resolve().parent.parent / "lib" / "data" / "inpm_table_data.dart"


def load_excel_row(inpm_target):
    wb = xlrd.open_workbook(str(XLS))
    tab = wb.sheet_by_name("Tabela")
    for r in range(tab.nrows):
        v = tab.cell_value(r, 0)
        if isinstance(v, float) and abs(v - inpm_target) < 0.01:
            hdr = r - 1
            while hdr >= 0 and str(tab.cell_value(hdr, 0)).strip().upper() != "INPM":
                hdr -= 1
            temps = [
                round(float(tab.cell_value(hdr, c)), 1)
                for c in range(1, tab.ncols)
                if tab.cell_value(hdr, c) != ""
            ]
            dens = {
                temps[c]: float(tab.cell_value(r, c + 1))
                for c in range(len(temps))
            }
            return inpm_target, dens
    return None, None


def load_dart():
    text = DART.read_text(encoding="utf-8")
    inpm_min = float(re.search(r"inpmMin = ([0-9.]+)", text).group(1))
    inpm_step = float(re.search(r"inpmStep = ([0-9.]+)", text).group(1))
    temp_min = float(re.search(r"tempMin = ([0-9.]+)", text).group(1))
    temp_step = float(re.search(r"tempStep = ([0-9.]+)", text).group(1))
    temp_count = int(re.search(r"tempCount = (\d+)", text).group(1))
    b64_block = re.search(r"base64Decode\(\s*(.*?)\s*,\s*\)", text, re.S).group(1)
    b64 = "".join(re.findall(r"'([^']*)'", b64_block))
    packed = zlib.decompress(base64.b64decode(b64))
    flat = struct.unpack("<" + "f" * (len(packed) // 4), packed)
    return inpm_min, inpm_step, temp_min, temp_step, temp_count, flat


def dart_density(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm, temp):
    idx = round((inpm - inpm_min) / inpm_step)
    t0 = round((temp - temp_min) / temp_step)
    return flat[idx * temp_count + t0]


def main():
    inpm_min, inpm_step, temp_min, temp_step, temp_count, flat = load_dart()
    for inpm in [93.27, 93.53, 100.0]:
        ex_inpm, dens = load_excel_row(inpm)
        print(f"INPM {inpm}")
        if dens:
            print(f"  excel d20={dens.get(20.0)} d23.5={dens.get(23.5)}")
        print(
            f"  dart d20={dart_density(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm, 20)} "
            f"d23.5={dart_density(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm, 23.5)}"
        )


if __name__ == "__main__":
    main()
