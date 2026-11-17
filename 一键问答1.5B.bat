@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title 嘉桦1.0pro 一键问答1.5B

call env.bat
if not defined PY goto nopy

if not exist out_1.5b_sft\ckpt_final.pt goto noweight

%PY% -c "import torch" >nul 2>&1
if errorlevel 1 (
    echo 没检测到 PyTorch，正在自动安装……
    %PY% -m pip install torch
)
%PY% -c "import torch" >nul 2>&1
if errorlevel 1 goto notorch

echo 使用权重：out_1.5b_sft\ckpt_final.pt
echo 8G 内存也能跑：默认 int8 量化，显存不够 4G 会自动退回 CPU
echo.
%PY% chat.py --ckpt out_1.5b_sft\ckpt_final.pt --quant8
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
echo [提示] 没找到 out_1.5b_sft\ckpt_final.pt，说明 1.5B 还没训练好。
echo        权重不会随代码下载，必须先训练：
echo          · 有 20GB 以上显存：双击 一键训练1.5B.bat
echo          · 没有显卡：双击 一键试跑.bat，先用小模型验证流程
pause
exit /b 1
