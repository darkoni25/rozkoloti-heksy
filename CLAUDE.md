# Розколоті Гекси — Godot Project

Dark fantasy tactical RPG. Solo developer. Godot 4.6.3, Compatibility renderer, isometric 2D.

## Current task
Вільний — базова гра повністю грається від початку до кінця.

## Done
- ✅ Ізометрична гексова сітка (HexGrid.gd — axial coords, pointy-top)
- ✅ Юніти, рух, анімація переміщення (Tween)
- ✅ Turn manager + черга ініціативи (TurnManager.gd)
- ✅ Бій: HP, атака ближня + дальня, смерть (Unit.gd, CombatScene.gd)
- ✅ Enemy AI: рух до гравця, атака ближня та дальня (EnemyAI.gd)
- ✅ Фаза розстановки (PHASE_DEPLOY / PHASE_COMBAT) — гравець сам ставить юнітів
- ✅ Нагороди за бій (COMBAT_LOOT → GameState.resources)
- ✅ Base scene: 9 слотів, 8 споруд, ресурси, меню будівництва (BaseScene.gd)
- ✅ Компаньйони: вибір загону (клік ✔/✘) до 3 юнітів (BaseScene + GameState)
- ✅ Головний герой: золотий юніт, смерть → recovery_raids (пропускає 1 рейд)
- ✅ Створення персонажа: 8 класів (Клірик→Бард + Паладін), ім'я, стать, колір
- ✅ GameState autoload: всі дані між сценами, збереження/завантаження (save.json)
- ✅ WorldMapScene: напрямки з туманом, reward preview, вибір вилазки
- ✅ RegionalMapScene: процедурна вузлова карта (шари, COMBAT/LOOT/END)
- ✅ Навчальний бій (tutorial): 1 гоблін, нагорода = рівно ресурси на каплицю
- ✅ Економіка: населення, робітники, їжа, цикл = 1 вилазка (process_cycle)
- ✅ Система спорядження — архітектура (GameState + UI):
  - `inventory: Array` (глобальний пул предметів)
  - `equipped: Dictionary` (char_key → slot → inventory_index)
  - 6 слотів: helmet, chest, legs, boots, main_hand, off_hand
  - 4 типи броні: тканина/шкіра/кольчуга/пластина; CLASS_ARMOR_MAX на клас
  - Формула броні: `dmg * (1 - armor/(armor+100))` в _do_attack()
  - Зброя перевизначає atk_range; двуручна займає main+off
  - Попап ⚔ у BaseScene: вкладки персонажів, 6 слотів, знімання предмета кліком
  - Unit.char_key: "hero" / "c{uid}" / "" (вороги) — прив'язка до equipment

## Key decisions made
- Isometric 2D (not 3D, not top-down)
- Compatibility renderer (GL Compat)
- Рендер через `_draw()` + `queue_redraw()` — жодних Control/UI нод
- Герой — людина без класу → тепер вибирається клас на старті гри
- Герой гине → не кінець гри; recovery_raids = 1 (пропускає наступний рейд)
- 8 класів героя відповідають компаньйонам (Каплиця→Клірик+Паладін … Таверна→Бард)
- Equipment architecture: inventory = глобальний пул; equipped = прив'язка до char_key
- Armor formula: diminishing returns armor/(armor+100) щоб не було hard cap
- char_key system: "hero", "c{uid}", "" (enemies) — єдиний ID для equipment lookup

## Navigation flow
```
CharacterCreationScene  (перший запуск / GameState.hero_created == false)
    ↓
BaseScene               (будування, загін, ресурси)
    ↓
WorldMapScene           (вибір напрямку, туман)
    ↓
RegionalMapScene        (вузлова карта: START → COMBAT/LOOT → END)
    ↓
CombatScene             (розстановка → бій → нагорода)
    ↓ (перемога)
RegionalMapScene        (продовження)
    ↓ (кінець шляху або поразка)
BaseScene
```

## Project structure (actual)
```
scenes/
  character_creation/   CharacterCreationScene.gd / .tscn
  combat/               CombatScene.gd / .tscn
  world_map/            WorldMapScene.gd / .tscn
                        RegionalMapScene.gd / .tscn
  base/                 BaseScene.gd / .tscn
scripts/
  systems/              GameState.gd (autoload)
                        HexGrid.gd   (autoload)
                        TurnManager.gd
                        Unit.gd
                        EnemyAI.gd
```

## GDD summary
- 3-layer navigation: Base → World Map → Regional Node Map → Combat
- 7 класів / компаньйонів, permadeath (майбутнє), multiclass (майбутнє)
- Ресурси: wood, stone, metal, food
- Старт: людські землі (SW), 3 напрямки (море = тупик, ельфи = бар'єр, гноми = єдиний шлях)

## Coding rules
- GDScript 4 strict: завжди `var x: Type`, жодних Variant без потреби
- Dictionary доступ через `.get(key, default)` + явний каст `int(...)` / `str(...)`
- `Array[Type]` скрізь де можливо
- Autoloads: GameState, HexGrid
- Не використовувати `@export` без необхідності (all-code scenes)
