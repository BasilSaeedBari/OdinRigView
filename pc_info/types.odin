package pc_info

// NOTE: This file is intentionally pure data:
// - No imports
// - No procedures
// - Shared structs/enums only

// View controls which content pane is displayed.
View :: enum {
	System_Info,
	Drives,
	Help,
}

// Theme controls semantic colors resolved in `ui_theme.odin`.
Theme :: enum {
	Dark,
	Light,
}

// Font_Size controls base/header point sizes for text rendering.
Font_Size :: enum {
	Small,
	Medium,
	Large,
}

// OS_Info holds Windows version and basic identity strings.
OS_Info :: struct {
	username:     string, // Windows env var: USERNAME; "N/A" if missing
	pc_name:      string, // Windows env var: COMPUTERNAME; "N/A" if missing
	os_name:      string, // Registry: HKLM\...\CurrentVersion\ProductName; e.g. "Windows 10 Pro"
	edition:      string, // Registry: HKLM\...\CurrentVersion\EditionID; e.g. "Professional"
	architecture: string, // Env var: PROCESSOR_ARCHITECTURE mapped to display; e.g. "64-bit"
}

// CPU_Info describes the primary CPU package.
CPU_Info :: struct {
	name:         string, // core:sys/info OR registry fallback: ...\CentralProcessor\0\ProcessorNameString
	core_count:   int,    // Physical cores (core:sys/info); -1 if unknown
	thread_count: int,    // Logical processors (core:sys/info); -1 if unknown
	base_clock:   f32,    // Base clock in GHz (registry "~MHz" / 1000.0); 0.0 if unknown
}

// RAM_Info describes installed/usable memory, plus live usage values.
RAM_Info :: struct {
	total_gb:      f32, // Installed physical RAM in GiB (GetPhysicallyInstalledSystemMemory); 0.0 if unknown
	usable_gb:     f32, // Usable RAM in GiB (GlobalMemoryStatusEx.ullTotalPhys); 0.0 if unknown
	reserved_mb:   f32, // Hardware Reserved in MiB = (total_gb - usable_gb) * 1024; 0.0 if unknown
	available_gb:  f32, // Available RAM in GiB (GlobalMemoryStatusEx.ullAvailPhys); refreshed ~1Hz
	in_use_gb:     f32, // In-use RAM in GiB = usable_gb - available_gb; refreshed ~1Hz
	usage_percent: f32, // Ratio 0.0–1.0 = in_use_gb / usable_gb; 0.0 if unknown
}

// GPU_Info describes the primary display adapter.
GPU_Info :: struct {
	name:    string, // DXGI adapter description (IDXGIAdapter.GetDesc); "N/A" if unknown
	vram_gb: f32,    // Dedicated VRAM in GiB (DXGI_ADAPTER_DESC.DedicatedVideoMemory); 0.0 if unknown
}

// Drive_Info describes a fixed/internal volume (e.g. C:, D:).
Drive_Info :: struct {
	letter:     string, // Drive root like "C:" (from GetLogicalDrives); "N/A" if unknown
	label:      string, // Volume label (GetVolumeInformationW); "N/A" if unknown
	format:     string, // Filesystem name (GetVolumeInformationW); e.g. "NTFS"
	drive_type: string, // "HDD" | "SSD" | "NVMe" | "N/A" (DeviceIoControl storage queries)
	total_gb:   f32,    // Total bytes converted to GiB (GetDiskFreeSpaceExW); 0.0 if unknown
	free_gb:    f32,    // Free bytes converted to GiB (GetDiskFreeSpaceExW); 0.0 if unknown
}

// MOBO_Info describes the motherboard/baseboard and firmware features.
MOBO_Info :: struct {
    manufacturer: string, // Registry: HKLM\...\BIOS\BaseBoardManufacturer; "N/A" if missing
    product:      string, // Registry: HKLM\...\BIOS\BaseBoardProduct; "N/A" if missing
    tpm_version:  string, // Registry: HKLM\...\TPM\SpecVersion; "Disabled/Missing" if unknown
    ram_slot_used:    int,    // Logical slot count; -1 if unknown (Requires WMI/SMBIOS)
	ram_slot_available: int,
}

// System_Data is the complete snapshot used by UI + clipboard formatting.
System_Data :: struct {
	os:     OS_Info,             // Collected once at startup
	cpu:    CPU_Info,            // Collected once at startup
	ram:    RAM_Info,            // Totals at startup; usage refreshed ~1Hz
	gpu:    GPU_Info,            // Collected once at startup
	mobo:   MOBO_Info,           // Collected once at startup
	drives: [dynamic]Drive_Info, // Collected once at startup; caller owns freeing the dynamic array
}

// App_State is the single app-level state container used by `main.odin`.
// It includes UI state and timing state for RAM refresh.
App_State :: struct {
	data:         System_Data, // Snapshot + live RAM fields
	current_view: View,        // Navigation target
	theme:        Theme,       // Dark/Light
	font_size:    Font_Size,   // Small/Medium/Large
	menu_open:    bool,        // Side drawer open/closed
	scroll_offset: f32,        // Vertical content scroll in pixels (+ down); 0.0 at top
	last_ram_tick: u64,        // Monotonic tick in nanoseconds (from core:time); 0 if unset
}
