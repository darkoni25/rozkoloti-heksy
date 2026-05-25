# Handoff: Головне меню — Розколоті Гекси

## Overview
Початковий екран гри **Розколоті Гекси** (Godot 4.6.3, 2D Compatibility renderer). Це перше, що бачить гравець після запуску. Звідси він починає нову гру, продовжує збережену або виходить з гри.

## About the Design Files
Файл `main-menu.html` у цій папці — **дизайн-референс**, прототип на HTML/CSS/SVG, який показує бажаний вигляд, композицію, типографіку, кольори та поведінку. Це **не код для копіювання у проєкт**.

Завдання — **відтворити цей дизайн у наявному Godot-кодбейсі** (`darkoni25/rozkoloti-heksy`), використовуючи власні патерни проєкту:
- Сцени `.tscn` + GDScript
- Compatibility renderer
- Рендер через `_draw()` + `queue_redraw()` як в інших сценах
- Без зайвих Control-вузлів там, де можна намалювати руками

Звертатися до HTML як до **picture-perfect етáлона**: кольори, відступи, шрифти, інтервали — як тут.

## Fidelity
**High-fidelity.** Точні кольори (hex), точні розміри, точна типографіка. Розробник має відтворити інтерфейс піксель-у-піксель з використанням готових бібліотек/підходів проєкту.

## Target Resolution
- **Дизайн-розмір:** 1920 × 1080 (16:9)
- **Стратегія:** все відмалювати в логічних координатах 1920×1080 і масштабувати до viewport з letterbox-чорними полями (як `transform: scale()` в HTML).
- У Godot це робиться через `Project Settings → Display → Window → Stretch: viewport / keep`.

---

## Screens / Views

### 1. Main Menu (єдиний екран у цьому хендофі)

**Назва:** `MainMenuScene`
**Призначення:** старт гри. Тут гравець:
1. починає нову партію (іде в `CharacterCreationScene`),
2. завантажує останнє збереження (`save.json` → `BaseScene`),
3. виходить з гри.

#### Layout

Композиція центрована, 5 вертикальних "поясів" зверху вниз:

```
┌─────────────────────────────────────────────────────────┐
│   [печатка кутова]                       [печатка SVII] │  ← y = 0..120
│                                                          │
│            Цитата з Хроніки Затемнення (3 рядки)         │  ← y = 88..220
│            ──── З Хроніки Затемнення · рік 472 ────      │
│                                                          │
│                     [емблема 132px]                      │  ← y = 320..452
│              РОЗКОЛОТІ ГЕКСИ (96px)                      │  ← y = 470..570
│                   Світ Семи Народів                      │  ← y = 590..620
│                                                          │
│              ────────  ✦  ────────                       │  ← y = 660
│                                                          │
│                    Нова гра                              │  ← y = 720..768
│                    Продовжити                            │  ← y = 782..830
│                    Вийти                                 │  ← y = 844..892
│                                                          │
│  [Зб: Хід XVII · ...]                  v 0.4.2 · Студія  │  ← y = 1010..1050
└─────────────────────────────────────────────────────────┘
```

Усі елементи — flex-стовпець з вирівнюванням по центру по `X`. Композиція має `padding-top: 88px`, `padding-bottom: 72px`. Між блоками — поступове наростання дистанції; точні значення — у HTML (`.composition` має `display: grid; grid-template-rows: 1fr auto auto auto 1fr`, тобто прелюдія прибита до верху, низ — повітря).

#### Background layers (порядок знизу вгору)

1. **Базовий радіальний градієнт** — теплий "вогнищевий" пул світла по центру:
   ```
   radial-gradient(ellipse 80% 70% at 50% 52%,
     #2a1d10 0%,
     #1a130a 45%,
     #0d0905 75%,
     #050302 100%)
   ```

2. **Painted scenery (SVG)** — три шари силуетних хребтів і сосон знизу екрану. Параметри й shape-и див. у HTML (`<svg class="scene-svg">`). У Godot — намалювати у `_draw()` як ряд полігонів з лінійними градієнтами:
   - **Far ridge** (`#1a140d → #0c0805`, opacity 0.85, м'який blur)
   - **Mid ridge** (`#100b07 → #070503`, opacity 0.92)
   - **Near ridge** (`#0a0704 → #040301`)
   - **Дві групи трикутних сосон** — ~80 на ближньому хребті, ~30 на середньому. Висоти й позиції — детермінований шум (див. JS-блок у HTML, дублюйте логіку sin/cos).
   - **Два маленьких замки-силуети** ліворуч і праворуч (точні координати — в SVG `<g transform="translate(...)">`).

3. **Parchment grain overlay** — SVG `feTurbulence` зерно у режимі `mix-blend-mode: overlay` з `opacity: 0.5`. У Godot — згенерувати noise-текстуру (`FastNoiseLite`), застосувати з відповідним blend-mode шейдером.

4. **Vignette** — `radial-gradient(ellipse 75% 70% at 50% 50%, transparent 45%, #06040380 75%, #050302 100%)`.

5. **Embers** — 28 крапок (3px), які підіймаються від низу екрану по 7-15с з легким горизонтальним коливанням. Колір: `#f0cf78` core → `#d4a44a` mid → transparent edge, з box-shadow glow `0 0 8px #d4a44a, 0 0 18px rgba(212,164,74,0.5)`. У Godot — `GPUParticles2D` з власною текстурою-крапкою.

6. **Corner frame** — латунний орнамент по 4 кутах (тонка подвійна лінія + завитки + кулькові акценти). Лінії: stroke `#8a6a2e`, weight 1.2px, opacity 0.85. Точні SVG-path-и — в HTML (`<svg class="frame-border">`).

#### Components

##### Chronicle prelude (зверху, центрований)
- Контейнер: `max-width: 560px`, центр.
- Шрифт: **IM Fell English**, `italic`, `17px`, line-height `1.55`, letter-spacing `0.02em`, колір `#8a7858`, opacity 0.92.
- Текст:
  > Світ був колись єдиний. Та сім народів пролили кров одне одного, щоб посісти землю — і виснажили самих себе. Лишилися тільки руїни й безчесні присяги.
- Декоративні `·` (latunна крапка `#8a6a2e`) по краях через `::before` / `::after`.
- Атрибуція (під цитатою): `З ХРОНІКИ ЗАТЕМНЕННЯ · РІК 472`, шрифт **IM Fell English**, `normal`, `13px`, letter-spacing `0.22em`, uppercase, колір `#5a4d36`.

##### Emblem (геральдичний знак)
- Розмір: `132 × 132 px`.
- SVG `viewBox="-66 -66 132 132"`.
- Кільце: коло `r=56`, stroke `#8a6a2e` 1px, opacity 0.7. Внутрішнє коло `r=51`, stroke `#4a3818` 0.6px.
- Семипроменева зірка (точки в HTML), залита **радіальним градієнтом** `#f0cf78 → #a8802a → #4a3818`.
- Внутрішній пентагон, stroke `#d4a44a` 0.8px.
- Ядро: `r=6` чорне, обведене `#d4a44a`; центральна крапка `r=2` `#f0cf78`.
- 7 латунних пипок по колу (точні координати в HTML).
- **Анімація мерехтіння:** `drop-shadow` між `0 0 18px rgba(212,164,74,0.22)` і `0 0 30px rgba(212,164,74,0.38)`, період 4.2с, ease-in-out.

##### Title — "Розколоті Гекси"
- Шрифт: **Cinzel Decorative 900**.
- Розмір: `96px`, line-height `1`, letter-spacing `0.12em`.
- Колір основних літер: `#e8d9b3`.
- Літера **"т"** виділена кольором `#d4a44a` з посиленим glow:
  ```
  text-shadow:
    0 1px 0 #000, 0 2px 0 #1a130b,
    0 0 18px rgba(240,207,120,0.5),
    0 0 40px rgba(212,164,74,0.35);
  ```
- Тінь решти тексту:
  ```
  text-shadow:
    0 1px 0 #000,
    0 2px 0 #1a130b,
    0 0 28px rgba(212,164,74,0.25),
    0 0 60px rgba(212,164,74,0.15);
  ```
- **Slow drift анімація** на блок (`titleblock`): `translateY(0) ↔ translateY(-4px)`, період 8с.

##### Subtitle — "Світ Семи Народів"
- Шрифт: **IM Fell English**, `italic`, `22px`, letter-spacing `0.34em`, uppercase, колір `#c8b487`.

##### Ornament divider
- SVG, ширина 520px, висота 22px.
- Дві лінії `#8a6a2e` (opacity 0.7) з обох боків, у центрі — ромб 20px залитий `#8a6a2e` з білою сяючою крапкою `#f0cf78` всередині, обрамлений 4 криволінійними завитками.

##### Menu items
3 кнопки, тип `button`. Спільні стилі:
- Min-width `460px`, padding `18px 56px`.
- Background: transparent.
- Border: none.
- Шрифт: **Cinzel 600**, `26px`, letter-spacing `0.36em`, uppercase.
- Колір спокою: `#c8b487`, text-shadow `0 1px 0 #000`.
- Курсор: `pointer`.
- Transitions: `color 180ms ease, letter-spacing 220ms ease`.

**Hover state:**
- Колір → `#e8d9b3` (`Вийти` → `#f6d2bc`).
- letter-spacing → `0.42em`.
- З'являються стрілки ліворуч (`←`) і праворуч (`→`), `width 56px`, `height 14px`, stroke `#d4a44a` 1.4px. Ліва "виїжджає" на `-6px`, права на `+6px`.
- З'являються 2 латунні лінії — згори (top:4) і знизу (bottom:4), ширина 280px, лінійний градієнт:
  ```
  linear-gradient(90deg, transparent, #8a6a2e 30%, #d4a44a 50%, #8a6a2e 70%, transparent)
  ```
  opacity 0.9, з fade-in 200ms.

**Active (натиснення):** `translateY(1px)` 80ms.

**Disabled state** (наразі НЕ використовується, але передбачено):
- Колір → `#5a4d36`, cursor `not-allowed`, стрілки opacity 0.3.
- Використовуйте, коли немає save-файлу — кнопка **Продовжити** має бути disabled, якщо `GameState.save_exists() == false`.

**Тексти кнопок:**
1. `Нова гра` → перехід в `CharacterCreationScene`
2. `Продовжити` → завантаження `save.json` → `BaseScene`
3. `Вийти` → `get_tree().quit()`

##### Corner meta — top-left
- Шрифт: **IM Fell English**, `italic`, `14px`, letter-spacing `0.16em`, колір `#5a4d36`.
- Усередині `<b>`: `normal`, `#c8b487`, letter-spacing `0.22em`.
- Текст: `З ХРОНІКИ ЗАТЕМНЕННЯ`.
- Позиція: `left: 56px; top: 44px`, max-width 280px.

##### Corner meta — top-right
- Латунна печатка `SIGILLUM VII GENTIUM`.
- SVG `88 × 88px`, два кола (40 і 34), солярна розетка, два рядки тексту по краях (Cinzel-подібне, але тут IM Fell English italic 8px).
- Позиція: `right: 64px; top: 52px`.
- Opacity 0.7.

##### Corner meta — bottom-left
- Текст: `Останнє збереження:` (italic, dim) + новий рядок: `Хід XVII · Місяць Чорнолистя` (`#c8b487`, normal, letter-spacing 0.08em).
- Якщо збереження немає — приховати весь блок.
- Позиція: `left: 56px; bottom: 44px`.

##### Corner meta — bottom-right
- `v 0.4.2 · ТВЕРДА ЗЕМЛЯ` (b: `#c8b487`, normal, letter-spacing 0.22em)
- `© Darkoni25 Studios` (italic, `#5a4d36`).
- Шрифт: **IM Fell English**, `italic`, `14px`, letter-spacing `0.16em`.
- Позиція: `right: 56px; bottom: 44px`, text-align right.

---

## Interactions & Behavior

### Entry animation
При завантаженні сцени елементи композиції з'являються послідовно (fade + slide up):
- Хроніка: затримка 0.15с
- Title block: 0.35с
- Ornament: 0.65с
- Menu: 0.85с
- Тривалість кожного: 1.4с, easing `cubic-bezier(.2, .7, .2, 1)`.

### Continuous animations
- **Emblem flicker** — 4.2с cycle на drop-shadow.
- **Title block drift** — 8с cycle на `translateY`.
- **Embers** — нескінченно, кожна іскра має власну тривалість 7-15с, негативний delay для випадкового зсуву.

### Menu actions
| Кнопка | Дія |
|---|---|
| Нова гра | `get_tree().change_scene_to_file("res://scenes/character_creation/CharacterCreationScene.tscn")` |
| Продовжити | Якщо `GameState.has_save()` — `GameState.load_save()` потім `change_scene_to_file(...BaseScene.tscn)`. Інакше — кнопка disabled. |
| Вийти | `get_tree().quit()` |

### Keyboard navigation
- `↑` / `↓` — рух між пунктами (hover state на активному).
- `Enter` / `Space` — активувати.
- `Esc` — нічого (це топ-меню).

---

## State Management

```gdscript
# MainMenuScene.gd
extends Node2D

@onready var continue_button: Control = $UI/MenuList/Continue

func _ready() -> void:
    continue_button.disabled = not GameState.has_save()
    if continue_button.disabled:
        continue_button.modulate.a = 0.4
```

`GameState.has_save()` — нова функція, що перевіряє існування `user://save.json`.

---

## Design Tokens

### Colors
```
--ink-night       #0a0805
--ink-stone       #15110c
--ink-parchment   #1c1611
--ink-vellum      #261d14

--brass-shadow    #4a3818
--brass-mid       #8a6a2e
--brass-bright    #d4a44a
--brass-flare     #f0cf78

--iron-mid        #3a342c

--text-bone       #e8d9b3
--text-parch      #c8b487
--text-dim        #8a7858
--text-faded      #5a4d36

--blood-glow      #c44a3a   (резерв для критичних дій)
```

### Typography
| Роль | Сім'я | Вага | Розмір | Letter-spacing |
|---|---|---|---|---|
| Game title | Cinzel Decorative | 900 | 96px | 0.12em |
| Subtitle | IM Fell English | italic | 22px | 0.34em |
| Menu items | Cinzel | 600 | 26px | 0.36em |
| Chronicle quote | IM Fell English | italic | 17px | 0.02em |
| Chronicle attribution | IM Fell English | normal | 13px | 0.22em |
| Corner meta | IM Fell English | italic | 14px | 0.16em |

**Завантажити шрифти в Godot:**
- Cinzel Decorative 900 — https://fonts.google.com/specimen/Cinzel+Decorative
- Cinzel 600 — https://fonts.google.com/specimen/Cinzel
- IM Fell English (regular + italic) — https://fonts.google.com/specimen/IM+Fell+English

Покласти `.ttf` у `res://assets/fonts/`, створити `FontFile`-ресурси для кожного.

### Spacing
| Назва | Значення |
|---|---|
| Frame padding (corners) | 36px |
| Composition top padding | 88px |
| Composition bottom padding | 72px |
| Menu min-width | 460px |
| Menu item padding | 18px × 56px |
| Menu items gap | 14px |

### Shadows / Glows
Усі рідкісні значення в `text-shadow` секціях вище. Узагальнено: brass-glow зазвичай `rgba(212, 164, 74, 0.15..0.5)` залежно від інтенсивності.

---

## Assets
**Власних растрових ассетів немає.** Усі візуали — векторні / згенеровані (CSS gradient + SVG path + parchment noise). В Godot:
- Шрифти (3) — завантажити з Google Fonts.
- Іскри — згенерувати спрайт `8×8` PNG з radial gradient або намалювати в шейдері.
- Зерно паперу — `NoiseTexture2D` з `FastNoiseLite`.

---

## Files in this handoff
- `main-menu.html` — повний дизайн-референс. Відкрити в браузері 16:9, щоб побачити. Усі точні значення — тут.
- `README.md` — цей файл.

---

## Suggested file structure in your repo
```
scenes/
  main_menu/
    MainMenuScene.tscn
    MainMenuScene.gd
assets/
  fonts/
    CinzelDecorative-Black.ttf
    Cinzel-SemiBold.ttf
    IMFellEnglish-Regular.ttf
    IMFellEnglish-Italic.ttf
  textures/
    ember.png         # маленький спрайт іскри
```

Прокачайте `project.godot` → `Application/Run/Main Scene` на новий `MainMenuScene.tscn` після інтеграції.

---

## Open questions for the implementer
1. Чи додавати кнопку **Налаштування** (звук/мова/роздільна здатність)? Зараз у дизайні навмисно лише 3 пункти.
2. Локалізація: усі тексти зараз українською. Якщо потрібна англійська/російська — підготувати `tr()` ключі.
3. Музика головного меню — окремий хендофф (не входить у цей пакет).
