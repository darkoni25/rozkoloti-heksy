class_name HexGrid

# Axial coordinate hex grid — pointy-top, isometric projection (y * 0.5)

const SQRT3 := 1.7320508075688772

static func hex_to_pixel(q: int, r: int, size: float) -> Vector2:
	var x := size * SQRT3 * (q + r * 0.5)
	var y := size * 1.5 * r * 0.5
	return Vector2(x, y)

static func pixel_to_hex(pos: Vector2, size: float) -> Vector2i:
	var y_flat := pos.y * 2.0
	var q := (SQRT3 / 3.0 * pos.x - 1.0 / 3.0 * y_flat) / size
	var r := (2.0 / 3.0 * y_flat) / size
	return _axial_round(q, r)

static func hex_vertices(center: Vector2, size: float) -> PackedVector2Array:
	var verts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		verts.append(Vector2(
			center.x + size * cos(angle),
			center.y + size * sin(angle) * 0.5
		))
	return verts

static func get_neighbors(q: int, r: int) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
	]
	var result: Array[Vector2i] = []
	for d in dirs:
		result.append(Vector2i(q + d.x, r + d.y))
	return result

static func get_reachable(from: Vector2i, move_range: int,
		hexes: Dictionary, occupied: Dictionary) -> Array[Vector2i]:
	var visited: Dictionary[Vector2i, bool] = {}
	visited[from] = true
	var frontier: Array[Vector2i] = [from]
	for _i in range(move_range):
		var next_f: Array[Vector2i] = []
		for hex in frontier:
			for nb in get_neighbors(hex.x, hex.y):
				if hexes.has(nb) and not visited.has(nb) and not occupied.has(nb):
					visited[nb] = true
					next_f.append(nb)
		frontier = next_f
	var result: Array[Vector2i] = []
	for hex in visited:
		if hex != from:
			result.append(hex)
	return result

static func distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

static func _axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundi(q)
	var rr := roundi(r)
	var rs := roundi(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(rq, rr)
