@echo off
chcp 65001 > nul
rem 一键问答：用试跑产出的权重聊两句（需要先跑过 一键试跑.bat）
cd /d "%~dp0"

if not exist out_tiny_sft\ckpt_final.pt (
    echo 没找到 out_tiny_sft\ckpt_final.pt
    echo 请先双击 一键试跑.bat 训练一遍
    pause
    exit /b 1
)

where py >nul 2>nul
if %errorlevel%==0 (set PY=py -3.13) else (set PY=python)

%PY% chat.py --ckpt out_tiny_sft\ckpt_final.pt --quant8
pause
