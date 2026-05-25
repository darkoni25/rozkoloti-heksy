class_name PaladinAbilities
## Навички класу Паладін (class_idx = 1).

static func get_data() -> Dictionary:
	return {
		2: {
			"name":  "Відновлення",
			"desc":  "+15 HP собі",
			"cd":    3,
			"mode":  AbilityEnums.TargetMode.SELF,
			"range": 0,
			"effects": [
				{"type": AbilityEnums.EffectType.SELF_HEAL, "power": 15},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [2]
