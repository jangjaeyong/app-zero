"""ZERO 장치 모델 공통 헬퍼.

장치를 60개 깎아야 하는 프로젝트라 프리미티브 조립 코드를 한 곳에 모은다.
각 device_XXX.py 는 이걸 import 해서 형태만 기술한다.

규칙 두 가지:
  - 부품마다 독립 Object 이고, 이름이 스테이지 JSON 의 id 와 정확히 같아야 한다
  - Blender 는 Z-up. glTF 로 나가며 Y-up 으로 변환된다
"""

import bpy
import math
import os
import sys

# ── 팔레트 (기획서 7번) ──────────────────────────────────────────────
NAVY     = (0.031, 0.043, 0.075, 1.0)
PANEL_W  = (0.900, 0.908, 0.918, 1.0)
GUNMETAL = (0.105, 0.125, 0.157, 1.0)
DARKGUN  = (0.062, 0.078, 0.102, 1.0)
STEEL    = (0.520, 0.552, 0.596, 1.0)
BRASS    = (0.620, 0.470, 0.235, 1.0)
GLASS    = (0.035, 0.055, 0.075, 1.0)
CYAN     = (0.180, 0.780, 0.980, 1.0)
AMBER    = (1.000, 0.616, 0.180, 1.0)


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


def palette():
    """장치마다 같은 재질 묶음을 쓴다. 색이 프로젝트 안에서 흔들리지 않게."""
    return {
        "panel": mat("M_Panel", PANEL_W, 0.04, 0.34),
        "gun":   mat("M_Gun", GUNMETAL, 0.80, 0.45),
        "dark":  mat("M_Dark", DARKGUN, 0.70, 0.55),
        "steel": mat("M_Steel", STEEL, 1.00, 0.24),
        "brass": mat("M_Brass", BRASS, 1.00, 0.30),
        "glass": mat("M_Glass", GLASS, 0.60, 0.08),
        "base":  mat("M_Base", NAVY, 0.55, 0.50),
        "cyan":  mat("M_Cyan", (0.012, 0.055, 0.090, 1.0), 0.10, 0.22, CYAN, 0.95),
        "amber": mat("M_Amber", (0.240, 0.105, 0.012, 1.0), 0.10, 0.20, AMBER, 0.9),
        "led":   mat("M_Led", (0.240, 0.105, 0.012, 1.0), 0.00, 0.30, AMBER, 1.4),
        "core":  mat("M_Core", (0.320, 0.120, 0.010, 1.0), 0.00, 0.10,
                     (1.0, 0.42, 0.06, 1.0), 1.9),
    }


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


def gear(r, depth, z, material, teeth=10, tooth=(0.066, 0.048), bore=0.0,
         bore_material=None):
    parts = [cyl(r, depth, (0, 0, z), material, verts=28)]
    for i in range(teeth):
        a = i * math.tau / teeth
        parts.append(box((tooth[0], tooth[1], depth),
                         (math.cos(a) * (r + tooth[1] * 0.42),
                          math.sin(a) * (r + tooth[1] * 0.42), z),
                         material, bevel=0.004, rot=(0, 0, a)))
    if bore > 0.0:
        parts.append(cyl(bore, depth * 1.2, (0, 0, z),
                         bore_material or material, verts=18))
    return parts


def pedestal(p, radius=0.62, top_radius=0.50, z=-0.690, feet=8):
    """받침대 3종 세트. Pedestal / PedestalGlow / PedestalTop 이름으로 나간다."""
    name_as(cyl(radius, 0.080, (0, 0, z), p["base"], verts=56), "Pedestal")
    name_as(torus(radius * 0.91, 0.016, (0, 0, z + 0.038), p["cyan"], seg=64),
            "PedestalGlow")
    top = [cyl(top_radius, 0.05, (0, 0, z + 0.062), p["gun"], verts=48)]
    for i in range(feet):
        a = i * math.tau / feet
        top.append(box((0.10, 0.05, 0.035),
                       (math.cos(a) * (radius - 0.10),
                        math.sin(a) * (radius - 0.10), z + 0.020),
                       p["steel"], bevel=0.004, rot=(0, 0, a)))
    join(top, "PedestalTop")


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


def export(filename):
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "game", "assets", "models", filename)
    bpy.ops.object.select_all(action='DESELECT')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_apply=True,
                              export_yup=True, export_cameras=False,
                              export_lights=False, use_selection=False)
    print("ZERO_BUILD_OK", out)
    print("ZERO_OBJECTS", ",".join(sorted(o.name for o in bpy.data.objects)))
    return out


def ensure_importable():
    """blender -b -P 로 돌면 스크립트 폴더가 sys.path 에 없다."""
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)
