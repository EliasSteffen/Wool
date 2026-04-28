# GitHub Copilot Instructions for Godot 4.5+

## 1. Project Context & Principles
- **Engine:** Godot 4.5.1
- **Language:** GDScript (Static Typed)
- **Architecture:** Hybrid (Inheritance for Taxonomy, Composition for Functionality).
- **Documentation:** DO NOT generate Markdown documentation or comments explaining the obvious. Code must be self-documenting.
- **Errors:** Check with `godot --headless --check-only <SCRIPT_FILE_NAME>` for syntax errors!
    - NEVER EVER USE `godot --headless --check-only project.godot` as it only opens the GODOT Program and NOT the GAME!! (NEVER do this!!!)
## 2. GDScript Style Guide

### Type Safety (CRITICAL)
- **Always** use explicit static types. Never rely on inference (`:=`).
- **Void returns:** Always add `-> void` for functions returning nothing.
- **Data Structures:** Use typed Arrays/Dictionaries.
    - ✅ `var items: Array[String] = []`
    - ❌ `var items = []`

### Naming Conventions
- **Classes:** `PascalCase` (e.g., `PlayerController`)
- **Nodes/Files:** `snake_case` (e.g., `player_controller.gd`, `enemy_slime.tscn`)
- **Functions/Vars:** `snake_case` (e.g., `current_health`)
- **Signals:** `snake_case` (past tense preferred, e.g., `health_changed`)
- **Constants:** `SCREAMING_SNAKE_CASE` (e.g., `MAX_SPEED`)
- **Privates:** Prefix with `_` (e.g., `_internal_state`)

### Code Structure Order
Organize scripts strictly in this order:
1.  `class_name` and `extends`
2.  `@tool` (if applicable)
3.  **Signals**
4.  **Enums**
5.  **Constants**
6.  **@export variables** (grouped via `@export_group`)
7.  **Public variables**
8.  **Private variables** (`_`)
9.  **@onready variables**
10. **Built-in functions** (`_init`, `_ready`, `_process`, `_physics_process`)
11. **Public functions**
12. **Private functions**
13. **Signal callbacks** (e.g., `_on_health_changed`)

## 3. Architecture Patterns

### Inheritance vs. Composition
Use a **Hybrid Approach**:
1.  **Inheritance** is for **Identity** ("Is-A"):
    - `BaseCharacter` -> `Enemy` -> `Slime`
    - Use inheritance to share common node structures (Sprite, Collision).
2.  **Composition** is for **Ability** ("Has-A"):
    - `HealthComponent`, `MovementComponent`, `InventoryComponent`.
    - Logic should reside in Components (Nodes) attached to the actor.
    - **Rule:** If a feature is used by the Player AND an Enemy, make it a Component.

### Node References
- Use `@onready` with explicit types.
- **NEVER** use `get_node()` inside `_process` or `_physics_process`.
- **String References:** Avoid string paths if possible. Use `@export` for flexibility or Unique Names (`%NodeName`) if structure is rigid.

### Signal Communication
- **Down:** Parent calls Child function directly.
- **Up:** Child emits Signal to Parent.
- **Lateral:** Siblings use a common Parent or EventBus.
- Connect signals in code (in `_ready`), not via Editor GUI.
  ```gdscript
  func _ready() -> void:
      health_component.health_changed.connect(_on_health_changed)
  ```

## 4. Best Practices & Performance

### Control Flow
- Use **Guard Clauses** (early return) over nested `if` statements.
  ```gdscript
  # Good
  if not is_active: return
  if health <= 0: return
  do_logic()
  ```

### Data Handling
- **DTOs:** Use strict custom `Resource` or `RefCounted` classes for passing complex data, NOT untyped Dictionaries.
- **Resources:** Use `.tres` files for static configuration (Stats, Spawn Tables).

### 2D Physics & Movement
- Use `CharacterBody2D` for entities.
- Movement logic belongs in `_physics_process`.
- Visual updates belong in `_process` (if decoupled).
- Multiply by `delta` for custom movement calculations (though `move_and_slide()` handles delta internally for velocity).

### Testing (GdUnit4)
- When asked to write tests, use **GdUnit4** syntax.
- Use `auto_free()` for manual instantiation in tests.
- Pattern: `assert_that(actual).is_equal(expected)`

## 5. Anti-Patterns (DO NOT DO)
- ❌ **Global State:** Do not dump logic into Autoloads. Use Autoloads *only* for global managers (Audio, SceneLoader) or Event Buses.
- ❌ **Magic Numbers:** Extract numbers to `const`.
- ❌ **Deep Nesting:** Refactor into small private functions.
- ❌ **Hardcoded Paths:** Use `preload("res://...")`, never relative paths like `../assets/`.

## 6. MCP & Tooling Integration
- **MCP Server:** If creating tools/scripts that interact with the project structure:
    - Use `create_scene` for batch generation.
    - Use `add_node` to manipulate scene trees programmatically.
- **Directory Structure:**
    - `scenes/` (tscn)
    - `scripts/` (gd)
    - `resources/` (tres)
    - `assets/` (png, wav)

## Example Class Template

```gdscript
class_name PlayerController
extends CharacterBody2D

signal died

const SPEED: float = 300.0

@export var max_health: int = 100

var _current_health: int

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    _current_health = max_health
    health_component.health_changed.connect(_on_health_changed)

func _physics_process(delta: float) -> void:
    _handle_movement()
    move_and_slide()

func take_damage(amount: int) -> void:
    health_component.damage(amount)

func _handle_movement() -> void:
    var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = direction * SPEED

func _on_health_changed(new_val: int) -> void:
    if new_val <= 0:
        died.emit()
```
