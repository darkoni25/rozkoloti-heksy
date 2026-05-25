extends Node2D

const HEX_SIZE    := 52.0
const GRID_RADIUS := 4

const COMBAT_LOOT: Dictionary = {"wood": 8, "stone": 5, "metal": 10, "food": 6}

# ── Пули ворогів та позиції ───────────────────────────────────────────────
# Позиції на правій стороні поля (q >= 2) — максимум 3 ворогів
const ENEMY_SPAWN_POS: Array[Vector2i] = [
	Vector2i(2, -1), Vector2i(3, -2), Vector2i(2, 1),
]
# Назви зон для UI (відповідає current_direction)
const DIRECTION_NAMES: Array[String] = ["Ліс", "Рудники", "Руїни"]
# Пули ворогів: [ім'я, move_range, color, base_hp, base_dmg, atk_range]
# Індекс масиву = current_direction
const ENEMY_POOLS: Array = [
	[  # 0 — Ліс: гобліни, лучник-гоблін, вовк
		["Гоблін",      3, Color(0.25, 0.52, 0.20), 12, 5, 1],
		["Гобл.Лучн.",  2, Color(0.18, 0.40, 0.15), 10, 4, 2],
		["Вовк",        4, Color(0.55, 0.50, 0.44), 15, 7, 1],
	],
	[  # 1 — Рудники: кобольд, шахтар, тролль
		["Кобольд",     2, Color(0.62, 0.38, 0.18), 14, 6, 1],
		["Шахтар",      3, Color(0.42, 0.36, 0.28), 17, 7, 1],
		["Тролль",      2, Color(0.38, 0.48, 0.30), 28, 9, 1],
	],
	[  # 2 — Руїни: скелет, бандит, лучник
		["Скелет",      2, Color(0.80, 0.76, 0.60), 13, 5, 1],
		["Бандит",      3, Color(0.52, 0.20, 0.18), 17, 8, 1],
		["Лучник",      2, Color(0.48, 0.32, 0.16), 12, 6, 2],
	],
]

# ── Фази ─────────────────────────────────────────────────────────────────
const PHASE_DEPLOY := 0
const PHASE_COMBAT := 1
var _phase: int = PHASE_DEPLOY

# ── Дані ─────────────────────────────────────────────────────────────────
var _hexes:     Dictionary[Vector2i, bool] = {}
var _units:     Array[Unit]                = []
var _hex_unit:  Dictionary[Vector2i, int]  = {}
var _unit_anim: Dictionary[int, Vector2]   = {}
var _tm:        TurnManager

# ── Розстановка ───────────────────────────────────────────────────────────
var _deploy_queue: Array[Unit]     = []   # ще не розставлені юніти
var _deploy_zone:  Array[Vector2i] = []   # гекси де можна ставити
var _deploy_hover: Vector2i        = Vector2i(-9999, -9999)
var _hero_uid:     int             = -1   # ID юніта-героя (-1 якщо не в рейді)

# ── Бій ──────────────────────────────────────────────────────────────────
var _animating:    bool            = false
var _hovered:      Vector2i        = Vector2i(-9999, -9999)
var _sel_id:       int             = -1
var _reachable:    Array[Vector2i] = []
var _attackable:   Array[Vector2i] = []
var _combat_log:   String          = ""
var _levelup_log:  String          = ""   # рядок про підвищення рівня (показується у результаті)
var _winner:       int             = -2   # -2 ongoing | 0 player | 1 enemy | -1 draw
var _obstacles:    Dictionary[Vector2i, int] = {}   # 0=дерево  1=камінь
var _ability_mode:    bool            = false   # очікуємо вибір цілі здібності
var _ability_targets: Array[Vector2i] = []      # підсвічені гекси-цілі

# ── Кольори ───────────────────────────────────────────────────────────────
const C_FILL        := Color(0.12, 0.09, 0.07, 0.95)
const C_HOVER       := Color(0.35, 0.55, 0.75, 0.40)
const C_REACHABLE   := Color(0.18, 0.42, 0.18, 0.70)
const C_ATTACK      := Color(0.55, 0.10, 0.10, 0.75)
const C_ATTACK_RNG  := Color(0.45, 0.10, 0.55, 0.75)
const C_ACT_HEX     := Color(0.45, 0.32, 0.06, 0.75)
const C_BORDER      := Color(0.45, 0.38, 0.28, 1.00)
const C_BORDER_S    := Color(0.90, 0.70, 0.20, 1.00)
const C_PLAYER      := Color(0.25, 0.55, 0.90)
const C_HERO        := Color(0.95, 0.80, 0.20)
const C_ENEMY       := Color(0.85, 0.22, 0.22)
const C_DEPLOY_ZONE := Color(0.18, 0.22, 0.42, 0.65)   # синій — зона розстановки
const C_DEPLOY_HOV  := Color(0.30, 0.40, 0.65, 0.80)   # підсвітка при наведенні
const C_ABILITY     := Color(0.55, 0.15, 0.75, 0.72)   # фіолетовий — цілі здібності

# ── Ініціалізація ─────────────────────────────────────────────────────────
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.04, 0.03))
	_build_grid()
	_prepare_deploy()

func _build_grid() -> void:
	for q in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for r in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var s := -q - r
			if absi(q) <= GRID_RADIUS and absi(r) <= GRID_RADIUS and absi(s) <= GRID_RADIUS:
				_hexes[Vector2i(q, r)] = true

# ── Фаза розстановки ─────────────────────────────────────────────────────
func _prepare_deploy() -> void:
	_generate_obstacles()
	# Зона розстановки — два лівих стовпці (q <= -3)
	_deploy_zone = []
	for hex in _hexes:
		if hex.x <= -3:
			_deploy_zone.append(hex)

	# ── Герой — завжди перший (якщо не на відновленні) ───────────────────
	# ── Пасивні бонуси будівель ──────────────────────────────────────────────
	var _bld_hp_flat: int   = 10   if GameState.has_building(1) else 0    # Казарма
	var _bld_hp_pct:  float = 0.15 if GameState.has_building(0) else 0.0  # Каплиця
	var _bld_mbar:    int   = 10   if GameState.has_building(3) else 0    # Башта мага

	var h: Dictionary = GameState.hero
	if not h.is_empty():
		if GameState.hero_recovery_raids > 0:
			# Пропускає цей рейд, рахуємо вниз
			GameState.hero_recovery_raids -= 1
		else:
			var uid    := _units.size()
			var hrange := h.get("atk_range", 1) as int
			var hdmg   := h.get("dmg", 12) as int
			var hero_base_hp := h.get("hp", 50) as int + GameState.get_char_hp_bonus("hero")
			var hero_hp      := hero_base_hp + _bld_hp_flat + int(float(hero_base_hp) * _bld_hp_pct)
			var unit   := Unit.new(uid, Vector2i(-9999, -9999), Unit.Team.PLAYER,
					h.get("name", "Герой") as String,
					h.get("move_range", 3) as int,
					GameState.get_hero_color(),
					hero_hp,
					hdmg + GameState.get_char_dmg_bonus("hero"),
					GameState.get_char_atk_range("hero", hrange))
			unit.char_key           = "hero"
			unit.initiative         = 10 + GameState.get_char_initiative_bonus("hero") + randi_range(1, 6)
			unit.simple_barrier     = GameState.get_char_simple_barrier("hero")
			unit.max_simple_barrier = unit.simple_barrier
			unit.magic_barrier      = GameState.get_char_magic_barrier("hero") + _bld_mbar
			AbilitySystem.setup_unit(unit, int(GameState.hero.get("class_idx", -1)))
			_units.append(unit)
			_deploy_queue.append(unit)
			_hero_uid = uid

	# ── Компаньйони ───────────────────────────────────────────────────────
	for i in mini(GameState.raid_party.size(), 3):
		var cuid: int = GameState.raid_party[i]
		if cuid >= GameState.COMPANIONS.size():
			continue
		var c: Dictionary = GameState.COMPANIONS[cuid]
		var uid    := _units.size()
		var ckey   := "c%d" % cuid
		var crange := c["atk_range"] as int
		var comp_base_hp := GameState.get_companion_hp(cuid) + GameState.get_char_hp_bonus(ckey)
		var comp_hp      := comp_base_hp + _bld_hp_flat + int(float(comp_base_hp) * _bld_hp_pct)
		var unit   := Unit.new(uid, Vector2i(-9999, -9999), Unit.Team.PLAYER,
				c["name"] as String, c["move_range"] as int,
				C_PLAYER,
				comp_hp,
				GameState.get_companion_dmg(cuid) + GameState.get_char_dmg_bonus(ckey),
				GameState.get_char_atk_range(ckey, crange))
		unit.char_key           = ckey
		unit.initiative         = 10 + GameState.get_char_initiative_bonus(ckey) + randi_range(1, 6)
		unit.simple_barrier     = GameState.get_char_simple_barrier(ckey)
		unit.max_simple_barrier = unit.simple_barrier
		unit.magic_barrier      = GameState.get_char_magic_barrier(ckey) + _bld_mbar
		AbilitySystem.setup_unit(unit, int(c.get("class_idx", -1)))
		_units.append(unit)
		_deploy_queue.append(unit)

	# Якщо немає нікого (помилка) — запасний юніт
	if _deploy_queue.is_empty():
		var unit := Unit.new(0, Vector2i(-9999, -9999), Unit.Team.PLAYER,
				"Воїн", 3, C_PLAYER, 30, 8)
		unit.initiative = 10 + randi_range(1, 6)
		_units.append(unit)
		_deploy_queue.append(unit)

	# Вороги одразу на позиціях
	if not GameState.tutorial_done:
		# Туторіал: один слабкий гоблін (фіксований)
		_add_unit(Vector2i(2, 0), Unit.Team.ENEMY, "Гоблін", 3,
				Color(0.30, 0.55, 0.25), 15, 4)
	else:
		_spawn_enemies()

func _add_unit(hex: Vector2i, team: int, label: String,
		move_range: int, color: Color, hp: int, dmg: int, atk_range: int = 1) -> void:
	var uid  := _units.size()
	var unit := Unit.new(uid, hex, team, label, move_range, color, hp, dmg, atk_range)
	unit.initiative = 10 + randi_range(1, 6)   # вороги: базова + випадок
	_units.append(unit)
	_hex_unit[hex] = uid

func _place_unit(unit: Unit, hex: Vector2i) -> void:
	unit.hex     = hex
	_hex_unit[hex] = unit.id
	_deploy_queue.erase(unit)

func _unplace_unit(unit: Unit) -> void:
	_hex_unit.erase(unit.hex)
	unit.hex = Vector2i(-9999, -9999)
	_deploy_queue.push_front(unit)

func _start_combat() -> void:
	_phase = PHASE_COMBAT
	_tm = TurnManager.new()
	add_child(_tm)
	_tm.turn_started.connect(_on_turn_started)
	_tm.combat_ended.connect(_on_combat_ended)
	_tm.setup(_units)

func _start_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 90, vp.y - 50, 180, 36)

func _all_deployed() -> bool:
	return _deploy_queue.is_empty()

# ── Перешкоди ─────────────────────────────────────────────────────────────
# Об'єднує hex_unit і obstacles в один словник «заблоковані гекси» для pathfinding
func _combined_blocked() -> Dictionary:
	var result: Dictionary = {}
	for hex in _hex_unit:   result[hex] = _hex_unit[hex]
	for hex in _obstacles:  result[hex] = -2
	return result

# ── Здібності: тонка обгортка навколо AbilitySystem ──────────────────────
func _ability_btn_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x - 182, vp.y - 50, 170, 38)

## Видалити юніта з поля (смерть від здібності або звичайної атаки).
func _kill_unit(unit: Unit) -> void:
	_hex_unit.erase(unit.hex)
	if unit.id == _hero_uid:
		GameState.hero_recovery_raids = 1
	_tm.remove_unit(unit.id)

func _execute_ability(actor: Unit, target_hex: Vector2i) -> void:
	_ability_mode = false; _ability_targets = []
	_sel_id = -1; _reachable = []; _attackable = []
	_combat_log = AbilitySystem.execute(
		actor.ability_id, actor, target_hex,
		_units, _hex_unit, _hexes,
		func(u: Unit) -> void: _kill_unit(u)
	)
	actor.ability_cd = actor.ability_cd_max
	actor.acted      = true
	queue_redraw()
	if _winner == -2:
		await get_tree().create_timer(0.6).timeout
		_tm.advance()

# Процедурна генерація перешкод (дерева / камені) у середній зоні карти
func _generate_obstacles() -> void:
	_obstacles.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Eligible: середня зона між зоною розстановки і позиціями ворогів
	var eligible: Array[Vector2i] = []
	for hex in _hexes:
		if hex.x >= -2 and hex.x <= 1:
			eligible.append(hex)
	eligible.shuffle()
	var target := rng.randi_range(9, 14)
	var placed := 0
	for hex in eligible:
		if placed >= target: break
		_obstacles[hex] = rng.randi() % 2   # 0=дерево  1=камінь
		# Перевіряємо що шлях між сторонами ще існує
		if not _check_connectivity():
			_obstacles.erase(hex)
		else:
			placed += 1

# BFS: перевіряємо що від зони розстановки (q<=-3) можна дістатись ворожої зони (q>=2)
func _check_connectivity() -> bool:
	var queue:   Array[Vector2i]            = []
	var visited: Dictionary[Vector2i, bool] = {}
	for hex in _hexes:
		if hex.x <= -3:
			queue.append(hex)
			visited[hex] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur.x >= 2:
			return true
		for nb in HexGrid.get_neighbors(cur.x, cur.y):
			if _hexes.has(nb) and not visited.has(nb) and not _obstacles.has(nb):
				visited[nb] = true
				queue.append(nb)
	return false

# ── Генерація ворогів ─────────────────────────────────────────────────────
# Повертає 0.0 (початок) … 1.0 (кінець) залежно від шару поточного вузла
func _get_combat_depth() -> float:
	if GameState.regional_nodes.is_empty():
		return 0.5
	var cur := GameState.regional_current
	for nv in GameState.regional_nodes:
		if not nv is Dictionary: continue
		var nd := nv as Dictionary
		if int(nd.get("id", -1)) == cur:
			var layer: int = int(nd.get("layer", 1))
			var total: int = int(nd.get("total_layers", 3))
			return float(layer) / float(maxi(1, total - 1))
	return 0.5

# Спауним ворогів залежно від напрямку, глибини та рівня героя
func _spawn_enemies() -> void:
	var dir := clampi(GameState.current_direction, 0, ENEMY_POOLS.size() - 1)
	var pool: Array = ENEMY_POOLS[dir]

	# Масштаб від рівня героя: +12% за кожен рівень понад 1
	var hero_level := GameState.get_hero_level()
	var enemy_scale := 1.0 + float(hero_level - 1) * 0.12

	# Кількість залежить від глибини вилазки
	var depth := _get_combat_depth()
	var squad_size: int
	if   depth < 0.35: squad_size = 1
	elif depth < 0.70: squad_size = 2
	else:              squad_size = 3

	# Вибираємо squad_size різних типів з пулу (перемішаний порядок)
	var indices: Array[int] = [0, 1, 2]
	indices.shuffle()
	var chosen := indices.slice(0, squad_size)

	for i in chosen.size():
		var t: Array = pool[chosen[i]]
		var hp:  int = maxi(1, int(round(float(int(t[3])) * enemy_scale)))
		var dmg: int = maxi(1, int(round(float(int(t[4])) * enemy_scale)))
		_add_unit(ENEMY_SPAWN_POS[i], Unit.Team.ENEMY,
				t[0] as String, int(t[1]), t[2] as Color, hp, dmg, int(t[5]))

# ── Сигнали TurnManager ───────────────────────────────────────────────────
func _on_turn_started(unit: Unit) -> void:
	_sel_id = -1; _reachable = []; _attackable = []
	_ability_mode = false; _ability_targets = []
	if unit.ability_cd > 0:
		unit.ability_cd -= 1
	queue_redraw()
	if unit.team == Unit.Team.ENEMY:
		_run_enemy_ai(unit)

func _run_enemy_ai(unit: Unit) -> void:
	await get_tree().create_timer(0.5).timeout
	if _winner != -2:
		return

	var blocked := _combined_blocked()

	# Дальній атакант: спочатку відступити якщо гравець впритул
	if unit.attack_range > 1:
		var retreat_hex := EnemyAI.find_retreat(unit, _hexes, blocked, _units)
		if retreat_hex != EnemyAI.INVALID:
			_move_unit(unit.id, unit.hex, retreat_hex)
			return

	var atk_hex := EnemyAI.find_attack(unit, _hex_unit, _units)
	if atk_hex != EnemyAI.INVALID:
		var uid: int = _hex_unit.get(atk_hex, -1)
		if uid != -1:
			_do_attack(unit, _units[uid])
			return

	var move_hex := EnemyAI.find_move(unit, _hexes, blocked, _units)
	if move_hex != EnemyAI.INVALID:
		_move_unit(unit.id, unit.hex, move_hex)
		return

	_tm.advance()

func _on_combat_ended(winner: int) -> void:
	_winner = winner
	_sel_id = -1; _reachable = []; _attackable = []

	if winner == Unit.Team.PLAYER:
		if not GameState.tutorial_done:
			# Туторіал: рівно ресурси на будівництво каплиці
			GameState.resources["wood"]  += 20
			GameState.resources["stone"] += 10
			GameState.tutorial_done = true
			_combat_log = "Перемога! Знайдено матеріали для будівництва каплиці:  Д+20  К+10"
		else:
			# Гільдія злодіїв (2): лут ×1.5
			var loot_mult := 1.5 if GameState.has_building(2) else 1.0
			var loot_w := maxi(1, int(round(float(COMBAT_LOOT["wood"])  * loot_mult)))
			var loot_s := maxi(1, int(round(float(COMBAT_LOOT["stone"]) * loot_mult)))
			var loot_m := maxi(1, int(round(float(COMBAT_LOOT["metal"]) * loot_mult)))
			var loot_f := maxi(1, int(round(float(COMBAT_LOOT["food"])  * loot_mult)))
			GameState.resources["wood"]  += loot_w
			GameState.resources["stone"] += loot_s
			GameState.resources["metal"] += loot_m
			GameState.resources["food"]  += loot_f
			# Таверна (6): XP ×1.25
			var xp_total := maxi(1, int(round(50.0 * (1.25 if GameState.has_building(6) else 1.0))))
			var leveled := GameState.award_xp(xp_total)
			_levelup_log = ("  ★  ".join(leveled)) if not leveled.is_empty() else ""
			var bonus_str := ""
			if GameState.has_building(2): bonus_str += "  [злодії ×1.5]"
			if GameState.has_building(6): bonus_str += "  [таверна XP×1.25]"
			_combat_log = "Перемога!  XP+%d   Д+%d  К+%d  М+%d  Ї+%d%s" % [
				xp_total, loot_w, loot_s, loot_m, loot_f, bonus_str
			]
	elif winner == Unit.Team.ENEMY:
		_combat_log = "Поразка... Повертаємось на базу."
	else:
		_combat_log = "Нічия..."

	queue_redraw()
	await get_tree().create_timer(2.5).timeout

	if winner == Unit.Team.PLAYER and GameState.in_regional_map:
		GameState.regional_combat_pending = false
		get_tree().change_scene_to_file("res://scenes/world_map/RegionalMapScene.tscn")
	else:
		GameState.end_regional_map()
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/base/BaseScene.tscn")

# ── Input ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _phase == PHASE_DEPLOY:
		_input_deploy(event)
	else:
		_input_combat(event)

func _input_deploy(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos  := (event as InputEventMouseMotion).position
		var prev := _deploy_hover
		var h    := HexGrid.pixel_to_hex(pos - _origin(), HEX_SIZE)
		_deploy_hover = h if (_deploy_zone.has(h) and not _hex_unit.has(h)) else Vector2i(-9999, -9999)
		if _deploy_hover != prev:
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position

		# Кнопка "Почати бій!"
		if _all_deployed() and _start_btn_rect().has_point(pos):
			_start_combat()
			return


		var h := HexGrid.pixel_to_hex(pos - _origin(), HEX_SIZE)

		# Клік на вже розставленого гравця → підняти назад
		var uid_here: int = _hex_unit.get(h, -1)
		if uid_here != -1 and _units[uid_here].team == Unit.Team.PLAYER:
			_unplace_unit(_units[uid_here])
			queue_redraw()
			return

		# Клік на вільний гекс зони → поставити наступного
		if _deploy_zone.has(h) and not _hex_unit.has(h) and not _deploy_queue.is_empty():
			_place_unit(_deploy_queue[0], h)
			queue_redraw()

func _input_combat(event: InputEvent) -> void:
	if _winner != -2:
		return

	if _animating:
		return
	var act := _tm.active()
	if act.team == Unit.Team.ENEMY or act.acted:
		return

	if event is InputEventMouseMotion:
		var h := HexGrid.pixel_to_hex(event.position - _origin(), HEX_SIZE)
		if h != _hovered:
			_hovered = h
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos := (event as InputEventMouseButton).position
		var act2 := _tm.active()
		if _ability_btn_rect().has_point(mpos) and act2.team == Unit.Team.PLAYER \
				and not act2.acted and act2.ability_cd == 0 and act2.ability_cd_max > 0:
			if AbilitySystem.is_instant(act2.ability_id):
				_execute_ability(act2, act2.hex)
			else:
				_ability_mode = not _ability_mode
				_sel_id = -1; _reachable = []; _attackable = []
				if _ability_mode:
					_ability_targets = AbilitySystem.get_targets(
							act2.ability_id, act2, _hex_unit, _units, _hexes)
				else:
					_ability_targets.clear()
				queue_redraw()
		else:
			_handle_click(HexGrid.pixel_to_hex(event.position - _origin(), HEX_SIZE))

	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_E]:
			if _ability_mode:
				_ability_mode = false; _ability_targets = []
				queue_redraw()
			else:
				_sel_id = -1; _reachable = []; _attackable = []
				_tm.advance()

func _handle_click(h: Vector2i) -> void:
	# Режим здібності: клік на ціль → виконати; клік будь-куди інде → скасувати
	if _ability_mode:
		if _ability_targets.has(h):
			_execute_ability(_tm.active(), h)
		else:
			_ability_mode = false; _ability_targets = []
			queue_redraw()
		return

	var act := _tm.active()

	if _sel_id == act.id:
		if _reachable.has(h):
			_move_unit(act.id, act.hex, h)
		elif _attackable.has(h):
			var uid_here: int = _hex_unit.get(h, -1)
			if uid_here != -1:
				_do_attack(act, _units[uid_here])
		else:
			_sel_id = -1; _reachable = []; _attackable = []
			queue_redraw()
	else:
		var uid_here: int = _hex_unit.get(h, -1)
		if uid_here == act.id:
			_sel_id     = act.id
			_reachable  = HexGrid.get_reachable(act.hex, act.move_range, _hexes, _combined_blocked())
			_attackable = _get_attackable(act)
		else:
			_sel_id = -1; _reachable = []; _attackable = []
		queue_redraw()

# ── Логіка бою ───────────────────────────────────────────────────────────
func _get_attackable(attacker: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if attacker.attack_range == 1:
		for nb in HexGrid.get_neighbors(attacker.hex.x, attacker.hex.y):
			var uid_here: int = _hex_unit.get(nb, -1)
			if uid_here != -1 and _units[uid_here].team != attacker.team:
				result.append(nb)
	else:
		for hex in _hexes:
			if hex == attacker.hex:
				continue
			if HexGrid.distance(attacker.hex, hex) <= attacker.attack_range:
				var uid_here: int = _hex_unit.get(hex, -1)
				if uid_here != -1 and _units[uid_here].team != attacker.team:
					result.append(hex)
	return result

func _do_attack(attacker: Unit, target: Unit) -> void:
	# 1. Броня зменшує урон: reduction = armor / (armor + 100)  [diminishing returns]
	var armor: int = GameState.get_char_armor(target.char_key)
	var raw:   int = attacker.damage
	# Святилище тіней (5): 20% крит. удар (×1.5) для юнітів гравця
	var is_crit := false
	if attacker.team == Unit.Team.PLAYER and GameState.has_building(5):
		if randf() < 0.20:
			raw     = maxi(1, int(round(float(raw) * 1.5)))
			is_crit = true
	var after_armor: int = raw
	if armor > 0:
		after_armor = maxi(1, int(round(float(raw) * (1.0 - float(armor) / float(armor + 100)))))

	# 2. Бар'єри поглинають урон що пройшов крізь броню
	#    Фіз.: simple_barrier → magic_barrier → HP
	var remaining := after_armor
	var barrier_log := ""
	if remaining > 0 and target.simple_barrier > 0:
		var absorbed := mini(target.simple_barrier, remaining)
		target.simple_barrier -= absorbed
		remaining             -= absorbed
		barrier_log += "  [щит-%d]" % absorbed
	if remaining > 0 and target.magic_barrier > 0:
		var absorbed := mini(target.magic_barrier, remaining)
		target.magic_barrier -= absorbed
		remaining            -= absorbed
		barrier_log += "  [мбар-%d]" % absorbed

	# 3. Решта — до HP
	var final_dmg := remaining
	target.take_damage(final_dmg)

	# 4. Другий удар від зброї в доп. руці (25% від damage атакуючого)
	#    Умова: char_key не порожній, off_hand — зброя (dmg_bonus > 0), не двуручна
	var off_dmg := 0
	if attacker.char_key != "":
		var off_item := GameState.get_equipped_item(attacker.char_key, "off_hand")
		if not off_item.is_empty() and int(off_item.get("dmg_bonus", 0)) > 0 \
				and not off_item.get("two_handed", false):
			var off_raw := maxi(1, int(round(float(attacker.damage) * 0.25)))
			var off_after_armor := off_raw
			if armor > 0:
				off_after_armor = maxi(1, int(round(
						float(off_raw) * (1.0 - float(armor) / float(armor + 100)))))
			var off_rem := off_after_armor
			if off_rem > 0 and target.simple_barrier > 0:
				var ab := mini(target.simple_barrier, off_rem)
				target.simple_barrier -= ab; off_rem -= ab
			if off_rem > 0 and target.magic_barrier > 0:
				var ab := mini(target.magic_barrier, off_rem)
				target.magic_barrier -= ab; off_rem -= ab
			off_dmg = off_rem
			target.take_damage(off_dmg)

	var armor_str := "  [бр.%d→-%d%%]" % [armor,
			int(round(float(armor) / float(armor + 100) * 100.0))] if armor > 0 else ""
	var off_str   := "  +%d(дворучка)" % off_dmg if off_dmg > 0 else ""
	var crit_str  := "  [КРИТ!]" if is_crit else ""
	_combat_log = "%s → %s: -%d HP%s%s%s%s  (зал.%d)" % [
		attacker.label, target.label, final_dmg, crit_str, armor_str, barrier_log, off_str, target.hp
	]
	attacker.acted = true
	_sel_id = -1; _reachable = []; _attackable = []

	if not target.is_alive():
		_hex_unit.erase(target.hex)
		# Якщо загинув герой — позначити відновлення
		if target.id == _hero_uid:
			GameState.hero_recovery_raids = 1
		_tm.remove_unit(target.id)

	queue_redraw()
	if _winner == -2:
		await get_tree().create_timer(0.6).timeout
		_tm.advance()

func _move_unit(uid: int, from_hex: Vector2i, to_hex: Vector2i) -> void:
	var origin   := _origin()
	var from_pos := HexGrid.hex_to_pixel(from_hex.x, from_hex.y, HEX_SIZE) + origin
	var to_pos   := HexGrid.hex_to_pixel(to_hex.x,   to_hex.y,   HEX_SIZE) + origin

	_hex_unit.erase(from_hex)
	_hex_unit[to_hex] = uid
	_units[uid].hex   = to_hex
	_units[uid].acted = true
	_unit_anim[uid]   = from_pos
	_sel_id = -1; _reachable = []; _attackable = []
	_animating = true

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_method(
		func(pos: Vector2) -> void:
			_unit_anim[uid] = pos
			queue_redraw(),
		from_pos, to_pos, 0.35
	)
	tween.tween_callback(func() -> void:
		_unit_anim.erase(uid)
		_animating = false
		_tm.advance()
	)

# ── Рендер ───────────────────────────────────────────────────────────────
func _origin() -> Vector2:
	return get_viewport_rect().size * 0.5

func _draw() -> void:
	if _phase == PHASE_DEPLOY:
		_draw_deploy()
	else:
		_draw_combat()

# ── Рендер: перешкода ────────────────────────────────────────────────────
func _draw_obstacle(center: Vector2, type: int) -> void:
	if type == 0:  # Дерево
		draw_rect(Rect2(center.x - 2.5, center.y - 2.0, 5.0, 13.0), Color(0.35, 0.22, 0.10))
		draw_circle(center + Vector2(-5.0, -8.0),  8.0, Color(0.14, 0.36, 0.11))
		draw_circle(center + Vector2( 5.0, -8.0),  8.0, Color(0.11, 0.32, 0.09))
		draw_circle(center + Vector2( 0.0, -14.0), 9.0, Color(0.17, 0.41, 0.13))
	else:  # Камінь
		draw_circle(center + Vector2(-5.0,  3.0), 10.0, Color(0.33, 0.31, 0.29))
		draw_circle(center + Vector2( 5.0,  4.0),  8.0, Color(0.30, 0.28, 0.26))
		draw_circle(center + Vector2( 0.0,  0.0),  7.0, Color(0.43, 0.41, 0.38))
		draw_circle(center + Vector2(-2.0, -2.0),  3.0, Color(0.58, 0.55, 0.50, 0.5))

# ── Рендер: розстановка ──────────────────────────────────────────────────
func _draw_deploy() -> void:
	var origin := _origin()
	var font   := ThemeDB.fallback_font
	var vp     := get_viewport_rect().size

	for hex in _hexes:
		var center := HexGrid.hex_to_pixel(hex.x, hex.y, HEX_SIZE) + origin
		var verts  := HexGrid.hex_vertices(center, HEX_SIZE - 2.0)
		var uid_here: int = _hex_unit.get(hex, -1)

		var is_obstacle := _obstacles.has(hex) and uid_here == -1
		var fill: Color
		if uid_here != -1 and _units[uid_here].team == Unit.Team.PLAYER:
			fill = Color(0.12, 0.22, 0.40, 0.9)
		elif uid_here != -1 and _units[uid_here].team == Unit.Team.ENEMY:
			fill = Color(0.28, 0.08, 0.08, 0.9)
		elif is_obstacle:
			fill = Color(0.07, 0.06, 0.04, 0.97)
		elif hex == _deploy_hover:
			fill = C_DEPLOY_HOV
		elif _deploy_zone.has(hex):
			fill = C_DEPLOY_ZONE
		else:
			fill = C_FILL

		draw_colored_polygon(verts, fill)
		var outline := PackedVector2Array(verts)
		outline.append(verts[0])
		var in_zone := _deploy_zone.has(hex)
		draw_polyline(outline, C_BORDER_S if in_zone else C_BORDER, 1.5 if in_zone else 1.0)
		if is_obstacle:
			_draw_obstacle(center, _obstacles[hex])

	# Назва зони (не туторіал)
	if GameState.tutorial_done:
		var dir := GameState.current_direction
		if dir >= 0 and dir < DIRECTION_NAMES.size():
			var depth_pct := int(_get_combat_depth() * 100.0)
			draw_string(font, Vector2(12, 22),
					"⚔  %s  ·  глибина %d%%" % [DIRECTION_NAMES[dir], depth_pct],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.68, 0.40))

	# Малюємо юнітів (розставлених і ворогів)
	for unit in _units:
		if unit.hex == Vector2i(-9999, -9999):
			continue
		var draw_pos := HexGrid.hex_to_pixel(unit.hex.x, unit.hex.y, HEX_SIZE) + origin
		var radius   := 14.0
		draw_circle(draw_pos, radius, unit.color)
		draw_arc(draw_pos, radius, 0.0, TAU, 32, Color.WHITE, 2.0)
		draw_string(font, draw_pos + Vector2(-5, 5), unit.label.left(1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		_draw_hp_bar(draw_pos, radius, unit)

	# Нижня панель
	draw_rect(Rect2(0, vp.y - 64, vp.x, 64), Color(0, 0, 0, 0.7))

	# Черга розстановки — показуємо юнітів що ще не поставлені
	var queue_x := 12.0
	for i in _deploy_queue.size():
		var u := _deploy_queue[i]
		var is_next := i == 0
		var r := 16.0 if is_next else 11.0
		var cy := vp.y - 32.0
		draw_circle(Vector2(queue_x + r, cy), r, u.color)
		draw_arc(Vector2(queue_x + r, cy), r, 0.0, TAU, 32,
				Color.WHITE if is_next else Color(0.5,0.5,0.5), 2.0)
		draw_string(font, Vector2(queue_x + r - 5, cy + 5), u.label.left(1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if is_next:
			draw_string(font, Vector2(queue_x + r * 2 + 6, cy - 8),
					u.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			var mode := "дальній р.%d" % u.attack_range if u.attack_range > 1 else "ближній"
			draw_string(font, Vector2(queue_x + r * 2 + 6, cy + 10),
					"HP:%d  АТК:%d  РУХ:%d  Ін:%d  [%s]" % [u.hp, u.damage, u.move_range, u.initiative, mode],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7,0.7,0.7))
		queue_x += r * 2 + (80 if is_next else 10)

	if _deploy_queue.is_empty():
		draw_string(font, Vector2(12, vp.y - 24), "Всі розставлені",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.9, 0.5))

	# Підказка
	var hint: String
	if not _deploy_queue.is_empty():
		hint = "Клікни на синій гекс щоб поставити  |  клікни на юніта щоб прибрати"
	else:
		hint = "Натисни 'Почати бій!' або перестав юнітів"
	draw_string(font, Vector2(vp.x * 0.5 - 220, vp.y - 10), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.6))

	# Кнопка "Почати бій!"
	var sb  := _start_btn_rect()
	var can := _all_deployed()
	draw_rect(sb, Color(0.18, 0.38, 0.14, 0.9) if can else Color(0.14, 0.14, 0.14, 0.6))
	draw_rect(sb, C_BORDER_S if can else C_BORDER, false, 1.5)
	draw_string(font, sb.position + Vector2(18, 24), "Почати бій!",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE if can else Color(0.4,0.4,0.4))


# ── Рендер: бій ──────────────────────────────────────────────────────────
func _draw_combat() -> void:
	var font := ThemeDB.fallback_font

	if _winner != -2:
		_draw_result(font)
		return

	var origin := _origin()
	var act    := _tm.active()

	for hex in _hexes:
		var center := HexGrid.hex_to_pixel(hex.x, hex.y, HEX_SIZE) + origin
		var verts  := HexGrid.hex_vertices(center, HEX_SIZE - 2.0)
		var uid_here: int = _hex_unit.get(hex, -1)
		var is_ranged := _sel_id != -1 and _units[_sel_id].attack_range > 1

		var is_obstacle := _obstacles.has(hex) and uid_here == -1
		var fill: Color
		if uid_here == _sel_id and _sel_id != -1:   fill = C_ACT_HEX
		elif _attackable.has(hex):                   fill = C_ATTACK_RNG if is_ranged else C_ATTACK
		elif _reachable.has(hex):                    fill = C_REACHABLE
		elif _ability_targets.has(hex):              fill = C_ABILITY
		elif is_obstacle:                            fill = Color(0.07, 0.06, 0.04, 0.97)
		elif hex == _hovered:                        fill = C_HOVER
		else:                                        fill = C_FILL

		draw_colored_polygon(verts, fill)
		var outline := PackedVector2Array(verts)
		outline.append(verts[0])
		var is_act_hex := hex == act.hex and act.team == Unit.Team.PLAYER
		draw_polyline(outline, C_BORDER_S if is_act_hex else C_BORDER, 1.5)
		if is_obstacle:
			_draw_obstacle(center, _obstacles[hex])

	for unit in _units:
		if not unit.is_alive():
			continue
		var draw_pos: Vector2 = _unit_anim.get(unit.id,
				HexGrid.hex_to_pixel(unit.hex.x, unit.hex.y, HEX_SIZE) + origin)
		var is_act := unit.id == act.id
		var is_sel := unit.id == _sel_id
		var radius := 16.0 if is_sel else 13.0

		draw_circle(draw_pos, radius, unit.color if not unit.acted else unit.color * 0.45)
		var ring_col: Color
		if is_sel:   ring_col = Color.WHITE
		elif is_act: ring_col = Color(1.0, 1.0, 0.4)
		else:        ring_col = Color(0.3, 0.3, 0.3)
		draw_arc(draw_pos, radius, 0.0, TAU, 32, ring_col, 2.5 if is_act or is_sel else 1.5)
		draw_string(font, draw_pos + Vector2(-5, 5), unit.label.left(1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		_draw_hp_bar(draw_pos, radius, unit)

	_draw_queue(font)
	_draw_status(font, act)

func _draw_result(font: Font) -> void:
	var vp  := get_viewport_rect().size
	var col := Color(0.3, 0.9, 0.3) if _winner == Unit.Team.PLAYER \
			else (Color(0.9, 0.3, 0.3) if _winner == Unit.Team.ENEMY \
			else Color(0.8, 0.8, 0.5))
	var box_h := 98.0 if _levelup_log != "" else 68.0
	draw_rect(Rect2(0, vp.y * 0.5 - box_h * 0.5, vp.x, box_h), Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(vp.x * 0.5 - 220, vp.y * 0.5 - 8 + (0 if _levelup_log == "" else -14)),
			_combat_log, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	if _levelup_log != "":
		draw_string(font, Vector2(vp.x * 0.5 - 220, vp.y * 0.5 + 22),
				_levelup_log, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.88, 0.25))

func _draw_hp_bar(center: Vector2, radius: float, unit: Unit) -> void:
	var bar_w := radius * 2.2
	var by    := center.y + radius + 4.0
	var ratio := float(unit.hp) / float(unit.max_hp)
	draw_rect(Rect2(center.x - bar_w * 0.5, by, bar_w, 4.0), Color(0.15, 0.15, 0.15))
	var hp_col := Color(0.15, 0.75, 0.15) if ratio > 0.5 else \
				 (Color(0.85, 0.75, 0.10) if ratio > 0.25 else Color(0.85, 0.15, 0.15))
	draw_rect(Rect2(center.x - bar_w * 0.5, by, bar_w * ratio, 4.0), hp_col)
	# Фіз. бар'єр — блакитна смужка над HP-баром (зменшується при поглинанні ударів)
	if unit.max_simple_barrier > 0:
		var sr := float(unit.simple_barrier) / float(unit.max_simple_barrier)
		draw_rect(Rect2(center.x - bar_w * 0.5, by - 4.0, bar_w, 3.0), Color(0.08, 0.10, 0.18))
		draw_rect(Rect2(center.x - bar_w * 0.5, by - 4.0, bar_w * sr, 3.0), Color(0.30, 0.55, 0.90))

func _draw_queue(font: Font) -> void:
	var vp      := get_viewport_rect().size
	var order   := _tm._order
	var slot    := 44.0
	var start_x := vp.x * 0.5 - order.size() * slot * 0.5
	draw_rect(Rect2(0, 0, vp.x, 52), Color(0, 0, 0, 0.5))
	for i in order.size():
		var unit := _units[order[i]]
		var cx   := start_x + i * slot + slot * 0.5
		var is_a := i == _tm._idx
		var r    := 14.0 if is_a else 10.0
		draw_circle(Vector2(cx, 26), r, unit.color)
		draw_arc(Vector2(cx, 26), r, 0.0, TAU, 32,
				Color.WHITE if is_a else Color(0.35, 0.35, 0.35), 2.0)
		draw_string(font, Vector2(cx - 4, 31), unit.label.left(1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	# Назва зони — правий кут черги
	if GameState.tutorial_done:
		var dir := GameState.current_direction
		if dir >= 0 and dir < DIRECTION_NAMES.size():
			draw_string(font, Vector2(vp.x - 90, 38), DIRECTION_NAMES[dir],
					HORIZONTAL_ALIGNMENT_RIGHT, 78, 11, Color(0.55, 0.50, 0.32))

func _draw_status(font: Font, act: Unit) -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(0, vp.y - 56, vp.x, 56), Color(0, 0, 0, 0.5))
	if _combat_log != "":
		draw_string(font, Vector2(12, vp.y - 30), _combat_log,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.4))

	# Кнопка здібності (тільки для активного гравця з здібністю)
	if act.team == Unit.Team.PLAYER and act.ability_cd_max > 0:
		var abr      := _ability_btn_rect()
		var can_use  := act.ability_cd == 0 and not act.acted
		var ab_name := AbilitySystem.get_ability_name(act.ability_id)
		if ab_name.is_empty(): ab_name = "?"
		var btn_bg: Color
		if _ability_mode:   btn_bg = Color(0.18, 0.08, 0.32, 0.97)
		elif can_use:       btn_bg = Color(0.22, 0.10, 0.38, 0.95)
		else:               btn_bg = Color(0.10, 0.07, 0.15, 0.90)
		var btn_bc: Color
		if _ability_mode:   btn_bc = Color(0.85, 0.55, 1.00)
		elif can_use:       btn_bc = Color(0.60, 0.32, 0.85)
		else:               btn_bc = Color(0.32, 0.26, 0.42)
		draw_rect(abr, btn_bg)
		draw_rect(abr, btn_bc, false, 1.5)
		var lbl_col := Color(0.95, 0.72, 1.00) if can_use else Color(0.52, 0.46, 0.60)
		draw_string(font, abr.position + Vector2(0, 16),
				"✦ %s" % ab_name, HORIZONTAL_ALIGNMENT_CENTER, int(abr.size.x), 13, lbl_col)
		if act.ability_cd > 0:
			draw_string(font, abr.position + Vector2(0, 31),
					"КД: %d хід." % act.ability_cd,
					HORIZONTAL_ALIGNMENT_CENTER, int(abr.size.x), 11, Color(0.60, 0.55, 0.70))
		elif can_use:
			draw_string(font, abr.position + Vector2(0, 31), "Готово!",
					HORIZONTAL_ALIGNMENT_CENTER, int(abr.size.x), 11,
					Color(0.90, 0.70, 1.00) if not _ability_mode else Color(1.0, 0.9, 1.0))

	var hint: String
	if act.team == Unit.Team.ENEMY:
		hint = "Хід ворога: %s..." % act.label
	elif act.acted:
		hint = "%s вже діяв  (Space — пропустити)" % act.label
	elif _ability_mode:
		var ab_n := AbilitySystem.get_ability_name(act.ability_id)
		hint = "%s [%s] — клікни на ціль  |  Space — скасувати" % [act.label, ab_n]
	elif _sel_id != -1:
		var mode := "дальній" if act.attack_range > 1 else "ближній"
		hint = "%s [%s, р.%d] — зелений: рух  |  пурп./черв.: атака  |  Space — пропустити" % [act.label, mode, act.attack_range]
	else:
		var has_ab := act.ability_cd_max > 0 and act.team == Unit.Team.PLAYER
		hint = "Хід: %s — клікни на юніт  |  ✦ %s" % [
				act.label, AbilitySystem.get_ability_name(act.ability_id)] if has_ab else \
				"Хід: %s — клікни на юніт" % act.label
	draw_string(font, Vector2(12, vp.y - 10), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
