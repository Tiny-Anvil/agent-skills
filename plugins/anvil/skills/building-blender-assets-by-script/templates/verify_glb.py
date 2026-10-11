"""verify_glb.py - re-import every GLB in a directory into an EMPTY scene and report what Godot will get.
Run: blender --background --factory-startup --python-exit-code 1 --python verify_glb.py -- \
        --dir <glb dir> --report <report.md> [--roles ASPHALT,CONCRETE,...] [--budgets budgets.json]
budgets.json: {"st_": 400, "prop_": 3000, "phys_": 3000}  (longest matching name prefix wins)
Positions and axes are printed in GODOT space: Godot (x, y, z) = Blender (x, z, -y); a node's Godot
forward (-Z) is its Blender +Y axis. Exits non-zero when any rule is violated."""
import bpy, glob, json, os, sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


DIR = opt("--dir", ".")
REPORT = opt("--report", os.path.join(DIR, "verify_report.md"))
ROLES = [r for r in (opt("--roles", "") or "").split(",") if r]
BUDGETS = json.load(open(opt("--budgets"))) if opt("--budgets") else {}


def g(v):
    """Blender vector -> Godot tuple."""
    return (round(v.x, 4), round(v.z, 4), round(-v.y, 4))


def budget_for(name):
    keys = [k for k in BUDGETS if name.startswith(k)]
    return BUDGETS[max(keys, key=len)] if keys else None


def inspect(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    name = os.path.splitext(os.path.basename(path))[0]
    r = dict(name=name, tris=0, mats=set(), sockets=[], cols=[], col0=False, extras={}, bones=0,
             actions=[], problems=[], render_meshes=[])
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in bpy.data.objects:
        if o.type == "EMPTY" and o.name.startswith("SOCKET_"):
            fwd = o.matrix_world.to_3x3().col[1].normalized()
            r["sockets"].append((o.name, g(o.matrix_world.translation), g(fwd)))
        elif o.type == "MESH" and ("-colonly" in o.name or "-convcolonly" in o.name):
            r["cols"].append(o.name)
        elif o.type == "MESH":
            r["render_meshes"].append(o.name)
            me = o.data
            r["tris"] += sum(len(p.vertices) - 2 for p in me.polygons)
            r["mats"].update(m.name.split(".")[0] for m in me.materials if m)
            r["col0"] = r["col0"] or len(me.color_attributes) > 0
            for v in me.vertices:
                w = o.matrix_world @ v.co
                for i, c in enumerate(g(w)):
                    lo[i] = min(lo[i], c)
                    hi[i] = max(hi[i], c)
        elif o.type == "ARMATURE":
            r["bones"] = len(o.data.bones)
        for k in o.keys():
            if k not in ("_RNA_UI",) and not k.startswith("glTF"):
                r["extras"][f"{o.name}.{k}"] = o[k]
    for a in bpy.data.actions:
        fr = a.frame_range
        r["actions"].append((a.name, round((fr[1] - fr[0]) / bpy.context.scene.render.fps, 3)))
    r["aabb_godot"] = (tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi))
    # rules
    if r["render_meshes"] != [name]:
        r["problems"].append(f"render meshes {r['render_meshes']} != [{name}]")
    if not r["cols"] and not name.startswith("fx_"):
        r["problems"].append("no collision proxy")
    if ROLES:
        for m in r["mats"]:
            if not any(m == role or m.startswith(role + "_") for role in ROLES):
                r["problems"].append(f"material '{m}' is not a known role")
    b = budget_for(name)
    if b is not None and r["tris"] > b:
        r["problems"].append(f"{r['tris']} tris > budget {b}")
    if lo[1] < -0.01 and not name.startswith("st_"):
        r["problems"].append(f"geometry below the origin plane (min y {lo[1]:.3f}): origin not on the ground")
    return r


rows = [inspect(p) for p in sorted(glob.glob(os.path.join(DIR, "*.glb")))]
lines = ["# Export verification (re-imported in an empty scene)", "",
         "| module | tris | materials | collision | sockets (Godot pos / fwd) | COLOR_0 | extras | problems |",
         "|---|---|---|---|---|---|---|---|"]
for r in rows:
    socks = "<br>".join(f"{n} {p} fwd {f}" for n, p, f in r["sockets"]) or "-"
    lines.append(f"| {r['name']} | {r['tris']} | {', '.join(sorted(r['mats']))} | {len(r['cols'])} | {socks} | "
                 f"{'yes' if r['col0'] else 'no'} | {r['extras'] or '-'} | {'; '.join(r['problems']) or 'ok'} |")
    if r["bones"] or r["actions"]:
        lines.append(f"|  ↳ rig | bones {r['bones']} | actions {r['actions']} | | | | | |")
with open(REPORT, "w") as f:
    f.write("\n".join(lines) + "\n")
print("\n".join(lines))
bad = sum(1 for r in rows if r["problems"])
print(f"VERIFY {len(rows)} modules, {bad} with problems -> {REPORT}")
sys.exit(1 if bad else 0)
