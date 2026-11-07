"""build_example.py - a three-piece street kit, rebuilt from nothing every run.
Run: blender --background --factory-startup --python-exit-code 1 --python build_example.py -- --out <dir>
Writes <dir>/<module>.glb and <dir>/street_kit.blend, then run verify_glb.py on <dir>."""
import bpy, bmesh, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kitlib_min as K
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)


def extrude_profile(profile_yz, x0, x1):
    """Open extrusion along X (no end caps): its seam edges are boundary edges, so they are never
    bevelled and two tiles meet without a groove."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in profile_yz]
    b = [bm.verts.new((x1, y, z)) for y, z in profile_yz]
    for i in range(len(profile_yz) - 1):
        bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(lo, hi):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector(tuple(lo[i] if v.co[i] < 0 else hi[i] for i in range(3)))
    return bm


def cylinder(r, h, z0=0.0, seg=16):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=h)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, z0 + h / 2))
    return bm


def kerb_4m():
    m = K.Module("st_kerb_4m")
    # profile in (y, z): road side at -Y (module front), kerb top 0.15 m
    m.add(extrude_profile([(-0.6, 0.0), (-0.3, 0.0)], -2.0, 2.0), "ASPHALT")
    m.add(extrude_profile([(-0.3, 0.0), (-0.3, 0.13), (-0.28, 0.15), (0.0, 0.15)], -2.0, 2.0), "CONCRETE")
    m.col_box((-2.0, -0.6, -0.2), (2.0, 0.0, 0.0), tag="road")
    m.col_box((-2.0, -0.3, -0.2), (2.0, 0.0, 0.15), tag="kerb")
    return m.finish(bevel=0.0)          # tiling piece: no bevel at all


def lamp():
    m = K.Module("prop_lamp")
    m.add(cylinder(0.08, 4.5), "METAL_PAINT_GREY")
    m.add(box((-0.08, -0.9, 4.4), (0.08, 0.0, 4.5)), "METAL_PAINT_GREY")
    m.add(box((-0.12, -1.0, 4.3), (0.12, -0.7, 4.4)), "LIGHT")
    m.col_box((-0.1, -0.1, 0.0), (0.1, 0.1, 4.5), kind="convcolonly", tag="pole")
    # light points DOWN: rotate the socket so Godot -Z (= Blender +Y at identity) points to Blender -Z
    m.socket("LIGHT", (0.0, -0.85, 4.28), (-1.5708, 0.0, 0.0))
    return m.finish()


def bench():
    m = K.Module("phys_bench")
    m.props["mass"] = 25.0
    m.add(box((-0.8, -0.2, 0.42), (0.8, 0.2, 0.47)), "WOOD")
    for x in (-0.7, 0.7):
        m.add(box((x - 0.04, -0.18, 0.0), (x + 0.04, 0.18, 0.42)), "METAL_DARK")
    m.col_box((-0.8, -0.2, 0.0), (0.8, 0.2, 0.47), kind="convcolonly", tag="hull")
    return m.finish()


K.reset_scene()
for build in (kerb_4m, lamp, bench):
    root = build()
    K.export_glb(root, os.path.join(OUT, root.name + ".glb"))
K.save_blend(os.path.join(OUT, "street_kit.blend"))
