class_name EnemyAI

const INVALID := Vector2i(-9999, -9999)

# Повертає гекс ворожого юніта для атаки (з найменшим HP) в радіусі attack_range, або INVALID
static func find_attack(unit: Unit, _hex_unit: Dictionary, all_units: Array[Unit]) -> Vector2i:
	var best   := INVALID
	var min_hp := 9999
	for target in all_units:
		if target.team != unit.team and target.is_alive():
			var d := HexGrid.distance(unit.hex, target.hex)
			if d <= unit.attack_range and target.hp < min_hp:
				min_hp = target.hp
				best   = target.hex
	return best

# Повертає найкращий гекс для переміщення до найближчого гравця, або INVALID
static func find_move(unit: Unit, hexes: Dictionary,
		hex_unit: Dictionary, all_units: Array[Unit]) -> Vector2i:
	# Знаходимо найближчого живого гравця
	var nearest: Unit = null
	var min_dist := 9999
	for u in all_units:
		if u.team == Unit.Team.PLAYER and u.is_alive():
			var d := HexGrid.distance(unit.hex, u.hex)
			if d < min_dist:
				min_dist = d
				nearest  = u
	if nearest == null:
		return INVALID

	# Якщо вже в радіусі атаки — не рухаємось
	if min_dist <= unit.attack_range:
		return INVALID

	# З досяжних гексів обираємо найближчий до цілі
	var reachable := HexGrid.get_reachable(unit.hex, unit.move_range, hexes, hex_unit)
	if reachable.is_empty():
		return INVALID

	var best      := INVALID
	var best_dist := HexGrid.distance(unit.hex, nearest.hex)
	for hex in reachable:
		var d := HexGrid.distance(hex, nearest.hex)
		if d < best_dist:
			best_dist = d
			best      = hex
	return best
