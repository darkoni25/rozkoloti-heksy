extends Node2D

# ── Карта світу: фіксована мережа локацій ────────────────────────────────────
#
# dir 0 = Дворфи (NW)   dir 2 = Берег (SE)   dir 1 = Ельфи (заблоковано водою)
#
# Структура (dir 0):
#   BASE → [Гірський перевал] ┬→ [Руїни форту]  → [Підземелля]
#                              └→ [Темний ліс]   ↗
#
# Структура (dir 2):
#   BASE → [Прибережний ліс] ┬→ [Покинуте село] → [Морська бухта]
#                             └→ [Болота]        ↗
#
const WORLD_NODES: Array[Dictionary] = [
	# dir 0 — Дворфи
	{"id":0,"dir":0,"name":"Гірський перевал","pos":Vector2(-185,-95), "diff":1,
	 "rewards":{"wood":0,"stone":15,"metal":20,"food":0}},
	{"id":1,"dir":0,"name":"Руїни форту",     "pos":Vector2(-310,-160),"diff":2,
	 "rewards":{"wood":0,"stone":20,"metal":25,"food":0}},
	{"id":2,"dir":0,"name":"Темний ліс",      "pos":Vector2(-195,-215),"diff":2,
	 "rewards":{"wood":20,"stone":0,"metal":15,"food":0}},
	{"id":3,"dir":0,"name":"Підземелля",      "pos":Vector2(-295,-278),"diff":3,
	 "rewards":{"wood":0,"stone":25,"metal":35,"food":0}},
	# dir 2 — Берег (тепер верхній-правий, NE)
	{"id":4,"dir":2,"name":"Прибережний ліс","pos":Vector2(188,-95),  "diff":1,
	 "rewards":{"wood":20,"stone":0,"metal":0,"food":15}},
	{"id":5,"dir":2,"name":"Покинуте село",  "pos":Vector2(312,-158), "diff":2,
	 "rewards":{"wood":15,"stone":0,"metal":0,"food":20}},
	{"id":6,"dir":2,"name":"Болота",         "pos":Vector2(198,-212), "diff":2,
	 "rewards":{"wood":0,"stone":10,"metal":0,"food":25}},
	{"id":7,"dir":2,"name":"Морська бухта",  "pos":Vector2(294,-275), "diff":3,
	 "rewards":{"wood":0,"stone":0,"metal":20,"food":30}},
]

# from == -1 означає з'єднання з базою
const WORLD_EDGES: Array = [
	[-1, 0], [-1, 4],          # база → вхідні точки
	[0, 1],  [0, 2],           # Дворфи: форк
	[1, 3],  [2, 3],           # Дворфи: сходяться в Підземеллі
	[4, 5],  [4, 6],           # Берег: форк
	[5, 7],  [6, 7],           # Берег: сходяться в Морській бухті
]

# Заблокований шлях (Ельфи — за морем): тільки візуально, тепер SE
const BLOCKED_OFFSET := Vector2(258, 195)

# ── Розмір вузлів ─────────────────────────────────────────────────────────────
const BASE_R  := 36.0
const NODE_R  := 22.0

# ── Кольори ───────────────────────────────────────────────────────────────────
const C_BASE      := Color(0.30, 0.22, 0.08)
const C_EXPLORED  := Color(0.13, 0.13, 0.11)
const C_REACH     := Color(0.16, 0.28, 0.16)
const C_REACH_H   := Color(0.23, 0.43, 0.20)
const C_FOG       := Color(0.09, 0.09, 0.11)
const C_SEL       := Color(0.46, 0.34, 0.07)
const C_BLOCKED   := Color(0.11, 0.16, 0.22)
const C_BORDER    := Color(0.48, 0.40, 0.28)
const C_BORDER_S  := Color(0.85, 0.65, 0.15)
const C_RES := {
	"wood":  Color(0.55, 0.38, 0.10),
	"stone": Color(0.55, 0.55, 0.55),
	"metal": Color(0.35, 0.58, 0.78),
	"food":  Color(0.28, 0.68, 0.28),
}
# Колір за складністю: індекс 0 не використовується
const DIFF_COL: Array[Color] = [
	Color.TRANSPARENT,
	Color(0.35, 0.80, 0.35),   # 1 — легко
	Color(0.85, 0.75, 0.20),   # 2 — середньо
	Color(0.88, 0.35, 0.28),   # 3 — важко
]
const DIFF_LABEL: Array[String] = ["", "Легка", "Середня", "Важка"]

# ── Стан ─────────────────────────────────────────────────────────────────────
var _hovered:  int = -1
var _selected: int = -1

# ── Готовність ───────────────────────────────────────────────────────────────
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.06))

# ── Позиції ───────────────────────────────────────────────────────────────────
func _center() -> Vector2:
	return get_viewport_rect().size * 0.5

func _node_pos(node_id: int) -> Vector2:
	return _center() + (WORLD_NODES[node_id]["pos"] as Vector2)

# ── Логіка видимості та досяжності ───────────────────────────────────────────

# Вузол видимий якщо хоча б один його попередник пройдено (або він прямо від бази)
func _is_discovered(node_id: int) -> bool:
	for edge in WORLD_EDGES:
		var e    := edge as Array
		var from := int(e[0])
		var to   := int(e[1])
		if to != node_id:
			continue
		if from == -1:
			return true
		if GameState.world_explored.has(from):
			return true
	return false

func _is_reachable(node_id: int) -> bool:
	if GameState.world_explored.has(node_id):
		return false
	return _is_discovered(node_id)

# ── Rect-хелпери ─────────────────────────────────────────────────────────────
func _confirm_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 92, vp.y - 68, 184, 38)

func _back_rect() -> Rect2:
	return Rect2(12, get_viewport_rect().size.y - 48, 112, 32)

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos  := (event as InputEventMouseMotion).position
		var prev := _hovered
		_hovered = -1
		for i in WORLD_NODES.size():
			if _is_reachable(i) and pos.distance_to(_node_pos(i)) <= NODE_R + 10:
				_hovered = i; break
		if _hovered != prev:
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position

		if _back_rect().has_point(pos):
			get_tree().change_scene_to_file("res://scenes/base/BaseScene.tscn")
			return

		if _selected != -1 and _confirm_rect().has_point(pos):
			_launch_raid()
			return

		for i in WORLD_NODES.size():
			if _is_reachable(i) and pos.distance_to(_node_pos(i)) <= NODE_R + 10:
				_selected = i if _selected != i else -1
				queue_redraw()
				return

		_selected = -1
		queue_redraw()

func _launch_raid() -> void:
	var node: Dictionary        = WORLD_NODES[_selected]
	GameState.current_direction  = int(node["dir"])
	GameState.current_world_node = _selected
	GameState.start_regional_map()
	GameState.save_game()   # зберігаємо перед вилазкою — in_regional_map і current_world_node в файлі
	get_tree().change_scene_to_file("res://scenes/world_map/RegionalMapScene.tscn")

# ── Рендер ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var center := _center()
	var font   := ThemeDB.fallback_font
	var vp     := get_viewport_rect().size

	# ── Ребра між вузлами (тільки між відкритими) ────────────────────────
	for edge in WORLD_EDGES:
		var e       := edge as Array
		var from_id := int(e[0])
		var to_id   := int(e[1])

		# Ребро видиме лише якщо TO вузол вже відкрито
		if not _is_discovered(to_id):
			continue
		# Якщо FROM не base — він теж має бути відкритий
		if from_id != -1 and not _is_discovered(from_id):
			continue

		var pa := center if from_id == -1 else _node_pos(from_id)
		var pb := _node_pos(to_id)

		var from_ok := from_id == -1 or GameState.world_explored.has(from_id)
		var to_exp  := GameState.world_explored.has(to_id)
		var col: Color
		if from_ok and to_exp:   col = Color(0.24, 0.22, 0.17, 0.8)
		elif from_ok:            col = Color(0.52, 0.72, 0.38, 0.9)
		else:                    col = Color(0.26, 0.24, 0.20, 0.45)
		draw_line(pa, pb, col, 2.0)

	# ── Заблокований напрямок (Ельфи) ────────────────────────────────────
	var blocked_pos := center + BLOCKED_OFFSET
	draw_line(center, blocked_pos, Color(0.20, 0.28, 0.38, 0.45), 1.5)
	draw_circle(blocked_pos, 18.0, C_BLOCKED)
	draw_arc(blocked_pos, 18.0, 0, TAU, 32, Color(0.24, 0.34, 0.48), 1.0)
	draw_string(font, blocked_pos + Vector2(-6, 6), "⚓",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.32, 0.42, 0.58))
	draw_string(font, blocked_pos + Vector2(-42, 28), "Ельфійський ліс",
			HORIZONTAL_ALIGNMENT_CENTER, 84, 10, Color(0.30, 0.38, 0.52))
	draw_string(font, blocked_pos + Vector2(-38, 40), "(море перекрито)",
			HORIZONTAL_ALIGNMENT_CENTER, 76, 9, Color(0.25, 0.32, 0.44))

	# ── База ─────────────────────────────────────────────────────────────
	draw_circle(center, BASE_R, C_BASE)
	draw_arc(center, BASE_R, 0, TAU, 48, C_BORDER_S, 2.5)
	draw_string(font, center + Vector2(0, 6), "БАЗА",
			HORIZONTAL_ALIGNMENT_CENTER, int(BASE_R * 2), 13, Color.WHITE)

	# ── Вузли (тільки відкриті) ──────────────────────────────────────────
	for i in WORLD_NODES.size():
		if not _is_discovered(i):
			continue
		var node:     Dictionary = WORLD_NODES[i]
		var np        := _node_pos(i)
		var is_sel    := i == _selected
		var is_hov    := i == _hovered
		var explored  := GameState.world_explored.has(i)
		var reachable := _is_reachable(i)

		# Фон вузла
		var bg: Color
		if is_sel:       bg = C_SEL
		elif is_hov:     bg = C_REACH_H
		elif reachable:  bg = C_REACH
		elif explored:   bg = C_EXPLORED
		else:            bg = C_FOG
		draw_circle(np, NODE_R, bg)

		# Рамка
		var bdr: Color
		if is_sel:       bdr = C_BORDER_S
		elif is_hov:     bdr = Color(0.52, 0.78, 0.40)
		elif reachable:  bdr = Color(0.42, 0.62, 0.32)
		elif explored:   bdr = Color(0.32, 0.30, 0.26)
		else:            bdr = Color(0.22, 0.22, 0.24)
		draw_arc(np, NODE_R, 0, TAU, 48, bdr,
				2.0 if (is_sel or is_hov) else 1.2)

		# Іконка всередині
		if explored:
			draw_string(font, np + Vector2(0, 6), "✓",
					HORIZONTAL_ALIGNMENT_CENTER, int(NODE_R * 2), 14,
					Color(0.38, 0.38, 0.36))
		else:
			# Зірки складності
			var diff: int = int(node["diff"])
			var stars := ""
			for _s in diff:
				stars += "★"
			var star_col := DIFF_COL[diff] if reachable else Color(DIFF_COL[diff], 0.35)
			draw_string(font, np + Vector2(0, 7), stars,
					HORIZONTAL_ALIGNMENT_CENTER, int(NODE_R * 2), 11, star_col)

		# Назва під вузлом
		var name_col: Color
		if explored:     name_col = Color(0.36, 0.34, 0.32)
		elif reachable:  name_col = Color(0.78, 0.88, 0.65)
		elif is_sel:     name_col = Color(1.00, 0.90, 0.50)
		else:            name_col = Color(0.28, 0.28, 0.30)
		draw_string(font, np + Vector2(0, NODE_R + 15), node["name"] as String,
				HORIZONTAL_ALIGNMENT_CENTER, 120, 11, name_col)

		# Тултіп
		if (is_hov or is_sel) and not explored:
			_draw_tooltip(font, np, node, vp)

	# ── Кнопка підтвердження ─────────────────────────────────────────────
	if _selected != -1:
		var sel_node: Dictionary = WORLD_NODES[_selected]
		var cr := _confirm_rect()
		draw_rect(cr, Color(0.16, 0.36, 0.10))
		draw_rect(cr, C_BORDER_S, false, 1.5)
		draw_string(font, Vector2(cr.position.x, cr.position.y + 25),
				"Вирушити: %s" % (sel_node["name"] as String),
				HORIZONTAL_ALIGNMENT_CENTER, int(cr.size.x), 13, Color.WHITE)

	# ── Кнопка назад ─────────────────────────────────────────────────────
	var br := _back_rect()
	draw_rect(br, Color(0.17, 0.12, 0.08, 0.9))
	draw_rect(br, C_BORDER, false, 1.0)
	draw_string(font, br.position + Vector2(10, 21), "< До бази",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	# Підказка якщо нічого не вибрано
	if _selected == -1:
		draw_string(font, Vector2(vp.x * 0.5, vp.y - 18), "Обери локацію для вилазки",
				HORIZONTAL_ALIGNMENT_CENTER, 300, 12, Color(0.48, 0.48, 0.48))

# ── Тултіп при наведенні ─────────────────────────────────────────────────────
func _draw_tooltip(font: Font, np: Vector2, node: Dictionary, vp: Vector2) -> void:
	var rewards: Dictionary = node["rewards"] as Dictionary
	var diff: int           = int(node["diff"])

	# Рахуємо скільки рядків нагород
	var rew_count := 0
	for k in ["wood", "stone", "metal", "food"]:
		if int(rewards.get(k, 0)) > 0:
			rew_count += 1

	var tw := 164.0
	var th := 28.0 + 16.0 + float(rew_count) * 16.0
	var tx  := np.x - tw * 0.5
	var ty  := np.y - NODE_R - th - 8.0

	# Тримаємо в межах екрану
	tx = clampf(tx, 6.0, vp.x - tw - 6.0)
	ty = maxf(ty, 6.0)

	draw_rect(Rect2(tx, ty, tw, th), Color(0.06, 0.05, 0.04, 0.95))
	draw_rect(Rect2(tx, ty, tw, th), DIFF_COL[diff] * 0.55, false, 1.2)

	# Складність
	draw_string(font, Vector2(tx + 8, ty + 15),
			DIFF_LABEL[diff] + " вилазка",
			HORIZONTAL_ALIGNMENT_LEFT, int(tw) - 12, 11, DIFF_COL[diff])

	# Нагороди
	var ry := ty + 31.0
	for k in ["wood", "stone", "metal", "food"]:
		var val: int = int(rewards.get(k, 0))
		if val == 0:
			continue
		var lbl_map: Dictionary = {"wood": "Деревина", "stone": "Камінь",
								   "metal": "Метал",   "food": "Їжа"}
		var col: Color = C_RES[k]
		draw_rect(Rect2(tx + 8, ry - 9, 8, 8), col)
		draw_string(font, Vector2(tx + 20, ry),
				"%s  +%d" % [lbl_map[k] as String, val],
				HORIZONTAL_ALIGNMENT_LEFT, int(tw) - 24, 11, col)
		ry += 16.0
