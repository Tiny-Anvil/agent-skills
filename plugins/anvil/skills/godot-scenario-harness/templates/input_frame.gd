extends Node
## InputFrame (autoload). The ONLY input game state reads: one frame per physics tick.
## Sources: LIVE (devices), PLAYBACK (a recording), BOT (a scenario writes bot_*).
## Every consumed frame can be recorded, so a live or bot session replays tick-exactly.
## Game code reads InputFrame.move / look / held() / pressed(), never Input or raw events.
##
## EXISTING PROJECT? If it already has an input layer or recorder, do NOT add this one beside
## it: implement BOT and PLAYBACK as sources on its existing seam (its polling interface),
## and keep only the frame contract below.

enum Mode { LIVE, PLAYBACK, BOT }

const B_JUMP := 1
const B_FIRE := 2
const B_ALT := 4
const B_RELOAD := 8
const B_SPRINT := 16
const B_USE := 32
const B_START := 64
const B_PAUSE := 128

var mode := Mode.LIVE
var mouse_sens := 0.0021            # rad per pixel
var enabled := true                 # false while menus are up (frames still recorded)

var move := Vector2.ZERO            # x = strafe right / steer right, y = forward / throttle
var look := Vector2.ZERO            # rad this tick: x = yaw right, y = pitch up
var buttons := 0
var prev_buttons := 0
var tick := 0

var bot_move := Vector2.ZERO
var bot_look := Vector2.ZERO        # consumed (zeroed) each tick
var bot_buttons := 0

var play_done := false
var _pending_look := Vector2.ZERO
var _latch := 0                     # presses between ticks are never lost
var _recording := false
var _rec: Array = []
var _play: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -1000   # sample before any game physics


func _input(event: InputEvent) -> void:
	if mode != Mode.LIVE:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var r: Vector2 = event.screen_relative
		_pending_look += Vector2(r.x * mouse_sens, -r.y * mouse_sens)
	_latch |= _buttons_from_event(event)


func _physics_process(_dt: float) -> void:
	prev_buttons = buttons
	match mode:
		Mode.LIVE:
			move = _sample_live_move().limit_length(1.0)
			look = _pending_look
			_pending_look = Vector2.ZERO
			buttons = _sample_live_buttons() | _latch
			_latch = 0
		Mode.BOT:
			move = bot_move.limit_length(1.0)
			look = bot_look
			bot_look = Vector2.ZERO
			buttons = bot_buttons
		Mode.PLAYBACK:
			if tick < _play.size():
				var f: Array = _play[tick]
				move = Vector2(f[0], f[1])
				look = Vector2(f[2], f[3])
				buttons = int(f[4])
			else:
				move = Vector2.ZERO
				look = Vector2.ZERO
				buttons = 0
				play_done = true
	if not enabled:
		move = Vector2.ZERO
		look = Vector2.ZERO
		buttons &= (B_START | B_PAUSE | B_FIRE)
	if _recording:
		_rec.append([move.x, move.y, look.x, look.y, buttons])
	tick += 1


## Replace these three with the project's device mapping (InputMap actions, its own input
## manager, a gamepad). They run only in LIVE mode.
func _sample_live_move() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))


func _sample_live_buttons() -> int:
	var b := 0
	if Input.is_physical_key_pressed(KEY_SPACE): b |= B_JUMP
	if Input.is_physical_key_pressed(KEY_SHIFT): b |= B_SPRINT
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): b |= B_FIRE
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): b |= B_ALT
	return b


func _buttons_from_event(e: InputEvent) -> int:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_SPACE: return B_JUMP
			KEY_R: return B_RELOAD
			KEY_E: return B_USE
			KEY_ENTER: return B_START
			KEY_ESCAPE: return B_PAUSE
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		return B_FIRE
	return 0


func held(b: int) -> bool:
	return (buttons & b) != 0


func pressed(b: int) -> bool:
	return (buttons & b) != 0 and (prev_buttons & b) == 0


func released(b: int) -> bool:
	return (buttons & b) == 0 and (prev_buttons & b) != 0


## Look not yet consumed by a tick (LIVE only): lets a render-rate camera stay responsive
## between ticks without changing game state.
func unconsumed_look() -> Vector2:
	return _pending_look if mode == Mode.LIVE else Vector2.ZERO


func start_recording() -> void:
	_recording = true
	_rec.clear()


## Returns false when the file cannot be written (Harness then exits 6). Relative paths resolve against the
## project (--path), not the shell's directory: pass absolute paths.
func save_recording(path: String, meta := {}) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[input] cannot write recording " + path)
		return false
	var d: Dictionary = meta.duplicate()
	d["tick_rate"] = Engine.physics_ticks_per_second
	d["engine"] = Engine.get_version_info().string
	d["frames"] = _rec
	# full_precision: default stringify rounds floats, and rounded look deltas make a replay drift
	f.store_string(JSON.stringify(d, "", false, true))
	f.close()
	print("[input] recording saved %s frames=%d" % [path, _rec.size()])
	return true


func load_playback(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		push_error("[input] bad playback file " + path)
		return {}
	if int(d.get("tick_rate", Engine.physics_ticks_per_second)) != Engine.physics_ticks_per_second:
		push_warning("[input] recording tick rate %s != project %d: replay will diverge"
			% [d.get("tick_rate"), Engine.physics_ticks_per_second])
	_play = d.get("frames", [])
	mode = Mode.PLAYBACK
	tick = 0
	play_done = false
	return d
