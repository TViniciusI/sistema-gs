import win32com.client

xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
wb = xl.Workbooks.Open(r"c:\Users\vinic\Downloads\correção a 20 - Alcool.xls")
sh = wb.Sheets("Conversão")

def run(d, t, tct, vol, danfe):
    sh.Range("D6").Value = d
    sh.Range("D7").Value = t
    sh.Range("D12").Value = vol
    sh.Range("D13").Value = tct
    sh.Range("D20").Value = danfe
    xl.CalculateFull()
    return {
        "d20": sh.Range("D9").Value,
        "inpm": sh.Range("D10").Value,
        "ctl": sh.Range("D15").Value,
        "vol": sh.Range("D17").Value,
        "var": sh.Range("D22").Value,
    }

for tct in [23.5, 20.5, 20.0]:
    r = run(809, 23.5, tct, 50000, 49600)
    print(f"809/23.5 tct={tct}", r)

for d in [800, 805]:
    r = run(d, 23.5, 23.5, 50000, 49600)
    print(f"{d}/23.5", r)

# target -95
r = run(809, 20, 20.5, 50000, 49600)
print("809/20 tct20.5", r)

wb.Close(False)
xl.Quit()
