class_name OccultistAbilities
## Навички класу Окультист (class_idx = 6).

static func get_data() -> Dictionary:
	return {
		7: {
			"name":  "Вампіризм",
			"desc":  "8 урону ворогу + відновлює 4 HP собі",
			"cd":    3,
			"mode":  AbilityEnums.TargetMode.ENEMY_NEAR,
			"range": 2,
			"effects": [
				# Спочатку урон, потім лікування — обидва ефекти незалежні
				{"type": AbilityEnums.EffectType.DAMAGE,    "power": 8, "armor": true},
				{"type": AbilityEnums.EffectType.SELF_HEAL, "power": 4},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [7]
