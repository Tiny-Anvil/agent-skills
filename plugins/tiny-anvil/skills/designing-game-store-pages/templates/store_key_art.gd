extends Bot
## Key-art renders for the store kit: posed views of the REAL game boot, rendered through a SubViewport that
## shares the game's World3D. Any size (not limited by the window), and no HUD (the HUD lives on the main
## viewport's canvas). Nodes in group "store_hide" (3D labels, debug gizmos, nameplates) are hidden while rendering.
## Put it in res://tests/scenarios/ and run it windowed (never --headless) through `capture.sh keyart`, which
## passes an absolute --out (a relative one resolves against the project). Add --views=wide,tall to limit the set.
## Edit SHOTS for the project: [name, size, camera position, look-at point, fov, actor position (or null), yaw deg].
## One view per capsule shape, because a render only has slack on one axis once it covers a panel:
##   wide   16:9   main capsule, page background, itch cover          subject centred or slightly right
##   banner ~2.1:1 header, small and library-header capsules           subject inside the right 40% (centre ~75%):
##                                                                     the logo takes the left 55%
##   hero   3.1:1  library hero (no words)                             subject inside the centred 860x380 safe area
##   tall   2:3    vertical and library capsules                       subject between 15% and 65% of the height:
##                                                                     the vertical capsule (5:6) crops ~10% top and
##                                                                     bottom; the logo goes in the lower third
## Render at about 2x the largest capsule a view serves (the hero is already 3840 wide: render it 1:1).

const SHOTS := [
	["wide", Vector2i(3840, 2160), Vector3(-1, 3, 8), Vector3(-0.6, 1, 0), 50.0, Vector3(0, 0, 0), 20.0],
	["banner", Vector2i(3840, 1800), Vector3(-2.5, 2.2, 6.5), Vector3(-2.6, 1.1, 0), 45.0, Vector3(0, 0, 0), 20.0],
	["hero", Vector2i(3840, 1240), Vector3(0, 2.5, 9), Vector3(0, 1, 0), 40.0, Vector3(0, 0, 0), 20.0],
	["tall", Vector2i(2000, 3000), Vector3(0, 2.4, 5.5), Vector3(0, 0.6, 0), 45.0, Vector3(0, 0, 0), 20.0],
]
const SETTLE_TICKS := 90


func run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("key art needs a real renderer: run windowed, not --headless")
		return
	var only := Harness.arg("views", "")
	for s in SHOTS:
		if only != "" and not only.split(",").has(s[0]):
			continue
		if s[5] != null:
			actor.global_position = s[5]
			actor.global_rotation = Vector3(0, deg_to_rad(s[6]), 0)
			if actor.has_method("reset_physics_interpolation"):
				actor.reset_physics_interpolation()
		await wait(SETTLE_TICKS)
		var path: String = Harness.out_dir.path_join("keyart_%s.png" % s[0])
		if await render(s[1], s[2], s[3], s[4], path):
			results["keyart_" + s[0]] = path
		else:
			fail("render failed: " + s[0])


func render(size: Vector2i, pos: Vector3, target: Vector3, fov: float, path: String) -> bool:
	var hidden: Array = []
	for n in get_tree().get_nodes_in_group("store_hide"):
		if n is Node3D and n.visible:
			n.visible = false
			hidden.append(n)
	var vp := SubViewport.new()
	vp.size = size
	vp.world_3d = get_viewport().find_world_3d()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.fov = fov
	vp.add_child(cam)
	add_child(vp)
	cam.look_at_from_position(pos, target)
	cam.current = true
	# Same rule as Harness.capture: never await frame_post_draw (an off-screen window stops presenting).
	# Let a few frames pass for shadows and exposure, push the camera pose, then force two draws.
	for i in 4:
		await render_frame()
	RenderingServer.camera_set_transform(cam.get_camera_rid(), cam.get_camera_transform())
	RenderingServer.force_draw()
	RenderingServer.force_draw()
	var img := vp.get_texture().get_image()
	for n in hidden:
		n.visible = true
	vp.queue_free()
	if img == null or img.is_empty() or img.get_size() != size:
		push_error("[store] no image for %s" % path)
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[store] saved %s %s" % [path, img.get_size()])
	return true
