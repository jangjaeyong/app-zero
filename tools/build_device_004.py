# DEVICE_004 — MK-04 ROUTING JUNCTION
#   blender -b -P tools/build_device_004.py
#
# 새 조작 셋이 여기서 처음 나온다.
#   Sequence   점화 버튼 셋을 정해진 순서로
#   Route      전원 플러그를 홈을 따라 단자까지
#   Multi-step 코어 클램프는 돌린 다음 뽑아야 한다
#
# Route 는 목표가 눈에 보여야 성립한다. 뒷벽에 홈을 파 넣고 끝에 단자를
# 시안으로 밝혀 뒀다. "이 길을 따라 저기로" 가 말 없이 읽혀야 한다.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zero_blender as z

WALL_Y = 0.310                       # 홈이 파인 뒷벽 안쪽 면
# 홈의 꺾은선 (Blender). 스테이지 JSON 의 route_points 와 반드시 같아야 한다.
ROUTE = [(-0.28, WALL_Y, -0.04), (-0.28, WALL_Y, 0.20), (0.06, WALL_Y, 0.20),
         (0.06, WALL_Y, 0.02), (0.30, WALL_Y, 0.02)]


def channel(p):
    """꺾은선을 따라 파인 홈. 구간마다 납작한 상자를 눕혀 잇는다."""
    parts = []
    for i in range(1, len(ROUTE)):
        a, b = ROUTE[i - 1], ROUTE[i]
        mid = ((a[0] + b[0]) * 0.5, WALL_Y + 0.012, (a[2] + b[2]) * 0.5)
        dx, dz = b[0] - a[0], b[2] - a[2]
        length = math.hypot(dx, dz) + 0.075
        if abs(dx) > abs(dz):
            size = (length, 0.030, 0.075)
        else:
            size = (0.075, 0.030, length)
        parts.append(z.box(size, mid, p["dark"], bevel=0.004))
    # 꺾이는 곳마다 작은 시안 점 — 길이 이어져 있다는 신호
    for pt in ROUTE[1:-1]:
        parts.append(z.cyl(0.020, 0.016, (pt[0], WALL_Y + 0.004, pt[2]),
                           p["cyan"], rot=(math.radians(90), 0, 0), verts=12))
    # 도착 단자 — 여기가 목적지다
    end = ROUTE[-1]
    parts.append(z.torus(0.062, 0.014, (end[0], WALL_Y + 0.004, end[2]),
                         p["cyan"], rot=(math.radians(90), 0, 0), seg=24))
    parts.append(z.cyl(0.048, 0.022, (end[0], WALL_Y + 0.020, end[2]),
                       p["dark"], rot=(math.radians(90), 0, 0), verts=20))
    return parts


def build():
    z.wipe()
    p = z.palette()

    z.pedestal(p, radius=0.68, top_radius=0.56, z=-0.700)

    # ── 섀시: 앞이 열리는 정션 박스 ───────────────────────────────────
    body = [
        z.box((0.94, 0.82, 0.08), (0, 0, -0.470), p["gun"], bevel=0.014),   # 바닥
        z.box((0.94, 0.82, 0.07), (0, 0, 0.470), p["gun"], bevel=0.014),    # 천장
        z.box((0.07, 0.82, 0.86), (-0.435, 0, 0), p["gun"], bevel=0.012),
        z.box((0.07, 0.82, 0.86), (0.435, 0, 0), p["gun"], bevel=0.012),
        z.box((0.88, 0.06, 0.86), (0, 0.375, 0), p["panel"], bevel=0.010),  # 뒷벽
    ]
    body += channel(p)
    # 바깥 껍데기 디테일 — 큰 회색 상자로 보이지 않게
    for sx in (-1, 1):
        body.append(z.box((0.020, 0.70, 0.030), (sx * 0.446, 0, 0.26), p["steel"],
                          bevel=0.003))
        body.append(z.box((0.020, 0.70, 0.030), (sx * 0.446, 0, -0.26), p["steel"],
                          bevel=0.003))
        for sy in (-1, 1):
            body.append(z.cyl(0.026, 0.018, (sx * 0.40, sy * 0.34, 0.470),
                              p["steel"], verts=12))
    body.append(z.box((0.80, 0.030, 0.024), (0, 0, 0.492), p["steel"], bevel=0.004))
    # 뒷벽 잔디테일
    for i in range(3):
        body.append(z.box((0.30, 0.016, 0.018), (-0.20, WALL_Y, -0.30 + i * 0.055),
                          p["steel"], bevel=0.003))
    body.append(z.torus(0.168, 0.009, (0, -0.06, -0.275), p["steel"],
                        rot=(math.radians(90), 0, 0), seg=32))
    body.append(z.cyl(0.050, 0.20, (0, 0.14, -0.40), p["steel"],
                      rot=(math.radians(90), 0, 0), verts=16))
    z.join(body, "Body", recenter=False)

    # ── 전면 덮개 (당기기) ────────────────────────────────────────────
    cover = [
        z.box((0.92, 0.055, 0.88), (0, -0.400, 0), p["panel"], bevel=0.016),
        z.box((0.70, 0.020, 0.66), (0, -0.436, 0), p["panel"], bevel=0.010),
    ]
    cover.append(z.cyl(0.115, 0.028, (0, -0.444, 0.0), p["glass"],
                       rot=(math.radians(90), 0, 0), verts=32))
    cover.append(z.torus(0.125, 0.016, (0, -0.446, 0.0), p["steel"],
                         rot=(math.radians(90), 0, 0), seg=32))
    for sx in (-1, 1):
        cover.append(z.torus(0.050, 0.013, (sx * 0.32, -0.452, -0.30), p["brass"],
                             rot=(0, math.radians(90), 0), seg=20))
    z.join(cover, "AccessCover")

    # ── 점화 버튼 셋 (순서) ───────────────────────────────────────────
    for idx, (label, x) in enumerate((("IgnitionA", -0.26), ("IgnitionB", 0.0),
                                      ("IgnitionC", 0.26))):
        btn = [
            z.cyl(0.062, 0.050, (x, WALL_Y - 0.012, 0.345), p["amber"],
                  rot=(math.radians(90), 0, 0), verts=24),
            z.torus(0.074, 0.016, (x, WALL_Y + 0.002, 0.345), p["steel"],
                    rot=(math.radians(90), 0, 0), seg=26),
        ]
        # 버튼마다 점 개수를 달리해 구분되게 (순서는 시범으로 알려 준다)
        for k in range(idx + 1):
            btn.append(z.cyl(0.009, 0.014, (x - 0.018 + k * 0.018,
                                            WALL_Y - 0.036, 0.345),
                             p["dark"], rot=(math.radians(90), 0, 0), verts=8))
        z.join(btn, label)

    # ── 전원 플러그 (경로) ────────────────────────────────────────────
    start = ROUTE[0]
    plug = [
        z.cyl(0.052, 0.070, (start[0], WALL_Y + 0.030, start[2]), p["brass"],
              rot=(math.radians(90), 0, 0), verts=20),
        z.box((0.090, 0.040, 0.090), (start[0], WALL_Y + 0.062, start[2]),
              p["steel"], bevel=0.006),
        z.cyl(0.026, 0.050, (start[0], WALL_Y + 0.006, start[2]), p["cyan"],
              rot=(math.radians(90), 0, 0), verts=12),
    ]
    z.join(plug, "PowerPlug")

    # ── 코어 클램프 (여러 단계: 돌린 뒤 뽑기) ─────────────────────────
    clamp = [z.torus(0.150, 0.030, (0, -0.06, -0.115), p["steel"], seg=36)]
    for i in range(2):
        a = i * math.pi
        clamp.append(z.box((0.230, 0.055, 0.045),
                           (math.cos(a) * 0.075, -0.06 + math.sin(a) * 0.075, -0.115),
                           p["steel"], bevel=0.006, rot=(0, 0, a)))
    clamp.append(z.cyl(0.045, 0.090, (0, -0.06, -0.070), p["brass"], verts=18))
    clamp.append(z.box((0.028, 0.120, 0.020), (0, 0.015, -0.045), p["led"],
                       bevel=0.003))
    z.join(clamp, "CoreClamp")

    # ── 에너지 코어 ───────────────────────────────────────────────────
    core = [z.sphere(0.118, (0, -0.06, -0.275), p["core"])]
    core.append(z.torus(0.122, 0.013, (0, -0.06, -0.275), p["brass"],
                        rot=(math.radians(90), 0, 0), seg=32))
    z.join(core, "EnergyCore")

    z.export("device_004.glb")


build()
