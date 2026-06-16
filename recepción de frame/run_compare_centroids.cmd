@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
python "%SCRIPT_DIR%compare_centroids.py" %*
exit /b %errorlevel%
