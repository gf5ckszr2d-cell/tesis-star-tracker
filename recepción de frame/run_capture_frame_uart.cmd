@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

where python >nul 2>nul
if %errorlevel%==0 (
    python --version >nul 2>nul
    if %errorlevel%==0 (
        python "%SCRIPT_DIR%capture_frame_uart.py" %*
        exit /b %errorlevel%
    )
)

where py >nul 2>nul
if %errorlevel%==0 (
    py --version >nul 2>nul
    if %errorlevel%==0 (
        py "%SCRIPT_DIR%capture_frame_uart.py" %*
        exit /b %errorlevel%
    )
)

for /d %%D in ("%LocalAppData%\Programs\Python\Python*") do (
    if exist "%%D\python.exe" (
        "%%D\python.exe" "%SCRIPT_DIR%capture_frame_uart.py" %*
        exit /b %errorlevel%
    )
)

echo No se encontro una instalacion valida de Python.
echo Instala Python 3 y marca "Add python.exe to PATH".
exit /b 1
