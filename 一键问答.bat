@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title 嘉桦1.0pro 一键问答

call env.bat
if not defined PY goto nopy

set "CKPT="
if exist out_1.5b_sft\ckpt_final.pt set "CKPT=out_1.5b_sft\ckpt_final.pt"
if not defined CKPT if exist out_tiny_sft\ckpt_final.pt set "CKPT=out_tiny_sft\ckpt_final.pt"
if not defined CKPT goto noweight

%PY% -c "import torch" >nul 2>&1
if errorlevel 1 (
    echo 没检测到 PyTorch，正在自动安装……
    %PY% -m pip install torch
)
%PY% -c "import torch" >nul 2>&1
if errorlevel 1 goto notorch

echo 使用权重：%CKPT%
echo 只有 8G 内存也没关系，默认 int8 量化，显存不够自动用 CPU
echo.
%PY% chat.py --ckpt "%CKPT%" --quant8
pause
exit /b 0

:nopy
echo.
echo [错误] 没找到可用的 Python。
echo        到 https://www.python.org/downloads/ 下载安装 3.10 或更高版本，
echo        安装第一页务必勾选 Add python.exe to PATH。
pause
exit /b 1

:notorch
echo.
echo [错误] PyTorch 没装上。请联网后手动执行：
echo        %PY% -m pip install torch
pause
exit /b 1

:noweight
echo.
echo [提示] 还没训练过，所以没有权重，也就无法问答。
echo        权重不会随代码一起下载，必须自己训练一次才会生成：
echo          · 有 20GB 以上显存的显卡：双击 一键训练1.5B.bat
echo          · 没有显卡或显存不够：先双击 一键试跑.bat，几分钟出结果
echo.
echo        想确认到底缺什么：双击 环境自检.bat
pause
exit /b 1
