extends Node
class_name Bot
## Base for scenarios and autopilots. A bot only produces INPUT (InputFrame BOT mode): move axes,
## look deltas, buttons. That is exactly what a human produces, so a bot run records and replays.
## Positioning the actor for a test (spawn/teleport) is allowed; moving it during the measured
## part of a test is not. Pushing state directly would only prove that the bot can set state.
##
## Subclass: override run(), put numbers in `results`, call fail("why") for a failed check.
## The project supplies the actor through _actor() and, if its forward is not -Z, FORWARD_SIGN.

const FORWARD_SIGN := -1.0           # -1: forward = -basis.z (Godot default); +1: forward = +basis.z

var actor: Node3D
var results := {}
var failures: Array = []
var max_look_rate := deg_to_rad(240.0)


func _ready() -> void:
	process_physics_priority = -2000   # write bot_* before InputFrame samples them
	actor = _actor()
	if not Harness.has("playback"):        # a replayed scenario keeps the recording as its input
		InputFrame.mode = InputFrame.Mode.BOT
	call_deferred("_start")


func _actor() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _start() -> void:
	if actor == null:
		fail("no actor found (group 'player'): is the real game scene loaded?")
		_finish()
		return
	await run()
	_finish()


func run() -> void:
	pass


func fail(why: String) -> void:
	failures.append(why)
	push_error("[bot] FAIL " + why)


func _finish() -> void:
	results["failures"] = failures
	results["pass"] = failures.is_empty()
	var dir := Harness.out_dir if Harness.out_dir != "" else OS.get_user_data_dir()
	var f := FileAccess.open(dir.path_join("result_%s.json" % Harness.arg("scenario", name)), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(results, "  "))
		f.close()
	print("[bot] %s %s" % ["PASS" if failures.is_empty() else "FAIL", JSON.stringify(results)])
	Harness.finish(0 if failures.is_empty() else 1)


func frame() -> void:
	await get_tree().physics_frame


func wait(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


## Advance one rendered frame (never await frame_post_draw: see Harness.capture).
func render_frame() -> void:
	await get_tree().process_frame


func shot(name_: String) -> void:
	await render_frame()
	Harness.capture(Harness.out_dir.path_join(name_ + ".png"))


func stop() -> void:
	InputFrame.bot_move = Vector2.ZERO
	InputFrame.bot_look = Vector2.ZERO
	InputFrame.bot_buttons = 0


func forward() -> Vector3:
	return actor.global_basis.z * FORWARD_SIGN


## Yaw/pitch look delta for this tick that turns the actor toward world direction d,
## limited to max_look_rate. Closed loop: call it every tick.
func look_delta_toward(d: Vector3, pitch_now := 0.0) -> Vector2:
	var up := actor.global_basis.y
	var fw := forward()
	var flat := d - up * d.dot(up)
	var yaw_err := 0.0
	if flat.length_squared() > 1e-8:
		flat = flat.normalized()
		yaw_err = atan2(-fw.cross(flat).dot(up), fw.dot(flat))
	var pitch_err := asin(clampf(d.normalized().dot(up), -1.0, 1.0)) - pitch_now
	var lim := max_look_rate / Engine.physics_ticks_per_second
	return Vector2(clampf(yaw_err, -lim, lim), clampf(pitch_err, -lim, lim))


## Move toward a world point through input only. Returns true when within tol (planar).
func walk_to(target: Vector3, tol := 1.0, timeout_s := 30.0, buttons := 0) -> bool:
	for t in int(timeout_s * Engine.physics_ticks_per_second):
		var to := target - actor.global_position
		var up := actor.global_basis.y
		var planar := to - up * to.dot(up)
		if planar.length() < tol:
			stop()
			return true
		InputFrame.bot_look = Vector2(look_delta_toward(planar).x, 0.0)
		InputFrame.bot_move = Vector2(0, 1)
		InputFrame.bot_buttons = buttons
		await frame()
	stop()
	return false
