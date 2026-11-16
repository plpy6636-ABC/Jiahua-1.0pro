@echo off
chcp 65001 > nul
rem 一键试跑：357 万参数的小模型，三五分钟跑通“建词表 -> 预训练 -> 微调 -> 提问”全流程
cd /d "%~dp0"

echo ==========================================================
echo   嘉桦1.0pro 试跑：小模型跑通整条流程（不需要显卡）
echo ==========================================================
echo.

where py >nul 2>nul
if %errorlevel%==0 (set PY=py -3.13) else (set PY=python)

%PY% -c "import torch" 2>nul
if errorlevel 1 (
    echo [提示] 没检测到 torch，正在安装……
    %PY% -m pip install torch
)

echo [1/4] 建词表……
%PY% tokenizer.py build --data data/corpus.txt data/qa.jsonl --out tokenizer.json
if errorlevel 1 goto fail

echo [2/4] 预训练 500 步……
%PY% train.py --config configs/tiny.json --data data/corpus.txt --out_dir out_tiny --max_steps 500 --batch_size 8 --seq_len 160 --log_every 100 --eval_every 250
if errorlevel 1 goto fail

echo [3/4] 问答微调 1500 步……
%PY% sft.py --ckpt out_tiny/ckpt_final.pt --data data/qa.jsonl --out_dir out_tiny_sft --max_steps 1500 --batch_size 8 --seq_len 112 --lr 2e-4
if errorlevel 1 goto fail

echo [4/4] 自动提问……
echo.
%PY% chat.py --ckpt out_tiny_sft/ckpt_final.pt --quant8 --temperature 0 --question "你好，你是谁？"
%PY% chat.py --ckpt out_tiny_sft/ckpt_final.pt --quant8 --temperature 0 --question "who are you"

echo.
echo 试跑完成。想自己聊就把上面两行改成 --question 去掉，直接不带参数运行 chat.py。
pause
exit /b 0

:fail
echo.
echo 出错了，看上面的报错信息。常见原因：没装 Python、没装 torch、或路径里有中文空格。
pause
exit /b 1
