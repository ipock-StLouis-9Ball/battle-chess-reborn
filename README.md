# Duel of Kings: Animated Chess ⚔️♟️

An original spiritual successor to classic theatrical chess, reimagining strategic turn-based board mastery with dramatic 3D isometric combat duels across High Fantasy, Cyberpunk, and Eldritch factions.

Built for **Godot Engine 4 (v4.3+)**, architected specifically for cross-platform delivery across:
- 🖥️ **Steam PC (Windows / Linux / Steam Deck)**
- 📱 **Samsung Galaxy Android Devices (Galaxy S21–S24 Ultra, Z Fold / Flip, A-Series)**

---

## 🌟 Core Gameplay Pillars

### 1. Pure Strategic Board Chess (100% FIDE Rules)
- Standard 8x8 chess rules, legal moves, check, checkmate, stalemate, castling, and pawn promotion.
- Deterministic captures: In chess, a capture is absolute. If Piece A takes Piece B's square, Piece B is always eliminated.
- **No hit points, no health bars, no fighting game controls**.
- Intelligent AI opponent with adjustable difficulty (Apprentice to Grandmaster).
- Local Pass & Play for 2 players on desktop or mobile touchscreens.

### 2. Scripted 5–8s 3-Act Choreographed Duels (1988 Battle Chess Style)
When a piece captures an occupied enemy square, the camera smoothly plunges into the contested tile for an intimate 3-act theatrical execution vignette:
- **Act 1 (0.0s – 2.5s) Opening Strike**: Attacker delivers a heavy opening blow; defender parries and blocks with shield or weapon.
- **Act 2 (2.5s – 5.0s) Counter-Blow**: Defender retaliates with a fierce counter-attack; attacker sidesteps or ducks under the swing.
- **Act 3 (5.0s – 7.5s) The Finisher**: Attacker charges thematic faction energy and executes their signature kill shot. At 5.8s, critical impact triggers **0.4x slow-motion**, haptic rumble, and emissive flash as the defender dramatically collapses.
- **7.5s – 8.0s**: Attacker takes the center of the square, the camera smoothly pulls back to the stationary overview, the chess clock resumes, and the turn advances.

### 3. Heroic Stationary Isometric Staging
- **One Fixed Stationary Camera**: Positioned at `Vector3(0, 16, 20)` with pitch $-39.5^\circ$ looking at the board center (White at bottom, Black at top). Narrow $35^\circ$ FOV eliminates wide-angle distortion.
- **Direct 3D Screen Rendering**: Rendered directly to the primary viewport with zero `SubViewport` collapse or sizing bugs.
- **Square-Targeted Duel Zooms**: Smooth 0.4s tween directly into `Vector3(sq_x, 3.2, sq_z + 4.8)` focused on the contested square.

---

## 💰 Unified Monetization Model ($9.99 USD)

*Duel of Kings* features a transparent, unified **$9.99 USD** pricing structure with 100% content parity across Steam PC and Mobile:

| Platform | Pricing Structure | Included Content |
| :--- | :--- | :--- |
| 🖥️ **Steam PC & Steam Deck** | **$9.99 Upfront Buy-to-Play** | 100% Unlocked from day one: all 3 factions, all duels, ranked multiplayer, replay theater, achievements. |
| 📱 **Mobile (Android / Samsung Galaxy)** | **Free Trial + $9.99 Full Game Unlock** | Free trial includes unlimited play with High Fantasy faction. A single one-time **$9.99 IAP** permanently unlocks 100% of all content: Cyberpunk and Eldritch factions, all 3D capture duels, ranked online Elo matchmaking, replay theater, and 100% ad-free gameplay. |

*Zero pay-to-win. Zero energy timers. Zero recurring subscriptions.*

---

## ⚔️ Three Theatrical Factions

1. **🏰 High Fantasy**:
   - Noble Paladins, Ivory Queens, Consecrated Bishops, and Granite Colossus Rooks.
   - Signature finishers: Holy Broadsword Cleave, Divine Smite, Colossus Rampart Crush, Underdog Impalement.
2. **⚡ Cyberpunk**:
   - Neon Mechs, Plasma Railgun Bishops, Cyber Katana Ninjas, and Heavy Nanite Tanks.
   - Signature finishers: Thermal Core Overcharge, Railgun Execution, EMP Nanite Swarm.
3. **🐙 Eldritch**:
   - Cosmic Horrors, Void Harbingers, Tentacled Queens, and Abyssal Leviathans.
   - Signature finishers: Abyssal Maw Rapture, Void Rift Banishment, Cosmic Oblivion.

---

## 🎮 Cross-Platform Optimizations

### 📱 Samsung Galaxy Android Specifics
- **Dynamic Safe Area Handling**: Integrates with `DisplayServer.get_display_safe_area()` for punch-hole cameras and curved screens.
- **AMOLED 120Hz High Refresh Rate**: Automatically queries `DisplayServer.screen_get_refresh_rate()` for native 120 FPS targeting.
- **Touch Raycasting & Emissive Markers**: Direct 3D physical picking on pieces and tiles with glowing golden selection rings and emerald legal move markers.
- **Haptic Tactile Feedback**: `Input.vibrate_handheld()` feedback on moves, attacks, and critical duel impact frames.
- **Power Management**: `DisplayServer.screen_set_keep_on(true)` prevents screen sleep during matches.

### 🖥️ Steam PC & Steam Deck Specifics
- Full mouse + keyboard and gamepad support.
- Resizable viewport with `canvas_items` stretch mode and `expand` aspect ratio (16:9, 16:10, 21:9 ultrawide).

---

## 🚀 Building & Exporting

### Android (Samsung Galaxy APK/AAB)
1. In Godot, go to **Project -> Export...**
2. Select **Android (Samsung Galaxy)** preset (`export/android/duel_of_kings.apk`).
3. Target Architecture: `arm64-v8a` (optimized for Galaxy 64-bit Exynos and Snapdragon devices).

### Steam PC (Windows / Linux)
1. In Godot, go to **Project -> Export...**
2. Choose **Windows Desktop (Steam)** (`export/windows/duel_of_kings.exe`) or **Linux/SteamOS (Steam Deck)** (`export/linux/duel_of_kings.x86_64`).
3. 64-bit architecture with embedded PCK enabled.

---

## 🛡️ License & Legal Disclaimer
*Duel of Kings: Animated Chess* is an original spiritual successor and independent creative work. Built with Godot Engine 4.
