class_name ClericAbilities
## Навички класу Клірик (class_idx = 0).

static func get_data() -> Dictionary:
	return {
		1: {
			"name":  "Лікування",
			"desc":  "+12 HP союзнику поруч",
			"cd":    2,
			"mode":  AbilityEnums.TargetMode.ALLY_NEAR,
			"range": 1,
			"effects": [
				{"type": AbilityEnums.EffectType.HEAL, "power": 12},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [1]
