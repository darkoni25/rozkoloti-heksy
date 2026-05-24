extends Node2D

# ── Дані напрямків ────────────────────────────────────────────────────────
const TUTORIAL_DIRECTION = {
	"rewards": {"wood": 20, "stone": 10, "metal": 0, "food": 0},
	"offset":  Vector2(0, -210),
}
const DIRECTIONS = [
	{
		"rewards": {"wood": 20, "food": 15, "metal": 0, "stone": 0},
		"offset":  Vector2(-280, 20),
	},
	{
		"rewards": {"wood": 0, "food": 0, "metal": 15, "stone": 25},
		"offset":  Vector2(290, 30),
	},
	{
		"rewards": {"wood": 10, "food": 20, "metal": 10, "stone": 0},
		"offset":  Vector2(200, -210),
	},
]

func _dirs() -> Array:
	return DIRECTIONS if GameState.tutorial_done else [TUTORIAL_DIRECTION]

# ── Layout ────────────────────────────────────────────────────────────────
const BASE_R    := 36.0
const NODE_R    := 28.0
const LINE_W    := 2.5

# ── Кольори ───────────────────────────────────────────────────────────────
const C_BASE      := Color(0.30, 0.22, 0.08)
const C_NODE      := Color(0.15, 0.20, 0.30)
const C_NODE_HOV  := Color(0.22, 0.35, 0.50)
const C_NODE_SEL  := Color(0.55, 0.42, 0.10)
const C_NODE_FOG  := Color(0.10, 0.12, 0.18)
const C_LINE      := Color(0.40, 0.35, 0.25)
const C_LINE_SEL  := Color(0.85, 0.65, 0.20)
const C_BORDER    := Color(0.50, 0.42, 0.30)
const C_BORDER_S  := Color(0.90, 0.70, 0.20)
const C_CONFIRM   := Color(0.20, 0.40, 0.15)
const C_BACK      := Color(0.20, 0.15, 0.10)
const C_RES       := {"wood": Color(0.6,0.4,0.1), "stone": Color(0.55,0.55,0.55),
					   "metal": Color(0.4,0.6,0.8), "food": Color(0.3,0.7,0.3)}

# ── Стан ─────────────────────────────────────────────────────────────────
var _hovered  := -1
var _selected := -1

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.06))

# ── Позиції ───────────────────────────────────────────────────────────────
func _center() -> Vector2:
	return get_viewport_rect().size * 0.5

func _node_pos(i: int) -> Vector2:
	return _center() + (_dirs()[i]["offset"] as Vector2)

func _confirm_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 90, vp.y - 70, 180, 36)

func _back_rect() -> Rect2:
	return Rect2(12, get_viewport_rect().size.y - 48, 110, 32)

# ── Input ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		var prev := _hovered
		_hovered = -1
		for i in _dirs().size():
			if pos.distance_to(_node_pos(i)) <= NODE_R + 12:
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
		for i in _dirs().size():
			if pos.distance_to(_node_pos(i)) <= NODE_R + 12:
				_selected = i if _selected != i else -1
				queue_redraw()
				return
		_selected = -1
		queue_redraw()

func _launch_raid() -> void:
	GameState.current_direction = _selected
	GameState.start_regional_map()
	get_tree().change_scene_to_file("res://scenes/world_map/RegionalMapScene.tscn")

# ── Рендер ───────────────────────────────────────────────────────────────
func _draw() -> void:
	var center := _center()
	var font   := ThemeDB.fallback_font

	var dirs := _dirs()
	for i in dirs.size():
		var np     := _node_pos(i)
		var is_sel := i == _selected
		draw_line(center, np, C_LINE_SEL if is_sel else C_LINE, LINE_W + (1.5 if is_sel else 0.0))

	# База
	draw_circle(center, BASE_R, C_BASE)
	draw_arc(center, BASE_R, 0, TAU, 48, C_BORDER_S, 2.5)
	draw_string(font, center + Vector2(-18, 6), "БАЗА",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	# Вузли напрямків
	for i in dirs.size():
		var np            := _node_pos(i)
		var d: Dictionary  = dirs[i]
		var is_sel        := i == _selected
		var is_hov        := i == _hovered
		var explored      := GameState.explored_directions.has(i)

		var node_col: Color
		if is_sel:      node_col = C_NODE_SEL
		elif is_hov:    node_col = C_NODE_HOV
		elif explored:  node_col = C_NODE
		else:           node_col = C_NODE_FOG

		draw_circle(np, NODE_R, node_col)
		draw_arc(np, NODE_R, 0, TAU, 48, C_BORDER_S if is_sel else C_BORDER, 2.0)

		if explored or is_hov or is_sel:
			_draw_rewards(np + Vector2(-50, NODE_R + 14), d["rewards"] as Dictionary, font, is_sel)
		else:
			draw_string(font, np + Vector2(-12, NODE_R + 24), "?  ?  ?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.35, 0.40))

	# Кнопка підтвердження
	if _selected != -1:
		var cr := _confirm_rect()
		draw_rect(cr, C_CONFIRM)
		draw_rect(cr, C_BORDER_S, false, 1.5)
		draw_string(font, cr.position + Vector2(22, 24), "Вирушити!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

	# Кнопка назад
	var br := _back_rect()
	draw_rect(br, C_BACK)
	draw_rect(br, C_BORDER, false, 1.0)
	draw_string(font, br.position + Vector2(10, 21), "< До бази",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	if _selected == -1:
		var vp := get_viewport_rect().size
		draw_string(font, Vector2(vp.x * 0.5 - 120, vp.y - 20),
				"Обери напрямок вилазки",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.55, 0.55))

func _draw_rewards(pos: Vector2, rewards: Dictionary, font: Font, bright: bool) -> void:
	var keys:   Array[String] = ["wood", "stone", "metal", "food"]
	var labels: Array[String] = ["Д", "К", "М", "Ї"]
	var x := 0.0
	for i in keys.size():
		var val: int = rewards[keys[i]]
		if val == 0:
			continue
		var col: Color = C_RES[keys[i]]
		if not bright:
			col = col * 0.75
		draw_rect(Rect2(pos.x + x, pos.y, 10, 10), col)
		draw_string(font, Vector2(pos.x + x + 13, pos.y + 10),
				"%s+%d" % [labels[i], val],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
		x += 52.0
