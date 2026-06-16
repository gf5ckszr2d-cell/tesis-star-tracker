@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
python "%SCRIPT_DIR%calibrate_capture.py" %*
exit /b %errorlevel%
