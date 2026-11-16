@echo off
chcp 65001 > nul
rem 一键问答 1.5B：嘉桦1.0pro 主力模型的聊天入口
rem 只有 8G 内存也能跑（默认 --quant8 量化，显存不足自动退回 CPU）
cd /d "%~dp0"

if not exist out_1.5b_sft\ckpt_final.pt (
    echo 没找到 out_1.5b_sft\ckpt_final.pt
    echo 请先双击 一键训练1.5B.bat 训练一遍
    pause
    exit /b 1
)

where py >nul 2>nul
if %errorlevel%==0 (set PY=py -3.13) else (set PY=python)

%PY% chat.py --ckpt out_1.5b_sft\ckpt_final.pt --quant8
pause
