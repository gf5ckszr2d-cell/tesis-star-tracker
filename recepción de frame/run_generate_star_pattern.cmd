@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
python "%SCRIPT_DIR%generate_star_pattern.py" %*
exit /b %errorlevel%
