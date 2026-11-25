"""Матч двух движков шашек (player.exe старый и новый) на одинаковых случайных дебютах.

Запуск: match.py <new.exe> <old.exe> <уровень> <дебютов> [ходов_в_дебюте] [первое_зерно]
Уровень — «5» у обоих или «4,5» (у нового 4, у старого 5); старый игрок — тот же
verify/player.lpr, собранный с прежней копией Engine.pas из другой папки (-Fu).
Каждый дебют играется дважды со сменой цвета. Конец партии: ходить нечем — проигрыш;
троекратное повторение позиции с той же очередью хода — ничья; 15 ходов каждой стороны
(30 полуходов) одними дамками без взятий и без хода шашкой — ничья; 300 полуходов — ничья.
"""
import collections
import os
import random
import subprocess
import sys
import time

new_exe, old_exe, n_open = sys.argv[1], sys.argv[2], int(sys.argv[4])
# уровень: «5» — у обоих, «5,3» — у нового 5, у старого 3
lv = [int(x) for x in sys.argv[3].split(",")]
level_new, level_old = lv[0], lv[-1]
open_plies = int(sys.argv[5]) if len(sys.argv) > 5 else 4
seed0 = int(sys.argv[6]) if len(sys.argv) > 6 else 1
START = "wwwwwwwwwwww........bbbbbbbbbbbb"


class Player:
    def __init__(self, exe, level):
        self.p = subprocess.Popen([os.path.abspath(exe)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.level = level
        self.ms = 0
        self.moves = 0

    def ask(self, line):
        self.p.stdin.write(line + "\n")
        self.p.stdin.flush()
        return self.p.stdout.readline().split()

    def close(self):
        self.p.kill()


def pieces(b):
    return sum(c != "." for c in b)


def men(b):
    return tuple(i for i, c in enumerate(b) if c in "wb"), tuple(c for c in b if c in "wb")


def play(white, black, board, side, game_seed):
    seen = collections.Counter()
    quiet = 0
    ply = 0
    # зёрна для выбора среди равных ходов — из питоновского датчика: соседние зёрна датчика
    # Delphi дают почти одинаковые числа
    grng = random.Random(game_seed)
    while True:
        seen[(board, side)] += 1
        if seen[(board, side)] >= 3:
            return 0, ply, "repetition"
        pl = white if side == 1 else black
        r = pl.ask(f"move {side} {pl.level} {grng.randrange(1, 2 ** 31)} {board}")
        pl.ms += int(r[1])
        pl.moves += 1
        if r[0] == "none":
            return (-1 if side == 1 else 1), ply, "no moves"
        nb = r[0]
        if pieces(nb) < pieces(board) or men(nb) != men(board):
            quiet = 0
        else:
            quiet += 1
        board, side, ply = nb, 3 - side, ply + 1
        if quiet >= 30:
            return 0, ply, "15 king moves"
        if ply >= 300:
            return 0, ply, "300 plies"


new, old = Player(new_exe, level_new), Player(old_exe, level_old)
openings = []
seen_open = set()
orng = random.Random(seed0)
attempts = 0
while len(openings) < n_open and attempts < 100 * n_open:
    attempts += 1
    b, side, ok = START, 1, True
    for k in range(open_plies):
        r = old.ask(f"rand {side} {orng.randrange(1, 2 ** 31)} {b}")
        if r[0] == "none":
            ok = False
            break
        b, side = r[0], 3 - side
    if ok and (b, side) not in seen_open:
        seen_open.add((b, side))
        openings.append((b, side, orng.randrange(1, 2 ** 31)))
print(f"openings: {len(openings)} distinct after {attempts} attempts", flush=True)
score = collections.Counter()
reasons = collections.Counter()
plies_total = 0
t0 = time.time()
try:
    for idx, (b, side, gs) in enumerate(openings):
        for new_white in (True, False):
            w, bl = (new, old) if new_white else (old, new)
            res, plies, why = play(w, bl, b, side, gs * 2 + int(new_white))
            res_new = res if new_white else -res
            score[{1: "win", 0: "draw", -1: "loss"}[res_new]] += 1
            reasons[why] += 1
            plies_total += plies
            print(f"{idx + 1:3d} new={'white' if new_white else 'black'} "
                  f"{'1-0' if res == 1 else '0-1' if res == -1 else '1/2'} {plies} plies, {why}", flush=True)
finally:
    new.close()
    old.close()
games = sum(score.values())
pts = score["win"] + score["draw"] / 2
print(f"level new {level_new} / old {level_old}: {games} games, new: +{score['win']} ={score['draw']} -{score['loss']}, "
      f"score {100 * pts / games:.1f}%")
print("endings:", dict(reasons), f"avg plies {plies_total / games:.0f}")
print(f"time per move: new {new.ms / max(new.moves, 1):.1f} ms, old {old.ms / max(old.moves, 1):.1f} ms; "
      f"wall {time.time() - t0:.0f} s")
