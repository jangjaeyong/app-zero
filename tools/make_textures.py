#!/usr/bin/env python3
"""ZERO 표면 디테일 텍스처 생성기 (의존성 없음).

    python3 tools/make_textures.py

왜 이렇게 만드나:
  장치를 60개 깎아야 하는데 Blender 에서 UV 를 일일이 펴면 장치당 반나절이 날아간다.
  Godot 의 삼중평면(triplanar) 매핑은 UV 없이 월드 좌표로 텍스처를 감는다.
  대신 **타일링이 완벽해야** 이음매가 보인다. 그래서 격자 인덱스를 모듈러로
  감아서 상하좌우가 딱 맞는 노이즈를 쓴다.

내보내는 것:
  surface_normal.png  미세 흠집 + 결. 노멀맵
  surface_rough.png   때와 얼룩. 거칠기 변화
  surface_grime.png   모서리·홈에 낀 때. 알베도를 살짝 어둡게
"""
import math
import os
import random
import struct
import zlib

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "assets", "textures")
SIZE = 512

random.seed(20260927)


# ── PNG ──────────────────────────────────────────────────────────────
def write_png(path, w, h, rows_rgb):
    raw = b"".join(b"\x00" + bytes(row) for row in rows_rgb)
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return path


# ── 타일링 값 노이즈 ─────────────────────────────────────────────────
def lattice(n, seed):
    rnd = random.Random(seed)
    return [[rnd.random() for _ in range(n)] for _ in range(n)]


def smooth(t):
    return t * t * (3.0 - 2.0 * t)


def noise_layer(size, cells, seed):
    """cells x cells 격자를 size x size 로 부드럽게 늘린다. 상하좌우가 이어진다."""
    g = lattice(cells, seed)
    out = [[0.0] * size for _ in range(size)]
    scale = cells / float(size)
    for y in range(size):
        fy = y * scale
        y0 = int(fy) % cells
        y1 = (y0 + 1) % cells
        ty = smooth(fy - int(fy))
        row = out[y]
        g0, g1 = g[y0], g[y1]
        for x in range(size):
            fx = x * scale
            x0 = int(fx) % cells
            x1 = (x0 + 1) % cells
            tx = smooth(fx - int(fx))
            a = g0[x0] + (g0[x1] - g0[x0]) * tx
            b = g1[x0] + (g1[x1] - g1[x0]) * tx
            row[x] = a + (b - a) * ty
    return out


def fbm(size, octaves, seed, base_cells=4):
    acc = [[0.0] * size for _ in range(size)]
    amp = 1.0
    total = 0.0
    cells = base_cells
    for o in range(octaves):
        layer = noise_layer(size, cells, seed + o * 977)
        for y in range(size):
            ar, lr = acc[y], layer[y]
            for x in range(size):
                ar[x] += lr[x] * amp
        total += amp
        amp *= 0.5
        cells *= 2
    inv = 1.0 / total
    for y in range(size):
        ar = acc[y]
        for x in range(size):
            ar[x] *= inv
    return acc


def add_scratches(height, size, count, depth, length_frac, seed):
    """가늘고 긴 홈. 화면 밖으로 나가면 반대편에서 이어진다."""
    rnd = random.Random(seed)
    for _ in range(count):
        ang = rnd.uniform(0.0, math.tau)
        dx, dy = math.cos(ang), math.sin(ang)
        px = rnd.uniform(0, size)
        py = rnd.uniform(0, size)
        steps = int(size * length_frac * rnd.uniform(0.4, 1.0))
        d = depth * rnd.uniform(0.4, 1.0)
        for s in range(steps):
            x = int(px + dx * s) % size
            y = int(py + dy * s) % size
            height[y][x] -= d
            # 홈 양옆을 살짝만 — 1픽셀 선은 노멀맵에서 안 보인다
            height[y][(x + 1) % size] -= d * 0.45
            height[(y + 1) % size][x] -= d * 0.45
    return height


def to_normal_rows(height, size, strength):
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            hl = height[y][(x - 1) % size]
            hr = height[y][(x + 1) % size]
            hu = height[(y - 1) % size][x]
            hd = height[(y + 1) % size][x]
            nx = (hl - hr) * strength
            ny = (hu - hd) * strength
            nz = 1.0
            inv = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz)
            row += bytes((
                int((nx * inv * 0.5 + 0.5) * 255.0),
                int((ny * inv * 0.5 + 0.5) * 255.0),
                int((nz * inv * 0.5 + 0.5) * 255.0),
            ))
        rows.append(row)
    return rows


def to_gray_rows(field, size, lo, hi):
    rows = []
    span = hi - lo
    for y in range(size):
        row = bytearray()
        for x in range(size):
            v = int(max(0.0, min(1.0, lo + field[y][x] * span)) * 255.0)
            row += bytes((v, v, v))
        rows.append(row)
    return rows


def build():
    os.makedirs(OUT, exist_ok=True)
    made = []

    print("  노멀맵 계산 중...")
    h = fbm(SIZE, 5, 11, base_cells=8)
    # 가공 결 — 한 방향으로 늘린 노이즈. 규칙적인 사인파를 쓰면 골덴 천이 된다.
    grain = fbm(SIZE, 3, 41, base_cells=2)
    for y in range(SIZE):
        for x in range(SIZE):
            # x 를 촘촘히, y 를 성기게 읽어 한 방향으로 늘어난 결을 만든다
            h[y][x] += (grain[y][(x * 7) % SIZE] - 0.5) * 0.10
    add_scratches(h, SIZE, 70, 0.085, 0.45, seed=23)
    add_scratches(h, SIZE, 18, 0.20, 0.14, seed=57)
    made.append(write_png(os.path.join(OUT, "surface_normal.png"), SIZE, SIZE,
                          to_normal_rows(h, SIZE, 4.0)))

    print("  거칠기 맵 계산 중...")
    r = fbm(SIZE, 4, 303, base_cells=3)
    made.append(write_png(os.path.join(OUT, "surface_rough.png"), SIZE, SIZE,
                          to_gray_rows(r, SIZE, 0.62, 1.0)))

    print("  때 맵 계산 중...")
    g = fbm(SIZE, 5, 707, base_cells=6)
    # 얼룩지게 — 중간값을 눌러 대비를 키운다
    for y in range(SIZE):
        for x in range(SIZE):
            v = g[y][x]
            g[y][x] = v * v * (3.0 - 2.0 * v)
    made.append(write_png(os.path.join(OUT, "surface_grime.png"), SIZE, SIZE,
                          to_gray_rows(g, SIZE, 0.74, 1.0)))

    for p in made:
        print("  %-22s %6.1f KB" % (os.path.basename(p), os.path.getsize(p) / 1024.0))
    print("ZERO_TEXTURES_OK")


build()
