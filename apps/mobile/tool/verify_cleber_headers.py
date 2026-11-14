# -*- coding: utf-8 -*-
import openpyxl
import re

cleber_path = r"c:\Users\vinic\Downloads\GS_Calibracao_PHOENIX_DISTRIBUIDORA_DE_COMBUSTIVEIS_LT.xlsx"
wb = openpyxl.load_workbook(cleber_path, data_only=True)
cleber = [c.value for c in next(wb["Instrumentos"].iter_rows(min_row=1, max_row=1))]

text = open(r"lib\data\client_excel.dart", encoding="utf-8").read()
# Find Instrumentos header list (the long const with Principio de funcionamento)
m = re.search(
    r"final instrumentSheet = excel\['Instrumentos'\];\s*"
    r"instrumentSheet\.appendRow\(\[\s*"
    r"for \(final header in const \[(.*?)\]\)",
    text,
    re.S,
)
headers = re.findall(r"'([^']+)'", m.group(1))
print("app", len(headers), "cleber", len(cleber))
ok = True
for i, (a, b) in enumerate(zip(headers, cleber), 1):
    if a != b:
        print("DIFF", i, repr(a), "!=", repr(b))
        ok = False
if len(headers) != len(cleber):
    print("len mismatch", len(headers), len(cleber))
    ok = False
print("MATCH_OK" if ok else "MISMATCH")

# Sample first data row keys by position
row2 = [c.value for c in next(wb["Instrumentos"].iter_rows(min_row=2, max_row=2))]
print("--- sample row 2 ---")
for h, v in zip(cleber, row2):
    if v not in (None, ""):
        print(f"  {h}: {v}")
