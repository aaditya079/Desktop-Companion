# Desktop Companion

An interactive, transparent, borderless anime desktop companion built with Godot 4 and Live2D Cubism (`gd_cubism`).

## ✨ Features
- **Authentic Live2D & 3D Models:**
  - **Camellya** *(Wuthering Waves)*
  - **Hiyori** *(Official Live2D Full-Body Sample)*
  - **Ellen Joe** *(Zenless Zone Zero)*
  - **Jane Doe** *(Zenless Zone Zero)*
  - **Mao** *(Official Live2D Sample)*
  - **Tingyun** *(Honkai: Star Rail)*
  - **Fu Xuan** *(Honkai: Star Rail)*
  - **Murasame** *(Senren Banka)*
  - **Nicole Demara** *(Zenless Zone Zero)*
  - **Reze** *(3D Chainsaw Man)*
- **Cursor Gaze & Motion Tracking:** Head, eye, and body angles smoothly follow mouse movements across your desktop.
- **Gravity Drop & Grounding Physics (with Toggle):**
  - **Gravity ON:** Drag and release the companion anywhere in the air to watch her accelerate downward and land on the taskbar with a landing bounce.
  - **Floating Mode:** Toggle gravity off from the right-click menu to place her freely anywhere on your screen.
- **Standalone Windows Executable (`DesktopCompanion.exe`):** Single-click launch with zero external Godot installation required.
- **Native Taskbar & System Tray Integration:** Custom companion tray icon in the Windows notification area with background process management and remote controls.
- **QuickDock Floating Mini-Bar:** Sleek frosted glass HUD docked at the bottom with quick buttons for Chat, Outfit cycle, Gravity toggle, Poke, and Menu.
- **Pomodoro Focus Study Timer:** 25-minute study timer with animated glowing badge (`⏱ 24:59`), sound alerts, and celebration confetti.
- **Procedural Sound FX Synthesizer:** Built-in audio engine generating soft bubble pops, chimes, and victory fanfares without external audio files.
- **Dizzy Shake & Toss Inertia Physics:** Rapidly shaking the companion triggers comical dizzy swirling eyes, body sway, and speech reactions; tossing her applies decaying horizontal momentum.
- **Multi-Zone Poke & Tap Interactions:** Contextual reactions for head strokes (blush & hearts), torso tickles (sparkles), and feet stretches (hop bounce).
- **Scale Presets (Compact / Standard / Large):** 85%, 100%, and 118% display scaling to fit 1080p, 1440p, or 4K monitors without distortion.
- **Ergonomic & Hydration Alerts:** 45-minute posture and hydration check-ins to keep you refreshed while working.
- **Visual Novel Pill Action HUD:** Clean unoccluded anime companion view with 9 authentic pill capsule action buttons (`✦ Action ˣ`).
- **Any AI API of Choice:** Universal OpenAI-compatible API engine. Connect any provider (Groq, OpenRouter, OpenAI, DeepSeek, Local LM Studio / vLLM, or custom endpoint URL), enter any model name, and test the connection live with the built-in ⚡ Test Connection tool. Offline fallback is built-in so no setup is required.

## 🎮 Controls
| Action | Input |
| :--- | :--- |
| **Context Menu** | Right-Click character (Switch outfits/models, toggle gravity, settings) |
| **Move / Carry** | Left-Click & Drag across screen |
| **Poke / Interact** | Left-Click quick tap |
| **Chat / Talk** | Press `Enter` or click `Talk` in right-click menu |
| **Close UI / Quit** | Press `Escape` |

## 🚀 Quick Start (Standalone Application)
Zero installation required!
1. Download or clone this repository:
   ```bash
   git clone https://github.com/aaditya079/Desktop-Companion.git
   ```
2. Double-click **`DesktopCompanion.exe`**.
3. That's it! Your companion appears seamlessly on your desktop with an interactive taskbar icon and Windows system tray menu in your notification area.

---

## 📌 Windows Taskbar & System Tray
Desktop Companion includes a native Windows Taskbar & System Tray runner:
* **Taskbar Icon:** Displays a custom companion portrait directly on your Windows taskbar.
* **System Tray Menu (Notification Area):** Right-click the companion icon near your system clock to:
  * 👁 **Show / Hide Companion** (or double-click the tray icon)
  * 💬 **Open Chat**
  * 👗 **Cycle Outfits & Models**
  * 🌍 **Toggle Gravity (Drop / Float Mode)**
  * ⏱ **Start 25m Pomodoro Focus Timer**
  * 🔊 **Toggle Sound Effects**
  * ❌ **Exit Application**
