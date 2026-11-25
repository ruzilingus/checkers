"""Сверка партий «компьютер сам с собой»: оригинал (seed 0, без Randomize) против реконструкции.

Позиции оригинала читаются из его памяти (MoveNo, History), реконструкция пишет их в лог.
Запуск: compare_games.py <orig_patched.exe> <recon.exe> <log> <games> [timeout_s]
"""
import os
import struct
import sys
import time

import winutil as w

orig, recon, log, games = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
timeout = float(sys.argv[5]) if len(sys.argv) > 5 else 900
CODE = {0: ".", 1: "w", 2: "b", 11: "W", 12: "B"}
MOVENO, HIST = 0x475518, 0x4769A4


def enc(blob):
    b = struct.unpack("<64i", blob)
    s = ""
    for j in range(1, 9):
        for i in range(1, 9):
            if (i + j) % 2 == 0:
                s += CODE.get(b[(i - 1) * 8 + (j - 1)], "?")
    return s


ROOT = {  # сторона: (CapCnt, CapList, SimCnt, SimList, RootValues)
    1: (0x1CE0AA8, 0x1CE2BDC, 0x1CE0AB0, 0x1CE4F7C, 0x1CE51FC),
    2: (0x1CE0AA4, 0x1CE0ABC, 0x1CE0AAC, 0x1CE4CFC, 0x1CE529C),
}
roots_o = []


def root_info(pid, side):
    cc, cl, sc, sl, rv = ROOT[side]
    rd = lambda a, n: w.read_mem(pid, a, n)  # noqa: E731
    capn = struct.unpack("<i", rd(cc, 4))[0]
    vals = struct.unpack("<40i", rd(rv, 160))
    parts = []
    if capn > 0:
        for k in range(capn):
            m = struct.unpack("<53i", rd(cl + k * 212, 212))
            ln = m[0]
            parts.append(f"{m[1]}{m[2]}-{m[1 + 2 * ln]}{m[2 + 2 * ln]}={vals[k]}")
        n = capn
    else:
        n = struct.unpack("<i", rd(sc, 4))[0]
        for k in range(n):
            fx, fy, tx, ty = struct.unpack("<4i", rd(sl + k * 16, 16))
            parts.append(f"{fx}{fy}-{tx}{ty}={vals[k]}")
    return f"ROOT {side} {n} " + " ".join(parts)


def start_cvc(p):
    h = w.main_window(p.pid)
    time.sleep(3)
    kids = w.children(h)
    panel1 = max(kids, key=lambda k: (w.rect(k)[2] - w.rect(k)[0]) * (w.rect(k)[3] - w.rect(k)[1]))
    w.click(panel1, 500, 64)  # SpeedButton3 на Panel1: компьютер сам с собой
    return h


if os.path.exists(log):
    os.remove(log)
po = w.launch(orig)
pr = w.launch(recon, "/fixedseed", f"/log={log}")
try:
    start_cvc(po)
    start_cvc(pr)
    seq_o, last, done_o = [], 0, 0
    t0 = time.time()
    while time.time() - t0 < timeout and done_o < games:
        n = struct.unpack("<i", w.read_mem(po.pid, MOVENO, 4))[0]
        if n < last:
            done_o += 1
        if n != last and n > 0:
            seq_o.append((n, enc(w.read_mem(po.pid, HIST + n * 256, 256))))
            if n >= 2:
                roots_o.append(root_info(po.pid, 1 if n % 2 == 0 else 2))
        last = n
        time.sleep(0.05)
    seq_r, roots_r = [], []
    if os.path.exists(log):
        for line in open(log, encoding="utf-8"):
            if line.startswith("ROOT"):
                roots_r.append(line.strip())
                continue
            k, s = line.split()
            seq_r.append((int(k), s))
finally:
    po.kill()
    pr.kill()

print("orig positions:", len(seq_o), "games finished:", done_o)
print("recon positions:", len(seq_r))
m = min(len(seq_o), len(seq_r))
first_diff = next((i for i in range(m) if seq_o[i] != seq_r[i]), None)
if first_diff is None:
    print(f"identical over {m} positions")
else:
    print("first difference at index", first_diff)
    for i in range(max(0, first_diff - 2), min(m, first_diff + 3)):
        print(i, seq_o[i], seq_r[i])
open(log + ".orig.txt", "w").write("\n".join(f"{k} {s}" for k, s in seq_o))
open(log + ".orig_roots.txt", "w").write("\n".join(roots_o))
open(log + ".recon_roots.txt", "w").write("\n".join(roots_r))
# корни: оригинал начат с опозданием — выравниваем по первой совпавшей строке
start = next((i for i, x in enumerate(roots_r) if roots_o and x == roots_o[0]), None)
print("roots orig", len(roots_o), "recon", len(roots_r), "align at", start)
if start is not None:
    for i, ro in enumerate(roots_o):
        if start + i >= len(roots_r):
            break
        if ro != roots_r[start + i]:
            print("first root diff at", i)
            print(" orig :", ro)
            print(" recon:", roots_r[start + i])
            break
    else:
        print("roots identical over", min(len(roots_o), len(roots_r) - start))
