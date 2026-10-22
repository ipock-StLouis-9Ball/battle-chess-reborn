# Duel of Kings: Animated Chess ⚔️♟️

An original spiritual successor to classic theatrical chess, reimagining strategic turn-based board mastery with dramatic 3D isometric combat duels across High Fantasy, Cyberpunk, and Eldritch factions.

Built for **Godot Engine 4 (v4.3+)**, architected specifically for cross-platform delivery across:
- 🖥️ **Steam PC (Windows / Linux / Steam Deck)**
- 📱 **Samsung Galaxy Android Devices (Galaxy S21–S24 Ultra, Z Fold / Flip, A-Series)**

---

## 🌟 Core Gameplay Pillars

1. **Strategic Board Chess**:
   - Standard 8x8 chess rules, move legality, check, checkmate, stalemate, castling, and pawn promotion.
   - Intelligent AI opponent with adjustable difficulty (Apprentice to Grandmaster).
   - Local Pass & Play for 2 players on desktop or mobile touchscreens.

2. **Action Arena Duels (Gladiator Combat Duels)**:
   - When an attacking piece moves onto an occupied enemy square, a **Real-Time Combat Duel** triggers!
   - Each chess piece class features unique combat stats, attack speed, armor, and signature abilities:
     - **Pawn**: *Underdog Rush* (Fast jabs, high crit rate against heavy pieces).
     - **Knight**: *Flanking Charge* (High mobility, lunging strikes).
     - **Bishop**: *Diagonal Smite* (High burst reach, critical smites).
     - **Rook**: *Castle Slam* (Heavy armor colossus, ground pounds).
     - **Queen**: *Royal Judgement* (Deadly blade dancer with high burst combos).
     - **King**: *Monarch's Decree* (High durability, area shockwaves).
   - The victor retains/claims the square, and surviving pieces carry remaining HP into subsequent battles!
   - *Fast Auto-Resolve* mode is available in Settings for players who want rapid statistical battle calculations.

---

## 🎮 Cross-Platform Optimizations

### 📱 Samsung Galaxy Android Specifics
- **Dynamic Safe Area Handling** (`SafeAreaContainer`):
  - Integrates with `DisplayServer.get_display_safe_area()`.
  - Automatically adjusts UI margins around Samsung Infinity-O punch-hole camera cutouts, curved edge displays, and gesture navigation bars.
- **AMOLED 120Hz High Refresh Rate**:
  - Automatically queries `DisplayServer.screen_get_refresh_rate()`.
  - Native 120 FPS targeting for buttery-smooth animations on Galaxy S/Fold series AMOLED panels.
- **Ergonomic Virtual Touch Controls**:
  - Left-hand analog floating `VirtualJoystick` with deadzone calibration.
  - Right-hand diamond-spaced `TouchActionButtons` (Light, Heavy, Dodge, Special) sized for comfortable thumb ergonomics (>64dp targets).
  - Configurable touch control visibility and opacity in Settings.
- **Haptic Tactile Feedback**:
  - `Input.vibrate_handheld()` feedback on moves, attacks, critical hits, and button presses.
- **Android Back Button Integration**:
  - `NOTIFICATION_WM_GO_BACK_REQUEST` handled gracefully (toggles in-game pause menu or prompts exit).
- **Power & Sleep Management**:
  - `DisplayServer.screen_set_keep_on(true)` prevents screen timeout during active gameplay.

### 🖥️ Steam PC & Steam Deck Specifics
- Full keyboard + mouse support (Left click select/attack, Right click cancel/heavy, WASD/Arrows move, Shift/L dodge).
- Steam Deck / Gamepad detection (`OS.has_feature("steamdeck")` / XInput / DualShock).
- Automatic hiding of on-screen touch controls when keyboard, mouse, or gamepad input is detected.
- Resizable viewport with `canvas_items` stretch mode and `expand` aspect ratio (supporting 16:9, 16:10, and 21:9 ultrawide monitors).

---

## 🏗️ Project Architecture

```
battle-chess-reborn/
├── project.godot                 # Core Godot 4 engine config, autoloads, input maps
├── export_presets.cfg            # Presets for Windows (Steam), Linux (Steam Deck), Android (Samsung Galaxy)
├── default_bus_layout.tres       # Audio routing (Master, Music, SFX, UI, Combat)
├── .gitignore                    # Godot 4 build & editor ignore rules
│
├── assets/                       # Audio, visual, and font assets
│   ├── audio/                    # Music, SFX, UI audio
│   ├── icons/                    # App & notification icons
│   ├── textures/                 # Board, pieces, UI, VFX textures
│   └── shaders/                  # Custom visual effect shaders
│
└── src/
    ├── autoload/                 # Global Singletons
    │   ├── event_bus.gd          # Decoupled publish/subscribe signal bus
    │   ├── platform_manager.gd   # OS, device model, safe area, haptics, refresh rate
    │   ├── settings_manager.gd   # Audio, display (120Hz), graphics, touch preferences
    │   ├── save_manager.gd       # Persistent profile, match history, duel stats
    │   ├── audio_manager.gd      # SFX pooling + procedural fallback sound generator
    │   └── game_manager.gd       # Global match state coordinator
    │
    ├── core/                     # Game foundation & state orchestration
    │   ├── main.tscn / .gd       # Root scene manager
    │   ├── game_enums.gd         # Global enums (states, pieces, inputs, platforms)
    │   └── state_machine/        # Modular Finite State Machine framework
    │
    ├── chess/                    # Chess system
    │   ├── logic/
    │   │   ├── chess_piece_data.gd  # Resource holding piece stats, HP, and abilities
    │   │   ├── chess_move.gd        # Move data container
    │   │   ├── fen_helper.gd        # FEN parser & serializer
    │   │   └── chess_engine.gd      # Move generation, check/checkmate validation, AI
    │   ├── board/
    │   │   ├── chess_board.tscn/.gd # 8x8 Board manager & input coordinator
    │   │   └── board_tile.tscn/.gd  # Interactive tile with highlights & selection
    │   └── pieces/
    │       └── piece_view.tscn/.gd  # Visual piece with animations & HP bar
    │
    ├── combat/                   # Tactical Real-Time Duel Arena
    │   ├── arena/
    │   │   ├── duel_arena.tscn/.gd  # Arena ring, round timer, resolution
    │   │   └── duel_camera.gd       # Dynamic 2D camera framing both fighters + screenshake
    │   └── fighters/
    │       ├── fighter_base.tscn/.gd        # Fighter entity (hitboxes, hurtboxes, combat states)
    │       ├── fighter_controller_player.gd # Player input router (WASD, Gamepad, Touch)
    │       └── fighter_controller_ai.gd     # Dynamic combat AI (spacing, dodges, combos)
    │
    ├── input/                    # Mobile & cross-platform input handlers
    │   ├── virtual_joystick.tscn/.gd     # Touch analog stick for Samsung Galaxy
    │   └── touch_action_buttons.tscn/.gd # Touch combat buttons (Light, Heavy, Dodge, Special)
    │
    ├── ui/                       # User Interface & screens
    │   ├── common/
    │   │   └── safe_area_container.gd # Samsung Galaxy notch & navbar margin inset
    │   └── screens/
    │       ├── splash_screen.tscn/.gd   # Boot logo screen
    │       ├── main_menu.tscn/.gd       # Title, mode select, career stats
    │       ├── match_hud.tscn/.gd       # Turn badge, captured graveyard, pause
    │       ├── duel_hud.tscn/.gd        # Duel HP bars, portraits, timer, touch controls
    │       ├── pause_menu.tscn/.gd      # In-game pause modal
    │       ├── settings_menu.tscn/.gd   # 120Hz, Audio, Touch, VSync, Auto-Duel options
    │       └── victory_screen.tscn/.gd  # Match victor announcement & duel battle recap
    │
    └── utils/
        ├── logger.gd             # Formatted, leveled logging
        └── math_helpers.gd       # Algebraic coordinates (A1-H8) & grid conversion
```

---

## ⌨️ Controls Reference

| Action | PC (Keyboard & Mouse) | Steam Deck / Gamepad | Samsung Galaxy Touch |
| :--- | :--- | :--- | :--- |
| **Select / Move Piece** | Left Click | A Button / D-Pad | Tap Tile / Piece |
| **Cancel Selection** | Right Click / Esc | B Button | Tap Outside / Background |
| **Duel Move** | `W, A, S, D` / Arrows | Left Analog Stick / D-Pad | Left Virtual Joystick |
| **Duel Light Attack** | `J` / `Space` | X Button (Square) | ⚔️ Light Button |
| **Duel Heavy Attack** | `K` / Right Click | Y Button (Triangle) | 💥 Heavy Button |
| **Duel Dodge / Roll** | `L` / `Shift` | B Button (Circle) | 💨 Dodge Button |
| **Duel Special Ability**| `U` / `E` | RB / R1 | ⚡ Special Button |
| **Pause Game** | `Escape` | Start / Options | ⏸ Pause Icon (Top Right) |

---

## 🚀 Building & Exporting

### Android (Samsung Galaxy APK/AAB)
1. Install Android SDK, NDK, and configure debug/release keystores in Godot Editor Settings.
2. In Godot, go to **Project -> Export...**
3. Select **Android (Samsung Galaxy)** preset.
4. Target Architecture: `arm64-v8a` (optimized for Galaxy S/Note/Z/A 64-bit Exynos/Snapdragon chips).
5. Click **Export Project** -> `duel_chess_battle_remake.apk`.

### Steam PC (Windows / Linux)
1. In Godot, go to **Project -> Export...**
2. Choose **Windows Desktop (Steam)** (`duel_chess_battle_remake.exe`) or **Linux/SteamOS (Steam Deck)** (`duel_chess_battle_remake.x86_64`).
3. 64-bit architecture with embedded PCK enabled.

---

## 🛡️ License & Credits
Developed for Duel of Kings: Animated Chess. Built with Godot Engine 4.
