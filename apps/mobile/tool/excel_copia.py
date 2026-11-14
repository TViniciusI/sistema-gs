import win32com.client

xl = win32com.client.Dispatch("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
path = r"c:\Users\vinic\Downloads\Cópia de correção a 20 - Alcool.xls"
try:
    wb = xl.Workbooks.Open(path)
except Exception as e:
    print("open failed", e)
    xl.Quit()
    raise SystemExit
sh = wb.Sheets("Conversão")
sh.Range("D6").Value = 809
sh.Range("D7").Value = 23.5
sh.Range("D12").Value = 50000
sh.Range("D13").Value = 23.5
sh.Range("D20").Value = 49600
xl.CalculateFull()
print("Copia:", sh.Range("D9").Value, sh.Range("D10").Value, sh.Range("D15").Value, sh.Range("D17").Value, sh.Range("D22").Value)
wb.Close(False)
xl.Quit()
