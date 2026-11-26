"""Отмена хода в окне Checkers.exe без человека: программа нажимает кнопку режима, по
сценарию щёлкает за человека ходы, выбранные по зерну, и отменяет ходы (Alt+Backspace
сообщением прямо в окно — клавиатура компьютера не трогается). С ключом /fixedseed две сборки
окна обязаны дать одинаковый журнал /log: позиции, возвраты после отмены и оценки корня.

Запуск: undo_play.py <Checkers.exe> <player.exe> <режим> <сценарий> <выход>
  режим: white — человек за белых, black — за чёрных;
  сценарий: строка из m (ход человека) и u (отмена), например mmmumuumm или umumuumm —
            за чёрных первая u отменяет первый ход компьютера, и он ходит заново;
  выход: <выход>.log — журнал игры. Путь — в папке проекта: из временной папки игре писать
         запрещено.
"""
import os
import random
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
gp_src = open(os.path.join(HERE, "gui_play.py"), encoding="utf-8").read().replace("\nmain()\n", "\n")
gp = {}
exec(compile(gp_src, "gui_play", "exec"), gp)
user32 = gp["user32"]

WM_SYSKEYDOWN, WM_SYSKEYUP, VK_BACK = 0x0104, 0x0105, 0x08


def alt_backspace(h):
    """Alt+Backspace: бит 29 lParam — нажат Alt, по нему LCL ставит ssAlt."""
    lp = 1 | (0x0E << 16) | (1 << 29)
    user32.PostMessageW(h, WM_SYSKEYDOWN, VK_BACK, lp)
    time.sleep(0.05)
    user32.PostMessageW(h, WM_SYSKEYUP, VK_BACK, lp | (1 << 30) | (1 << 31))


def wait_stable(log, sec=2.5, limit=30):
    """Ждёт, пока журнал sec секунд не меняется: компьютер ответил и пауза после хода прошла."""
    t0 = time.time()
    last, since = None, time.time()
    while time.time() - t0 < limit:
        n = os.path.getsize(log) if os.path.exists(log) else 0
        if n != last:
            last, since = n, time.time()
        elif time.time() - since >= sec:
            return
        time.sleep(0.1)


def main():
    exe, player, mode, script, out = sys.argv[1:6]
    log = os.path.abspath(out + ".log")
    if os.path.exists(log):
        os.remove(log)
    human = gp["HUMAN_SIDE"][mode]
    game = subprocess.Popen([os.path.abspath(exe), "/fixedseed", "/log=" + log])
    pl = subprocess.Popen([os.path.abspath(player)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          text=True)
    rng = random.Random(5)
    try:
        time.sleep(3)
        wins = [h for h in gp["windows_of"](game.pid) if gp["class_name"](h) != "#32770"]
        main_wnd = max(wins, key=lambda h: gp["size"](h)[0] * gp["size"](h)[1])
        panel = max(gp["children"](main_wnd), key=lambda h: gp["size"](h)[0] * gp["size"](h)[1])
        board = next(h for h in gp["children"](panel) if gp["size"](h) == (402, 402))
        gp["click"](panel, *gp["MODE_BUTTON"][mode])
        wait_stable(log)
        for act in script:
            if act == "m":
                _, pos = gp["positions"](log)[-1]
                pl.stdin.write(f"list {human} {pos}\n")
                pl.stdin.flush()
                move = rng.choice(pl.stdout.readline().split())
                for sq in move.split("-"):
                    gp["click"](board, *gp["square_point"](int(sq[0]), int(sq[1]), human == 2))
                    time.sleep(0.15)
            else:
                alt_backspace(main_wnd)
            wait_stable(log)
            print(act, "->", [k for k, _ in gp["positions"](log)][-6:])
    finally:
        game.kill()
        pl.kill()


main()
