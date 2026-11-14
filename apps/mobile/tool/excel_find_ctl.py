import win32com.client

xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
wb = xl.Workbooks.Open(r"c:\Users\vinic\Downloads\correção a 20 - Alcool.xls")
sh = wb.Sheets("Conversão")

for tct in range(15, 41):
    for t in range(15, 41):
        sh.Range("D6").Value = 800
        sh.Range("D7").Value = t
        sh.Range("D12").Value = 50000
        sh.Range("D13").Value = tct
        xl.CalculateFull()
        ctl = sh.Range("D15").Value
        if ctl is not None and abs(ctl - 0.9901) < 0.00005:
            print(f"ctl 0.9901: t={t} tct={tct} d20={sh.Range('D9').Value} inpm={sh.Range('D10').Value}")

wb.Close(False)
xl.Quit()
