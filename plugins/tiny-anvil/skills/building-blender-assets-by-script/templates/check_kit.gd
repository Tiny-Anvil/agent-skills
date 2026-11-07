extends SceneTree
## Godot-side check of what the importer actually made of the kit (verify_glb.py only shows how
## Blender reads the GLB). Run after `godot --headless --import`:
##   godot --headless --path <project> --script res://tools/check_kit.gd -- --dir=res://assets/city --roles=ASPHALT,CONCRETE
## Exits 1 on any problem (counted failures, not assert(): release builds strip asserts).

var fails := 0


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dir: String = args.get("dir", "res://assets")
	var roles: PackedStringArray = String(args.get("roles", "")).split(",", false)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "glb":
			_check(dir.path_join(f), f.get_basename(), roles)
	print("[kit] %d problem(s)" % fails)
	quit(1 if fails > 0 else 0)


func _check(path: String, name: String, roles: PackedStringArray) -> void:
	var root: Node = (load(path) as PackedScene).instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var bodies := root.find_children("*", "StaticBody3D", true, false)
	var sockets := root.find_children("SOCKET_*", "Node3D", true, false)
	if meshes.size() != 1 or meshes[0].name != name:
		_fail(name, "expected one MeshInstance3D named %s, got %s" % [name, meshes.map(func(m): return m.name)])
	for b in bodies:
		for cs in b.find_children("*", "CollisionShape3D", true, false):
			var sh: Shape3D = cs.shape
			if name.begins_with("phys_") and not (sh is BoxShape3D or sh is ConvexPolygonShape3D):
				_fail(name, "physics prop has a %s (box/convex only)" % sh.get_class())
	if bodies.is_empty() and not name.begins_with("fx_"):
		_fail(name, "no collision")
	if not roles.is_empty() and meshes.size() == 1:
		var mesh: Mesh = (meshes[0] as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			var rn := mat.resource_name if mat else "<none>"
			if not Array(roles).any(func(r): return rn == r or rn.begins_with(r + "_")):
				_fail(name, "surface %d material '%s' is not a known role" % [i, rn])
	var extras: Dictionary = meshes[0].get_meta("extras", {}) if meshes.size() == 1 else {}
	if name.begins_with("phys_") and not extras.has("mass"):
		_fail(name, "physics prop without extras.mass")
	for s in sockets:
		var t: Transform3D = (s as Node3D).transform
		var parent := s.get_parent()
		while parent and parent != root:
			t = (parent as Node3D).transform * t
			parent = parent.get_parent()
		print("[kit] %s %s pos %s fwd %s" % [name, s.name, t.origin, -t.basis.z])
	root.free()


func _fail(name: String, why: String) -> void:
	fails += 1
	push_error("[kit] %s: %s" % [name, why])
