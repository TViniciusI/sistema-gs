import win32com.client

xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
wb = xl.Workbooks.Open(r"c:\Users\vinic\Downloads\correção a 20 - Alcool.xls")
sh = wb.Sheets("Conversão")

best = None
for d in [798, 800, 802, 804, 806, 808]:
    for t in [20, 22, 23, 23.5, 24, 25, 30]:
        for tct in [20, 21, 22, 23, 23.5, 24, 25, 30, 32.7]:
            sh.Range("D6").Value = d
            sh.Range("D7").Value = t
            sh.Range("D12").Value = 50000
            sh.Range("D13").Value = tct
            sh.Range("D20").Value = 49600
            xl.CalculateFull()
            var = sh.Range("D22").Value
            ctl = sh.Range("D15").Value
            if var is not None and abs(var + 95) < 2:
                print(f"MATCH d={d} t={t} tct={tct} ctl={ctl} vol={sh.Range('D17').Value} var={var} inpm={sh.Range('D10').Value} d20={sh.Range('D9').Value}")
                best = True
if not best:
    print("no -95 match with danfe 49600")
    # show closest to -95
    sh.Range("D6").Value = 800
    sh.Range("D7").Value = 23.5
    sh.Range("D12").Value = 50000
    sh.Range("D13").Value = 23.5
    sh.Range("D20").Value = 49600
    xl.CalculateFull()
    print("800/23.5", sh.Range("D15").Value, sh.Range("D17").Value, sh.Range("D22").Value)
    sh.Range("D20").Value = 49505
    xl.CalculateFull()
    print("danfe=49505", sh.Range("D22").Value)

wb.Close(False)
xl.Quit()
