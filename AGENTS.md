# Розколоті Гекси — Agent Coding Guide

Dark fantasy tactical RPG. Godot 4.6.3, Compatibility renderer, isometric 2D. Solo developer.

---

## Project state (current)

The game is fully playable end-to-end. Every system below exists and works — do not rewrite or restructure unless explicitly asked.

**Navigation flow:**
```
CharacterCreationScene → BaseScene → WorldMapScene → RegionalMapScene → CombatScene → back
```

**Autoloads (always available globally):** `GameState`, `HexGrid`

---

## Critical GDScript 4 rules for THIS project

### 1. Strict typing everywhere
```gdscript
# CORRECT
var bid: int = node["building_id"]
var name: String = data.get("name", "") as String

# WRONG — never leave Variant
var bid = node["building_id"]
```

### 2. Dictionary access — always use .get() + explicit cast
```gdscript
# CORRECT
var hp: int  = int(hero.get("hp", 50))
var name: String = str(hero.get("name", "Герой"))

# WRONG — crashes if key missing
var hp = hero["hp"]
```

### 3. Typed arrays — never assign untyped [] to Array[T]
```gdscript
# CORRECT — clear instead of reassign
if condition:
    my_typed_array = compute_values()
else:
    my_typed_array.clear()

# WRONG — type error at runtime
my_typed_array = [] if not condition else compute_values()
```

### 4. Never name a method get_name()
Godot's `Object` base class has `get_name()` with 0 args. Any static method or instance method named `get_name(id)` will silently conflict and crash. Use `get_ability_name()`, `get_label()`, etc.

### 5. Never shadow built-in Node2D properties
```gdscript
# WRONG — shadows Node2D.scale, causes silent bugs
var scale: float = 2.0

# CORRECT
var enemy_scale: float = 2.0
```

Known shadowed names to avoid: `scale`, `position`, `rotation`, `visible`, `name`, `owner`.

---

## Rendering — how this project draws everything

**There are NO Control/UI nodes anywhere.** Every pixel is drawn in `_draw()` via `draw_*` calls. This is intentional and must be preserved.

```gdscript
# Pattern used everywhere
func _draw() -> void:
    var font := ThemeDB.fallback_font
    var vp   := get_viewport_rect().size
    draw_rect(Rect2(0, 0, vp.x, TOP_H), Color(0, 0, 0, 0.72))
    draw_string(font, Vector2(x, y), "text", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

# To trigger a redraw after state change:
queue_redraw()
```

**`draw_string` alignment:** `HORIZONTAL_ALIGNMENT_CENTER` anchors at the LEFT edge of the bounding box, not the center. To center text at position `cx`:
```gdscript
draw_string(font, Vector2(cx - half_width, y), text, HORIZONTAL_ALIGNMENT_CENTER, full_width, size, col)
```

**Hit detection** uses `Rect2.has_point(mouse_pos)` — all clickable areas are computed from viewport size each frame, not cached.

---

## GameState — the only source of truth

`GameState` is an autoload (`Node`) that persists all game data across scenes.

### Key data structures
```gdscript
GameState.resources: Dictionary[String, int]   # "wood", "stone", "metal", "food"
GameState.hero: Dictionary                     # name, hp, dmg, xp, level, gender, spec_name ...
GameState.inventory: Array                     # Array of item Dictionaries
GameState.equipped: Dictionary                 # char_key → slot → inventory_index
GameState.loot_bag: Dictionary                 # str(item_id) → quantity
GameState.base_slots: Array[int]               # slot_index → building_id (-1 = empty)
GameState.raid_party: Array[int]               # companion uids in current party
GameState.companion_progress: Dictionary       # "c{uid}" → {level, xp, hp, dmg, skill_points}
GameState.loot_bag: Dictionary                 # str(expedition_loot_id) → quantity
```

### char_key system — critical
Every character has a unique string key used as dictionary key in `equipped` and `companion_progress`:
- Hero: `"hero"`
- Companion uid=3: `"c3"`
- Enemies: `""` (empty — no equipment)

### Item structure
```gdscript
# Equipment item fields (all optional except name and slot):
{
    "name": "Кований меч",
    "slot": "main_hand",       # see EQUIP_SLOTS constant
    "armor_type": 2,           # 0=cloth 1=leather 2=chain 3=plate
    "armor": 10,
    "dmg_bonus": 7,
    "hp_bonus": 0,
    "magic_bonus": 0,
    "agility_bonus": 0,
    "initiative_bonus": 0,
    "critical_bonus": 0,       # percent points
    "simple_barrier": 0,       # physical shield
    "magic_barrier": 0,
    "two_handed": false,        # occupies main_hand AND off_hand
    "is_quiver": false,
    "requires_quiver": false,
    "atk_range": 0,            # 0 = no override, >0 overrides unit range
}
```

### Expedition loot items (EXPEDITION_LOOT constant, ids 0-7)
Separate from equipment. Stored in `loot_bag` as `{"0": qty, "3": qty, ...}`.
Keys are always **strings** in loot_bag (JSON serialization), but **ints** in EXPEDITION_LOOT and BUILDING_ACTIONS loot_cost dicts. Always convert: `str(id_key)` when accessing loot_bag.

### save_game() / load_game()
`save_game()` is called automatically at key points (end of expedition, craft, equip, etc.). If you add a new persistent variable, you MUST add it to both `save_game()` data dict and `load_game()` parsing, AND initialize it in `_init_state()`.

---

## Adding content — correct patterns

### Add a new building action (craft recipe, etc.)
Edit `BUILDING_ACTIONS` in `GameState.gd`. The building id (bid) maps to `BaseScene.BUILDINGS` array index. Effects: `craft_item`, `award_party_xp`, `award_resources`, `award_loot_random`, `award_hunt`, `gossip`.

```gdscript
# In BUILDING_ACTIONS dict, bid 7 = Кузня:
{"label": "Нова зброя", "desc": "+15 Атк",
 "cost": {"metal": 20}, "loot_cost": {},
 "effect": "craft_item",
 "effect_data": {"name": "Нова зброя", "slot": "main_hand", "dmg_bonus": 15}}
```

### Add a new expedition loot item
Append to `EXPEDITION_LOOT` array in `GameState.gd`. The id is the array index. Rarity: 0=common, 1=rare, 2=very rare.

### Add a new ability (for a class)
Each class has its own file in `scripts/systems/classes/` (e.g. `WarriorAbilities.gd`). Abilities are registered in `AbilityDatabase.gd`. Each ability is a dict with `{id, name, desc, cd, mode, range, effects[]}`. Effects are processed by `AbilityEffects.gd` based on `AbilityEnums.EffectType`.

Do NOT add abilities directly to `AbilitySystem.gd` — it is a thin coordinator only.

### Add a new scene
1. Create `.gd` + `.tscn` (or all-code: instantiate the node in `_ready()`)
2. Transition with `get_tree().change_scene_to_file("res://scenes/...")`
3. Save state in GameState before transitioning if needed

---

## Architecture decisions — do not change these

| Decision | Reason |
|---|---|
| All rendering via `_draw()` | Consistent style, no node bloat, performance |
| No `@export` unless necessary | All-code scenes, no Inspector coupling |
| `inventory` is a global pool | Items are never duplicated per-character; `equipped` maps char+slot → index |
| `award_xp()` always awards to hero AND all party companions | Call once, not per character |
| `regional_combat_pending` flag | Allows returning to the exact node map after combat |
| `char_key` string IDs | JSON-safe, works across save/load without integer key issues |

---

## Common mistakes to avoid

1. **Don't call `queue_redraw()` inside `_draw()`** — infinite loop.
2. **Don't store node references across scene changes** — nodes are freed. Store data in GameState.
3. **Don't use `var x: Array[T] = []` then assign untyped** — use `.clear()` or typed literal.
4. **Don't forget `await get_tree().create_timer(N).timeout`** before scene transitions when showing a result message — the user needs time to read it.
5. **Don't add UI Nodes (Label, Button, etc.)** — everything is `_draw()`.
6. **`loot_cost` keys in BUILDING_ACTIONS are ints; keys in `loot_bag` are strings** — always `str(id_key)` when looking up.
7. **`SLOT_BUILDING[slot_i]`** maps slot index → building id. `base_slots[slot_i]` is the currently built building (-1 if empty). These are different.

---

## File map

```
scripts/systems/GameState.gd          — all persistent state, constants, save/load
scripts/systems/HexGrid.gd            — hex coordinate math (autoload)
scripts/systems/TurnManager.gd        — initiative queue, turn signals
scripts/systems/Unit.gd               — unit stats, movement, attack logic
scripts/systems/EnemyAI.gd            — enemy decision making
scripts/systems/AbilityEnums.gd       — shared enums (no dependencies)
scripts/systems/AbilityEffects.gd     — effect execution
scripts/systems/AbilityDatabase.gd    — merges all class ability files
scripts/systems/AbilitySystem.gd      — public API: get_ability_name, execute, get_targets
scripts/systems/classes/              — one file per class (ClericAbilities.gd, etc.)

scenes/base/BaseScene.gd              — base camp UI, building menus, equipment, inventory
scenes/character_creation/            — hero creation (classes, name, gender, color)
scenes/world_map/WorldMapScene.gd     — direction fog-of-war map
scenes/world_map/RegionalMapScene.gd  — procedural node map (START/COMBAT/LOOT/END)
scenes/combat/CombatScene.gd          — hex grid combat, deploy phase, AI turns
```
