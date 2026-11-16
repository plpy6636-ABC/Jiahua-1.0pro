@echo off
chcp 65001 > nul
rem 一键训练 1.5B：嘉桦1.0pro 主力配置；需要 20GB 以上显存的显卡（推荐 24GB）
cd /d "%~dp0"

echo ==========================================================
echo   嘉桦1.0pro / 1.5B 训练（实测 1,507,855,104 参数）
echo   需要：约 20GB 显存（全参数训练），8G 内存只够推理
echo ==========================================================
echo.

echo [0/3] 检查显卡……
where py >nul 2>nul
if %errorlevel%==0 (set PY=py -3.13) else (set PY=python)
%PY% -c "import torch; print('CUDA 可用' if torch.cuda.is_available() else 'CUDA 不可用'); print('显存 %.1f GB' % torch.cuda.get_device_properties(0).total_memory/1024**3 if torch.cuda.is_available() else '无显卡')"

echo [1/3] 建词表……
%PY% tokenizer.py build --data data/corpus.txt data/qa.jsonl --out tokenizer.json
if errorlevel 1 goto fail

echo [2/3] 预训练（默认 2 万步，可以 Ctrl+C 随时停，已保存的 ckpt 还能续训）……
%PY% train.py --config configs/1.5b.json --data data/corpus.txt --out_dir out_1.5b --max_steps 20000 --batch_size 1 --grad_accum 16 --seq_len 1024
if errorlevel 1 goto fail

echo [3/3] 问答微调（3000 步）……
%PY% sft.py --ckpt out_1.5b/ckpt_last.pt --data data/qa.jsonl --out_dir out_1.5b_sft --max_steps 3000 --batch_size 2 --seq_len 512 --lr 1e-4
if errorlevel 1 goto fail

echo.
echo 训练完成，接下来双击 一键问答1.5B.bat 就能提问了。
pause
exit /b 0

:fail
echo.
echo 出错了。常见原因：显存不够（需 20GB 以上）、没装 torch、或训练中断后没加 --resume。
pause
exit /b 1
