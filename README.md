# Wool - Mobile Platformer

[Play the Demo!](https://wooly-wield-mobile-9b13c2.fh-muenster.io/)

A mobile platformer game developed with **Godot 4.x**. Play as Wool, navigate through challenging levels, swing on hooks, and avoid enemies like Eagles and Fish!

## 🎮 Game Description

This project is a 2D mobile platformer featuring:
- **Character Control**: Jump, Hook, and Swing mechanics.
- **Enemies**: Avoiding dynamic enemies like Eagles (flying) and Fish (jumping).
- **Audio**: Immersive sound effects with dynamic volume based on proximity/visibility.
- **Mobile Optimized**: Designed for landscape mobile play (2532x1170).

## 🚀 Getting Started

### Prerequisites

- **Godot Engine 4.x** (Standard version recommended).
  - Download from [godotengine.org](https://godotengine.org/download).

### Installation

1.  **Clone the Repository**:
    ```bash
    git clone https://git.fh-muenster.de/vclab/Gameentwicklung/ge-wise25/team1/wooly-wield-mobile.git
    ```
2.  **Open Godot Engine**.
3.  Click **Import** and navigate to the cloned directory.
4.  Select the `project.godot` file.
5.  Click **Import & Edit**.

## 🕹️ Controls

The game supports both mobile touch inputs and keyboard/mouse for testing.

- **Jump / Interact**: `Spacebar`, `Left Mouse Click`, or `Touch Screen`.
- **Hook / Swing**: Automatically engages when near a hook point.

## 🛠️ Project Structure

- `assets/`: Contains all game assets (sprites, audio, fonts).
- `scenes/`: all game scenes (`.tscn`).
    - `levels/`: Level scenes (e.g., `level_1.tscn`).
    - `characters/`: Character prefabs (Wool, Enemies).
    - `ui/`: User Interface scenes (Menus, HUD).
- `scripts/`: All GDScript files.
    - `globals/`: Autoloaded singletons (`AudioManager`, `GameManager`).
    - `characters/`: Character logic.

## 📦 How to Export

The project is configured for export to mobile platforms and web.

1.  **Open Export Menu**:
    - Go to `Project` -> `Export...` in the top menu.
2.  **Select Preset**:
    - Choose your target platform (e.g., **Android**, **iOS**, or **Web**) from the presets list.
    - *Note: You may need to install export templates if you haven't already.*
3.  **Export**:
    - Click **Export Project...**.
    - Choose a destination folder (e.g., `builds/`).
    - Uncheck "Export With Debug" for a release build, or keep it checked for testing.
