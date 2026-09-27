# DEVICE_003 — MK-03 CALIBRATION CELL
#   blender -b -P tools/build_device_003.py
#
# 여기서 Align 이 처음 나온다. 돌리기와 다른 점: 얼마나 돌렸는가가 아니라
# **어디에 세웠는가**를 본다. 그래서 목표를 눈으로 볼 수 있어야 한다.
#
# 섀시 상판에 눈금을 새기고 목표 눈금 하나만 시안으로 발광시킨다.
# 다이얼에는 황동 포인터를 달았다. 포인터를 시안 눈금에 맞추고 손을 떼면 걸린다.
# 설명 문구 없이 "여기에 맞춰라"가 읽히는지가 이 장치의 시험대다.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zero_blender as z

# 다이얼 두 개의 위치와 목표 각(도, Blender +Z 기준. Godot 에서도 부호가 같다)
DIAL = {"pos": (-0.215, 0.02, 0.300), "target": 55.0, "r": 0.140}
VALVE = {"pos": (0.225, 0.02, 0.300), "target": -80.0, "r": 0.125}


def dial_marks(p, center, radius, target, count=12):
    """눈금 한 벌. 목표 눈금만 시안으로 빛난다. 포인터는 쉴 때 -Y 를 본다."""
    marks = []
    ring_r = radius + 0.058
    for i in range(count):
        deg = -180.0 + i * (360.0 / count)
        a = math.radians(deg)
        # 쉬는 자세(-Y)에서 deg 만큼 +Z 축으로 돈 방향
        dx = math.sin(a)
        dy = -math.cos(a)
        hit = abs(((deg - target + 180.0) % 360.0) - 180.0) < 0.5
        marks.append(z.box((0.018, 0.042, 0.012),
                           (center[0] + dx * ring_r, center[1] + dy * ring_r,
                            center[2] + 0.006),
                           p["steel"], bevel=0.002, rot=(0, 0, a)))
    # 목표 표시. 작은 막대 하나로는 안 읽힌다 —
    # 굵은 눈금 + 그 바깥에 삼각 화살표를 겹쳐 시선을 잡는다.
    a = math.radians(target)
    tx, ty = math.sin(a), -math.cos(a)
    marks.append(z.box((0.040, 0.100, 0.020),
                       (center[0] + tx * ring_r, center[1] + ty * ring_r,
                        center[2] + 0.010),
                       p["cyan"], bevel=0.003, rot=(0, 0, a)))
    marks.append(z.cyl(0.036, 0.018,
                       (center[0] + tx * (ring_r + 0.062),
                        center[1] + ty * (ring_r + 0.062), center[2] + 0.010),
                       p["cyan"], verts=3, rot=(0, 0, a + math.pi)))
    return marks


def build():
    z.wipe()
    p = z.palette()

    z.pedestal(p, radius=0.70, top_radius=0.58, z=-0.700)

    # ── 섀시: 낮고 넓은 콘솔 ──────────────────────────────────────────
    body = [
        z.box((0.98, 0.72, 0.10), (0, 0, -0.470), p["gun"], bevel=0.016),
        z.box((0.94, 0.68, 0.44), (0, 0, -0.190), p["dark"], bevel=0.014),
        z.box((1.00, 0.74, 0.06), (0, 0, 0.270), p["panel"], bevel=0.012),  # 상판: 흰 작업면
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            body.append(z.cyl(0.030, 0.10, (sx * 0.442, sy * 0.310, 0.300),
                              p["steel"], verts=12))
    # 앞면 통풍구
    for i in range(4):
        body.append(z.box((0.62, 0.016, 0.022), (0, -0.342, -0.32 + i * 0.10),
                          p["steel"], bevel=0.003))
    # 다이얼 자리(음푹한 접시)와 눈금
    for d in (DIAL, VALVE):
        body.append(z.cyl(d["r"] + 0.085, 0.020, (d["pos"][0], d["pos"][1], 0.292),
                          p["dark"], verts=36))
        body += dial_marks(p, d["pos"], d["r"], d["target"])
    # 연료봉 소켓과 코어 케이지
    body.append(z.cyl(0.115, 0.045, (0, 0, 0.296), p["dark"], verts=28))
    for rot in ((math.radians(90), 0, 0), (0, math.radians(90), 0)):
        body.append(z.torus(0.152, 0.009, (0, 0, 0.352), p["steel"], rot=rot, seg=32))
    body.append(z.tube([(-0.40, 0.26, -0.28), (-0.10, 0.30, -0.14),
                        (0.28, 0.24, -0.26)], 0.028, p["cyan"]))
    z.join(body, "Body", recenter=False)

    # ── 접근 덮개 (당기기) ────────────────────────────────────────────
    cover = [
        z.box((0.96, 0.72, 0.055), (0, 0, 0.400), p["panel"], bevel=0.016),
        z.box((0.76, 0.52, 0.020), (0, 0, 0.436), p["panel"], bevel=0.010),
    ]
    cover.append(z.cyl(0.120, 0.028, (0, 0, 0.446), p["glass"], verts=32))
    cover.append(z.torus(0.130, 0.016, (0, 0, 0.446), p["steel"], seg=36))
    for sx in (-1, 1):
        cover.append(z.torus(0.052, 0.014, (sx * 0.34, 0.0, 0.452), p["brass"],
                             rot=(math.radians(90), 0, 0), seg=24))
        cover.append(z.box((0.050, 0.050, 0.014), (sx * 0.40, -0.28, 0.434),
                           p["led"], bevel=0.003, rot=(0, 0, math.radians(45))))
    z.join(cover, "AccessCover")

    # ── 보정 다이얼 (맞추기) ──────────────────────────────────────────
    dial = [z.cyl(DIAL["r"], 0.055, (DIAL["pos"][0], DIAL["pos"][1], 0.318),
                  p["steel"], verts=36)]
    for i in range(8):                                   # 손잡이 홈
        a = i * math.tau / 8.0
        dial.append(z.box((0.028, 0.040, 0.058),
                          (DIAL["pos"][0] + math.cos(a) * DIAL["r"],
                           DIAL["pos"][1] + math.sin(a) * DIAL["r"], 0.318),
                          p["gun"], bevel=0.004, rot=(0, 0, a)))
    dial.append(z.box((0.034, 0.145, 0.026),                 # 포인터: 쉴 때 -Y
                      (DIAL["pos"][0], DIAL["pos"][1] - 0.072, 0.352),
                      p["brass"], bevel=0.004))
    dial.append(z.cyl(0.044, 0.040, (DIAL["pos"][0], DIAL["pos"][1], 0.352),
                      p["brass"], verts=20))
    z.join(dial, "CalibrationDial")

    # ── 압력 밸브 (맞추기) ────────────────────────────────────────────
    valve = [z.torus(VALVE["r"], 0.030, (VALVE["pos"][0], VALVE["pos"][1], 0.322),
                     p["steel"], seg=44)]
    for i in range(4):
        a = i * math.tau / 4.0
        valve.append(z.box((0.034, VALVE["r"] * 2.0, 0.026),
                           (VALVE["pos"][0], VALVE["pos"][1], 0.322),
                           p["steel"], bevel=0.004, rot=(0, 0, a)))
    valve.append(z.cyl(0.048, 0.055, (VALVE["pos"][0], VALVE["pos"][1], 0.330),
                       p["gun"], verts=20))
    valve.append(z.box((0.030, 0.140, 0.024),                # 포인터
                       (VALVE["pos"][0], VALVE["pos"][1] - 0.070, 0.352),
                       p["brass"], bevel=0.004))
    z.join(valve, "PressureValve")

    # ── 잠금 바 둘 (밀기) ─────────────────────────────────────────────
    for side, label in ((-1, "LockBarL"), (1, "LockBarR")):
        bar = [
            z.box((0.150, 0.090, 0.070), (side * 0.370, 0.268, 0.330), p["steel"],
                  bevel=0.008),
            z.cyl(0.048, 0.062, (side * 0.445, 0.268, 0.330), p["brass"],
                  rot=(0, math.radians(90), 0), verts=20),
            z.box((0.026, 0.110, 0.100), (side * 0.292, 0.268, 0.330), p["dark"],
                  bevel=0.005),
        ]
        z.join(bar, label)

    # ── 연료봉 (당기기) ───────────────────────────────────────────────
    rod = [z.cyl(0.072, 0.34, (0, 0, 0.400), p["amber"], verts=24)]
    rod.append(z.cyl(0.098, 0.050, (0, 0, 0.560), p["steel"], verts=24))
    rod.append(z.torus(0.062, 0.016, (0, 0, 0.596), p["brass"],
                       rot=(math.radians(90), 0, 0), seg=24))
    rod.append(z.cyl(0.090, 0.040, (0, 0, 0.252), p["steel"], verts=24))
    z.join(rod, "FuelRod")

    # ── 에너지 코어 (길게 누르기) ─────────────────────────────────────
    core = [z.sphere(0.112, (0, 0, 0.352), p["core"])]
    core.append(z.torus(0.116, 0.013, (0, 0, 0.352), p["brass"],
                        rot=(math.radians(90), 0, 0), seg=32))
    z.join(core, "EnergyCore")

    z.export("device_003.glb")


build()
