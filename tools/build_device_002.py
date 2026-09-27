# DEVICE_002 — MK-02 PRESSURE DRUM
#   blender -b -P tools/build_device_002.py
#
# DEVICE_001 이 속을 다 보여 주는 장치였다면, 이건 닫혀 있는 원통이다.
# 슬릿 사이로 안쪽 주황 불빛만 새어 나온다. 외피를 벗기는 순간이 보상이다.
#
# 새 조작 둘이 여기서 처음 나온다.
#   Slide — 밑동의 안전 걸쇠 두 개를 바깥으로 민다
#   Press — 배출 버튼을 누르면 잠긴다
#
# 의존 이야기: 통 안에 압력이 차 있다. 위 배기구를 먼저 빼야 걸쇠가 움직인다.
# 걸쇠를 못 밀 때 배기구가 붉게 번쩍이므로, 말 없이도 순서가 읽힌다.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zero_blender as z


def build():
    z.wipe()
    p = z.palette()

    z.pedestal(p, radius=0.66, top_radius=0.54, z=-0.720)

    # ── 섀시 (정적) ───────────────────────────────────────────────────
    body = [
        z.cyl(0.52, 0.10, (0, 0, -0.500), p["gun"], verts=40, bevel=0.014),
        z.torus(0.505, 0.032, (0, 0, -0.452), p["steel"], seg=48),
        z.cyl(0.070, 0.40, (0, 0, -0.250), p["steel"], verts=20),   # 스핀들
        z.cyl(0.230, 0.045, (0, 0, -0.140), p["gun"], verts=32),     # 포드 받침
    ]
    for i in range(3):                                               # 내부 기둥
        # 기둥이 포드의 -X 진행 경로에 걸리지 않게 각도를 튼다
        a = i * math.tau / 3.0 + math.radians(90)
        body.append(z.cyl(0.028, 0.72, (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.02),
                          p["steel"], verts=12))
    body += z.gear(0.150, 0.045, -0.330, p["steel"], teeth=12,
                   tooth=(0.050, 0.040), bore=0.045, bore_material=p["dark"])
    body.append(z.tube([(-0.22, 0.16, -0.36), (-0.05, 0.24, -0.18),
                        (0.16, 0.14, -0.02)], 0.030, p["cyan"]))
    for rot in ((math.radians(90), 0, 0), (0, math.radians(90), 0)):
        body.append(z.torus(0.205, 0.010, (0, 0, 0.300), p["steel"], rot=rot, seg=36))
    z.join(body, "Body", recenter=False)

    # ── 외피: 24 조각으로 두른 원통. 3 자리를 비워 슬릿을 만든다 ──────
    shell = []
    seg_count = 24
    for i in range(seg_count):
        if i % 8 == 0:                       # 세로 슬릿 3개
            continue
        a = i * math.tau / seg_count
        shell.append(z.box((0.055, 0.118, 0.740),
                           (math.cos(a) * 0.418, math.sin(a) * 0.418, 0.020),
                           p["panel"], bevel=0.008, rot=(0, 0, a)))
    shell.append(z.cyl(0.462, 0.055, (0, 0, 0.420), p["panel"], verts=40, bevel=0.012))
    shell.append(z.torus(0.452, 0.022, (0, 0, 0.392), p["steel"], seg=48))
    shell.append(z.torus(0.452, 0.030, (0, 0, -0.352), p["steel"], seg=48))
    shell.append(z.cyl(0.175, 0.020, (0, 0, 0.450), p["dark"], verts=32))  # 배기구 자리
    z.join(shell, "OuterShell")

    # ── 배기구 (당기기) ───────────────────────────────────────────────
    vent = [z.cyl(0.165, 0.055, (0, 0, 0.482), p["panel"], verts=32, bevel=0.010)]
    for i in range(6):
        a = i * math.tau / 6.0
        vent.append(z.box((0.022, 0.150, 0.020),
                          (math.cos(a) * 0.075, math.sin(a) * 0.075, 0.506),
                          p["dark"], bevel=0.003, rot=(0, 0, a)))
    vent.append(z.torus(0.170, 0.016, (0, 0, 0.480), p["steel"], seg=36))
    vent.append(z.torus(0.055, 0.014, (0, 0.0, 0.536), p["brass"],
                        rot=(math.radians(90), 0, 0), seg=24))   # 손잡이 고리
    z.name_as(z.join(vent, "TopVent"), "TopVent")

    # ── 안전 걸쇠 둘 (밀기) ───────────────────────────────────────────
    for side, label in ((-1, "SafetyLatchL"), (1, "SafetyLatchR")):
        latch = [
            z.box((0.170, 0.075, 0.062), (side * 0.500, 0, -0.430), p["steel"],
                  bevel=0.008),
            z.cyl(0.055, 0.070, (side * 0.585, 0, -0.430), p["brass"],
                  rot=(0, math.radians(90), 0), verts=20),
            z.box((0.030, 0.090, 0.090), (side * 0.430, 0, -0.430), p["dark"],
                  bevel=0.005),
        ]
        z.join(latch, label)

    # ── 배출 버튼 (누르기) ────────────────────────────────────────────
    btn = [
        z.cyl(0.078, 0.060, (0, -0.505, -0.430), p["amber"],
              rot=(math.radians(90), 0, 0), verts=26),
        z.torus(0.092, 0.020, (0, -0.492, -0.430), p["steel"],
                rot=(math.radians(90), 0, 0), seg=30),
    ]
    z.join(btn, "ReleaseButton")

    # ── 고정 칼라 (돌리기) ────────────────────────────────────────────
    collar = [z.torus(0.245, 0.048, (0, 0, 0.115), p["steel"], seg=48)]
    for i in range(6):
        a = i * math.tau / 6.0
        collar.append(z.box((0.070, 0.048, 0.055),
                            (math.cos(a) * 0.245, math.sin(a) * 0.245, 0.115),
                            p["brass"], bevel=0.005, rot=(0, 0, a)))
    collar.append(z.torus(0.283, 0.012, (0, 0, 0.115), p["cyan"], seg=48))
    z.join(collar, "CollarRing")

    # ── 냉각 포드 (당기기) ────────────────────────────────────────────
    pod = [z.cyl(0.085, 0.30, (-0.14, 0.05, -0.020), p["amber"],
                 rot=(0, math.radians(90), 0), verts=26)]
    for x in (-0.295, 0.015):
        pod.append(z.cyl(0.098, 0.045, (x, 0.05, -0.020), p["steel"],
                         rot=(0, math.radians(90), 0), verts=26))
    pod.append(z.box((0.26, 0.022, 0.030), (-0.14, -0.035, -0.020), p["brass"],
                     bevel=0.004))
    z.join(pod, "CoolantPod")

    # ── 에너지 코어 (길게 누르기) ─────────────────────────────────────
    core = [z.sphere(0.148, (0, 0, 0.300), p["core"])]
    core.append(z.torus(0.152, 0.016, (0, 0, 0.300), p["brass"],
                        rot=(math.radians(90), 0, 0), seg=36))
    core.append(z.cyl(0.026, 0.34, (0, 0, 0.300), p["brass"],
                      rot=(math.radians(90), 0, 0), verts=12))
    z.join(core, "EnergyCore")

    z.export("device_002.glb")


build()
