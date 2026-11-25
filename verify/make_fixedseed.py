"""Копия оригинального Шашки.exe без вызовов Randomize: датчик случайных чисел стартует с 0.

Запуск: python make_fixedseed.py <Шашки.exe> <копия.exe>
"""
import sys

data = bytearray(open(sys.argv[1], "rb").read())
for va in (0x46FF0F, 0x470297):  # call Randomize в ходе компьютера за белых и за чёрных
    off = va - 0x401000 + 0x400
    rel = int.from_bytes(data[off + 1:off + 5], "little", signed=True)
    assert data[off] == 0xE8 and va + 5 + rel == 0x402858, hex(va)
    data[off:off + 5] = b"\x90" * 5
open(sys.argv[2], "wb").write(data)
print("written", sys.argv[2])
