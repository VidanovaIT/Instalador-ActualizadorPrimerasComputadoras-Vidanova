@echo off
:: ---------------------------------------------
:: Elevacion de privilegios si no es administrador
:: ---------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ---------------------------------------------
:: Ejecutar winget list una vez para forzar aceptacion si es necesario
:: ---------------------------------------------
echo.
echo Verificacion inicial de Winget.
echo Se abrira una ventana para mostrar la lista de paquetes.
echo Si es la primera vez, se te pedira aceptar los terminos. Presiona Y y ENTER.
echo Si no ocurre nada, simplemente cierra la ventana.
timeout /t 2 >nul
start powershell -NoExit -Command "winget list"

echo.
echo Una vez cerrada la ventana de Winget, presiona una tecla para continuar...
pause

:: ---------------------------------------------
:: Ejecutar script PowerShell principal
:: ---------------------------------------------
echo.
echo Ejecutando InstaladorDefinitivo.ps1...
start powershell -NoExit -ExecutionPolicy Bypass -File "%~dp0InstaladorDefinitivo.ps1"
exit /b
