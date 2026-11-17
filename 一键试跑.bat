@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title 嘉桦1.0pro 一键试跑

echo ============================================================
echo   嘉桦1.0pro 试跑：357 万参数小模型，几分钟跑通全流程
echo   不需要显卡，8G 内存的笔记本就行
echo ============================================================
echo.

call env.bat
if not defined PY goto nopy
echo [0/4] 解释器：%PY%
%PY% -c "import sys;print('      Python ' + sys.version.split()[0])"

%PY% -c "import torch" >nul 2>&1
if errorlevel 1 (
    echo [0/4] 没检测到 PyTorch，正在自动安装，第一次要等几分钟……
    %PY% -m pip install --upgrade pip
    %PY% -m pip install torch
)
%PY% -c "import torch" >nul 2>&1
if errorlevel 1 goto notorch
%PY% -c "import torch;print('      PyTorch ' + torch.__version__)"

echo [1/4] 建词表……
%PY% tokenizer.py build --data data/corpus.txt data/qa.jsonl --out tokenizer.json
if errorlevel 1 goto failed

echo [2/4] 预训练 500 步……
%PY% train.py --config configs/tiny.json --data data/corpus.txt --out_dir out_tiny --max_steps 500 --batch_size 8 --seq_len 160 --log_every 100 --eval_every 250
if errorlevel 1 goto failed

echo [3/4] 问答微调 1500 步……
%PY% sft.py --ckpt out_tiny\ckpt_final.pt --data data/qa.jsonl --out_dir out_tiny_sft --max_steps 1500 --batch_size 8 --seq_len 112 --lr 2e-4
if errorlevel 1 goto failed

echo [4/4] 自动提问……
%PY% chat.py --ckpt out_tiny_sft\ckpt_final.pt --quant8 --temperature 0 --question "你好，你是谁？"
%PY% chat.py --ckpt out_tiny_sft\ckpt_final.pt --quant8 --temperature 0 --question "who are you"

echo.
echo 试跑完成，权重在：out_tiny_sft\ckpt_final.pt
echo 想自己聊：双击 一键问答.bat
pause
exit /b 0

:nopy
echo.
echo [错误] 没找到可用的 Python。
echo        到 https://www.python.org/downloads/ 下载安装 3.10 或更高版本，
echo        安装第一页务必勾选 Add python.exe to PATH，装完关掉窗口重新双击本脚本。
pause
exit /b 1

:notorch
echo.
echo [错误] PyTorch 没装上。请联网后手动执行：
echo        %PY% -m pip install torch
pause
exit /b 1

:failed
echo.
echo [错误] 上一步报错了，把上面的文字截图发出来，或者双击 环境自检.bat 把结果发出来。
pause
exit /b 1
