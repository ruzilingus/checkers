"""Сверка двух сборок: эталон (по умолчанию HEAD) против рабочей копии — движок, окно, снимки.
Для правок, которые не должны менять игру: всё, что сравнивается, обязано совпасть.

Запуск из папки проекта: python verify/compare_builds.py [--ref HEAD] [--quick] [--no-gui]
  --ref     коммит эталона (берётся git archive), по умолчанию HEAD;
  --quick   без долгих партий в окне (gui_play, scenario_play, поддавки, дамка) — минуты 3;
  --no-gui  только движок.
Полный прогон — около 20 минут. Эталон собирается в lib/cmp/ref, рабочая копия — на месте, как
в README. Окно игры открывается на экране и закрывается само: его не трогать. Звук на время
сверки выключается, настройки в реестре потом возвращаются как были. Итог — таблица OK / DIFF;
код выхода 1, если что-то разошлось. Замеры скорости — для сведения, на итог не влияют.
Нужны Lazarus в C:/lazarus, Python 3 и Pillow.

Не проверяется (сообщениями не вызвать): подсветка координат под мышью и белая дамка.
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import hashlib
import io
import os
import random
import shutil
import statistics
import subprocess
import sys
import tarfile
import time
import winreg

from PIL import Image

import gui_play as gp  # лежит рядом: папка скрипта входит в путь поиска модулей

LAZBUILD = "C:/lazarus/lazbuild.exe"
FPC = "C:/lazarus/fpc/3.2.2/bin/x86_64-win64/fpc.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "lib", "cmp")
START = "w" * 12 + "." * 8 + "b" * 12  # начальная позиция строкой (BoardToText)
SETTINGS = r"Software\AppDataLow\Checkers"

results = []  # (группа, проверка, совпало, подробности)


def report(group, name, ok, detail=""):
    results.append((group, name, ok, detail))
    print(f"{'OK  ' if ok else 'DIFF'} {group}: {name} {detail}", flush=True)


def run(args, cwd, **kw):
    # вывод lazbuild и fpc — в кодировке консоли: читается без ошибок, с заменой
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", **kw)


# ---------- сборка ----------

def build(root, tag):
    """Окно (lazbuild) и проверки regress, abcheck, player (fpc из папки дерева)."""
    r = run([LAZBUILD, "Checkers.lpi"], root)
    if r.returncode:
        sys.exit(f"{tag}: lazbuild failed\n{r.stdout[-2000:]}")
    for prog, units in (("regress", "lib/regress"), ("abcheck", "lib/abtest"),
                        ("player", "lib/player")):
        os.makedirs(os.path.join(root, units), exist_ok=True)
        r = run([FPC, "-Mdelphi", "-O2", "-Fu.", "-FU" + units, "-B", f"verify/{prog}.lpr"], root)
        if r.returncode:
            sys.exit(f"{tag}: fpc {prog} failed\n{r.stdout[-2000:]}")


def checkout_ref(ref):
    path = os.path.join(WORK, "ref")
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(path)
    data = subprocess.run(["git", "archive", "--format=tar", ref], cwd=ROOT, capture_output=True,
                          check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data)) as t:
        t.extractall(path, filter="data")
    return path


# ---------- движок ----------

def player_session(exe, commands):
    out = subprocess.run([exe], input="\n".join(commands) + "\n", capture_output=True,
                         text=True).stdout.splitlines()
    return out


def gen_positions(player):
    """Позиции из случайных партий по ходам player rand: (сторона, доска)."""
    p = subprocess.Popen([player], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    res = []
    for g in range(12):
        board, side = START, 1
        for ply in range(30):
            res.append((side, board))
            p.stdin.write(f"rand {side} {g * 1000 + ply} {board}\n")
            p.stdin.flush()
            nxt = p.stdout.readline().strip()
            if nxt == "none":
                break
            board, side = nxt, 3 - side
    p.kill()
    return res


def engine_checks(ref, new, quick):
    exe = lambda root, name: os.path.join(root, "verify", name + ".exe")
    r = run([exe(new, "regress"), "verify/regress_normal.txt"], new)
    last = (r.stdout.strip().splitlines() or ["(нет вывода)"])[-1]
    report("движок", "regress против эталона хэшей", r.returncode == 0, last)
    args = ["300", "3", "5"]
    a = run([exe(ref, "abcheck")] + args, ref).stdout
    b = run([exe(new, "abcheck")] + args, new).stdout
    report("движок", "abcheck 300 позиций, ур. 1-3", a == b and "mismatches: 0" in b, b.strip())
    pos = gen_positions(exe(ref, "player"))
    rng = random.Random(3)
    cmds = []
    for side, board in pos:
        cmds += [f"move {side} {rng.randint(1, 5)} {rng.randint(0, 10 ** 9)} {board}",
                 f"rand {side} {rng.randint(0, 10 ** 9)} {board}", f"list {side} {board}",
                 f"list {3 - side} {board}"]
    strip = lambda lines: [l.rsplit(" ", 1)[0] if c.startswith("move") else l
                           for c, l in zip(cmds, lines)]
    a = strip(player_session(exe(ref, "player"), cmds))
    b = strip(player_session(exe(new, "player"), cmds))
    report("движок", f"player: {len(cmds)} команд на {len(pos)} позициях", a == b)
    if quick:
        return
    # скорость: поочерёдно, по три пары
    l6 = [f"move {side} 6 1 {board}" for side, board in pos]
    times = {"ref": [], "new": []}
    answers = {}
    for _ in range(3):
        for tag, root in (("ref", ref), ("new", new)):
            out = player_session(exe(root, "player"), l6)
            times[tag].append(sum(int(l.rsplit(" ", 1)[1]) for l in out if l.strip()))
            answers[tag] = [l.rsplit(" ", 1)[0] for l in out]
    report("движок", f"ход 6-м уровнем на {len(pos)} позициях", answers["ref"] == answers["new"],
           f"(время, медиана: эталон {statistics.median(times['ref'])} мс, "
           f"новая {statistics.median(times['new'])} мс)")


# ---------- окно ----------

user32, gdi32 = gp.user32, ctypes.WinDLL("gdi32")
user32.PrintWindow.argtypes = [wt.HWND, wt.HDC, wt.UINT]
user32.GetDC.restype = wt.HDC
user32.ReleaseDC.argtypes = [wt.HWND, wt.HDC]
gdi32.CreateCompatibleDC.argtypes = [wt.HDC]
gdi32.CreateCompatibleDC.restype = wt.HDC
gdi32.CreateCompatibleBitmap.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleBitmap.restype = wt.HBITMAP
gdi32.SelectObject.argtypes = [wt.HDC, wt.HGDIOBJ]
gdi32.GetDIBits.argtypes = [wt.HDC, wt.HBITMAP, wt.UINT, wt.UINT, ctypes.c_void_p, ctypes.c_void_p,
                            wt.UINT]
gdi32.DeleteObject.argtypes = [wt.HGDIOBJ]
gdi32.DeleteDC.argtypes = [wt.HDC]
WM_KEYDOWN, WM_KEYUP, VK_ESCAPE, VK_LEFT = 0x0100, 0x0101, 0x1B, 0x25


def capture(h):
    """Снимок окна h через PrintWindow (окно может быть и не сверху)."""
    r = wt.RECT()
    user32.GetWindowRect(h, ctypes.byref(r))
    w, ht = r.right - r.left, r.bottom - r.top
    sdc = user32.GetDC(0)
    dc = gdi32.CreateCompatibleDC(sdc)
    bmp = gdi32.CreateCompatibleBitmap(sdc, w, ht)
    gdi32.SelectObject(dc, bmp)
    user32.PrintWindow(h, dc, 2)
    hdr = (ctypes.c_uint32 * 10)(40, w, (-ht) & 0xFFFFFFFF, 1 | (32 << 16), 0, 0, 0, 0, 0, 0)
    buf = ctypes.create_string_buffer(w * ht * 4)
    gdi32.GetDIBits(dc, bmp, 0, ht, buf, hdr, 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(dc)
    user32.ReleaseDC(0, sdc)
    return Image.frombuffer("RGBA", (w, ht), buf, "raw", "BGRA", 0, 1).convert("RGB")


def digest(img, save=None):
    """Хэш снимка; save — имя, под которым снимок сохраняется в lib/cmp/shots для разбора."""
    if save:
        path = os.path.join(WORK, "shots", save + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)
    return hashlib.md5(img.tobytes()).hexdigest()[:12]


def key(h, vk):
    user32.PostMessageW(h, WM_KEYDOWN, vk, 1)
    user32.PostMessageW(h, WM_KEYUP, vk, 1 | (3 << 30))
    time.sleep(0.3)


class Game:
    """Окно игры с /fixedseed; log — путь журнала /log или None."""

    def __init__(self, exe, log=None):
        args = [exe, "/fixedseed"] + (["/log=" + log] if log else [])
        self.proc = subprocess.Popen(args)
        time.sleep(3)
        wins = [w for w in gp.windows_of(self.proc.pid) if gp.class_name(w) != "#32770"]
        self.wnd = max(wins, key=lambda w: gp.size(w)[0] * gp.size(w)[1])
        self.panel = max(gp.children(self.wnd), key=lambda c: gp.size(c)[0] * gp.size(c)[1])
        self.board = next(c for c in gp.children(self.panel) if gp.size(c) == (402, 402))

    def button(self, name, wait=0.8):
        y = {"auto": 64, "white": 96, "black": 128, "new": 160, "stop": 192, "colors": 224,
             "flip": 256, "poddavki": 288}[name]
        gp.click(self.panel, 502, y)
        time.sleep(wait)

    def dialog(self):
        ws = [w for w in gp.windows_of(self.proc.pid)
              if w != self.wnd and gp.class_name(w) != "#32770"
              and gp.size(w)[0] > 100 and gp.size(w)[1] > 100]
        return max(ws, key=lambda w: gp.size(w)[0] * gp.size(w)[1])

    def close(self):
        self.proc.kill()
        self.proc.wait()


def window_shots(exe, tag):
    """Снимки: запуск, «стоп» + «перевернуть», автоигра + «стоп» + «Заново», окно цветов
    (образцы и значения: открыто, сдвинут красный, после Escape открыто снова), значок
    поддавков. Заголовок и рамка фокуса окна цветов зависят от того, активно ли оно, — в
    сравнение не входят. Снимки сохраняются в lib/cmp/shots/<tag>."""
    g = Game(exe)
    shots = {}
    try:
        shots["запуск"] = digest(capture(g.wnd), f"{tag}/start")
        g.button("stop")
        g.button("flip")
        shots["стоп + перевернуть"] = digest(capture(g.wnd), f"{tag}/flip")
        g.button("flip")
        g.button("auto", 3)
        g.button("stop", 1.5)
        g.button("new", 1)
        shots["автоигра + стоп + Заново"] = digest(capture(g.wnd), f"{tag}/newgame")

        def dialog_parts(name):
            img = capture(g.dialog())
            img.save(os.path.join(WORK, "shots", tag, name + "_full.png"))
            return (digest(img.crop((10, 38, 270, 90)), f"{tag}/{name}_samples")
                    + digest(img.crop((22, 100, 62, 186)), f"{tag}/{name}_values"))

        def red_slider():
            """Верхний ползунок окна цветов; Escape закрывает окно только из ползунка."""
            bars = [c for c in gp.children(g.dialog()) if "trackbar" in gp.class_name(c).lower()]
            def top(c):
                r = wt.RECT()
                user32.GetWindowRect(c, ctypes.byref(r))
                return r.top
            return min(bars, key=top)

        g.button("colors", 1.5)
        shots["окно цветов"] = dialog_parts("colors_open")
        red = red_slider()
        for _ in range(3):
            key(red, VK_LEFT)
        shots["окно цветов, сдвинут красный"] = dialog_parts("colors_moved")
        key(red, VK_ESCAPE)
        g.button("colors", 1.5)
        shots["окно цветов после Escape"] = dialog_parts("colors_reopen")
        key(red_slider(), VK_ESCAPE)
        time.sleep(0.5)
        g.button("poddavki", 1.5)
        shots["значок поддавков"] = digest(capture(g.wnd), f"{tag}/poddavki")
    finally:
        g.close()
    return shots


def blink_frames(exe, mode):
    """Набор кадров мигания шашки (c3 за белых, b6 за чёрных) за 2,5 с."""
    g = Game(exe)
    try:
        g.button(mode, 2.5)
        x, y = (3, 3) if mode == "white" else (2, 6)
        px, py = gp.square_point(x, y, mode == "black")
        gp.click(g.board, px, py)
        frames = set()
        t0 = time.time()
        while time.time() - t0 < 2.5:
            frames.add(digest(capture(g.wnd).crop((34 + px - 25, 50 + py - 25, 34 + px + 25,
                                                   50 + py + 25))))
    finally:
        g.close()
    return frozenset(frames)


def poddavki_auto(exe, tag):
    """Автоигра в поддавки 60 с: позиции журнала."""
    log = os.path.join(WORK, f"podd_{tag}.log")
    if os.path.exists(log):
        os.remove(log)
    g = Game(exe, log)
    try:
        g.button("stop")
        g.button("poddavki")
        g.button("auto", 60)
    finally:
        g.close()
    return gp.positions(log)


def king_image(exe, tag):
    """Автоигра до 52-й позиции, «стоп»: снимки клеток с дамками по последней позиции."""
    log = os.path.join(WORK, f"king_{tag}.log")
    if os.path.exists(log):
        os.remove(log)
    g = Game(exe, log)
    try:
        g.button("auto", 0)
        t0 = time.time()
        while len(gp.positions(log)) < 52 and time.time() - t0 < 120:
            time.sleep(0.05)
        g.button("stop", 2)
        img = capture(g.wnd)
    finally:
        g.close()
    k, board = gp.positions(log)[-1]
    dark = [(i, j) for j in range(1, 9) for i in range(1, 9) if (i + j) % 2 == 0]
    kings = sorted(digest(img.crop((35 + (i - 1) * 50, 51 + (8 - j) * 50, 85 + (i - 1) * 50,
                                    101 + (8 - j) * 50)))
                   for (i, j), ch in zip(dark, board) if ch in "WB")
    return k, board, kings


class Settings:
    """Настройки игры в реестре: на время сверки меняются, потом возвращаются как были."""

    def __enter__(self):
        self.saved = {}
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, SETTINGS) as k:
                for name in ("R", "G", "B", "Sound"):
                    try:
                        self.saved[name] = winreg.QueryValueEx(k, name)[0]
                    except FileNotFoundError:
                        pass
        except FileNotFoundError:
            pass
        return self

    def set(self, **values):
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, SETTINGS) as k:
            for name, v in values.items():
                winreg.SetValueEx(k, name, 0, winreg.REG_SZ, str(v))

    def reset_colors(self):
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, SETTINGS) as k:
            for name in ("R", "G", "B"):
                if name in self.saved:
                    winreg.SetValueEx(k, name, 0, winreg.REG_SZ, self.saved[name])
                else:
                    try:
                        winreg.DeleteValue(k, name)
                    except FileNotFoundError:
                        pass

    def __exit__(self, *exc):
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, SETTINGS) as k:
            for name in ("R", "G", "B", "Sound"):
                if name in self.saved:
                    winreg.SetValueEx(k, name, 0, winreg.REG_SZ, self.saved[name])
                else:
                    try:
                        winreg.DeleteValue(k, name)
                    except FileNotFoundError:
                        pass


def same(group, name, a, b, detail=""):
    report(group, name, a == b, detail)


def gui_checks(ref, new, quick):
    exe_ref, exe_new = os.path.join(ref, "Checkers.exe"), os.path.join(ROOT, "Checkers.exe")
    player = os.path.join(ref, "verify", "player.exe")
    with Settings() as s:
        s.set(Sound=0)
        a, b = window_shots(exe_ref, "ref"), window_shots(exe_new, "new")
        for name in a:
            same("окно", name, a[name], b.get(name))
        for mode in ("white", "black"):
            same("окно", f"кадры мигания ({mode})", blink_frames(exe_ref, mode),
                 blink_frames(exe_new, mode))
        s.set(R=-10, B=3)
        same("окно, цвета R=-10 B=3", "запуск", digest(capture_start(exe_ref)),
             digest(capture_start(exe_new)))
        same("окно, цвета R=-10 B=3", "кадры мигания (white)", blink_frames(exe_ref, "white"),
             blink_frames(exe_new, "white"))
        s.reset_colors()
        if quick:
            return
        k_ref, k_new = king_image(exe_ref, "ref"), king_image(exe_new, "new")
        same("окно", f"дамки на позиции {k_new[0]}", k_ref, k_new)
        p_ref, p_new = poddavki_auto(exe_ref, "ref"), poddavki_auto(exe_new, "new")
        n = min(len(p_ref), len(p_new))
        same("окно", f"автоигра в поддавки, {n} позиций", p_ref[:n], p_new[:n])
        for mode, limit in (("white", "40"), ("black", "40"), ("auto", "120")):
            outs = {}
            for tag, exe in (("ref", exe_ref), ("new", exe_new)):
                out = os.path.join(WORK, f"gui_{tag}_{mode}")
                run([sys.executable, "verify/gui_play.py", exe, player, mode, limit, out], ROOT)
                outs[tag] = (read_lines(out + ".pos"), "\n".join(read_lines(out + ".msg")))
            (pa, ma), (pb, mb) = outs["ref"], outs["new"]
            if mode == "auto":  # автоигра по времени: сравнивается общее начало
                n = min(len(pa), len(pb))
                pa, pb = pa[:n], pb[:n]
            same("окно", f"gui_play {mode}: {len(pb)} позиций и сообщения", (pa, ma), (pb, mb))
        for mode, script in (("white", "mkmnuxmumm"), ("black", "ukmuxuumnk")):
            logs = {}
            for tag, exe in (("ref", exe_ref), ("new", exe_new)):
                out = os.path.join(WORK, f"scen_{tag}_{mode}")
                run([sys.executable, "verify/scenario_play.py", exe, player, mode, script, out],
                    ROOT)
                logs[tag] = read_lines(out + ".log")
            same("окно", f"scenario_play {mode} {script}: журнал", logs["ref"], logs["new"])


def read_lines(path):
    """Строки файла; файла нет (скрипт упал) — пометка, которая с другой сборкой не совпадёт."""
    if not os.path.exists(path):
        return [f"<нет файла {os.path.basename(path)}>"]
    return open(path, encoding="utf-8").read().splitlines()


def capture_start(exe):
    g = Game(exe)
    try:
        return capture(g.wnd)
    finally:
        g.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", default="HEAD")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--no-gui", action="store_true")
    opt = ap.parse_args()
    os.makedirs(WORK, exist_ok=True)
    shutil.rmtree(os.path.join(WORK, "shots"), ignore_errors=True)
    t0 = time.time()
    ref = checkout_ref(opt.ref)
    print(f"эталон {opt.ref} — сборка в {ref}", flush=True)
    build(ref, "ref")
    print("рабочая копия — сборка", flush=True)
    build(ROOT, "new")
    engine_checks(ref, ROOT, opt.quick)
    if not opt.no_gui:
        gui_checks(ref, ROOT, opt.quick)
    bad = [r for r in results if not r[2]]
    print(f"\nИтог: {len(results) - len(bad)} OK, {len(bad)} DIFF, {time.time() - t0:.0f} с")
    for group, name, _, detail in bad:
        print(f"  DIFF {group}: {name} {detail}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
