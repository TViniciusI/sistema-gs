import win32com.client

xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
wb = xl.Workbooks.Open(r"c:\Users\vinic\Downloads\correção a 20 - Alcool.xls")
sh = wb.Sheets("Conversão")
for tct in [28.0, 28.5, 29.0, 29.2, 29.45, 29.5, 29.7, 30.0]:
    sh.Range("D6").Value = 800
    sh.Range("D7").Value = 29.45
    sh.Range("D12").Value = 50000
    sh.Range("D13").Value = tct
    sh.Range("D20").Value = 49600
    xl.CalculateFull()
    ctl = sh.Range("D15").Value
    print(f"tct={tct} ctl={ctl} vol={sh.Range('D17').Value} var={sh.Range('D22').Value}")

wb.Close(False)
xl.Quit()
