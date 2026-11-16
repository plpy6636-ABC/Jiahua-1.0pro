# -*- coding: utf-8 -*-
"""
chat.py —— 嘉桦1.0pro 的问答脚本（推理）

用法：
    # 单问单答
    py -3.13 chat.py --ckpt out_1.5b_sft/ckpt_final.pt --question "你好，你是谁？"

    # 多轮对话（直接回车退出）
    py -3.13 chat.py --ckpt out_1.5b_sft/ckpt_final.pt

    # 只有 8G 内存的笔记本：加 --quant8，权重从约 6GB 降到约 1.7GB
    py -3.13 chat.py --ckpt out_1.5b_sft/ckpt_final.pt --quant8
"""
import argparse
import os
import sys

import torch

from data import BOT_TAG, END_TAG, USER_TAG
from model import GPT, GPTConfig
from tokenizer import CharTokenizer


def split_params(model):
    """量化后 model.parameters() 只剩词向量和 norm，参数量会算少。
    这里按模块名把参数量好好数一遍。"""
    total = 0
    for n, p in model.named_parameters():
        total += p.numel()
    for name, mod in model.named_modules():
        if isinstance(mod, torch.nn.quantized.dynamic.Linear):
            total += mod.weight().numel()
            if mod.bias() is not None:
                total += mod.bias().numel()
    return total


def load_model(ckpt_path, quant8=False, device="auto", verbose=True):
    ck = torch.load(ckpt_path, map_location="cpu", weights_only=False)
    cfg = GPTConfig.from_dict(ck["config"])
    tok = CharTokenizer(ck["tokenizer_chars"])
    model = GPT(cfg)
    model.load_state_dict(ck["model"], strict=False)
    n_params = model.num_params()          # 必须在量化前算，否则会算少

    if device == "auto":
        if torch.cuda.is_available():
            free_gb = torch.cuda.get_device_properties(0).total_memory / 1024**3
            if free_gb >= 4.0:
                device = "cuda"
            else:
                if verbose:
                    print(f"[提示] 显卡显存只有 {free_gb:.1f}G，装不下这个模型，自动改用 CPU（速度会慢，但能跑）")
                device = "cpu"
        else:
            device = "cpu"

    if quant8:
        # 只量化线性层（大头在这里），词向量表保持 fp32
        model = torch.quantization.quantize_dynamic(model, {torch.nn.Linear}, dtype=torch.qint8)
    model.to(device)
    model.eval()

    if verbose:
        print(f"模型已载入：{os.path.basename(ckpt_path)}")
        print(f"  参数 {n_params:,}（{n_params / 1e9:.3f} B）  "
              f"{"int8 量化" if quant8 else "fp32"}  设备 {device}")
    return model, tok, device


def answer(model, tok, device, messages, max_new_tokens=96, temperature=0.7,
           top_k=40, top_p=0.9, repetition_penalty=1.15):
    # 把历史对话拼成模板
    s = ""
    for role, text in messages:
        s += (USER_TAG + text) if role == "user" else (BOT_TAG + text + END_TAG)
    s += BOT_TAG

    ids = tok.encode(s)
    if len(ids) > model.cfg.max_seq_len - max_new_tokens - 4:
        ids = ids[-(model.cfg.max_seq_len - max_new_tokens - 4):]

    idx = torch.tensor([ids], dtype=torch.long, device=device)
    banned = {tok.pad_id, tok.unk_id, tok.bos_id, tok.stoi["<"]}
    out = model.generate(idx, max_new_tokens=max_new_tokens, temperature=temperature,
                         top_k=top_k, top_p=top_p,
                         repetition_penalty=repetition_penalty, banned_ids=banned)

    text = tok.decode(out[0][len(ids):].tolist())
    for stop in (END_TAG, USER_TAG, "<|结束", "<|用户"):
        if stop in text:
            text = text.split(stop)[0]
    return text.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt", default="out_1.5b_sft/ckpt_final.pt")
    ap.add_argument("--quant8", action="store_true", help="int8 量化，8G 内存也能跑")
    ap.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"])
    ap.add_argument("--question", default=None, help="只问一句就退出")
    ap.add_argument("--max_new_tokens", type=int, default=96)
    ap.add_argument("--temperature", type=float, default=0.7)
    ap.add_argument("--top_k", type=int, default=40)
    ap.add_argument("--top_p", type=float, default=0.9)
    ap.add_argument("--repetition_penalty", type=float, default=1.15)
    args = ap.parse_args()

    if not os.path.exists(args.ckpt):
        sys.exit(f"找不到权重文件：{args.ckpt}\n先跑训练脚本（一键训练1.5B.bat）吧")

    model, tok, device = load_model(args.ckpt, args.quant8, args.device)
    gen_kw = dict(max_new_tokens=args.max_new_tokens, temperature=args.temperature,
                  top_k=args.top_k, top_p=args.top_p,
                  repetition_penalty=args.repetition_penalty)

    # 单问单答
    if args.question:
        print(f"用户：{args.question}")
        print(f"助手：{answer(model, tok, device, [("user", args.question)], **gen_kw)}")
        return

    # 多轮对话
    print("=" * 66)
    print("嘉桦1.0pro 问答 —— 输入问题回车，输入 退出 结束（清空 重开对话）")
    print("说中文它就用中文回，说英文它就用英文回")
    print("=" * 66)
    history = []
    while True:
        try:
            q = input("用户：").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n再见")
            break
        if not q:
            continue
        if q in ("退出", "exit", "quit", "q"):
            print("再见")
            break
        if q in ("清空", "clear", "reset"):
            history = []
            print("（对话已清空）")
            continue
        history.append(("user", q))
        reply = answer(model, tok, device, history, **gen_kw)
        history.append(("assistant", reply))
        print(f"助手：{reply}\n")
        if len(history) > 8:              # 只带最近 4 轮，防止超上下文
            history = history[-8:]


if __name__ == "__main__":
    main()
