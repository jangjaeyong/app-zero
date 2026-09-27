# DEVICE_001 — MK-01 CONTAINMENT UNIT
#   blender -b -P tools/build_device_001.py
#
# 설계 의도:
#  - 앞면(-Y)을 열어 둔다. 첫 화면부터 내부 기계가 보여야 "관찰"이 시작된다.
#  - 패널은 면을 덮는 판때기가 아니라 섀시 프레임 안에 끼워진 판이다.
#    가장자리에 어두운 프레임이 남아야 "끼워져 있다"로 읽힌다.
#  - 파워 셀은 앞에서 보이지만 왼쪽으로만 빠진다. 보이는데 못 빼는 상태가
#    좋은 퍼즐 도입이다.
#  - 발광은 절제한다. 기획서 8번: Bloom 과하게 쓰지 않는다.
#
# Blender 는 Z-up, glTF 로 나가며 Y-up 으로 변환된다.
# 부품 이름은 resources/stages/stage_001.json 의 id 와 정확히 같아야 한다.

import bpy
import math
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "assets", "models", "device_001.glb")

NAVY     = (0.031, 0.043, 0.075, 1.0)
PANEL_W  = (0.900, 0.908, 0.918, 1.0)
GUNMETAL = (0.105, 0.125, 0.157, 1.0)
DARKGUN  = (0.062, 0.078, 0.102, 1.0)
STEEL    = (0.520, 0.552, 0.596, 1.0)
BRASS    = (0.620, 0.470, 0.235, 1.0)
GLASS    = (0.035, 0.055, 0.075, 1.0)

CYAN  = (0.180, 0.780, 0.980, 1.0)
AMBER = (1.000, 0.616, 0.180, 1.0)


def wipe():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, base, metallic=0.0, roughness=0.5, emission=None, strength=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = base
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = roughness
    if emission is not None:
        b.inputs["Emission Color"].default_value = emission
        b.inputs["Emission Strength"].default_value = strength
    return m


def _post(obj, material, bevel, smooth):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    if bevel > 0.0:
        b = obj.modifiers.new("bevel", 'BEVEL')
        b.width = bevel
        b.segments = 2
        b.limit_method = 'ANGLE'
        b.angle_limit = math.radians(40)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def box(size, loc, material, bevel=0.010, rot=(0, 0, 0), smooth=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _post(o, material, bevel, smooth)


def cyl(r, depth, loc, material, rot=(0, 0, 0), verts=32, bevel=0.005, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts,
                                        location=loc, rotation=rot)
    return _post(bpy.context.active_object, material, bevel, smooth and verts >= 20)


def torus(major, minor, loc, material, rot=(0, 0, 0), seg=44):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=seg, minor_segments=10,
                                     location=loc, rotation=rot)
    return _post(bpy.context.active_object, material, 0.0, True)


def sphere(r, loc, material, seg=30):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=seg // 2,
                                         location=loc)
    return _post(bpy.context.active_object, material, 0.0, True)


def tube(points, radius, material, seg=8):
    curve = bpy.data.curves.new("tube_curve", 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = radius
    curve.bevel_resolution = 5
    curve.resolution_u = seg
    sp = curve.splines.new('NURBS')
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
    sp.use_endpoint_u = True
    sp.order_u = 3
    obj = bpy.data.objects.new("tube", curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    return _post(bpy.context.active_object, material, 0.0, True)


def name_as(obj, label, recenter=True):
    obj.name = label
    obj.data.name = label + "_mesh"
    if recenter:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    return obj


def join(objs, label, recenter=True):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return name_as(bpy.context.active_object, label, recenter)


def build():
    wipe()

    m_panel = mat("M_Panel",   PANEL_W,  0.04, 0.34)
    m_gun   = mat("M_Gun",     GUNMETAL, 0.80, 0.45)
    m_dark  = mat("M_Dark",    DARKGUN,  0.70, 0.55)
    m_steel = mat("M_Steel",   STEEL,    1.00, 0.24)
    m_brass = mat("M_Brass",   BRASS,    1.00, 0.30)
    m_glass = mat("M_Glass",   GLASS,    0.60, 0.08)
    m_base  = mat("M_Base",    NAVY,     0.55, 0.50)

    m_cyan  = mat("M_Cyan",  (0.012, 0.055, 0.090, 1.0), 0.10, 0.22, CYAN,  0.95)
    m_amber = mat("M_Amber", (0.240, 0.105, 0.012, 1.0), 0.10, 0.20, AMBER, 0.9)
    m_led   = mat("M_Led",   (0.240, 0.105, 0.012, 1.0), 0.00, 0.30, AMBER, 1.4)
    m_core  = mat("M_Core",  (0.320, 0.120, 0.010, 1.0), 0.00, 0.10,
                  (1.0, 0.42, 0.06, 1.0), 1.9)

    # ── 받침대 ────────────────────────────────────────────────────────
    name_as(cyl(0.62, 0.080, (0, 0, -0.690), m_base, verts=56), "Pedestal")
    name_as(torus(0.565, 0.016, (0, 0, -0.652), m_cyan, seg=64), "PedestalGlow")
    ped_top = [cyl(0.50, 0.05, (0, 0, -0.628), m_gun, verts=48)]
    for i in range(8):
        a = i * math.tau / 8.0
        ped_top.append(box((0.10, 0.05, 0.035),
                           (math.cos(a) * 0.52, math.sin(a) * 0.52, -0.670),
                           m_steel, bevel=0.004, rot=(0, 0, a)))
    name_as(join(ped_top, "PedestalTop"), "PedestalTop")

    # ── 섀시: 앞(-Y)이 열린 프레임 ────────────────────────────────────
    body = [
        box((0.86, 0.86, 0.07), (0, 0, -0.400), m_gun, bevel=0.014),   # 바닥
        # 상부는 통판이 아니라 사각 프레임이다. 가운데가 뚫려 있어야
        # 상단 커버를 떼었을 때 기어 락이 드러난다.
        box((0.86, 0.17, 0.06), (0,  0.345, 0.400), m_gun, bevel=0.012),
        box((0.86, 0.17, 0.06), (0, -0.345, 0.400), m_gun, bevel=0.012),
        box((0.17, 0.52, 0.06), ( 0.345, 0, 0.400), m_gun, bevel=0.012),
        box((0.17, 0.52, 0.06), (-0.345, 0, 0.400), m_gun, bevel=0.012),
        box((0.84, 0.05, 0.74), (0,  0.405, 0), m_dark, bevel=0.010),  # 뒷판
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            body.append(box((0.085, 0.085, 0.80),
                            (sx * 0.378, sy * 0.378, 0), m_gun, bevel=0.012))
    # 뒷판 방열 슬릿
    for i in range(5):
        body.append(box((0.58, 0.018, 0.022), (0, 0.378, -0.22 + i * 0.11),
                        m_steel, bevel=0.003))
    # 내부 레일과 브래킷 — 안쪽이 텅 비어 보이지 않게
    body.append(box((0.70, 0.05, 0.045), (0, 0.24, -0.30), m_steel, bevel=0.006))
    body.append(box((0.05, 0.42, 0.045), (-0.30, 0.10, 0.20), m_steel, bevel=0.006))
    body.append(box((0.05, 0.42, 0.045), (0.30, 0.10, 0.20), m_steel, bevel=0.006))
    for sx in (-1, 1):
        body.append(cyl(0.055, 0.07, (sx * 0.24, 0.30, 0.10), m_brass,
                        rot=(math.radians(90), 0, 0), verts=16))
    # 코어 케이지 — 코어를 감싸는 얇은 링 둘. 코어가 빠져도 남는다.
    body.append(torus(0.198, 0.010, (0, 0.05, 0.02), m_steel,
                      rot=(math.radians(90), 0, 0), seg=40))
    body.append(torus(0.198, 0.010, (0, 0.05, 0.02), m_steel,
                      rot=(0, math.radians(90), 0), seg=40))
    name_as(join(body, "Body", recenter=False), "Body", recenter=False)

    # ── 좌측 패널 ─────────────────────────────────────────────────────
    lp = [
        box((0.055, 0.68, 0.68), (-0.405, 0, 0), m_panel, bevel=0.016),
        box((0.022, 0.54, 0.54), (-0.443, 0, 0), m_panel, bevel=0.010),
        box((0.016, 0.30, 0.035), (-0.448, 0.0, -0.24), m_dark, bevel=0.004),
    ]
    lp.append(cyl(0.021, 0.022, (-0.452, -0.22, -0.24), m_led,
                  rot=(0, math.radians(90), 0), verts=16))
    lp.append(cyl(0.085, 0.03, (-0.450, 0.0, 0.17), m_glass,
                  rot=(0, math.radians(90), 0), verts=28))
    lp.append(torus(0.095, 0.014, (-0.452, 0.0, 0.17), m_steel,
                    rot=(0, math.radians(90), 0), seg=32))
    name_as(join(lp, "LeftPanel"), "LeftPanel")

    # ── 우측 패널 ─────────────────────────────────────────────────────
    rp = [
        box((0.055, 0.68, 0.68), (0.405, 0, 0), m_panel, bevel=0.016),
        box((0.022, 0.54, 0.54), (0.443, 0, 0), m_panel, bevel=0.010),
    ]
    rp.append(cyl(0.125, 0.032, (0.450, 0.0, 0.02), m_glass,
                  rot=(0, math.radians(90), 0), verts=32))
    rp.append(torus(0.135, 0.018, (0.452, 0.0, 0.02), m_steel,
                    rot=(0, math.radians(90), 0), seg=36))
    for i in range(3):
        rp.append(box((0.016, 0.22, 0.026), (0.448, 0.0, -0.20 - i * 0.055),
                      m_dark, bevel=0.003))
    name_as(join(rp, "RightPanel"), "RightPanel")

    # ── 상단 커버 ─────────────────────────────────────────────────────
    tc = [
        box((0.78, 0.78, 0.065), (0, 0, 0.532), m_panel, bevel=0.018),
        box((0.60, 0.60, 0.022), (0, 0, 0.572), m_panel, bevel=0.010),
    ]
    tc.append(cyl(0.155, 0.030, (0, 0, 0.582), m_glass, verts=36))
    tc.append(torus(0.168, 0.018, (0, 0, 0.582), m_steel, seg=40))
    tc.append(box((0.055, 0.055, 0.016), (0.225, -0.225, 0.576), m_led,
                  bevel=0.003, rot=(0, 0, math.radians(45))))
    for sx in (-1, 1):
        for sy in (-1, 1):
            tc.append(cyl(0.024, 0.020, (sx * 0.30, sy * 0.30, 0.574),
                          m_steel, verts=12))
    name_as(join(tc, "TopCover"), "TopCover")

    # ── 잠금 링 ───────────────────────────────────────────────────────
    lr = [torus(0.360, 0.044, (0, 0, 0.462), m_steel, seg=56)]
    for i in range(4):
        a = i * math.tau / 4.0 + math.radians(45)
        lr.append(box((0.085, 0.055, 0.052),
                      (math.cos(a) * 0.360, math.sin(a) * 0.360, 0.462),
                      m_brass, bevel=0.006, rot=(0, 0, a)))
    lr.append(torus(0.406, 0.012, (0, 0, 0.462), m_cyan, seg=56))
    name_as(join(lr, "LockRing"), "LockRing")

    # ── 기어 락 ───────────────────────────────────────────────────────
    gl = [cyl(0.185, 0.062, (0, 0, 0.292), m_steel, verts=28)]
    for i in range(10):
        a = i * math.tau / 10.0
        gl.append(box((0.066, 0.048, 0.062),
                      (math.cos(a) * 0.205, math.sin(a) * 0.205, 0.292),
                      m_steel, bevel=0.004, rot=(0, 0, a)))
    gl.append(cyl(0.062, 0.075, (0, 0, 0.292), m_dark, verts=18))
    gl.append(box((0.030, 0.150, 0.020), (0, 0.085, 0.328), m_brass, bevel=0.003))
    name_as(join(gl, "GearLock"), "GearLock")

    # ── 파워 셀 (앞에서 보이지만 왼쪽으로만 빠진다) ───────────────────
    pc = [cyl(0.082, 0.34, (-0.14, 0.02, -0.26), m_amber,
              rot=(0, math.radians(90), 0), verts=26)]
    for x in (-0.305, 0.025):
        pc.append(cyl(0.094, 0.048, (x, 0.02, -0.26), m_steel,
                      rot=(0, math.radians(90), 0), verts=26))
    pc.append(box((0.30, 0.020, 0.030), (-0.14, -0.065, -0.26), m_brass, bevel=0.004))
    name_as(join(pc, "PowerCell"), "PowerCell")

    # ── 냉각 튜브 ─────────────────────────────────────────────────────
    name_as(tube([(-0.05, 0.10, -0.26), (0.02, -0.14, -0.14),
                  (0.20, -0.10, 0.02), (0.38, 0.04, 0.06)],
                 0.040, m_cyan), "CoolingTube")

    # ── 에너지 코어 ───────────────────────────────────────────────────
    core = [sphere(0.132, (0, 0.05, 0.02), m_core)]
    core.append(torus(0.136, 0.016, (0, 0.05, 0.02), m_brass, rot=(math.radians(90), 0, 0), seg=36))
    core.append(cyl(0.026, 0.33, (0, 0.05, 0.02), m_brass, rot=(math.radians(90), 0, 0), verts=12))
    name_as(join(core, "EnergyCore"), "EnergyCore")

    bpy.ops.object.select_all(action='DESELECT')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True,
                              export_yup=True, export_cameras=False,
                              export_lights=False, use_selection=False)
    tris = sum(len(o.data.loop_triangles) if o.type == 'MESH' else 0
               for o in bpy.data.objects)
    print("ZERO_BUILD_OK", OUT)
    print("ZERO_OBJECTS", ",".join(sorted(o.name for o in bpy.data.objects)))


build()
