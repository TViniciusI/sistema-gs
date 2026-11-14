import win32com.client

xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
wb = xl.Workbooks.Open(r"c:\Users\vinic\Downloads\correção a 20 - Alcool.xls")
sh = wb.Sheets("Conversão")
for t, tct in [(29.45, 23.5), (29.45, 29.45), (23.5, 23.5), (30, 32.7)]:
    sh.Range("D6").Value = 800
    sh.Range("D7").Value = t
    sh.Range("D12").Value = 50000
    sh.Range("D13").Value = tct
    sh.Range("D20").Value = 49600
    xl.CalculateFull()
    print(
        f"t={t} tct={tct} inpm={sh.Range('D10').Value} "
        f"d20={sh.Range('D9').Value} ctl={sh.Range('D15').Value} "
        f"vol={sh.Range('D17').Value} var={sh.Range('D22').Value}"
    )
wb.Close(False)
xl.Quit()
