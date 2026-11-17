@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title 嘉桦1.0pro 环境自检

echo ============================================================
echo   嘉桦1.0pro 环境自检：出问题时先跑这个
echo ============================================================
echo.

call env.bat
if not defined PY goto nopy

%PY% check_env.py

echo.
echo 把上面这段文字（或截图）发给作者，就能定位问题。
echo.
pause
exit /b 0

:nopy
echo [错误] 没找到可用的 Python。
echo        到 https://www.python.org/downloads/ 下载安装 3.10 或更高版本，
echo        安装第一页务必勾选 Add python.exe to PATH，装完关掉窗口重新双击。
echo.
pause
exit /b 1
