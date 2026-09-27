#!/usr/bin/env python3
"""ZERO 런처 아이콘 생성기 (의존성 없음, zlib+struct 로 PNG 직접 씀).

    python3 tools/make_icons.py

4배로 그린 뒤 박스 축소해서 계단을 없앤다.
"""
import math
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "assets", "icons")
SS = 4  # 슈퍼샘플 배율

NAVY  = (11, 14, 24)
CYAN  = (46, 199, 250)
AMBER = (255, 157, 46)


def write_png(path, w, h, px):
    raw = b"".join(b"\x00" + bytes(v for x in range(w) for v in px[y * w + x])
                   for y in range(h))
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return path


def downsample(big, n, factor):
    """n×n RGBA 를 factor 배 줄인다. 알파를 가중치로 premultiply 해서 섞는다."""
    m = n // factor
    out = [(0, 0, 0, 0)] * (m * m)
    inv = 1.0 / (factor * factor)
    for y in range(m):
        for x in range(m):
            r = g = b = a = 0.0
            for dy in range(factor):
                row = (y * factor + dy) * n
                for dx in range(factor):
                    pr, pg, pb, pa = big[row + x * factor + dx]
                    w = pa / 255.0
                    r += pr * w; g += pg * w; b += pb * w; a += pa
            if a > 0.0:
                wsum = a / 255.0
                out[y * m + x] = (int(r / wsum), int(g / wsum), int(b / wsum),
                                  int(a * inv))
            else:
                out[y * m + x] = (0, 0, 0, 0)
    return out


def blend(dst, src, alpha):
    return tuple(int(dst[i] + (src[i] - dst[i]) * alpha) for i in range(3))


def draw(n, rounded_bg, glyph):
    px = [(0, 0, 0, 0)] * (n * n)
    c = n / 2.0
    radius = n * 0.205          # 모서리 둥글기
    ring_r = n * 0.285
    ring_w = n * 0.042
    core_r = n * 0.105
    tick_in, tick_out = n * 0.375, n * 0.468
    tick_w = n * 0.042

    for y in range(n):
        for x in range(n):
            fx, fy = x + 0.5, y + 0.5
            col = None
            a = 0.0

            if rounded_bg:
                # 둥근 사각형 안쪽이면 배경색
                dx = max(abs(fx - c) - (c - radius), 0.0)
                dy = max(abs(fy - c) - (c - radius), 0.0)
                if math.hypot(dx, dy) <= radius:
                    col, a = NAVY, 1.0

            if glyph:
                d = math.hypot(fx - c, fy - c)
                if abs(d - ring_r) <= ring_w * 0.5:
                    col = CYAN if col is None else blend(col, CYAN, 1.0)
                    a = 1.0
                if d <= core_r:
                    col = AMBER if col is None else blend(col, AMBER, 1.0)
                    a = 1.0
                # 십자 눈금 4개
                for ang in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
                    ux, uy = math.cos(ang), math.sin(ang)
                    t = (fx - c) * ux + (fy - c) * uy
                    if tick_in <= t <= tick_out:
                        perp = abs(-(fx - c) * uy + (fy - c) * ux)
                        if perp <= tick_w * 0.5:
                            col = CYAN if col is None else blend(col, CYAN, 1.0)
                            a = 1.0

            if col is not None:
                px[y * n + x] = (col[0], col[1], col[2], int(a * 255))
    return px


def build():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, size, bg, glyph in (
        ("icon_192", 192, True, True),               # 런처 기본
        ("adaptive_foreground_432", 432, False, True),
        ("adaptive_background_432", 432, True, False),
        ("adaptive_monochrome_432", 432, False, True),
    ):
        n = size * SS
        made.append(write_png(os.path.join(OUT, name + ".png"), size, size,
                              downsample(draw(n, bg, glyph), n, SS)))
    for p in made:
        print("  %-30s %5.1f KB" % (os.path.basename(p), os.path.getsize(p) / 1024.0))
    print("ZERO_ICONS_OK")


build()
