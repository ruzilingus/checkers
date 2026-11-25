"""Дифференциальная сверка движков: оригинал (оракул в его процессе) против реконструкции.

Запуск: fuzz.py <orig.exe> <engtest.exe> <count> <depths> [seed] [pieces_max]
"""
import random
import subprocess
import sys

from oracle import Oracle

orig, eng, count, depths = sys.argv[1], sys.argv[2], int(sys.argv[3]), [int(x) for x in sys.argv[4].split(",")]
seed = int(sys.argv[5]) if len(sys.argv) > 5 else 1
pmax = int(sys.argv[6]) if len(sys.argv) > 6 else 8
rnd = random.Random(seed)

DARK = [(i, j) for j in range(1, 9) for i in range(1, 9) if (i + j) % 2 == 0]


def rand_board():
    cells = {sq: "." for sq in DARK}
    free = DARK[:]
    rnd.shuffle(free)
    for side in "wb":
        for _ in range(rnd.randint(1, pmax)):
            sq = free.pop()
            king = rnd.random() < 0.3
            if not king and ((side == "w" and sq[1] == 8) or (side == "b" and sq[1] == 1)):
                king = True
            cells[sq] = side.upper() if king else side
    return "".join(cells[sq] for sq in DARK)


def show(b):
    rows = []
    k = 0
    grid = {}
    for sq in DARK:
        grid[sq] = b[k]
        k += 1
    for j in range(8, 0, -1):
        rows.append(f"{j} " + " ".join(grid.get((i, j), " ") for i in range(1, 9)))
    rows.append("  a b c d e f g h")
    return "\n".join(rows)


cases = []
if len(sys.argv) > 7:
    for line in open(sys.argv[7]):
        if line.strip():
            s, d, p, b = line.split()
            cases.append((int(s), int(d), int(p), b))
while len(cases) < count:
    cases.append((rnd.choice([1, 2]), rnd.choice(depths), rnd.choice([0, 0, 0, 1]), rand_board()))

o = Oracle(orig)
pe = subprocess.Popen([eng], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
bad = 0
try:
    for idx, (side, depth, podd, b) in enumerate(cases):
        ro = o.search(side, depth, podd, b)
        pe.stdin.write(f"{side} {depth} {podd} {b}\n")
        pe.stdin.flush()
        parts = list(map(int, pe.stdout.readline().split()))
        rr = (parts[0], parts[1], parts[2:])
        if ro != rr:
            bad += 1
            print(f"MISMATCH #{idx}: side={side} depth={depth} podd={podd} board={b}")
            print(show(b))
            print(" orig :", ro)
            print(" recon:", rr)
            if bad >= 3:
                break
finally:
    o.close()
    pe.kill()
print(f"checked {idx + 1} cases, mismatches: {bad}")
