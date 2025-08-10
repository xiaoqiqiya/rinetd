@echo off
setlocal

rem Ruta completa al ejecutable y al archivo de configuración
set RINETD_EXECUTABLE=C:\Users\Administrator\Desktop\rinetd.exe
set RINETD_CONFIG=C:\Users\Administrator\Desktop\rinetd.conf

rem Verificar si el archivo de configuración existe
if not exist "%RINETD_CONFIG%" (
    echo El archivo de configuración "%RINETD_CONFIG%" no se encontró.
    pause
    exit /b
)

rem Iniciar el servicio rinetd
start "" "%RINETD_EXECUTABLE%" -c "%RINETD_CONFIG%"

endlocal