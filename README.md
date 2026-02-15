<!-- Header Section -->
<div align="center">

# 🧶 Wool - Mobile Platformer

![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue?style=for-the-badge&logo=godot-engine&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Mobile%20%7C%20Web%20%7C%20Windows%20%7C%20MacOS-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-In%20Development-orange?style=for-the-badge)

<br/>

<!-- Dynamic Build Status Badges -->
![Web Build](https://img.shields.io/endpoint?url=https%3A%2F%2Fwooly-wield-mobile-9b13c2.fh-muenster.io%2Fbadges%2Fweb.json)
![Android Build](https://img.shields.io/endpoint?url=https%3A%2F%2Fwooly-wield-mobile-9b13c2.fh-muenster.io%2Fbadges%2Fandroid.json)
![Windows Build](https://img.shields.io/endpoint?url=https%3A%2F%2Fwooly-wield-mobile-9b13c2.fh-muenster.io%2Fbadges%2Fwindows.json)

<br/>

### [👉 Play the Live Demo! 👈](https://wooly-wield-mobile-9b13c2.fh-muenster.io/demo)

<br/>

A mobile platformer game developed with **Godot 4.x**. Play as Wool, navigate through challenging levels, swing on hooks, and avoid enemies like Eagles and Fish!

</div>

---

## 🎮 Game Description

This project is a high-quality 2D mobile platformer featuring:

*   **🏃 Character Control**: Fluid Jump, Hook, and Swing mechanics.
*   **🦅 Dynamic Enemies**: Surviving encounters with Eagles (flying) and Fish (jumping).
*   **🔊 Immersive Audio**: 3D-positioned sound effects with dynamic volume based on visibility and proximity.
*   **📱 Mobile Optimized**: Designed specifically for landscape mobile play (2532x1170).

---

## 🚀 Getting Started

### Prerequisites

| Software | Version | Link |
| :--- | :--- | :--- |
| **Godot Engine** | 4.x (Standard) | [Download Here](https://godotengine.org/download) |

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://git.fh-muenster.de/vclab/Gameentwicklung/ge-wise25/team1/wool.git
    ```

2.  **Open Godot Engine**

3.  Click **Import** and navigate to the cloned directory.

4.  Select the `project.godot` file.

5.  Click **Import & Edit**.

---

## 🕹️ Controls

The game supports both mobile touch inputs and keyboard/mouse for testing.

| Action | Input |
| :--- | :--- |
| **Jump / Interact** | `Spacebar` / `Left Mouse Click` / `Touch Screen` |
| **Hook / Swing** | **Automatic** when near a hook point |

---

## 🛠️ Project Structure

The project follows a clean, modular structure:

*   📁 **`assets/`** - Contains all game assets (sprites, audio, fonts).
*   📁 **`scenes/`** - All game scenes (`.tscn`).
    *   `levels/` - Playing fields (e.g., `level_1.tscn`).
    *   `characters/` - Character prefabs (Wool, Enemies).
    *   `ui/` - User Interface scenes (Menus, HUD).
*   📁 **`scripts/`** - All GDScript logic.
    *   `globals/` - Autoloaded singletons (`AudioManager`, `GameManager`).
    *   `characters/` - Character behavior logic.

---

## 📦 How to Export

The project is pre-configured for export to mobile platforms and web.

1.  **Open Export Menu**
    *   Navigate to `Project` -> `Export...` in the top menu.

2.  **Select Preset**
    *   Choose your target platform (e.g., **Android**, **iOS**, or **Web**) from the presets list.
    *   *> Note: You may need to install export templates if you haven't already.*

3.  **Export**
    *   Click **Export Project...**.
    *   Choose a destination folder (e.g., `builds/`).
    *   Uncheck "Export With Debug" for a release build, or keep it checked for testing.
