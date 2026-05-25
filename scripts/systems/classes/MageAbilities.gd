class_name MageAbilities
## Навички класу Маг (class_idx = 4).

static func get_data() -> Dictionary:
	return {
		5: {
			"name":  "Вогн. куля",
			"desc":  "8 урону всім у радіусі 1 від цілі (дружній вогонь!)",
			"cd":    3,
			"mode":  AbilityEnums.TargetMode.ANY_HEX,
			"range": 3,
			"effects": [
				# friendly_fire=true → б'є також союзників; armor=false → без редукції
				{
					"type":          AbilityEnums.EffectType.AOE_DAMAGE,
					"power":         8,
					"radius":        1,
					"friendly_fire": true,
					"armor":         false,
				},
			],
		},
	}

static func get_ids() -> Array[int]:
	return [5]
