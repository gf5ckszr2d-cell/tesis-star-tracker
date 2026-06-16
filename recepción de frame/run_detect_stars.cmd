@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
python "%SCRIPT_DIR%detect_stars.py" %*
exit /b %errorlevel%
