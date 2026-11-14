# -*- coding: utf-8 -*-
"""Compare Cleber Phoenix Excel versions vs app headers."""
import openpyxl
import re

NEW = r"c:\Users\vinic\Downloads\GS_Calibracao_PHOENIX_DISTRIBUIDORA_DE_COMBUSTIVEIS_LT (1).xlsx"
OLD = r"c:\Users\vinic\Downloads\GS_Calibracao_PHOENIX_DISTRIBUIDORA_DE_COMBUSTIVEIS_LT.xlsx"
APP_DART = r"C:\dev\sistema_gs\apps\mobile\lib\data\client_excel.dart"

def headers(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb["Instrumentos"]
    return [c.value for c in next(ws.iter_rows(min_row=1, max_row=1)) if c.value is not None]

def app_headers():
    text = open(APP_DART, encoding="utf-8").read()
    m = re.search(
        r"final instrumentSheet = excel\['Instrumentos'\];\s*"
        r"instrumentSheet\.appendRow\(\[\s*"
        r"for \(final header in const \[(.*?)\]\)",
        text,
        re.S,
    )
    return re.findall(r"'([^']+)'", m.group(1))

new_h = headers(NEW)
try:
    old_h = headers(OLD)
except Exception as e:
    old_h = []
    print("old file missing:", e)
app_h = app_headers()

print(f"NEW Cleber: {len(new_h)} cols")
print(f"OLD Cleber: {len(old_h)} cols")
print(f"APP hoje:   {len(app_h)} cols")
print()

print("=== NEW order ===")
for i, h in enumerate(new_h, 1):
    print(f"{i:2d}. {h}")

print()
print("=== Removidas vs APP (estão no app, não na nova) ===")
removed = [h for h in app_h if h not in new_h]
for h in removed:
    print(f"  - {h}")

print()
print("=== Novas / renomeadas (estão na nova, não no app exatamente) ===")
added = [h for h in new_h if h not in app_h]
for h in added:
    print(f"  + {h}")

print()
print("=== Removidas vs OLD Cleber (50) ===")
if old_h:
    for h in old_h:
        if h not in new_h:
            print(f"  - {h}")
    print()
    print("=== Só na nova vs OLD ===")
    for h in new_h:
        if h not in old_h:
            print(f"  + {h}")

# semantic mapping hints
print()
print("=== Resumo contagem ===")
print(f"App 50 -> Nova {len(new_h)} = retirou {len(app_h)-len(new_h)} colunas líquidas")
print(f"Removidas exatas do app: {len(removed)}")
print(f"Cabeçalhos novos/renomeados: {len(added)}")
