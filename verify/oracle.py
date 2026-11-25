"""Оракул: вызывает функцию перебора оригинального exe в его собственном процессе.

Позиция и уровни пишутся в память процесса, затем удалённый поток выполняет
`mov eax, depth; call Search; mov [res], eax` и результат читается обратно.
"""
import ctypes
import ctypes.wintypes as wt
import struct
import subprocess
import time

import winutil as w

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.VirtualAllocEx.restype = ctypes.c_void_p
k32.VirtualAllocEx.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_size_t, wt.DWORD, wt.DWORD]
k32.WriteProcessMemory.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                   ctypes.POINTER(ctypes.c_size_t)]
k32.CreateRemoteThread.restype = wt.HANDLE
k32.CreateRemoteThread.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p,
                                   ctypes.c_void_p, wt.DWORD, ctypes.c_void_p]
k32.OpenProcess.restype = wt.HANDLE

BOARD, WLEVEL, BLEVEL, PODD, STOP, CLOSING = 0x4768A4, 0x475534, 0x475530, 0x47552C, 0x475528, 0x475520
SEARCH = {1: 0x46E808, 2: 0x46F39C}
CAPD = {1: 0x1CE5428, 2: 0x1CE5400}
SIMD = {1: 0x1CE5478, 2: 0x1CE5450}
ROOTV = {1: 0x1CE51FC, 2: 0x1CE529C}
CODE = {".": 0, "w": 1, "b": 2, "W": 11, "B": 12}


class Oracle:
    def __init__(self, exe):
        self.p = subprocess.Popen([exe])
        w.main_window(self.p.pid)
        time.sleep(3)
        self.h = k32.OpenProcess(0x1F0FFF, False, self.p.pid)
        self.mem = k32.VirtualAllocEx(self.h, None, 4096, 0x3000, 0x40)

    def write(self, addr, data):
        n = ctypes.c_size_t()
        if not k32.WriteProcessMemory(self.h, ctypes.c_void_p(addr), data, len(data), ctypes.byref(n)):
            raise OSError(ctypes.get_last_error())

    def read(self, addr, size):
        return w.read_mem(self.p.pid, addr, size)

    def search(self, side, depth, podd, board32, level=None):
        cells = [0] * 64
        k = 0
        for j in range(1, 9):
            for i in range(1, 9):
                if (i + j) % 2 == 0:
                    cells[(i - 1) * 8 + (j - 1)] = CODE[board32[k]]
                    k += 1
        self.write(BOARD, struct.pack("<64i", *cells))
        self.write(WLEVEL, struct.pack("<i", level or depth))
        self.write(BLEVEL, struct.pack("<i", level or depth))
        self.write(PODD, struct.pack("<i", podd))
        self.write(STOP, b"\0")
        self.write(CLOSING, b"\0")
        res = self.mem + 0x100
        code = (b"\xB8" + struct.pack("<I", depth) + b"\xBA" + struct.pack("<I", SEARCH[side])
                + b"\xFF\xD2" + b"\xA3" + struct.pack("<I", res) + b"\x31\xC0\xC2\x04\x00")
        self.write(self.mem, code)
        th = k32.CreateRemoteThread(self.h, None, 0, ctypes.c_void_p(self.mem), None, 0, None)
        if not th:
            raise OSError(ctypes.get_last_error())
        k32.WaitForSingleObject(th, 600000)
        k32.CloseHandle(th)
        r = struct.unpack("<i", self.read(res, 4))[0]
        n = struct.unpack("<i", self.read(CAPD[side] + depth * 4, 4))[0]
        if n <= 0:
            n = struct.unpack("<i", self.read(SIMD[side] + depth * 4, 4))[0]
        vals = struct.unpack(f"<{n}i", self.read(ROOTV[side], 4 * n)) if n > 0 else ()
        after = self.read(BOARD, 256)
        assert after == struct.pack("<64i", *cells), "board not restored"
        return r, n, list(vals)

    def close(self):
        self.p.kill()
