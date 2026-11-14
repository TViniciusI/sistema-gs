# -*- coding: utf-8 -*-
import openpyxl
wb = openpyxl.load_workbook(
    r"c:\Users\vinic\Downloads\GS_Calibracao_PHOENIX_DISTRIBUIDORA_DE_COMBUSTIVEIS_LT.xlsx",
    data_only=True,
)
ws = wb["Instrumentos"]
h = [c.value for c in next(ws.iter_rows(min_row=1, max_row=1))]
idx = {name: h.index(name) for name in h}
for row in ws.iter_rows(min_row=2, values_only=True):
    if not row[0]:
        continue
    print(
        f"{str(row[idx['Tag do preset']]):10} "
        f"{str(row[idx['Tag do medidor']]):10} "
        f"densP={row[idx['Principio do densimetro']]!s:8} "
        f"ptMfg={row[idx['Fabricante do pt100']]!s:12} "
        f"ptMod={str(row[idx['Modelo do pt100']]):10} "
        f"ptNS={row[idx['N/S do pt100']]!s:5} "
        f"ptTag={row[idx['Tag do pt100']]!s:18} "
        f"ptP={row[idx['Principio do pt100']]}"
    )
