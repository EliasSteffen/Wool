# GitHub Copilot Instructions für Godot 4.5.1 Projekt

## Projekt-Übersicht

Dieses Projekt ist ein 2D-Spiel entwickelt mit **Godot Engine 4.5.1** und **GDScript**. Es nutzt eine node-basierte Architektur mit Vererbungshierarchien für Characters (Players/Enemies).

## Godot-Spezifische Konventionen

### Naming Conventions

#### Dateien und Ordner
- **Szenen**: `snake_case.tscn` (z.B. `base_player.tscn`, `enemy_slime.tscn`)
- **Skripte**: `snake_case.gd` (z.B. `player_controller.gd`, `health_component.gd`)
- **Ressourcen**: `snake_case.tres` (z.B. `player_stats.tres`)
- **Ordner**: `snake_case/` (z.B. `characters/`, `ui_components/`)

#### GDScript Code
- **Klassen**: `PascalCase` (z.B. `class_name PlayerController`)
- **Funktionen**: `snake_case()` (z.B. `func update_health()`)
- **Variablen**: `snake_case` (z.B. `var max_health: int`)
- **Konstanten**: `SCREAMING_SNAKE_CASE` (z.B. `const MAX_SPEED: float = 300.0`)
- **Signale**: `snake_case` (z.B. `signal health_changed(new_value: int)`)
- **Private Variablen**: Prefix mit `_` (z.B. `var _internal_state: bool`)
- **Onready Variablen**: `@onready var` für Node-Referenzen

### Node-Struktur Best Practices

#### Szenen-Hierarchie
```
CharacterBody2D (Root)
├── CollisionShape2D
├── AnimatedSprite2D
├── HealthComponent (Custom Node/Script)
├── MovementComponent (Custom Node/Script)
└── HitboxArea (Area2D)
    └── CollisionShape2D
```

**Regeln:**
- Root-Node sollte den Hauptzweck widerspiegeln (CharacterBody2D für bewegliche Characters)
- Komponenten als Child-Nodes organisieren
- Collision-Shapes immer als direkte Kinder ihrer Physics-Nodes
- UI-Elemente in separaten CanvasLayer-Nodes

### Signal-basierte Kommunikation

#### Deklaration
```gdscript
# Immer mit Typ-Annotationen
signal health_changed(new_health: int, max_health: int)
signal died()
signal item_collected(item_type: String, item_data: Dictionary)
```

#### Verbindung
```gdscript
# Bevorzugt: Code-basierte Verbindung in _ready()
func _ready() -> void:
    health_component.health_changed.connect(_on_health_changed)

# Type-safe callback
func _on_health_changed(new_health: int, max_health: int) -> void:
    health_bar.value = new_health
```

#### Signal-Patterns
- **Bottom-up Communication**: Child → Parent (via Signale)
- **Top-down Communication**: Parent → Child (via direkte Funktionsaufrufe)
- **Sibling Communication**: Über gemeinsamen Parent oder Autoload/Singleton
- Vermeide direkte Abhängigkeiten zwischen Siblings

### GDScript Style Guide

#### Type Annotations (PFLICHT)
```gdscript
# Variablen
var speed: float = 200.0
var player_name: String = "Wool"
var items: Array[String] = []
var health_data: Dictionary = {}

# Funktionen
func calculate_damage(base_damage: int, multiplier: float) -> int:
    return int(base_damage * multiplier)

func get_player_position() -> Vector2:
    return global_position
```

#### Einrückung und Formatierung
- **Einrückung**: 1 Tab (Godot-Standard)
- **Leerzeichen**: Um Operatoren (`=`, `+`, `-`, etc.)
- **Zeilenlänge**: Max. 100 Zeichen
- **Leere Zeilen**: Zwischen Funktionen und logischen Blöcken

```gdscript
class_name PlayerController
extends CharacterBody2D

# === SIGNALS ===
signal jumped()
signal landed()

# === CONSTANTS ===
const MAX_SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0

# === EXPORTED VARIABLES ===
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# === PUBLIC VARIABLES ===
var is_grounded: bool = false

# === PRIVATE VARIABLES ===
var _direction: Vector2 = Vector2.ZERO

# === ONREADY VARIABLES ===
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# === BUILT-IN METHODS ===
func _ready() -> void:
    _setup_components()

func _physics_process(delta: float) -> void:
    _handle_movement(delta)
    move_and_slide()

# === PUBLIC METHODS ===
func take_damage(amount: int) -> void:
    health -= amount

# === PRIVATE METHODS ===
func _handle_movement(delta: float) -> void:
    # Implementation
    pass
```

#### Funktions-Organisation
1. Signale
2. Konstanten
3. @export Variablen
4. Öffentliche Variablen
5. Private Variablen
6. @onready Variablen
7. Built-in Methods (_ready, _process, _physics_process, etc.)
8. Öffentliche Methoden
9. Private Methoden
10. Signal Callbacks (gruppiert am Ende)

### Szenen-Architektur Patterns

#### WICHTIG: Vererbung MAXIMIEREN, Code-Duplikation VERMEIDEN!

Dieses Projekt nutzt eine **strikte Vererbungshierarchie** um Code und Node-Strukturen wiederzuverwenden:

**Szenen-Vererbung (Scene Inheritance):**
```
scenes/characters/
  base-character.tscn          # Root: CharacterBody2D + HealthComponent + MovementComponent
    ├── players/
    │   base-player.tscn        # Erbt base-character + Input + Camera + PlayerController
    │   └── wool.tscn           # Erbt base-player + spezielle Wool-Fähigkeiten
    └── enemies/
        base-enemy.tscn         # Erbt base-character + AI + EnemyBehavior
        ├── enemy-slime.tscn    # Erbt base-enemy + Slime-spezifische Properties
        └── enemy-bird.tscn     # Erbt base-enemy + Flying behavior
```

**⚠️ KRITISCHE REGEL: Immer Scene Inheritance nutzen!**
- Rechtsklick auf Szene → "New Inherited Scene" verwenden
- NIEMALS Nodes/Scripts manuell kopieren zwischen ähnlichen Szenen
- Änderungen an base-character.tscn propagieren automatisch zu allen Kindern
- Nur überschreibe Properties, die sich unterscheiden müssen

**Design Patterns für maximale Wiederverwendung:**

1. **Composition Pattern (Komponenten-System):**
```gdscript
# scripts/components/health_component.gd
class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died()

@export var max_health: int = 100
var current_health: int

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health, max_health)
    if current_health == 0:
        died.emit()

func heal(amount: int) -> void:
    current_health = min(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)
```

2. **Strategy Pattern (Austauschbares Verhalten):**
```gdscript
# scripts/ai/ai_behavior.gd (Base-Klasse)
class_name AIBehavior
extends Node

func calculate_move(delta: float) -> Vector2:
    return Vector2.ZERO  # Override in subclass

# scripts/ai/chase_behavior.gd
class_name ChaseBehavior
extends AIBehavior

@export var target: Node2D
@export var speed: float = 100.0

func calculate_move(delta: float) -> Vector2:
    if target:
        return global_position.direction_to(target.global_position) * speed
    return Vector2.ZERO
```

3. **State Machine Pattern (für komplexe Character-States):**
```gdscript
# scripts/state_machine/state_machine.gd
class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State

func _ready() -> void:
    for child in get_children():
        if child is State:
            child.state_machine = self
    if initial_state:
        current_state = initial_state
        current_state.enter()

func change_state(new_state: State) -> void:
    if current_state:
        current_state.exit()
    current_state = new_state
    current_state.enter()

# scripts/state_machine/state.gd
class_name State
extends Node

var state_machine: StateMachine

func enter() -> void:
    pass

func exit() -> void:
    pass

func process(delta: float) -> void:
    pass
```

4. **Resource-basierte Konfiguration (für Stats):**
```gdscript
# scripts/resources/character_stats.gd
class_name CharacterStats
extends Resource

@export var max_health: int = 100
@export var speed: float = 200.0
@export var damage: int = 10
@export var defense: int = 5

# Dann in Szenen:
# @export var stats: CharacterStats
# und .tres Dateien für jeden Character-Typ erstellen
```

**Vererbung vs. Komposition - Wann was?**

**✅ Verwende VERERBUNG für:**
- Szenen-Struktur (base-character → base-player → wool)
- Klare "ist-ein"-Beziehungen
- Wenn Node-Struktur identisch ist
- **IMMER wenn möglich, um Duplikation zu vermeiden!**

**✅ Verwende KOMPOSITION für:**
- Wiederverwendbare Features (HealthComponent, MovementComponent)
- Mix-and-Match Funktionalität
- Austauschbares Verhalten (AIBehavior)

**❌ NIEMALS:**
- Szenen duplizieren und händisch ändern
- Gleichen Code in mehreren Skripten kopieren
- Node-Strukturen manuell nachbauen

#### Szenen-Instanzierung

```gdscript
# Statisch (zur Design-Zeit)
# Verwende Scene-Editor zum Hinzufügen von Child-Nodes

# Dynamisch (zur Laufzeit)
const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_slime.tscn")

func spawn_enemy(position: Vector2) -> void:
    var enemy: Node2D = ENEMY_SCENE.instantiate()
    enemy.global_position = position
    get_tree().current_scene.add_child(enemy)
```

### Ressourcen-Organisation

#### Projekt-Pfade (immer absolute res:// Pfade)
```gdscript
# ✅ RICHTIG
const PLAYER_TEXTURE: Texture2D = preload("res://assets/characters/player_sprite.png")

# ❌ FALSCH
const PLAYER_TEXTURE = preload("../assets/player.png")
```

#### Asset-Organisation
```
/assets/
  /characters/
    /players/     # 16x16, 32x32, 64x64 Sprites
    /enemies/
  /environment/
  /ui/
  /audio/
    /music/
    /sfx/
```

#### Import-Einstellungen
- **Pixel-Art**: Filter deaktivieren, Compress → Lossless
- **Sprites**: Import als Texture, nicht als Image
- **Audio**: OGG für Musik, WAV für kurze SFX

### Performance-Richtlinien für 2D

#### Optimierungen
1. **Verwende `@onready` für Node-Referenzen** (einmalig beim _ready)
2. **Vermeide `get_node()` in _process()/_physics_process()**
3. **Nutze Object Pooling** für häufig gespawnte Objekte (Projektile, Partikel)
4. **Verwende `queue_free()` statt `free()`**
5. **Setze `process_mode` auf DISABLED** für inaktive Nodes

```gdscript
# ✅ Performance-optimiert
@onready var sprite: Sprite2D = $Sprite2D

func _process(delta: float) -> void:
    sprite.position.x += 10.0

# ❌ Performance-Problem
func _process(delta: float) -> void:
    $Sprite2D.position.x += 10.0  # Lookup jedes Frame!
```

#### Physics vs. Idle Process
- **_physics_process()**: Bewegung, Kollision, Physik (60 FPS fix)
- **_process()**: Visuals, UI, Audio (variabel FPS)

### Testing-Strategien

#### Unit Tests (GdUnit4)
```gdscript
# test_player_movement.gd
extends GdUnitTestSuite

func test_player_moves_right() -> void:
    var player = auto_free(PlayerController.new())
    player.move_right()
    assert_float(player.velocity.x).is_greater(0.0)
```

#### Scene Tests
```gdscript
# Teste komplette Szenen
func test_player_scene_loads() -> void:
    var scene = load("res://scenes/characters/players/wool.tscn")
    var instance = auto_free(scene.instantiate())
    assert_object(instance).is_not_null()
```

#### Integration Tests
- Teste Signal-Verbindungen zwischen Nodes
- Teste Szenen-Instanzierung
- Teste Autoload-Zugriff

### Git-Workflow

#### Commit-Konventionen
```
feat: Füge neuen Enemy-Typ hinzu (Slime)
fix: Behebe Player-Kollisionsproblem
refactor: Extrahiere HealthComponent aus BaseCharacter
docs: Update ARCHITECTURE.md mit Signal-Pattern
style: Formatiere player_controller.gd nach Style Guide
perf: Optimiere Enemy-Spawning mit Object Pool
test: Füge Tests für MovementComponent hinzu
ci: Update GitLab CI für Web-Export
```

#### Branch-Strategie
- `main`: Produktions-bereit
- `develop`: Entwicklungs-Branch
- `feature/feature-name`: Neue Features
- `fix/bug-description`: Bugfixes
- `refactor/component-name`: Code-Refactoring

#### .gitignore Essentials
```gitignore
# Godot
.import/
*.import
.godot/
export_presets.cfg

# OS
.DS_Store
Thumbs.db
```

### Godot 4.5 Spezifische Features

#### Verwende neue Annotations
```gdscript
@export_range(0.0, 100.0, 0.1) var health: float = 100.0
@export_group("Movement")
@export var speed: float = 200.0
@export var acceleration: float = 1000.0
@export_group("")

@onready var sprite: Sprite2D = $Sprite2D
@warning_ignore("unused_parameter")
```

#### CharacterBody2D (statt KinematicBody2D)
```gdscript
func _physics_process(delta: float) -> void:
    velocity = calculate_velocity(delta)
    move_and_slide()  # Keine Parameter mehr!

    # Neue Properties
    if is_on_floor():
        coyote_time = 0.1
```

#### Typed Arrays
```gdscript
var enemies: Array[Enemy] = []
var item_names: Array[String] = []
var positions: Array[Vector2] = []
```

## Häufige Anti-Patterns (VERMEIDEN!)

❌ **Globale Variablen missbrauchen**
```gdscript
# Schlecht: Alles in Autoload-Singleton
Global.player_health = 100
Global.player_position = Vector2(0, 0)
```

✅ **Besser: Signale und Dependency Injection**

❌ **Zyklische Dependencies**
```gdscript
# Player kennt Enemy UND Enemy kennt Player
```

✅ **Besser: Beide kennen nur gemeinsame Base-Klasse oder Interface**

❌ **String-basierte Node-Zugriffe**
```gdscript
get_node("../../Player/Sprite2D")
```

✅ **Besser: @onready var oder @export NodePath**

❌ **Fehlende Typ-Annotationen**
```gdscript
var speed = 200
func move(direction):
    pass
```

✅ **Immer Typen angeben!**

## Code Review Checklist

Vor jedem Commit prüfen:
- [ ] Alle Variablen und Funktionen haben Typ-Annotationen
- [ ] Signale werden für Bottom-up Communication verwendet
- [ ] Keine `get_node()` Calls in _process() Loops
- [ ] Node-Referenzen sind @onready deklariert
- [ ] Naming Conventions eingehalten
- [ ] Keine hardcoded Pfade (immer res://)
- [ ] Kommentare für komplexe Logik
- [ ] Keine `print()` Statements im finalen Code (verwende `push_warning()`)

## Hilfreiche Debugging-Befehle

```gdscript
# Console Output
print("Value: ", value)
push_warning("This might cause issues")
push_error("Critical error occurred")

# Assertions
assert(health > 0, "Health must be positive")

# Tree-Debugging
print_tree_pretty()  # Zeige Node-Hierarchie
```

## Performance-Monitoring

```gdscript
# FPS und Profiling
var fps: int = Engine.get_frames_per_second()
var memory: int = OS.get_static_memory_usage()

# Verwende Godot's Profiler (Debug → Profiler)
```

---

**Bei Unklarheiten**: Konsultiere die [Godot 4.5 Dokumentation](https://docs.godotengine.org/en/stable/) oder frage nach spezifischen Use Cases!

## MCP Server Integration

### Godot MCP Server
Dieses Projekt nutzt einen **Godot MCP Server** für erweiterte Entwickler-Workflows:

**Verfügbare MCP Tools:**
- `create_scene`: Neue Szenen programmatisch erstellen
- `add_node`: Nodes zu existierenden Szenen hinzufügen
- `load_sprite`: Sprites in Szenen laden
- `get_project_info`: Projekt-Metadaten abrufen
- `run_project`: Projekt ausführen und Output erfassen
- `save_scene`: Szenen-Änderungen speichern

**Nützliche Anwendungsfälle:**
1. **Batch-Szenen-Erstellung**: Mehrere Enemy-Varianten automatisch generieren
2. **Prototyping**: Schnell Szenen-Strukturen testen ohne Editor
3. **Testing**: Projekt automatisiert starten und Logs analysieren
4. **Refactoring**: Programmatisch Node-Strukturen anpassen

**Workflow-Beispiel:**
```bash
# MCP Server nutzen um neue Enemy-Variante zu erstellen
# (via MCP-fähiger KI oder CLI)
create_scene(
  projectPath: "/Users/e.steffen/godot/wool",
  scenePath: "scenes/characters/enemies/enemy_bat.tscn",
  rootNodeType: "CharacterBody2D"
)

# Node-Struktur von base-enemy kopieren
add_node(...) für Sprite, Collision, etc.
```

**Wichtig:** Der `godot-mcp/` Ordner ist **NUR für MCP Server** - nicht für Game-Code verwenden!
