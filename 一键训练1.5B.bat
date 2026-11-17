@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"
title 嘉桦1.0pro 一键训练1.5B

echo ============================================================
echo   嘉桦1.0pro / 1.5B 训练（实测 1,507,855,104 参数）
echo   需要：约 20GB 显存的显卡，推荐 24GB
echo   注意：8G 内存只够推理，不能训练
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
%PY% check_env.py --require-vram 18
if errorlevel 2 goto nogpu

echo [1/3] 建词表……
%PY% tokenizer.py build --data data/corpus.txt data/qa.jsonl --out tokenizer.json
if errorlevel 1 goto failed

echo [2/3] 预训练，默认 2 万步，可以 Ctrl+C 随时停……
%PY% train.py --config configs/1.5b.json --data data/corpus.txt --out_dir out_1.5b --max_steps 20000 --batch_size 1 --grad_accum 16 --seq_len 1024
if errorlevel 1 goto failed

echo [3/3] 问答微调 3000 步……
%PY% sft.py --ckpt out_1.5b\ckpt_last.pt --data data/qa.jsonl --out_dir out_1.5b_sft --max_steps 3000 --batch_size 2 --seq_len 512 --lr 1e-4
if errorlevel 1 goto failed

echo.
echo 训练完成，权重在：out_1.5b_sft\ckpt_final.pt
echo 接下来双击 一键问答1.5B.bat 就能提问。
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
echo [停止] 1.5B 全参数训练需要约 20GB 显存，这台电脑不够，所以没有开始训练。
echo        略微抬高显存也扛不住，CPU 上训 1.5B 一步要几分钟，几天也跑不完。
echo        可以：1. 先双击 一键试跑.bat，几分钟看完整流程
echo              2. 换一台有显卡的电脑，或者租云端 GPU
echo        如果你确实有卡但被误拦，用命令行手动跑：train.py --config configs/1.5b.json --force_cpu
pause
exit /b 1

:failed
echo.
echo [错误] 上一步报错了，把上面的文字截图发出来，或者双击 环境自检.bat。
echo        若是在显存边缘的卡上爆内存，把 --batch_size 1 保持不动，并加 --grad_accum 32 再试。
pause
exit /b 1
