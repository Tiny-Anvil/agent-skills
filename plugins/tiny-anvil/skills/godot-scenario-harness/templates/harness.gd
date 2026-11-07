extends Node
## Harness (autoload). Drives every unattended run from user args after `--`:
##   --scenario=<name>      run res://tests/scenarios/<name>.gd (extends Bot)
##   --out=<dir>            artefact directory (results JSON, PNGs)
##   --shot=<png> [--shot-tick=N]   one capture at physics tick N (default 90), then quit
##   --stills=<json>        [[tick, "path.png"], ...] captured during a run/playback
##   --record=<json>        record every consumed input frame; written on finish
##   --playback=<json>      drive the game from a recording
##   --log=<csv>            per-rendered-frame camera log (for jitter / snap analysis)
##   --quit-ticks=N         quit after N physics ticks
##   --max-seconds=S        wall-clock guard (default 900): a hung run exits non-zero
##   --fps-cap=N            Engine.max_fps
##   --seed=N               seed for every gameplay RNG (game code reads Harness.seed_value)
##   --hide-group=a,b       hide every node in these groups for the whole run (debug labels out of store captures)
## Paths resolve against the project (--path), not the shell's directory: pass absolute paths.
## Exit codes: 0 ok, 1 scenario failure, 3 scenario missing, 4 wall-clock limit, 5 capture impossible,
## 6 recording not written.

const SCENARIO_DIR := "res://tests/scenarios/"

var args := {}
var tick := 0
var frame := 0
var out_dir := ""
var seed_value := 1
var scenario: Node
var quitting := false

var _shot_path := ""
var _shot_tick := 90
var _stills: Array = []
var _quit_ticks := -1
var _max_ms := 900000
var _log: FileAccess
var _ft: PackedFloat64Array = PackedFloat64Array()


## Args are parsed in _init, not _ready: the main scene's _enter_tree can run BEFORE an
## autoload's _ready (measured, Godot 4.8), and would read an empty args dict.
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000            # after game code: logs/captures see the finished frame state
	process_physics_priority = 1000
	out_dir = arg("out", "")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	seed_value = int(arg("seed", "1"))
	seed(seed_value)
	_shot_path = arg("shot", "")
	_shot_tick = int(arg("shot-tick", "90"))
	_quit_ticks = int(arg("quit-ticks", "-1"))
	_max_ms = int(float(arg("max-seconds", "900")) * 1000.0)
	if has("fps-cap"):
		Engine.max_fps = int(arg("fps-cap"))
	if has("stills"):
		var d = JSON.parse_string(FileAccess.get_file_as_string(arg("stills")))
		if typeof(d) == TYPE_ARRAY:
			_stills = d
	if has("log"):
		_log = FileAccess.open(arg("log"), FileAccess.WRITE)
		if _log:
			_log.store_line("frame,tick,usec,dt,cx,cy,cz,qx,qy,qz,qw,fps")
	if has("playback"):
		InputFrame.load_playback(arg("playback"))
	if has("record"):
		InputFrame.start_recording()


## Connected here, not in _ready: the main scene can enter the tree before this autoload's _ready.
func _enter_tree() -> void:
	if has("hide-group") and not get_tree().node_added.is_connected(_hide_if_grouped):
		get_tree().node_added.connect(_hide_if_grouped)


func _hide_if_grouped(n: Node) -> void:
	if not (n is Node3D or n is CanvasItem):
		return
	for g in arg("hide-group").split(","):
		if n.is_in_group(g):
			n.set_deferred("visible", false)
			return


func has(k: String) -> bool:
	return args.has(k)


func arg(k: String, def := "") -> String:
	return args.get(k, def)


## The game calls this once its world exists (end of the main scene's _ready or after loading).
func world_ready(main: Node) -> void:
	if has("hide-group"):
		for g in arg("hide-group").split(","):
			for n in get_tree().get_nodes_in_group(g):
				_hide_if_grouped(n)
	if not has("scenario"):
		return
	var path := SCENARIO_DIR + arg("scenario") + ".gd"
	var scr = load(path) if ResourceLoader.exists(path) else null
	if scr == null or not scr.can_instantiate():
		push_error("[harness] scenario not found: " + path)
		finish(3)
		return
	scenario = scr.new()
	scenario.name = "Scenario"
	main.add_child(scenario)


func _physics_process(_dt: float) -> void:
	tick += 1
	if _quit_ticks > 0 and tick >= _quit_ticks:
		finish(0)
	if Time.get_ticks_msec() > _max_ms:
		push_error("[harness] wall-clock limit reached at tick %d" % tick)
		finish(4)


func _process(delta: float) -> void:
	frame += 1
	if frame > 30:
		_ft.append(delta * 1000.0)
	var cam := get_viewport().get_camera_3d()
	if _log and cam:
		# get_camera_transform() is what is drawn (interpolated); global_transform leads by up to a tick
		var t := cam.get_camera_transform()
		var q := t.basis.get_rotation_quaternion()
		_log.store_line("%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.7f,%.7f,%.7f,%.7f,%.1f" % [frame, tick,
			Time.get_ticks_usec(), delta, t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w,
			Engine.get_frames_per_second()])
	if _shot_path != "" and tick >= _shot_tick:
		capture(_shot_path)
		_shot_path = ""
		if not has("scenario") and _quit_ticks < 0:
			finish(0)
	while not _stills.is_empty() and InputFrame.tick >= int(_stills[0][0]):
		capture(String(_stills[0][1]))
		_stills.pop_front()


## Capture the current view. NEVER await RenderingServer.frame_post_draw for this: an unfocused or
## off-screen window stops presenting after a frame or two and the signal never fires (silent hang).
## force_draw() does not flush Node3D transform notifications, so push the camera pose first, then
## draw twice (one forced draw has been seen to return the previous frame).
func capture(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		push_error("[harness] capture impossible under --headless (dummy renderer writes blank frames)")
		finish(5)
		return false
	var cam := get_viewport().get_camera_3d()
	if cam:
		RenderingServer.camera_set_transform(cam.get_camera_rid(), cam.get_camera_transform())
	RenderingServer.force_draw()
	RenderingServer.force_draw()
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("[harness] no viewport image for " + path)
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[harness] saved %s %s" % [path, img.get_size()])
	return true


func finish(code := 0) -> void:
	if quitting:
		return
	quitting = true
	if has("record") and not InputFrame.save_recording(arg("record"), {"seed": seed_value}):
		if code == 0:
			code = 6
	if _log:
		_log.close()
		_log = null
	if _ft.size() > 0:
		var s := Measures.frame_time_stats(_ft)
		print("[harness] frame ms p50 %.2f p95 %.2f max %.1f over %d frames" % [s.p50, s.p95, s.max, s.n])
	print("[harness] finish code=%d ticks=%d frames=%d" % [code, tick, frame])
	get_tree().quit(code)
