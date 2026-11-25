"""Сравнение партий по отдельности: последовательности режутся на партии по сбросу номера хода."""
import sys


def games(path):
    res, cur, prev = [], [], 0
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("ROOT"):
            continue
        k, s = line.split()
        k = int(k)
        if k < prev and cur:
            res.append(cur)
            cur = []
        if not cur or cur[-1] != (k, s):
            cur.append((k, s))
        prev = k
    if cur:
        res.append(cur)
    return res


go, gr = games(sys.argv[1]), games(sys.argv[2])
print("games: orig", len(go), "recon", len(gr))
total = 0
for i, (a, b) in enumerate(zip(go, gr)):
    db = dict(b)
    common = [(k, s) for k, s in a if k in db]
    bad = [(k, s, db[k]) for k, s in common if db[k] != s]
    total += len(common)
    last_o, last_r = a[-1][0], b[-1][0]
    complete = len(a) > 1 and len(b) > 1
    print(f"game {i + 1}: orig moves {a[0][0]}..{last_o}, recon 1..{last_r}, "
          f"compared {len(common)}, mismatches {len(bad)}"
          + ("" if complete else " (неполная)"))
    for k, s, r in bad[:3]:
        print("   ", k, s, r)
print("positions compared:", total)
