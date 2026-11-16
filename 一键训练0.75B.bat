@echo off
chcp 65001 > nul
rem 一键训练 0.75B：需要显卡（建议 8G 以上显存）；没显卡就别跑了
cd /d "%~dp0"

echo ==========================================================
echo   嘉桦1.0pro / 0.75B 训练（嘉桦1.0 旧配置）
echo ==========================================================
echo.

echo [0/3] 检查显卡……
where py >nul 2>nul
if %errorlevel%==0 (set PY=py -3.13) else (set PY=python)
%PY% -c "import torch; print('CUDA 可用' if torch.cuda.is_available() else 'CUDA 不可用（将使用 CPU，会很慢）')"

echo [1/3] 建词表……
%PY% tokenizer.py build --data data/corpus.txt data/qa.jsonl --out tokenizer.json
if errorlevel 1 goto fail

echo [2/3] 预训练……
%PY% train.py --config configs/0.75b.json --data data/corpus.txt --out_dir out_0.75b --max_steps 12000 --batch_size 4 --grad_accum 8
if errorlevel 1 goto fail

echo [3/3] 问答微调……
%PY% sft.py --ckpt out_0.75b/ckpt_last.pt --data data/qa.jsonl --out_dir out_0.75b_sft --max_steps 1500 --batch_size 4 --seq_len 256
if errorlevel 1 goto fail

echo.
echo 训练完成，接下来双击 一键问答.bat（或自己跑 chat.py）。
pause
exit /b 0

:fail
echo.
echo 出错了，看上面的报错信息。
pause
exit /b 1
