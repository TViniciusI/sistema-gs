#!/usr/bin/env python3
"""Find INPM and CTL for 809@23.5 matching Excel."""
import base64
import bisect
import re
import struct
import zlib
from pathlib import Path

DART = Path(__file__).resolve().parent.parent / "lib" / "data" / "inpm_table_data.dart"


def load_dart():
    text = DART.read_text(encoding="utf-8")
    inpm_min = float(re.search(r"inpmMin = ([0-9.]+)", text).group(1))
    inpm_step = float(re.search(r"inpmStep = ([0-9.]+)", text).group(1))
    temp_min = float(re.search(r"tempMin = ([0-9.]+)", text).group(1))
    temp_step = float(re.search(r"tempStep = ([0-9.]+)", text).group(1))
    temp_count = int(re.search(r"tempCount = (\d+)", text).group(1))
    inpm_count = int(re.search(r"inpmCount = (\d+)", text).group(1))
    b64_block = re.search(r"base64Decode\(\s*(.*?)\s*,\s*\)", text, re.S).group(1)
    b64 = "".join(re.findall(r"'([^']*)'", b64_block))
    packed = zlib.decompress(base64.b64decode(b64))
    flat = struct.unpack("<" + "f" * (len(packed) // 4), packed)
    return inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, flat


def row_dens(flat, idx, temp_min, temp_step, temp_count, temp):
    base = idx * temp_count
    dens = [flat[base + c] for c in range(temp_count)]
    if temp <= temp_min:
        return dens[0]
    t_max = temp_min + (temp_count - 1) * temp_step
    if temp >= t_max:
        slope = (dens[-1] - dens[-2]) / temp_step
        return dens[-1] + slope * (temp - t_max)
    t0 = int((temp - temp_min) / temp_step)
    f = (temp - (temp_min + t0 * temp_step)) / temp_step
    return dens[t0] + f * (dens[t0 + 1] - dens[t0])


def rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, temp):
    idx_f = (inpm - inpm_min) / inpm_step
    i = int(idx_f)
    if i >= inpm_count - 1:
        return row_dens(flat, inpm_count - 1, temp_min, temp_step, temp_count, temp)
    frac = idx_f - i
    d0 = row_dens(flat, i, temp_min, temp_step, temp_count, temp)
    d1 = row_dens(flat, i + 1, temp_min, temp_step, temp_count, temp)
    return d0 + frac * (d1 - d0)


def find_inpm(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, rho_target, temp):
    lo = inpm_min
    hi = inpm_min + (inpm_count - 1) * inpm_step
    for _ in range(80):
        mid = (lo + hi) / 2
        if rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, mid, temp) < rho_target:
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2


def ctl_beta(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, tct):
    rho20 = rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, 20)
    dt = 0.01
    drho = (
        rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, tct + dt)
        - rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, tct - dt)
    ) / (2 * dt)
    beta = -drho / rho20
    return 1 / (1 + beta * (tct - 20))


def ctl_hyc(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, tct):
    rho20 = rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, 20)
    rho_ct = rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, inpm, tct)
    return rho_ct / rho20 * (1 + 0.000036 * (tct - 20))


def main():
    inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, flat = load_dart()
    for rho_amb, t in [(809, 23.5), (809, 20), (800, 23.5)]:
        inpm = find_inpm(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, rho_amb, t)
        ir = round(inpm * 100) / 100
        d20 = rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, ir, 20)
        cb = ctl_beta(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, ir, t)
        ch = ctl_hyc(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, ir, t)
        vol = 50000 * round(ch, 4)
        print(f"rho={rho_amb} T={t} inpm={inpm:.4f}->{ir} d20={d20:.3f} ctl_b={cb:.4f} ctl_h={ch:.4f} vol={vol} var={vol-49600}")

    # Excel path: INPM from density@20?
    inpm = find_inpm(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, 809, 20)
    ir = round(inpm * 100) / 100
    print(f"809@20 inpm {ir} d20={rho(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, ir, 20):.3f}")
    for name, ctl_fn in [("beta", ctl_beta), ("hyc", ctl_hyc)]:
        ctl = ctl_fn(flat, inpm_min, inpm_step, temp_min, temp_step, temp_count, inpm_count, ir, 23.5)
        vol = 50000 * round(ctl, 4)
        print(f"  {name} ctl@23.5={ctl:.4f} vol={vol} var={vol-49600}")


if __name__ == "__main__":
    main()
