#!/usr/bin/env python3
"""ZERO 연출용 스프라이트 (의존성 없음, RGBA PNG).

    python3 tools/make_fx_textures.py

  bokeh.png  초점 나간 배경 불빛. 가장자리가 살짝 밝은 원반
  smoke.png  증기·연기. 뭉게진 덩어리
  spark.png  불꽃. 가운데가 흰 작은 점
"""
import math
import os
import random
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "assets", "textures")
random.seed(4242)


def write_rgba(path, n, px):
    raw = b"".join(b"\x00" + bytes(v for x in range(n) for v in px[y * n + x])
                   for y in range(n))
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return path


def bokeh(n=128):
    """초점 나간 불빛은 가운데가 아니라 **가장자리가** 조금 더 밝다.
    그래야 렌즈로 본 것처럼 보인다."""
    px = []
    c = n / 2.0
    r_max = c - 1.0
    for y in range(n):
        for x in range(n):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / r_max
            if d >= 1.0:
                px.append((0, 0, 0, 0))
                continue
            a = 1.0 - d
            a = a ** 0.45                      # 가장자리까지 채운 원반
            a *= 0.80 + 0.20 * math.sin(d * math.pi)   # 테두리를 살짝 밝게
            edge = max(0.0, 1.0 - (d - 0.86) / 0.14) if d > 0.86 else 1.0
            a *= edge                          # 바깥을 부드럽게 끊는다
            px.append((255, 255, 255, int(max(0.0, min(1.0, a)) * 255)))
    return n, px


def smoke(n=128):
    """뭉게진 덩어리. 값 노이즈를 원형 마스크로 깎는다."""
    cells = 6
    g = [[random.random() for _ in range(cells)] for _ in range(cells)]
    def sm(t):
        return t * t * (3.0 - 2.0 * t)
    px = []
    c = n / 2.0
    for y in range(n):
        for x in range(n):
            fx, fy = x / n * cells, y / n * cells
            x0, y0 = int(fx) % cells, int(fy) % cells
            x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
            tx, ty = sm(fx - int(fx)), sm(fy - int(fy))
            a0 = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * tx
            a1 = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * tx
            v = a0 + (a1 - a0) * ty
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / (c - 1.0)
            mask = max(0.0, 1.0 - d) ** 1.6
            a = max(0.0, min(1.0, v * 1.25 - 0.28)) * mask
            px.append((255, 255, 255, int(a * 255)))
    return n, px


def spark(n=64):
    px = []
    c = n / 2.0
    for y in range(n):
        for x in range(n):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / (c - 1.0)
            a = max(0.0, 1.0 - d) ** 2.6
            px.append((255, 255, 255, int(min(1.0, a * 1.4) * 255)))
    return n, px


def build():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, fn in (("bokeh", bokeh), ("smoke", smoke), ("spark", spark)):
        n, px = fn()
        made.append(write_rgba(os.path.join(OUT, name + ".png"), n, px))
    for p in made:
        print("  %-16s %6.1f KB" % (os.path.basename(p), os.path.getsize(p) / 1024.0))
    print("ZERO_FX_TEXTURES_OK")


build()
