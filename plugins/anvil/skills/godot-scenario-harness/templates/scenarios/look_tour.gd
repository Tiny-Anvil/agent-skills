extends Bot
## Capture tour: fixed named viewpoints from the REAL game boot. --views=a,b limits the set.
## Poses the actor (allowed: positioning), waits for streaming/TAA/exposure to settle, captures.
## Edit VIEWS for the project: [name, position, yaw_deg].

const VIEWS := [
	["origin", Vector3(0, 0, 0), 0.0],
	["side", Vector3(6, 0, 0), 90.0],
]
const SETTLE_TICKS := 60


func run() -> void:
	var only := Harness.arg("views", "")
	for v in VIEWS:
		if only != "" and not only.split(",").has(v[0]):
			continue
		actor.global_position = v[1]
		actor.global_rotation = Vector3(0, deg_to_rad(v[2]), 0)
		if actor.has_method("reset_physics_interpolation"):
			actor.reset_physics_interpolation()   # a teleport must not interpolate across the map
		await wait(SETTLE_TICKS)
		await shot("look_" + v[0])
		results["look_" + v[0]] = Harness.out_dir.path_join("look_" + v[0] + ".png")
