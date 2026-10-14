class_name TerrainField
extends RefCounted

var seed := 11011
var grid := 121
var cell := 8.0
var size := 960.0
var water_level := 3.35
var trail_on := false
var trail_from := Vector2.ZERO
var trail_to := Vector2.ZERO


func configure(p_seed: int, p_grid: int = 121, p_cell: float = 8.0) -> void:
	seed = p_seed
	grid = maxi(p_grid, 8)
	cell = p_cell
	size = float(grid - 1) * cell


func cell_pos(ix: int, iz: int) -> Vector3:
	var x := (float(ix) - float(grid - 1) * 0.5) * cell
	var z := (float(iz) - float(grid - 1) * 0.5) * cell
	return Vector3(x, height_at(x, z), z)


func height_at(x: float, z: float) -> float:
	var nx := x / size
	var nz := z / size
	var h := 7.5
	h += _noise(nx * 1.35 + 2.0, nz * 1.35 - 1.0) * 16.0
	h += _noise(nx * 3.1 + 8.0, nz * 2.7 + 3.0) * 7.0
	h += _noise(nx * 6.4, nz * 6.1) * 2.2
	var river := absf(nz - 0.05 * sin(nx * TAU * 1.4))
	var bank := smoothstep(0.0, 0.075, river)
	h = lerpf(water_level - 0.45, h, bank)
	var edge := minf(minf(nx + 0.5, 0.5 - nx), minf(nz + 0.5, 0.5 - nz))
	var rim := 1.0 - smoothstep(0.0, 0.16, edge)
	h += rim * rim * 78.0
	return h


func slope_at(x: float, z: float) -> float:
	var e := cell
	var dx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var dz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return sqrt(dx * dx + dz * dz)


func normal_at(x: float, z: float) -> Vector3:
	var e := cell
	var dx := (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var dz := (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()


func biome_at(x: float, z: float) -> String:
	return biome_of(height_at(x, z), slope_at(x, z))


func biome_of(h: float, slope: float) -> String:
	if h < water_level + 0.85:
		return "sand"
	if slope > 0.46 or h > 34.0:
		return "rock"
	if h > 24.0:
		return "alpine"
	return "grass"


func color_at(x: float, z: float) -> Color:
	return color_of(x, z, height_at(x, z), slope_at(x, z))


func color_of(x: float, z: float, h: float, slope: float) -> Color:
	var biome := biome_of(h, slope)
	var n := _noise(x * 0.031, z * 0.031)
	var m := _noise(x * 0.09 + 4.0, z * 0.08 - 2.0)
	var col := Color(0.30, 0.46, 0.20)
	if biome == "sand":
		col = Color(0.62, 0.54, 0.34).lerp(Color(0.50, 0.44, 0.30), m)
	elif biome == "rock":
		col = Color(0.48, 0.46, 0.43).lerp(Color(0.34, 0.36, 0.38), n)
	elif biome == "alpine":
		col = Color(0.52, 0.56, 0.42).lerp(Color(0.40, 0.46, 0.36), m)
	else:
		col = Color(0.20, 0.38, 0.15).lerp(Color(0.40, 0.56, 0.20), n)
		col = col.lerp(Color(0.15, 0.30, 0.13), m * 0.55)
	if trail_on:
		var dist := _segment_distance(Vector2(x, z), trail_from, trail_to)
		if dist < 6.0:
			var dirt := Color(0.40, 0.31, 0.20)
			col = col.lerp(dirt, smoothstep(6.0, 1.2, dist) * 0.85)
	return col


func height_span() -> float:
	var lo := 1000.0
	var hi := -1000.0
	for iz in range(0, grid, 2):
		for ix in range(0, grid, 2):
			var h := cell_pos(ix, iz).y
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


func biome_counts(step: int = 4) -> Dictionary:
	var counts := {"sand": 0, "rock": 0, "alpine": 0, "grass": 0, "below_water": 0}
	for iz in range(0, grid, step):
		for ix in range(0, grid, step):
			var p := cell_pos(ix, iz)
			var biome := biome_at(p.x, p.z)
			counts[biome] = int(counts[biome]) + 1
			if p.y < water_level:
				counts.below_water = int(counts.below_water) + 1
	return counts


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _noise(x: float, z: float) -> float:
	var x0 := int(floor(x))
	var z0 := int(floor(z))
	var fx := x - float(x0)
	var fz := z - float(z0)
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	var a := _hash(x0, z0)
	var b := _hash(x0 + 1, z0)
	var c := _hash(x0, z0 + 1)
	var d := _hash(x0 + 1, z0 + 1)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sz)


func _hash(ix: int, iz: int) -> float:
	var a := (ix + 10007) * 73856093
	var b := (iz + 20011) * 19349663
	var n := (a ^ b ^ (seed * 83492791)) & 2147483647
	n = (n * 1103515245 + 12345) & 2147483647
	return float(n) / 2147483647.0
