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

# Дальній атакант: відступити якщо гравець впритул (відстань == 1).
# Повертає гекс що максимізує відстань від усіх гравців, або INVALID якщо
# ніхто не впритул або немає куди відступати.
static func find_retreat(unit: Unit, hexes: Dictionary,
		hex_unit: Dictionary, all_units: Array[Unit]) -> Vector2i:
	# Чи є хтось з гравців впритул?
	var player_adjacent := false
	for u in all_units:
		if u.team == Unit.Team.PLAYER and u.is_alive():
			if HexGrid.distance(unit.hex, u.hex) == 1:
				player_adjacent = true; break
	if not player_adjacent:
		return INVALID
	# Знайти гекс з максимальною мінімальною відстанню до всіх гравців
	var reachable := HexGrid.get_reachable(unit.hex, unit.move_range, hexes, hex_unit)
	var best_hex  := INVALID
	var best_dist := 1   # потрібно краще ніж 1, тобто справді відійти
	for hex in reachable:
		var min_d := 9999
		for u in all_units:
			if u.team == Unit.Team.PLAYER and u.is_alive():
				var d := HexGrid.distance(hex, u.hex)
				if d < min_d: min_d = d
		if min_d > best_dist:
			best_dist = min_d
			best_hex  = hex
	return best_hex

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
