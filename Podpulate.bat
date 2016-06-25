cd bin\Scripts
SET ftpUrl=""
SET ftpUser=""
SET ftpPassword=""
SET startPath=""
start powershell -command "& '.\Podpulate.ps1' -ftpUrl %ftpUrl% -ftpUser %ftpUser% -ftpPassword %ftpPassword%" -startPath %startPath% 