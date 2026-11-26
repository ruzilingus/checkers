"""Игра в окне Checkers.exe без человека: программа нажимает кнопку режима, за человека
щёлкает по доске ходы, выбранные по зерну, закрывает окна сообщений и записывает их текст.
С ключом /fixedseed компьютер ходит одинаково, поэтому две сборки окна (до и после правки)
обязаны дать одинаковые позиции и сообщения.

Запуск: gui_play.py <Checkers.exe> <player.exe> <режим> <предел> <выход>
  режим: white — человек за белых, black — за чёрных (предел — число ходов человека),
         auto — компьютер сам с собой (предел — секунды);
  выход: <выход>.log — лог игры (ключ /log), <выход>.pos — позиции для сравнения: в игре
         с человеком — до последнего его хода (ответ компьютера после него зависит от того,
         успел ли он до остановки), <выход>.msg — сообщения по порядку.
Пути — в папке проекта: из временной папки игре писать запрещено.
"""
import ctypes
import ctypes.wintypes as wt
import os
import random
import subprocess
import sys
import time

user32 = ctypes.WinDLL("user32", use_last_error=True)
WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
user32.EnumWindows.argtypes = [WNDENUMPROC, wt.LPARAM]
user32.EnumChildWindows.argtypes = [wt.HWND, WNDENUMPROC, wt.LPARAM]
user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
user32.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
user32.SendMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]

WM_GETTEXT, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_COMMAND, IDOK = 0x000D, 0x0201, 0x0202, 0x0111, 1
MODE_BUTTON = {"auto": (502, 64), "white": (502, 96), "black": (502, 128)}  # на MainPanel
HUMAN_SIDE = {"white": 1, "black": 2}


def windows_of(pid):
    res = []

    def cb(h, _):
        p = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(p))
        if p.value == pid and user32.IsWindowVisible(h):
            res.append(h)
        return True
    user32.EnumWindows(WNDENUMPROC(cb), 0)
    return res


def children(h):
    res = []

    def cb(c, _):
        res.append(c)
        return True
    user32.EnumChildWindows(h, WNDENUMPROC(cb), 0)
    return res


def size(h):
    r = wt.RECT()
    user32.GetWindowRect(h, ctypes.byref(r))
    return r.right - r.left, r.bottom - r.top


def class_name(h):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(h, buf, 256)
    return buf.value


def text(h):
    """Текст окна чужого процесса: GetWindowText отдаёт только заголовок, текст элемента —
    по WM_GETTEXT."""
    buf = ctypes.create_unicode_buffer(512)
    user32.SendMessageW(h, WM_GETTEXT, 512, ctypes.addressof(buf))
    return buf.value


def click(h, x, y):
    lp = (y << 16) | (x & 0xFFFF)
    user32.PostMessageW(h, WM_LBUTTONDOWN, 1, lp)
    time.sleep(0.05)
    user32.PostMessageW(h, WM_LBUTTONUP, 0, lp)


UIA_TEXT = r"""[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$e = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]%d)
$c = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Text)
foreach ($x in $e.FindAll([System.Windows.Automation.TreeScope]::Descendants, $c)) { $x.Current.Name }
"""


def message_box(pid):
    """Открытое окно сообщения и его текст или (None, ''). Окно — Task Dialog: текст рисует
    DirectUI, поэтому он читается через UI Automation, а не WM_GETTEXT."""
    for h in windows_of(pid):
        if class_name(h) == "#32770":
            out = subprocess.run(["powershell", "-NoProfile", "-Command", UIA_TEXT % h],
                                 capture_output=True, timeout=30)
            return h, " ".join(out.stdout.decode("utf-8", errors="replace").split())
    return None, ""


def positions(log):
    """Позиции из лога игры: [(номер хода, доска)]."""
    if not os.path.exists(log):
        return []
    res = []
    for line in open(log, encoding="utf-8"):
        if not line.startswith("ROOT") and line.strip():
            k, b = line.split()
            res.append((int(k), b))
    return res


def square_point(x, y, flipped):
    """Точка на BoardPanel в центре поля (x, y): картинка доски стоит в BoardPanel со сдвигом 1."""
    if flipped:
        return 1 + (8 - x) * 50 + 25, 1 + (y - 1) * 50 + 25
    return 1 + (x - 1) * 50 + 25, 1 + (8 - y) * 50 + 25


def main():
    exe, player, mode, limit, out = sys.argv[1:6]
    limit = float(limit)
    log, msg_file, pos_file = (os.path.abspath(out + ext) for ext in (".log", ".msg", ".pos"))
    cut = None  # позиций в логе сразу после последнего хода человека
    for f in (log, msg_file, pos_file):
        if os.path.exists(f):
            os.remove(f)
    game = subprocess.Popen([os.path.abspath(exe), "/fixedseed", "/log=" + log])
    pl = subprocess.Popen([os.path.abspath(player)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    messages = []
    rng = random.Random(1)
    try:
        t0 = time.time()
        main_wnd = None
        while main_wnd is None and time.time() - t0 < 20:
            wins = [h for h in windows_of(game.pid) if class_name(h) != "#32770"]
            if wins:
                main_wnd = max(wins, key=lambda h: size(h)[0] * size(h)[1])
            time.sleep(0.2)
        time.sleep(2)
        panel1 = max(children(main_wnd), key=lambda h: size(h)[0] * size(h)[1])
        panel2 = next(h for h in children(panel1) if size(h) == (402, 402))
        click(panel1, *MODE_BUTTON[mode])
        human = HUMAN_SIDE.get(mode)
        moves_done = 0
        last_change, last_len = time.time(), 0
        start = time.time()
        while True:
            if mode == "auto" and time.time() - start >= limit:
                break
            if human and moves_done >= limit:
                break
            if time.time() - start > 3600 or game.poll() is not None:
                raise RuntimeError("game exited or test ran over an hour")
            box, msg = message_box(game.pid)
            if box:
                pos = positions(log)
                messages.append(f"after position {len(pos)}: {msg}")
                time.sleep(0.2)
                user32.PostMessageW(box, WM_COMMAND, IDOK, 0)
                time.sleep(0.5)
                continue
            pos = positions(log)
            if len(pos) != last_len:
                last_len, last_change = len(pos), time.time()
            if not human or not pos or time.time() - last_change < 1.0:
                time.sleep(0.1)
                continue
            k, board = pos[-1]
            side = 1 if k % 2 == 1 else 2
            if side != human:
                time.sleep(0.1)
                continue
            pl.stdin.write(f"list {human} {board}\n")
            pl.stdin.flush()
            legal = pl.stdout.readline().split()
            if not legal:
                time.sleep(0.1)  # проигрыш: окно сообщения вот-вот появится
                continue
            move = rng.choice(legal)
            for sq in move.split("-"):
                click(panel2, *square_point(int(sq[0]), int(sq[1]), human == 2))
                time.sleep(0.15)
            moves_done += 1
            wait = time.time()
            while len(positions(log)) == last_len and time.time() - wait < 5:
                time.sleep(0.05)
            cut = last_len + 1
    finally:
        game.kill()
        pl.kill()
    with open(msg_file, "w", encoding="utf-8") as f:
        f.write("\n".join(messages) + ("\n" if messages else ""))
    pos = positions(log)
    with open(pos_file, "w", encoding="utf-8") as f:
        f.writelines(f"{k} {b}\n" for k, b in (pos[:cut] if cut else pos))
    games = sum(1 for k, _ in pos if k == 1)
    print(f"{mode}: {len(pos)} positions, {games} game starts, {len(messages)} messages")


main()
