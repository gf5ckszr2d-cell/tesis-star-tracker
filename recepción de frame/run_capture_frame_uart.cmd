@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

where python >nul 2>nul
if %errorlevel%==0 (
    python "%SCRIPT_DIR%capture_frame_uart.py" %*
    exit /b %errorlevel%
)

where py >nul 2>nul
if %errorlevel%==0 (
    py "%SCRIPT_DIR%capture_frame_uart.py" %*
    exit /b %errorlevel%
)

if exist "%LocalAppData%\Programs\Python\Python313\python.exe" (
    "%LocalAppData%\Programs\Python\Python313\python.exe" "%SCRIPT_DIR%capture_frame_uart.py" %*
    exit /b %errorlevel%
)

echo No se encontro Python. Instala Python 3 y vuelve a intentar.
exit /b 1
