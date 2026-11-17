@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title 嘉桦1.0pro 一键训练0.75B

echo ============================================================
echo   嘉桦1.0pro / 0.75B 训练（嘉桦1.0 旧配置）
echo   需要：显卡约 12GB 以上显存
echo ============================================================
echo.

call env.bat
if not defined PY goto nopy

%PY% -c "import torch" >nul 2>&1
if errorlevel 1 (
    echo 没检测到 PyTorch，正在自动安装……
    %PY% -m pip install torch
)
%PY% -c "import torch" >nul 2>&1
if errorlevel 1 goto notorch

echo [0/3] 检查显卡和显存……
%PY% check_env.py --require-vram 12
if errorlevel 2 goto nogpu

echo [1/3] 建词表……
%PY% tokenizer.py build --data data/corpus.txt data/qa.jsonl --out tokenizer.json
if errorlevel 1 goto failed

echo [2/3] 预训练……
%PY% train.py --config configs/0.75b.json --data data/corpus.txt --out_dir out_0.75b --max_steps 12000 --batch_size 4 --grad_accum 8 --save_every 500 --eval_every 500
if errorlevel 1 goto failed

echo [3/3] 问答微调……
%PY% sft.py --ckpt out_0.75b\ckpt_last.pt --data data/qa.jsonl --out_dir out_0.75b_sft --max_steps 2000 --batch_size 4 --seq_len 512
if errorlevel 1 goto failed

echo.
echo 训练完成，权重在：out_0.75b_sft\ckpt_final.pt
echo 接下来双击 一键问答.bat 就能提问。
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

:nogpu
echo.
echo [停止] 这台电脑的显卡显存不够 12GB，训不了 0.75B。
echo        CPU 强行训练一步要几分钟，几天也跑不完，所以这里直接停下。
echo        可以：1. 先双击 一键试跑.bat，看完整流程
echo              2. 换一台有显卡的电脑，或者用云端 GPU
pause
exit /b 1

:failed
echo.
echo [错误] 上一步报错了，把上面的文字截图发出来，或者双击 环境自检.bat。
pause
exit /b 1
