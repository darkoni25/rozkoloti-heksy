extends Node2D

const LOOT_REWARDS = {"wood": 15, "stone": 10, "metal": 5, "food": 10}

# ── Кольори ───────────────────────────────────────────────────────────────
const C_NODE_IDLE    := Color(0.14, 0.12, 0.10)
const C_NODE_VISIT   := Color(0.10, 0.10, 0.10)
const C_NODE_REACH   := Color(0.18, 0.32, 0.18)
const C_NODE_CURRENT := Color(0.45, 0.35, 0.08)
const C_NODE_HOV     := Color(0.28, 0.48, 0.25)
const C_NODE_END     := Color(0.35, 0.12, 0.12)
const C_EDGE         := Color(0.35, 0.30, 0.22)
const C_EDGE_DONE    := Color(0.20, 0.20, 0.18)
const C_EDGE_REACH   := Color(0.55, 0.75, 0.40)
const C_BORDER       := Color(0.50, 0.42, 0.30)
const C_BORDER_S     := Color(0.85, 0.65, 0.15)
const NODE_R         := 26.0

# ── Стан ─────────────────────────────────────────────────────────────────
var _hovered:   int            = -1
var _reachable: Array[int]     = []
var _message:   String         = ""

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.06))
	_update_reachable()
	# Якщо завантажились під час бою — відразу повертаємось у бій
	if GameState.regional_combat_pending:
		get_tree().change_scene_to_file("res://scenes/combat/CombatScene.tscn")
		return

func _update_reachable() -> void:
	_reachable = []
	var cur := GameState.regional_current
	for edge in GameState.regional_edges:
		var a: int = edge[0]; var b: int = edge[1]
		if a == cur and not GameState.regional_visited.has(b):
			_reachable.append(b)

# ── Позиції ───────────────────────────────────────────────────────────────
func _node_pos(node_id: int) -> Vector2:
	var n: Dictionary   = GameState.regional_nodes[node_id]
	var vp              := get_viewport_rect().size
	var layer: int      = n["layer"]
	var slot:  int      = n["slot"]
	var max_s: int      = n["max_slots"]
	var total: int      = n["total_layers"]

	var x_frac := (slot + 0.5) / float(max_s)
	var x      := lerpf(80.0, vp.x - 80.0, x_frac)
	var y      := lerpf(vp.y - 90.0, 90.0, layer / float(total - 1))
	return Vector2(x, y)

func _back_rect() -> Rect2:
	return Rect2(12, get_viewport_rect().size.y - 46, 130, 30)

# ── Input ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos  := (event as InputEventMouseMotion).position
		var prev := _hovered
		_hovered = -1
		for nid in _reachable:
			if pos.distance_to(_node_pos(nid)) <= NODE_R + 10:
				_hovered = nid; break
		if _hovered != prev:
			queue_redraw()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position
		if _back_rect().has_point(pos):
			GameState.end_regional_map()
			GameState.save_game()
			get_tree().change_scene_to_file("res://scenes/base/BaseScene.tscn")
			return
		for nid in _reachable:
			if pos.distance_to(_node_pos(nid)) <= NODE_R + 10:
				_enter_node(nid)
				return

func _enter_node(nid: int) -> void:
	GameState.regional_current = nid
	GameState.regional_visited.append(nid)
	_update_reachable()

	var n: Dictionary = GameState.regional_nodes[nid]
	var t: int        = n["type"]

	if t == GameState.NodeType.COMBAT:
		GameState.regional_combat_pending = true
		get_tree().change_scene_to_file("res://scenes/combat/CombatScene.tscn")

	elif t == GameState.NodeType.LOOT:
		for key in LOOT_REWARDS:
			GameState.resources[key] += LOOT_REWARDS[key]
		var leveled  := GameState.award_xp(25)
		var exp_loot := GameState.award_expedition_loot(false)
		var loot_msg := "Знайдено: Д+%d  К+%d  М+%d  Ї+%d  |  %s" % [
			LOOT_REWARDS["wood"], LOOT_REWARDS["stone"],
			LOOT_REWARDS["metal"], LOOT_REWARDS["food"], exp_loot
		]
		if not leveled.is_empty():
			loot_msg += "  |  " + "  ★  ".join(leveled)
		_message = loot_msg
		_update_reachable()
		queue_redraw()

	elif t == GameState.NodeType.END:
		# XP за завершення вилазки
		var leveled := GameState.award_xp(30)
		# Позначити напрямок як досліджений
		if GameState.current_direction != -1 and \
				not GameState.explored_directions.has(GameState.current_direction):
			GameState.explored_directions.append(GameState.current_direction)
		# end_regional_map() ПЕРЕД save_game() — щоб in_regional_map = false
		# записався в файл (інакше при завантаженні гра знову відкриє карту)
		GameState.end_regional_map()
		GameState.save_game()
		var end_msg := "Вилазка завершена! Повертаємось на базу."
		if not leveled.is_empty():
			end_msg += "  " + "  ★  ".join(leveled)
		_message = end_msg
		queue_redraw()
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/base/BaseScene.tscn")

# ── Рендер ───────────────────────────────────────────────────────────────
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp   := get_viewport_rect().size

	# Ребра
	for edge in GameState.regional_edges:
		var a: int = edge[0]; var b: int = edge[1]
		var pa := _node_pos(a); var pb := _node_pos(b)
		var both_visited := GameState.regional_visited.has(a) and GameState.regional_visited.has(b)
		var is_reach     := a == GameState.regional_current and _reachable.has(b)
		var col := C_EDGE_DONE if both_visited else (C_EDGE_REACH if is_reach else C_EDGE)
		draw_line(pa, pb, col, 2.5 if is_reach else 1.5)

	# Вузли
	for node: Dictionary in GameState.regional_nodes:
		var nid:   int = node["id"]
		var ntype: int = node["type"]
		var np         := _node_pos(nid)
		var visited    := GameState.regional_visited.has(nid)
		var is_cur     := nid == GameState.regional_current
		var is_reach   := _reachable.has(nid)
		var is_hov     := nid == _hovered

		var bg: Color
		if is_cur:                              bg = C_NODE_CURRENT
		elif is_hov:                            bg = C_NODE_HOV
		elif is_reach:                          bg = C_NODE_REACH
		elif visited:                           bg = C_NODE_VISIT
		elif ntype == GameState.NodeType.END:   bg = C_NODE_END
		else:                                   bg = C_NODE_IDLE

		draw_circle(np, NODE_R, bg)
		draw_arc(np, NODE_R, 0, TAU, 48,
				C_BORDER_S if (is_cur or is_reach) else C_BORDER,
				2.5 if (is_cur or is_reach) else 1.5)

		# Іконка типу
		var icon: String
		match ntype:
			GameState.NodeType.START:  icon = "★"
			GameState.NodeType.COMBAT: icon = "⚔" if not visited else "✓"
			GameState.NodeType.LOOT:   icon = "◆" if not visited else "✓"
			GameState.NodeType.END:    icon = "!"
			_:                         icon = "?"
		var icon_col := Color.WHITE if not visited or is_cur else Color(0.4, 0.4, 0.4)
		draw_string(font, np + Vector2(-7, 7), icon,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, icon_col)

		# Тултіп при наведенні
		if is_hov and not visited:
			var tt_title: String
			var tt_body:  String
			var tt_col:   Color
			match ntype:
				GameState.NodeType.COMBAT:
					tt_title = "⚔  Бій"
					tt_body  = "Зустріч з ворогами\nПеремога дає XP та лут"
					tt_col   = Color(0.90, 0.45, 0.35)
				GameState.NodeType.LOOT:
					tt_title = "◆  Знахідка"
					tt_body  = "Ресурси та трофеї\nБез бою"
					tt_col   = Color(0.45, 0.85, 0.55)
				GameState.NodeType.END:
					tt_title = "!  Кінець шляху"
					tt_body  = "Повернення на базу\n+30 XP загону"
					tt_col   = Color(0.75, 0.62, 0.30)
				_:
					tt_title = ""; tt_body = ""; tt_col = Color.WHITE
			if tt_title != "":
				var tw := 148.0; var th := 52.0
				var tx := np.x - tw * 0.5
				var ty := np.y - NODE_R - th - 8.0
				# Тримаємо в межах екрана
				tx = clampf(tx, 6.0, vp.x - tw - 6.0)
				ty = maxf(ty, 6.0)
				draw_rect(Rect2(tx, ty, tw, th), Color(0.06, 0.05, 0.04, 0.92))
				draw_rect(Rect2(tx, ty, tw, th), tt_col * 0.6, false, 1.2)
				draw_string(font, Vector2(tx + 8, ty + 15), tt_title,
						HORIZONTAL_ALIGNMENT_LEFT, int(tw) - 12, 12, tt_col)
				for li in tt_body.split("\n"):
					draw_string(font, Vector2(tx + 8, ty + 30 + tt_body.split("\n").find(li) * 14),
							li as String, HORIZONTAL_ALIGNMENT_LEFT, int(tw) - 12, 10,
							Color(0.72, 0.70, 0.65))

	# Повідомлення
	if _message != "":
		draw_rect(Rect2(0, vp.y * 0.5 - 24, vp.x, 44), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(vp.x * 0.5 - 180, vp.y * 0.5 + 8), _message,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.5))

	# Кнопка назад
	var br := _back_rect()
	draw_rect(br, Color(0.18, 0.14, 0.10, 0.9))
	draw_rect(br, C_BORDER, false, 1.0)
	draw_string(font, br.position + Vector2(10, 20), "< Покинути",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	# Підказка знизу
	if _reachable.is_empty() and not _message.contains("Вилазка"):
		draw_string(font, Vector2(vp.x * 0.5 - 80, vp.y - 56),
				"Шлях закритий", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.3, 0.3))
