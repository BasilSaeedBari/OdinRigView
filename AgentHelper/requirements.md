# Product Requirements Document (PRD)
**Project Name:** PC Seller System Info App
**Implementation Language:** Odin
**Target Platform:** Windows (x86_64), compiled natively
**Target Audience:** Non-technical PC owners who want to quickly read and share their system specs when listing a computer for sale.

---

## 1. Overview

This application reads the host computer's hardware and software information and presents it in a clean, easy-to-read UI. It removes the need for users to navigate Windows Settings, Task Manager, Device Manager, or BIOS. A buyer should be able to get every spec they need from a single screenshot or a single paste.

The reference implementation (C# / .NET WPF) is located at:
https://github.com/Adeptstack-Studios/PC-Info/tree/main/PC_Component_Info

Your implementation in Odin must replicate its functionality — not its architecture.

---

## 2. Core Data to Collect & Display

All data collection procedures live in `sysinfo.odin` (cross-platform) and `sys_windows.odin` (Windows-specific).
All data is stored in the `System_Data` struct defined in `types.odin` (see `memory.md`).

### A. General System Information — `System_Data.os`, `.cpu`, `.ram`, `.gpu`

#### Operating System — `OS_Info`

| Field | Source | Notes |
| :--- | :--- | :--- |
| `username` | `os.get_env("USERNAME")` | Windows env var |
| `pc_name` | `os.get_env("COMPUTERNAME")` | Windows env var |
| `os_name` | Registry: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion` → `ProductName` | e.g., `Windows 10 Pro` |
| `edition` | Same registry key → `EditionID` | |
| `architecture` | `os.get_env("PROCESSOR_ARCHITECTURE")` | e.g., `AMD64` → display as `64-bit` |

#### Processor (CPU) — `CPU_Info`

| Field | Source | Notes |
| :--- | :--- | :--- |
| `name` | `core:sys/info` CPU info OR Registry: `HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0` → `ProcessorNameString` | Full name, e.g., `AMD Ryzen 5 2600 Six-Core Processor` |
| `core_count` | `core:sys/info` | Physical cores |
| `thread_count` | `core:sys/info` | Logical processors |
| `base_clock` | Registry key above → `~MHz` | Stored as MHz; convert to GHz for display |

#### Memory (RAM) — `RAM_Info`

| Field | Source | Notes |
| :--- | :--- | :--- |
| `total_gb` | SMBIOS / registry total physical RAM | Use `GetPhysicallyInstalledSystemMemory` Win32 call |
| `usable_gb` | `GlobalMemoryStatusEx` → `ullTotalPhys` | What Windows can actually address |
| `reserved_mb` | `total_gb` – `usable_gb` | Computed field |
| `available_gb` | `GlobalMemoryStatusEx` → `ullAvailPhys` | Refreshed every ~1 second |
| `in_use_gb` | `usable_gb` – `available_gb` | Computed field |
| `usage_percent` | `in_use_gb / usable_gb` | Float 0.0–1.0; drives the progress bar |

> **Live updates:** `available_gb`, `in_use_gb`, and `usage_percent` must refresh every 1 second.
> Use a `last_ram_tick: time.Time` field in `App_State` and check elapsed time each frame.

#### Graphics Card (GPU) — `GPU_Info`

| Field | Source | Notes |
| :--- | :--- | :--- |
| `name` | DXGI: `IDXGIAdapter.GetDesc()` → `Description` | Use `vendor:directx`. Prefer first adapter (index 0). |
| `vram_gb` | DXGI: `DXGI_ADAPTER_DESC.DedicatedVideoMemory` | Convert bytes → GB (divide by `1024^3`) |

> Implement in `sys_windows.odin` as `get_gpu_info() -> GPU_Info`.

---

### B. Storage Drives — `[dynamic]Drive_Info`

Enumerate all fixed internal drives. Ignore optical drives, network drives, and removable USB storage unless labeled as internal.

| Field | Source | Notes |
| :--- | :--- | :--- |
| `letter` | `GetLogicalDrives` + `GetDriveTypeW` | e.g., `C:` |
| `label` | `GetVolumeInformationW` → `lpVolumeNameBuffer` | e.g., `Windows` |
| `format` | `GetVolumeInformationW` → `lpFileSystemNameBuffer` | e.g., `NTFS`, `exFAT` |
| `drive_type` | `DeviceIoControl` → `IOCTL_STORAGE_QUERY_PROPERTY` → `StorageDeviceSeekPenaltyProperty` | `"HDD"` if seek penalty = TRUE, `"SSD"` or `"NVMe"` otherwise. Check protocol type for NVMe distinction. |
| `total_gb` | `GetDiskFreeSpaceExW` → `lpTotalNumberOfBytes` | Convert bytes → GB |
| `free_gb` | `GetDiskFreeSpaceExW` → `lpTotalNumberOfFreeBytes` | Convert bytes → GB |

> Implement drive enumeration in `sys_windows.odin` as `get_drive_infos() -> [dynamic]Drive_Info`.
> Free the dynamic array when the app closes.

---

## 3. Core Functionality & Action Buttons

Four action buttons are always visible in the top bar (see `design.md` §6). They are represented as a bitmask or separate bool fields in `App_State` if they have toggle state.

### 3.1 Copy to Clipboard
- **What it copies:** A plain-text summary of all static hardware fields — OS, CPU, RAM totals, GPU, and all drives.
- **Format:** Clean, human-readable, ready to paste into a marketplace listing. Example:

```
PC Specifications
=================
OS:           Windows 10 Pro (64-bit)
Computer:     DESKTOP-ABC123 / JohnDoe

Processor:    AMD Ryzen 5 2600 Six-Core Processor
Cores/Threads: 6 / 12
Base Clock:   3.40 GHz

RAM:          16.0 GB Total  |  15.7 GB Usable
              Hardware Reserved: 256 MB

GPU:          NVIDIA GeForce GTX 1050 Ti
VRAM:         4.0 GB

Drives:
  C: (Windows)  —  NTFS  |  SSD  |  Total: 476.9 GB  |  Free: 210.4 GB
  D: (Data)     —  NTFS  |  HDD  |  Total: 931.5 GB  |  Free: 450.2 GB
```

- **Implementation:** Build the string using `core:fmt` (`fmt.sbprintf` into a `strings.Builder`). Write to clipboard using Win32 `SetClipboardData(CF_UNICODETEXT, ...)`. Implement in `clipboard.odin`.

### 3.2 Take Screenshot
- Captures the application window only (not the desktop).
- Use `rl.LoadImageFromScreen()` to get the framebuffer.
- Save to `%TEMP%\pc_info_screenshot.png` using `rl.ExportImage()`.
- Optionally also copy raw pixel data to clipboard using Win32 `SetClipboardData(CF_BITMAP, ...)`.
- Implement in `clipboard.odin` as `take_screenshot(state: ^App_State)`.

### 3.3 Font Size Toggle
- Cycles through three states: `.Small` → `.Medium` → `.Large` → `.Small`.
- On each cycle: update `App_State.font_size`, then reload the raylib font at the new point size.
- All text rendering reads from `App_State.font_size` every frame via `get_font_base()` / `get_font_header()` (see `design.md` §5).

### 3.4 Theme Toggle
- Switches between `Theme.Dark` and `Theme.Light`.
- On toggle: flip `App_State.theme`.
- All color rendering calls `get_theme_colors(state.theme)` every frame — no other state change needed.

---

## 4. Navigation & Views

Navigation is driven by `App_State.current_view`, an enum with three values.

```odin
View :: enum {
    System_Info,
    Drives,
    Help,
}
```

### Side Drawer Menu
- Opened and closed via the hamburger button in the top bar.
- Controlled by `App_State.menu_open: bool`.
- Clicking a nav item sets `current_view` and closes the menu.

### View 1: System Information (`View.System_Info`)
- Displays `OS_Info`, `CPU_Info`, `RAM_Info`, `GPU_Info`.
- RAM progress bar reflects live `usage_percent`.
- See `design.md` §4 View 1 for full layout spec.

### View 2: Drives (`View.Drives`)
- Iterates over `System_Data.drives` and renders one card per drive.
- See `design.md` §4 View 2 for card spec.

### View 3: Help & Info (`View.Help`)
- Static content: app name, version, short description.
- Three action buttons that open URLs in the default browser:
  - **Changelog:** `https://github.com/Adeptstack-Studios/PC-Info/releases`
  - **Update:** `https://github.com/Adeptstack-Studios/PC-Info/releases/latest`
  - **Website:** *(creator portfolio URL — set as a constant in `main.odin`)*
- Open URLs using `ShellExecuteW` from `core:sys/windows`.
- See `design.md` §4 View 3 for layout spec.

---

## 5. Non-Functional Requirements

| Requirement | Detail |
| :--- | :--- |
| **Startup time** | All static hardware data (OS, CPU, GPU, Drives) collected once at launch. RAM refreshed every 1 second. |
| **Memory** | No unnecessary allocations in the render loop. All persistent strings allocated once at startup. |
| **Window** | Resizable. Minimum size: 640×480. Content scrolls vertically rather than clipping. |
| **No installer** | Single `.exe` output. No DLLs required beyond system-provided ones (raylib statically linked). |
| **No network** | The app does not make any network requests. The Help page buttons open URLs in the OS browser. |
| **Error resilience** | If a hardware query fails, display `"N/A"` for that field. Never crash on missing data. |
| **Unicode** | All strings handled as UTF-8 internally. Win32 calls use the `W` (wide) variants, converted at the boundary. |

---

## 6. Out of Scope (v1.0)

- Linux / macOS support (architecture is prepared for it, but not implemented).
- Auto-update logic (the Update button only opens a browser link).
- Temperature / fan speed monitoring.
- Network adapter info.
- Motherboard / BIOS info.
