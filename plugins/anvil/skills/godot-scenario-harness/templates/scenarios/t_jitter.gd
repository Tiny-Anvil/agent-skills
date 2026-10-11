extends Bot
## Feel test: camera jitter while moving straight with no look input. Run at two frame rates:
##   ... --fixed-fps 60  -- --scenario=t_jitter --out=<dir>
##   ... --fixed-fps 144 -- --scenario=t_jitter --out=<dir>
## Samples the DRAWN camera (get_camera_transform) once per rendered frame.
## At --fixed-fps EQUAL to the physics rate every frame gets exactly one tick, so this test cannot
## fail there: measure at a different fixed rate (144), or in real time with velocity_jump_mm.
## NEGATIVE CONTROL: run once with physics interpolation off at 144 FPS; this test must FAIL
## there, or it cannot catch anything.

const SECONDS := 3.0
const MAX_P99_MM := 2.0       # thresholds come from the brief
const MAX_ROT_STEP_DEG := 0.05

var _rec := false
var _pos: Array = []
var _rot: Array = []


func _process(_d: float) -> void:
	if _rec:
		var t := get_viewport().get_camera_3d().get_camera_transform()
		_pos.append(t.origin)
		_rot.append(t.basis.get_rotation_quaternion())


func run() -> void:
	InputFrame.bot_move = Vector2(0, 1)
	await wait(int(0.7 * Engine.physics_ticks_per_second))   # reach full speed first
	_rec = true
	for i in int(SECONDS * Engine.physics_ticks_per_second):
		InputFrame.bot_move = Vector2(0, 1)
		await frame()
	_rec = false
	stop()
	var pos := Measures.second_diff_mm(_pos)
	var rot := Measures.rot_steps_deg(_rot)
	results["fps"] = Engine.get_frames_per_second()
	results["physics_hz"] = Engine.physics_ticks_per_second
	results["frames"] = _pos.size()
	results["pos_second_diff_mm"] = pos
	results["rot_step_deg"] = rot
	if pos.p99 > MAX_P99_MM:
		fail("position jitter p99 %.3f mm > %.3f" % [pos.p99, MAX_P99_MM])
	if rot.max > MAX_ROT_STEP_DEG:
		fail("rotation step max %.4f deg > %.4f with no look input" % [rot.max, MAX_ROT_STEP_DEG])
