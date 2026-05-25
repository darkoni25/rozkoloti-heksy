class_name Unit
extends RefCounted

enum Team { PLAYER = 0, ENEMY = 1 }

var id:           int
var hex:          Vector2i
var team:         int
var label:        String
var move_range:   int
var attack_range: int
var color:        Color
var max_hp:       int
var hp:           int
var damage:       int
var acted:           bool   = false
var initiative:      int    = 10   # визначає порядок ходів (вищий — раніше)
var char_key:        String = ""   # "hero", "c{uid}" для компаньйона, "" для ворогів
var simple_barrier:  int    = 0    # фіз. бар'єр від щита (скидається після бою)
var magic_barrier:   int    = 0    # маг. бар'єр від магічних предметів (скидається після бою)
var max_simple_barrier: int = 0    # початкове значення (для відновлення після бою)

var ability_id:      int    = 0    # 0 = немає; 1-8 = конкретна здібність (CombatScene ABILITY_*)
var ability_cd_max:  int    = 0    # кількість ходів відновлення; 0 = без здібності
var ability_cd:      int    = 0    # поточний КД (0 = готова до використання)

func _init(p_id: int, p_hex: Vector2i, p_team: int, p_label: String,
		p_range: int, p_color: Color, p_hp: int, p_dmg: int, p_atk_range: int = 1) -> void:
	id = p_id; hex = p_hex; team = p_team; label = p_label
	move_range = p_range; attack_range = p_atk_range
	color = p_color; max_hp = p_hp; hp = p_hp; damage = p_dmg

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
