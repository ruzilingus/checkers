"""Ввод хода в окне Checkers.exe без человека: программа нажимает кнопку режима и по сценарию
ходит за человека (щелчками или с клавиатуры), отменяет ходы и сбрасывает выбор. Клавиши
посылаются сообщениями прямо в окно — клавиатура компьютера не трогается. С ключом /fixedseed
две сборки окна обязаны дать одинаковый журнал /log: позиции, возвраты после отмены и оценки
корня.

Запуск: scenario_play.py <Checkers.exe> <player.exe> <режим> <сценарий> <выход>
  режим: white — человек за белых, black — за чёрных;
  сценарий — строка действий:
    m — ход щелчками по полям; k — ход с клавиатуры: буква вертикали и цифра горизонтали;
    n — то же с цифрами на цифровом блоке; u — отмена хода (Alt+Backspace);
    x — щелчок по фигуре, Escape и щелчок по полю, куда она могла пойти: после сброса выбора
        ход не делается.
    Ход выбирается из разрешённых по зерну. Например: white mkmnuxmumm, black ukmuxuumm —
    за чёрных первая u отменяет первый ход компьютера, и он ходит заново;
  выход: <выход>.log — журнал игры. Путь — в папке проекта: из временной папки игре писать
         запрещено.
"""
import os
import random
import subprocess
import sys
import time

import gui_play as gp  # лежит рядом: папка скрипта входит в путь поиска модулей

user32 = gp.user32

WM_KEYDOWN, WM_KEYUP, WM_SYSKEYDOWN, WM_SYSKEYUP = 0x0100, 0x0101, 0x0104, 0x0105
VK_BACK, VK_ESCAPE, VK_NUMPAD0 = 0x08, 0x1B, 0x60


def key(h, vk, alt=False):
    """Нажатие клавиши vk; alt — с Alt: бит 29 lParam, по нему LCL ставит ssAlt."""
    lp = 1 | ((1 << 29) if alt else 0)
    user32.PostMessageW(h, WM_SYSKEYDOWN if alt else WM_KEYDOWN, vk, lp)
    time.sleep(0.05)
    user32.PostMessageW(h, WM_SYSKEYUP if alt else WM_KEYUP, vk, lp | (1 << 30) | (1 << 31))
    time.sleep(0.05)


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
    human = gp.HUMAN_SIDE[mode]
    flipped = human == 2
    game = subprocess.Popen([os.path.abspath(exe), "/fixedseed", "/log=" + log])
    pl = subprocess.Popen([os.path.abspath(player)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          text=True)
    rng = random.Random(5)
    try:
        time.sleep(3)
        wins = [h for h in gp.windows_of(game.pid) if gp.class_name(h) != "#32770"]
        main_wnd = max(wins, key=lambda h: gp.size(h)[0] * gp.size(h)[1])
        panel = max(gp.children(main_wnd), key=lambda h: gp.size(h)[0] * gp.size(h)[1])
        board = next(h for h in gp.children(panel) if gp.size(h) == (402, 402))

        def click(sq):
            gp.click(board, *gp.square_point(int(sq[0]), int(sq[1]), flipped))
            time.sleep(0.15)

        gp.click(panel, *gp.MODE_BUTTON[mode])
        wait_stable(log)
        for act in script:
            if act in "mknx":
                _, pos = gp.positions(log)[-1]
                pl.stdin.write(f"list {human} {pos}\n")
                pl.stdin.flush()
                squares = rng.choice(pl.stdout.readline().split()).split("-")
                if act == "m":
                    for sq in squares:
                        click(sq)
                elif act == "x":
                    click(squares[0])
                    key(main_wnd, VK_ESCAPE)
                    click(squares[1])
                else:
                    for sq in squares:
                        key(main_wnd, ord("A") + int(sq[0]) - 1)
                        digit = int(sq[1])
                        key(main_wnd, VK_NUMPAD0 + digit if act == "n" else ord("0") + digit)
            elif act == "u":
                key(main_wnd, VK_BACK, alt=True)
            wait_stable(log)
            print(act, "->", [k for k, _ in gp.positions(log)][-6:])
    finally:
        game.kill()
        pl.kill()


if __name__ == "__main__":
    main()
