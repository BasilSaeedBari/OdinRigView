# Memory — Odin PC Info App

This file is your long-term reference. Read it at the start of every session before writing any code.
It contains documentation anchors, API notes, known pitfalls, and project-specific conventions.

---

## 1. Official Documentation Links

| Resource | URL |
| :--- | :--- |
| Odin Language Overview | https://odin-lang.org/ |
| Odin Language Docs | https://odin-lang.org/docs/ |
| Built-in Package Index | https://pkg.odin-lang.org/ |
| `core:sys/info` | https://pkg.odin-lang.org/core/sys/info/ |
| `core:sys/windows` | https://pkg.odin-lang.org/core/sys/windows/ |
| `core:os` | https://pkg.odin-lang.org/core/os/ |
| `core:fmt` | https://pkg.odin-lang.org/core/fmt/ |
| `core:time` | https://pkg.odin-lang.org/core/time/ |
| `vendor:raylib` | https://pkg.odin-lang.org/vendor/raylib/ |
| `vendor:microui` | https://pkg.odin-lang.org/vendor/microui/ |
| `vendor:directx` | https://pkg.odin-lang.org/vendor/directx/ |
| PC-Info Reference Repo | https://github.com/Adeptstack-Studios/PC-Info/tree/main/PC_Component_Info |

---

## 2. Package Usage Notes

### `core:sys/info`
- Provides cross-platform hardware info: CPU name, core/thread count, RAM totals.
- Key procedures to know:
  - `sys_info.get_cpu_info()` — returns `CPU_Info` struct.
  - `sys_info.get_ram_info()` — returns total and available RAM in bytes.
- **Limitation:** Does not provide GPU VRAM or drive type (SSD vs HDD). These require Windows-specific calls.

### `core:sys/windows`
- Direct access to Win32 API types and procedures.
- Used for: WMI queries, drive type detection, hardware-reserved RAM, GPU info fallback.
- Always isolate this in `sys_windows.odin`. Never scatter Win32 calls across other files.
- WMI queries use COM — initialize with `CoInitializeEx` before use, release with `CoUninitialize`.

### `vendor:directx` (DXGI)
- Use `IDXGIFactory` → `EnumAdapters` → `GetDesc` to retrieve GPU name and VRAM.
- `DXGI_ADAPTER_DESC.DedicatedVideoMemory` gives VRAM in bytes.
- This is the preferred method over WMI for GPU data — faster and more reliable.
- Wrap in a `get_gpu_info()` procedure inside `sys_windows.odin`.

### `vendor:raylib`
- Handles window creation, rendering loop, input, and font rendering.
- Always call `rl.InitWindow(width, height, title)` then `rl.SetTargetFPS(fps)` at startup.
- Use `rl.BeginDrawing()` / `rl.EndDrawing()` every frame.
- Font scaling: load font once at startup, pass scale factor to draw calls.

### `vendor:microui`
- Immediate-mode UI library — pairs naturally with raylib for rendering.
- Every frame: call `mu.begin()`, build your UI commands, call `mu.end()`, then render with raylib.
- No retained state — all UI state is rebuilt from application data each frame. This is a feature.
- Use `mu.layout_row` for columnar layouts (label + value pairs).

---

## 3. Project File Structure (Planned)

```
pc_info/
├── main.odin           // Entry point, window init, main loop
├── sysinfo.odin        // Platform-neutral data collection (uses core:sys/info)
├── sys_windows.odin    // Windows-specific: WMI, DXGI, drive type queries
├── ui.odin             // microui layout and rendering logic
├── ui_theme.odin       // Color palette constants, font size constants, theme state
├── clipboard.odin      // Copy-to-clipboard and screenshot logic
└── types.odin          // Shared struct definitions (SystemData, DriveInfo, etc.)
```

---

## 4. Core Data Structs (Reference)

Define these in `types.odin`. Keep them flat.

```odin
OS_Info :: struct {
    username:      string,
    pc_name:       string,
    os_name:       string,
    edition:       string,
    architecture:  string,
}

CPU_Info :: struct {
    name:         string,
    core_count:   int,
    thread_count: int,
    base_clock:   f32,   // GHz
}

RAM_Info :: struct {
    total_gb:        f32,
    usable_gb:       f32,
    reserved_mb:     f32,
    available_gb:    f32,
    in_use_gb:       f32,
    usage_percent:   f32,  // 0.0 – 1.0, for progress bar
}

GPU_Info :: struct {
    name:     string,
    vram_gb:  f32,
}

Drive_Info :: struct {
    letter:      string,
    label:       string,
    format:      string,
    drive_type:  string,  // "SSD", "NVMe", "HDD"
    total_gb:    f32,
    free_gb:     f32,
}

System_Data :: struct {
    os:     OS_Info,
    cpu:    CPU_Info,
    ram:    RAM_Info,
    gpu:    GPU_Info,
    drives: [dynamic]Drive_Info,
}
```

---

## 5. Known Gotchas & Constraints

### Explicit Types — Always
Odin infers types with `:=`. **Do not use it.** Always write:
```odin
x: int = 5
label: string = "Hello"
```
This is a project-wide non-negotiable rule for readability.

### String Memory in Odin
- Odin strings are not null-terminated by default. When passing to C APIs (raylib, Win32), use `strings.clone_to_cstring()` and free after use.
- Never assume a `string` returned from a Windows API survives past the current frame without cloning.

### RAM Values from Windows
- `GlobalMemoryStatusEx` returns `MEMORYSTATUSEX` — use `ullTotalPhys` and `ullAvailPhys`.
- Hardware Reserved = `TotalPhys` (from SMBIOS/registry) minus `ullTotalPhys`.
- Refresh RAM usage stats every ~1 second (use `core:time` delta accumulation).

### Drive Type Detection
- `GetDriveTypeW` gives "fixed", "removable", etc. — not SSD vs HDD.
- To distinguish SSD/NVMe from HDD: use `DeviceIoControl` with `IOCTL_STORAGE_QUERY_PROPERTY` → `StorageDeviceSeekPenaltyProperty`. If `IncursSeekPenalty == FALSE` → SSD/NVMe.
- For NVMe specifically: check `StorageAdapterProtocolSpecificData` for NVMe protocol type.

### Screenshot
- Use raylib's `rl.TakeScreenshot(filename)` OR capture via `rl.LoadImageFromScreen()` and copy pixels to clipboard using Win32 `SetClipboardData`.
- Save to a temp path in `os.get_env("TEMP")` if writing to disk.

### Copy to Clipboard (Text)
- Use Win32: `OpenClipboard(nil)` → `EmptyClipboard()` → `SetClipboardData(CF_UNICODETEXT, hMem)` → `CloseClipboard()`.
- Format the text cleanly for marketplace listings (see `requirements.md` for exact fields).

### Font Rendering in Raylib
- Load a system font with `rl.LoadFontEx("C:/Windows/Fonts/segoeui.ttf", base_size, nil, 0)`.
- Store as a global in `ui.odin`. Reload only when font size changes.
- Three sizes: Small (12px base), Medium (14px base), Large (18px base). See `design.md`.

---

## 6. Application State (Single Global)

Keep one `App_State` struct in `main.odin`:

```odin
App_State :: struct {
    data:          System_Data,
    current_view:  View,          // enum: .System_Info, .Drives, .Help
    theme:         Theme,         // enum: .Dark, .Light
    font_size:     Font_Size,     // enum: .Small, .Medium, .Large
    menu_open:     bool,
    last_ram_tick: time.Time,
}
```

Pass pointers to procedures rather than using globals everywhere.

---

## 7. UI Layout Quick-Reference (microui)

```
Frame
└── Top Bar (fixed height)
    ├── Hamburger button [left]
    ├── Page title text [center]
    └── Action buttons: Copy | Screenshot | FontSize | Theme [right]
└── Side Drawer (conditional, ~60% width, slides from left)
    ├── Nav item: System Information
    ├── Nav item: Drives
    ├── Nav item: Help & Info
    └── Close Menu button [bottom]
└── Content Area (remaining width/height)
    ├── View: System Information
    ├── View: Drives (card per drive)
    └── View: Help & Info
```

---

## 8. Version & Build Info

| Key | Value |
| :--- | :--- |
| App Name | PC Seller System Info |
| Version | 1.0.0 |
| Target Platform | Windows (x86_64) |
| Odin Compiler | Latest stable |
| Build command | `odin build . -out:pc_info.exe` |

