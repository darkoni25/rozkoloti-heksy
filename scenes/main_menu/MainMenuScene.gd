extends Node2D

const C_BG    := Color(0.05, 0.04, 0.03)
const C_TITLE := Color(0.95, 0.80, 0.20)
const C_BTN   := Color(0.14, 0.11, 0.08, 0.95)
const C_BTN_H := Color(0.28, 0.20, 0.08, 0.95)
const C_BORD  := Color(0.45, 0.38, 0.28, 1.0)
const C_BORD_S:= Color(0.85, 0.65, 0.15, 1.0)

var _hov: int = -1   # -1 нічого  0 продовжити  1 нова гра  2 вийти

func _ready() -> void:
	RenderingServer.set_default_clear_color(C_BG)

# ── Кнопки ────────────────────────────────────────────────────────────────
func _btn_rect(i: int) -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(vp.x * 0.5 - 130, vp.y * 0.5 - 20 + i * 58.0, 260, 44)

func _has_save() -> bool:
	return FileAccess.file_exists("user://save.json")

# ── Input ─────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pos  := (event as InputEventMouseMotion).position
		var prev := _hov
		_hov = -1
		var count := 3 if _has_save() else 2
		for i in count:
			if _btn_rect(i).has_point(pos): _hov = i; break
		if _hov != prev: queue_redraw()

	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var pos   := (event as InputEventMouseButton).position
		var has_s := _has_save()
		if has_s and _btn_rect(0).has_point(pos):
			get_tree().change_scene_to_file("res://scenes/base/BaseScene.tscn")
		elif _btn_rect(1 if has_s else 0).has_point(pos):
			_new_game()
		elif _btn_rect(2 if has_s else 1).has_point(pos):
			get_tree().quit()

# ── Логіка ────────────────────────────────────────────────────────────────
func _new_game() -> void:
	# Видаляємо старе збереження і йдемо на створення персонажа
	if FileAccess.file_exists("user://save.json"):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path("user://save.json"))
	GameState._init_state()
	get_tree().change_scene_to_file(
		"res://scenes/character_creation/CharacterCreationScene.tscn")

# ── Рендер ────────────────────────────────────────────────────────────────
func _draw() -> void:
	var vp   := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var has_s := _has_save()

	# Назва гри
	draw_string(font, Vector2(vp.x * 0.5 - 180, vp.y * 0.5 - 100),
			"РОЗКОЛОТІ ГЕКСИ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 36, C_TITLE)
	draw_string(font, Vector2(vp.x * 0.5 - 100, vp.y * 0.5 - 62),
			"dark fantasy tactical RPG",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.40, 0.32))

	# Кнопки
	var labels: Array[String] = []
	if has_s:
		labels = ["Продовжити", "Нова гра", "Вийти"]
	else:
		labels = ["Нова гра", "Вийти"]

	for i in labels.size():
		var r     := _btn_rect(i)
		var is_h  := i == _hov
		draw_rect(r, C_BTN_H if is_h else C_BTN)
		draw_rect(r, C_BORD_S if is_h else C_BORD, false, 1.5)
		draw_string(font, r.position + Vector2(20, 29), labels[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				Color.WHITE if is_h else Color(0.80, 0.75, 0.65))

	# Версія
	draw_string(font, Vector2(8, vp.y - 8), "v0.1-dev",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.25, 0.25, 0.25))
