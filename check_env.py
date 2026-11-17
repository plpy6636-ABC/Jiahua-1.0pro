# -*- coding: utf-8 -*-
"""
check_env.py —— 环境自检

跑不起来的时候先双击 环境自检.bat，把打印出来的内容截图发出来，就能定位原因。

用法：
    py check_env.py                     打印环境 + 文件 + 权重状态
    py check_env.py --require-vram 18   显存不够时以状态码 2 退出（训练脚本靠这个判断）
"""
import argparse
import glob
import json
import os
import platform
import sys

LINE = "-" * 62


def total_ram_gb():
    """返回 (总内存 GB, 可用内存 GB)，拿不到就返回 (None, None)"""
    try:
        if platform.system() == "Windows":
            import ctypes

            class MemStatus(ctypes.Structure):
                _fields_ = [
                    ("dwLength", ctypes.c_ulong),
                    ("dwMemoryLoad", ctypes.c_ulong),
                    ("ullTotalPhys", ctypes.c_ulonglong),
                    ("ullAvailPhys", ctypes.c_ulonglong),
                    ("ullTotalPageFile", ctypes.c_ulonglong),
                    ("ullAvailPageFile", ctypes.c_ulonglong),
                    ("ullTotalVirtual", ctypes.c_ulonglong),
                    ("ullAvailVirtual", ctypes.c_ulonglong),
                    ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
                ]

            st = MemStatus()
            st.dwLength = ctypes.sizeof(MemStatus)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(st))
            return st.ullTotalPhys / 1024 ** 3, st.ullAvailPhys / 1024 ** 3
        if platform.system() == "Linux":
            total = avail = None
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        total = int(line.split()[1]) / 1024 ** 2
                    elif line.startswith("MemAvailable:"):
                        avail = int(line.split()[1]) / 1024 ** 2
            return total, avail
        out = __import__("subprocess").check_output(["sysctl", "-n", "hw.memsize"])
        return int(out.decode().strip()) / 1024 ** 3, None
    except Exception:
        return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--require-vram", type=float, default=None,
                    help="要求的最小显存 GB；不够就以状态码 2 退出")
    args = ap.parse_args()

    # ---------------- 1. 系统与 Python ----------------
    print(LINE)
    print("1. 系统与解释器")
    print(LINE)
    print(f"  操作系统      : {platform.system()} {platform.release()} ({platform.machine()})")
    print(f"  Python 解释器 : {sys.executable}")
    print(f"  Python 版本   : {sys.version.split()[0]}")
    if sys.version_info < (3, 9):
        print("  ✗ 版本太低，PyTorch 2.x 需要 3.9 以上")

    # ---------------- 2. 依赖 ----------------
    print(LINE)
    print("2. 依赖")
    print(LINE)
    try:
        import torch
        print(f"  torch         : {torch.__version__}")
    except Exception as e:
        torch = None
        print(f"  torch         : 没装（{e.__class__.__name__}）")

    # ---------------- 3. 硬件 ----------------
    print(LINE)
    print("3. 硬件")
    print(LINE)
    ram = total_ram_gb()
    if ram[0]:
        extra = f"，当前可用 {ram[1]:.1f} GB" if ram[1] else ""
        print(f"  内存          : 共 {ram[0]:.1f} GB{extra}")
    else:
        print("  内存          : 读不到")

    cuda = bool(torch and torch.cuda.is_available())
    vram = 0.0
    if cuda:
        props = torch.cuda.get_device_properties(0)
        vram = props.total_memory / 1024 ** 3
        print(f"  显卡          : {props.name}")
        print(f"  显存          : {vram:.1f} GB")
    else:
        print("  显卡          : 没有可用 CUDA 显卡")

    # ---------------- 4. 文件是否齐全 ----------------
    print(LINE)
    print("4. 代码文件")
    print(LINE)
    need = ["model.py", "tokenizer.py", "data.py", "train.py", "sft.py", "chat.py",
            "configs/1.5b.json", "configs/0.75b.json", "configs/tiny.json",
            "data/corpus.txt", "data/qa.jsonl"]
    missing = [p for p in need if not os.path.exists(p)]
    if missing:
        print("  ✗ 缺文件：" + ", ".join(missing))
        print("    多半是下载的 ZIP 解压后多套了一层文件夹，或者只解压了一部分")
    else:
        print("  ✓ 11 个代码/配置文件都在")
    print(f"  词表 tokenizer.json : {('已有' if os.path.exists('tokenizer.json') else '还没有（第一次训练自动生成）')}")

    # ---------------- 5. 权重 ----------------
    print(LINE)
    print("5. 训练产物（权重）")
    print(LINE)
    found = sorted(glob.glob("out_*/*.pt"))
    if found:
        for p in found:
            print(f"  ✓ {p}  {os.path.getsize(p) / 1024 ** 2:.1f} MB")
    else:
        print("  还没有任何权重文件（out_*/ 目录里没有 .pt）")

    # ---------------- 6. 结论 ----------------
    print(LINE)
    print("6. 结论与建议")
    print(LINE)
    tips = []
    if torch is None:
        tips.append("· 没装 PyTorch：双击任一脚本会自动安装，或手动执行  %s -m pip install torch" % sys.executable)
    if missing:
        tips.append("· 代码文件不全：重新下载 ZIP，解压后确认目录里能直接看到 model.py、train.py")
    if not found:
        tips.append("· 没有权重是正常现象：权重不随代码下载，必须自己训练一次才会生成")
        if cuda and vram >= 18:
            tips.append("· 你有 %.1f GB 显存，可以直接双击 一键训练1.5B.bat" % vram)
        else:
            tips.append("· 你这台没有 20GB 显存的显卡，训不了 1.5B；先双击 一键试跑.bat 看完整流程")
    if torch is not None and not cuda:
        tips.append("· 没有 CUDA 显卡：推理能跑（走 CPU，慢一点），训练不行")
    if ram[0] and ram[0] < 8:
        tips.append("· 内存不到 8G，1.5B int8 推理会很吃紧")
    if not tips:
        tips.append("· 看起来一切正常，双击 一键问答.bat 就能聊")
    for t in tips:
        print("  " + t)
    print(LINE)

    # ---------------- 7. 训练脚本用的显存门槛检查 ----------------
    if args.require_vram is not None:
        if not cuda:
            print(f"✗ 没有可用显卡，而这一步需要 {args.require_vram:.0f} GB 显存")
            return 2
        if vram < args.require_vram:
            print(f"✗ 当前显存 {vram:.1f} GB，不够 {args.require_vram:.0f} GB")
            return 2
        print(f"✓ 显存 {vram:.1f} GB，满足 {args.require_vram:.0f} GB 的要求")
    return 0


if __name__ == "__main__":
    sys.exit(main())
