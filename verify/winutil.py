"""Запуск GUI-программы, поиск её окна, снимок окна (PrintWindow), щелчки и чтение памяти."""
import ctypes
import ctypes.wintypes as wt
import subprocess
import time

from PIL import Image

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32")
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
user32.EnumWindows.argtypes = [WNDENUMPROC, wt.LPARAM]
user32.EnumChildWindows.argtypes = [wt.HWND, WNDENUMPROC, wt.LPARAM]
user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
user32.PrintWindow.argtypes = [wt.HWND, wt.HDC, wt.UINT]
user32.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
user32.SendMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
user32.SendMessageW.restype = ctypes.c_ssize_t
kernel32.OpenProcess.restype = wt.HANDLE
kernel32.ReadProcessMemory.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                       ctypes.POINTER(ctypes.c_size_t)]


def windows_of(pid, visible_only=True):
    res = []

    def cb(h, _):
        p = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(p))
        if p.value == pid and (not visible_only or user32.IsWindowVisible(h)):
            res.append(h)
        return True
    user32.EnumWindows(WNDENUMPROC(cb), 0)
    return res


def rect(h):
    r = wt.RECT()
    user32.GetWindowRect(h, ctypes.byref(r))
    return r.left, r.top, r.right, r.bottom


def class_name(h):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(h, buf, 256)
    return buf.value


def text(h):
    buf = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(h, buf, 512)
    return buf.value


def children(h):
    res = []

    def cb(c, _):
        res.append(c)
        return True
    user32.EnumChildWindows(h, WNDENUMPROC(cb), 0)
    return res


def main_window(pid, timeout=20):
    t0 = time.time()
    while time.time() - t0 < timeout:
        ws = [w for w in windows_of(pid) if (rect(w)[2] - rect(w)[0]) > 300]
        if ws:
            return max(ws, key=lambda w: (rect(w)[2] - rect(w)[0]) * (rect(w)[3] - rect(w)[1]))
        time.sleep(0.2)
    raise TimeoutError("window not found")


def snapshot(h, path):
    l, t, r, b = rect(h)
    w, hh = r - l, b - t
    hdc = user32.GetWindowDC(h)
    mdc = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, hh)
    gdi32.SelectObject(mdc, bmp)
    user32.PrintWindow(h, mdc, 2)

    class BITMAPINFOHEADER(ctypes.Structure):
        _fields_ = [("biSize", wt.DWORD), ("biWidth", wt.LONG), ("biHeight", wt.LONG),
                    ("biPlanes", wt.WORD), ("biBitCount", wt.WORD), ("biCompression", wt.DWORD),
                    ("biSizeImage", wt.DWORD), ("biXPelsPerMeter", wt.LONG),
                    ("biYPelsPerMeter", wt.LONG), ("biClrUsed", wt.DWORD), ("biClrImportant", wt.DWORD)]
    bi = BITMAPINFOHEADER()
    bi.biSize = ctypes.sizeof(bi)
    bi.biWidth, bi.biHeight, bi.biPlanes, bi.biBitCount = w, -hh, 1, 32
    buf = ctypes.create_string_buffer(w * hh * 4)
    gdi32.GetDIBits(mdc, bmp, 0, hh, buf, ctypes.byref(bi), 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mdc)
    user32.ReleaseDC(h, hdc)
    img = Image.frombuffer("RGBA", (w, hh), buf, "raw", "BGRA", 0, 1).convert("RGB")
    img.save(path)
    return img


def launch(exe, *args):
    return subprocess.Popen([exe, *args])


def click(h, x, y, right=False, double=False, ctrl=False, post=False):
    """Щелчок в клиентских координатах окна h (дочернего или верхнего).

    post=True — асинхронно: нужно, если щелчок открывает модальное меню или окно."""
    lp = (y << 16) | (x & 0xFFFF)
    mk = 0x0008 if ctrl else 0
    if right:
        down, up, dbl, btn = 0x0204, 0x0205, 0x0206, 0x0002
    else:
        down, up, dbl, btn = 0x0201, 0x0202, 0x0203, 0x0001
    send = user32.PostMessageW if post else user32.SendMessageW
    send(h, 0x0200, mk, lp)
    send(h, down, btn | mk, lp)
    send(h, up, mk, lp)
    if double:
        send(h, dbl, btn | mk, lp)
        send(h, up, mk, lp)


def read_mem(pid, addr, size):
    h = kernel32.OpenProcess(0x0010 | 0x0400, False, pid)
    buf = ctypes.create_string_buffer(size)
    n = ctypes.c_size_t()
    ok = kernel32.ReadProcessMemory(h, ctypes.c_void_p(addr), buf, size, ctypes.byref(n))
    kernel32.CloseHandle(h)
    if not ok:
        raise OSError(ctypes.get_last_error())
    return buf.raw[:n.value]
