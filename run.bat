SET whoAmI=%USERNAME%
SET webDir=alfresco\service\api\people\%whoAmI%\sites\
mkdir %webDir%
copy stub\sites.json %webDir%\index.json
type NUL > alfresco_careers_icon.ico
<<<<<<< HEAD
<<<<<<< HEAD
powershell.exe Start-Job {.\server.ps1} 
=======
powershell.exe "Start-Process powershell.exe .\server.ps1 -Verb runAs" 
>>>>>>> Start powershell as admin so that the certs can be added for https connection
=======
powershell.exe "Start-Process powershell.exe .\server.ps1 -Verb runAs" 
>>>>>>> 0ca1648d704364b503fc0046d864ac3379aade62
powershell.exe -noexit Invoke-Pester .\QuickAccessAlfresco.Tests.ps1 -CodeCoverage .\QuickAccessAlfresco.ps1
