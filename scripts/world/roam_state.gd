class_name RoamState
extends RefCounted

const HOUR_PER_SEC := 0.045
const COLLECT_RADIUS := 2.5
const SHELTER_RADIUS := 4.6

var seed := 11011
var region := "İlk Kamp"
var position := Vector3.ZERO
var yaw := 0.0
var facing := 0.0
var pitch := -0.22
var sitting := false
var scrap := 0
var hour := 9.4
var exposure := 0.0
var sheltered := false
var collected: Array[int] = []


func is_night() -> bool:
	return hour >= 19.5 or hour < 5.5


func advance(delta: float, near_shelter: bool) -> void:
	hour = fposmod(hour + delta * HOUR_PER_SEC, 24.0)
	sheltered = near_shelter
	if is_night() and not near_shelter:
		exposure = minf(100.0, exposure + delta * 2.4)
	else:
		exposure = maxf(0.0, exposure - delta * 8.0)


func try_collect(index: int, player: Vector3, scraps: Array) -> bool:
	if index < 0 or index >= scraps.size():
		return false
	if collected.has(index):
		return false
	var spot: Vector3 = scraps[index]
	if _flat_distance(player, spot) > COLLECT_RADIUS:
		return false
	collected.append(index)
	scrap += 1
	return true


func try_rest(player: Vector3, shelter_pos: Vector3) -> bool:
	if _flat_distance(player, shelter_pos) > SHELTER_RADIUS:
		return false
	hour = 7.05
	exposure = 0.0
	sheltered = true
	return true


func to_dict() -> Dictionary:
	var ids: Array = []
	for item in collected:
		ids.append(int(item))
	return {
		"v": 1,
		"seed": seed,
		"region": region,
		"x": position.x,
		"y": position.y,
		"z": position.z,
		"yaw": yaw,
		"facing": facing,
		"pitch": pitch,
		"sitting": sitting,
		"scrap": scrap,
		"hour": hour,
		"exposure": exposure,
		"sheltered": sheltered,
		"collected": ids,
	}


static func from_dict(data: Dictionary) -> RoamState:
	var state := RoamState.new()
	state.seed = int(data.get("seed", 11011))
	state.region = str(data.get("region", "İlk Kamp"))
	state.position = Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
	state.yaw = float(data.get("yaw", 0.0))
	state.facing = float(data.get("facing", state.yaw))
	state.pitch = float(data.get("pitch", -0.22))
	state.sitting = bool(data.get("sitting", false))
	state.scrap = int(data.get("scrap", 0))
	state.hour = float(data.get("hour", 9.4))
	state.exposure = float(data.get("exposure", 0.0))
	state.sheltered = bool(data.get("sheltered", false))
	var raw = data.get("collected", [])
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			state.collected.append(int(item))
	return state


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
