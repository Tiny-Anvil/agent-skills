"""kitlib_min.py - minimal helpers for script-built game kits (Blender 4.2+ / 5.x, background mode).

Contract (see SKILL.md): metres, Blender Z-up, module FRONT = Blender -Y = Godot +Z.
One GLB per module: ONE render mesh object named after the module, with children
  <module>_<tag>-colonly / -convcolonly   collision proxies (Godot import hints)
  SOCKET_<KIND>_<n>                        empties (identity rotation = faces module front)
Material slot names are ROLES (prefix + optional variant suffix), e.g. ASPHALT, METAL_PAINT_TEAL.
Custom properties (o["mass"] = 25.0) export as glTF extras.
"""
import bpy, bmesh, math, random
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(role, rgba=(0.5, 0.5, 0.5, 1.0), roughness=0.6, metallic=0.0):
    """A placeholder material whose NAME is the contract; colours are only hints for previews."""
    m = bpy.data.materials.get(role) or bpy.data.materials.new(role)
    m.diffuse_color = rgba
    m.roughness = roughness
    m.metallic = metallic
    return m


def box_uv_metres(bm):
    """UV0 = box projection in metres (1 UV unit = 1 m) by dominant face normal."""
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.y, co.z) if ax == 0 else (co.x, co.z) if ax == 1 else (co.x, co.y)


class Module:
    """Collect parts (bmesh + role) into one render mesh, plus collision proxies and sockets."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.roles = []
        self.cols = []
        self.sockets = []
        self.props = {}

    def _role_index(self, role):
        if role not in self.roles:
            self.roles.append(role)
        return self.roles.index(role)

    def add(self, part_bm, role):
        """Merge a part bmesh into the module with one material role."""
        idx = self._role_index(role)
        tmp = bpy.data.meshes.new("tmp")
        part_bm.to_mesh(tmp)
        for p in tmp.polygons:
            p.material_index = idx
        self.bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)

    def col_box(self, lo, hi, kind="colonly", tag="body"):
        bm = bmesh.new()
        r = bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector(tuple(lo[i] if v.co[i] < 0 else hi[i] for i in range(3)))
        me = bpy.data.meshes.new(f"{self.name}_{tag}-{kind}")
        bm.to_mesh(me)
        bm.free()
        self.cols.append(bpy.data.objects.new(me.name, me))

    def socket(self, kind, pos, rot_euler=(0.0, 0.0, 0.0)):
        n = sum(1 for s in self.sockets if s["socket_name"].startswith(f"SOCKET_{kind}_"))
        want = f"SOCKET_{kind}_{n}"
        # Unique in the .blend (several modules may own SOCKET_LIGHT_0); exact name restored at export.
        e = bpy.data.objects.new(f"{want}@{self.name}", None)
        e["socket_name"] = want
        e.empty_display_size = 0.15
        e.location = pos
        e.rotation_euler = rot_euler
        self.sockets.append(e)

    def finish(self, bevel=0.01, ao=True):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        box_uv_metres(self.bm)
        self.bm.to_mesh(me)
        self.bm.free()
        for role in self.roles:
            me.materials.append(material(role))
        root = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(root)
        for k, v in self.props.items():
            root[k] = v
        if bevel > 0:
            # Open boundary edges (tile seams left uncapped) are never bevelled: tiles meet without grooves.
            b = root.modifiers.new("Bevel", "BEVEL")
            b.width = bevel
            b.segments = 2
            b.limit_method = "ANGLE"
            b.harden_normals = True
        for o in self.cols + self.sockets:
            bpy.context.scene.collection.objects.link(o)
            o.parent = root
        if ao:
            bake_ao(root)
        self.root = root
        return root


def bake_ao(ob, dist=0.8, rays=24, floor=0.2, seed=7):
    """Cheap ray-cast AO per face corner into a colour attribute (exported as COLOR_0).
    White = open, dark = cavity. Drive grime/wetness with it in the game shader."""
    me = ob.data
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices for p in me.polygons])
    rnd = random.Random(seed)
    dirs = []
    while len(dirs) < rays:
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
        if 0.05 < d.length <= 1.0:
            dirs.append(d.normalized())
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for p in me.polygons:
        n = p.normal
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co + n * 0.002
            hits = sum(1 for d in dirs if d.dot(n) > 0 and bvh.ray_cast(co, d, dist)[0] is not None)
            up = sum(1 for d in dirs if d.dot(n) > 0) or 1
            a = max(floor, 1.0 - hits / up)
            attr.data[li].color = (a, a, a, 1.0)
    me.color_attributes.active_color = attr


def export_glb(root, path):
    """Export ONE module with explicit options; options a given Blender lacks are dropped, not guessed."""
    want = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                export_yup=True, export_extras=True, export_materials="EXPORT", export_normals=True,
                export_texcoords=True, export_tangents=False, export_vertex_color="ACTIVE",
                export_colors=True, export_cameras=False, export_lights=False, export_animations=False)
    have = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
    # Critical options must exist (a renamed option would silently drop COLOR_0 or the extras);
    # vertex colours are export_vertex_color in newer exporters, export_colors in older ones.
    missing = {"export_yup", "export_apply", "export_extras"} - have
    if not ({"export_vertex_color", "export_colors"} & have):
        missing.add("export_vertex_color|export_colors")
    if missing:
        raise SystemExit(f"glTF exporter lacks critical options {sorted(missing)}: check this Blender's exporter")
    opts = {k: v for k, v in want.items() if k in have}
    socks = [o for o in root.children if "socket_name" in o]
    for sk in socks:
        other = bpy.data.objects.get(sk["socket_name"])
        if other is not None and other != sk:
            other.name = sk["socket_name"] + "@_parked"
        sk.name = sk["socket_name"]
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in [root] + list(root.children):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(**opts)
    for sk in socks:
        sk.name = sk["socket_name"] + "@" + root.name
    print("EXPORTED", path)


def save_blend(path):
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    print("SAVED", path)
