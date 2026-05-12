@echo off
setlocal
set WORKDIR=%~dp0
cd /d "%WORKDIR%"

set PYTHON_PATH=%WORKDIR%python
set PYTHON_SCRIPTS=%PYTHON_PATH%\Scripts
set PATH=%PYTHON_PATH%;%PYTHON_SCRIPTS%;%PATH%

cmd /K


