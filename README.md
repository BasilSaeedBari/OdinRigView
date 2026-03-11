# OdinRigView

A minimal, native Windows desktop utility for reading and sharing PC hardware specs — written in the [Odin programming language](https://odin-lang.org/).

Built as a clean reimplementation of [PC-Info by Adeptstack Studios](https://github.com/Adeptstack-Studios/PC-Info), stripped of framework overhead and rewritten from scratch with a data-oriented, explicitly-typed approach. No .NET runtime. No installer. Just a single `.exe`.

---

## What It Does

Non-technical users who are selling their computer need one thing: a fast, readable summary of their PC specs they can copy and paste into a marketplace listing. OdinRigView gives them exactly that.

- Displays **OS, CPU, RAM, GPU, and storage drives** in a clean, easy-to-read layout
- Shows a **live RAM usage bar** that refreshes every second
- **One-click copy** formats all specs as plain text, ready to paste anywhere
- **Dark and light mode** with a strict 5-color palette
- **Three font sizes** (Small / Medium / Large) to suit any screen

---

## Screenshots

> *(Add screenshots here once the app is built)*

---

## Features

| Feature | Detail |
| :--- | :--- |
| OS Info | Username, PC name, Windows edition, architecture |
| CPU Info | Full name, core count, thread count, base clock (GHz) |
| RAM Info | Total, usable, hardware-reserved, live available vs. in-use |
| GPU Info | Full GPU name, dedicated VRAM (GB) via DXGI |
| Drive Info | Per-drive: letter, label, format, type (SSD / NVMe / HDD), total and free space |
| Copy to Clipboard | Clean plain-text summary of all specs, marketplace-ready |
| Font Size Toggle | Cycles Small → Medium → Large |
| Theme Toggle | Dark mode (default) and Light mode |
| Side Menu | Hamburger drawer with three views: System Info, Drives, Help & Info |

---

## Tech Stack

| Purpose | Library |
| :--- | :--- |
| Window + rendering | `vendor:raylib` |
| Immediate-mode UI | `vendor:microui` |
| GPU info (DXGI) | `vendor:directx` |
| Cross-platform hardware info | `core:sys/info` |
| Windows API (RAM, drives, clipboard) | `core:sys/windows` |
| Text formatting | `core:fmt` |
| Frame timing | `core:time` |

No external dependencies beyond what ships with the Odin compiler. Raylib is statically linked — the output is a self-contained `.exe`.

---

## Project Structure

```
pc_info/
├── main.odin           # Entry point, window init, main loop, App_State
├── types.odin          # All shared structs — System_Data, CPU_Info, RAM_Info, etc.
├── sysinfo.odin        # Platform-neutral hardware collection via core:sys/info
├── sys_windows.odin    # All Win32 / DXGI calls — isolated here only
├── ui.odin             # microui layout and per-view rendering
├── ui_theme.odin       # Color palette constants, Theme and Font_Size enums
└── clipboard.odin      # Copy-to-clipboard and screenshot logic
```

---

## Building

### Requirements

- [Odin compiler](https://odin-lang.org/docs/install/) — version dev-2026-03-nightly:6d9a611 (used for Latest Release)
- Windows 10 or Windows 11 (x86_64)
- Odin's `vendor:raylib` bindings (included with the compiler)

### Compile

Run this from the **project root** (the directory containing the `pc_info` folder):

```sh
odin build pc_info -out:pc_info.exe -define:RAYLIB_SHARED=false -extra-linker-flags:"/FORCE:MULTIPLE"
```

| Flag | Reason |
| :--- | :--- |
| `-out:pc_info.exe` | Names the output binary. |
| `-define:RAYLIB_SHARED=false` | Statically links Raylib — no separate DLL required. |
| `-extra-linker-flags:"/FORCE:MULTIPLE"` | Suppresses duplicate symbol errors that can arise when Raylib and microui share some definitions. |

The result is a single `pc_info.exe` with no runtime dependencies. Copy it anywhere and run it.

---

## Design

The UI uses a strict 5-color palette:

| Name | Hex | Role |
| :--- | :--- | :--- |
| Onyx | `#000f08` | Dark background |
| Jet Black | `#1c3738` | Menu / card backgrounds |
| Charcoal | `#4d4847` | Muted text, borders |
| Mint Cream | `#f4fff8` | Light background, primary text in dark mode |
| Cool Steel | `#8baaad` | Accent color, buttons, RAM bar |

Full design specification is in [`design.md`](./design.md).

---

## Inspired By

- [PC-Info — Adeptstack Studios](https://github.com/Adeptstack-Studios/PC-Info) — the original C# / WPF application this project reimplements.

---

## License

MIT — see [`LICENSE`](./LICENSE) for details.
