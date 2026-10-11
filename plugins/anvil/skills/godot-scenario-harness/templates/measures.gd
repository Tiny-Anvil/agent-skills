extends RefCounted
class_name Measures
## Pure measurement helpers for feel / solidity / performance tests. No scene access except
## tunnelled(), which takes the space state explicitly.


## Rotation between two orientations in degrees, accurate for tiny angles.
## (acos(dot) loses all precision below ~0.1 deg: a 0.01 deg snap reads as 0.)
static func qangle_deg(a: Quaternion, b: Quaternion) -> float:
	var d := a.inverse() * b
	return rad_to_deg(2.0 * atan2(Vector3(d.x, d.y, d.z).length(), absf(d.w)))


## Frame-to-frame jitter of a sampled position track (one sample per RENDERED frame), in mm.
## The second difference cancels constant velocity; a missed or doubled physics step shows up
## as ~v*dt (tens of mm at walking speed). Catches lateral jitter that a speed-magnitude
## metric misses.
static func second_diff_mm(positions: Array) -> Dictionary:
	var v := PackedFloat64Array()
	for i in range(1, positions.size() - 1):
		var p0: Vector3 = positions[i - 1]
		var p1: Vector3 = positions[i]
		var p2: Vector3 = positions[i + 1]
		v.append(((p2 - p1) - (p1 - p0)).length() * 1000.0)
	return _stats(v)


## Real-time variant of second_diff_mm: frame-time variation alone adds about speed x d(dt)
## (5 mm per ms at 5 m/s), which is frame pacing, not camera jitter. Normalises by each frame's dt.
static func velocity_jump_mm(positions: Array, dts: PackedFloat64Array) -> Dictionary:
	var v := PackedFloat64Array()
	for i in range(1, positions.size() - 1):
		var a: Vector3 = ((positions[i] as Vector3) - (positions[i - 1] as Vector3)) / maxf(dts[i], 1e-6)
		var b: Vector3 = ((positions[i + 1] as Vector3) - (positions[i] as Vector3)) / maxf(dts[i + 1], 1e-6)
		v.append((b - a).length() * dts[i + 1] * 1000.0)
	return _stats(v)


## Per-frame rotation steps of a sampled orientation track, in degrees. With no look input this
## is pure noise; during a transition its max is the "snap" number.
static func rot_steps_deg(quats: Array) -> Dictionary:
	var v := PackedFloat64Array()
	for i in range(1, quats.size()):
		v.append(qangle_deg(quats[i - 1], quats[i]))
	return _stats(v)


## Frame times in ms (collected AFTER warm-up, with no capture running).
static func frame_time_stats(ms: PackedFloat64Array) -> Dictionary:
	return _stats(ms)


## True if the straight segment from -> to crosses world geometry (tunnelling between ticks).
static func tunnelled(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		exclude: Array[RID], mask := 0xFFFFFFFF) -> bool:
	if from.distance_to(to) < 0.001:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	q.hit_from_inside = false
	return not space.intersect_ray(q).is_empty()


## Longest time (s) in which the actor made less than min_progress m of net progress while
## being driven forward. Feed one position per physics tick.
static func max_stuck_s(track: Array, tick_rate: int, window_s := 2.0, min_progress := 0.3) -> float:
	var w := int(window_s * tick_rate)
	var worst := 0.0
	var run_start := -1
	for i in range(w, track.size()):
		var stuck := (track[i] as Vector3).distance_to(track[i - w]) < min_progress
		if stuck and run_start < 0:
			run_start = i - w
		elif not stuck and run_start >= 0:
			worst = maxf(worst, float(i - run_start) / tick_rate)
			run_start = -1
	if run_start >= 0:
		worst = maxf(worst, float(track.size() - run_start) / tick_rate)
	return worst


static func _stats(v: PackedFloat64Array) -> Dictionary:
	var n := v.size()
	if n == 0:
		return {"n": 0, "mean": 0.0, "rms": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var s := v.duplicate()
	s.sort()
	var sum := 0.0
	var sq := 0.0
	for x in s:
		sum += x
		sq += x * x
	return {"n": n, "mean": sum / n, "rms": sqrt(sq / n), "p50": s[n / 2],
		"p95": s[mini(n - 1, int(n * 0.95))], "p99": s[mini(n - 1, int(n * 0.99))], "max": s[n - 1]}
