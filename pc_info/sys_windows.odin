package pc_info

// Windows-specific system queries only.
// Allowed imports: vendor:directx, core:sys/info, core:sys/windows, core:os, core:fmt, core:time.

import sysinfo "core:sys/info"
import os "core:os"
import fmt "core:fmt"
import time "core:time"
import win "core:sys/windows"
import dxgi "vendor:directx/dxgi"
import "core:strings"

NA_STRING :: "N/A"

GIB_DIVISOR: f64 : f64(1024 * 1024 * 1024)
MIB_DIVISOR: f64 : f64(1024 * 1024)

bytes_to_gib_f32 :: proc(b: u64) -> f32 {
	v: f64 = f64(b) / GIB_DIVISOR
	return f32(v)
}

kb_to_gib_f32 :: proc(kb: u64) -> f32 {
	b: u64 = kb * 1024
	return bytes_to_gib_f32(b)
}

// --- UTF-8 <-> UTF-16 helpers (Win32 boundary) ---

utf8_to_wide_z :: proc(dst: []u16, s: string) -> (ok: bool) {
	// Returns a null-terminated UTF-16 string in dst.
	// dst must be large enough for converted chars + '\0'.
	if len(dst) == 0 {
		return false
	}

	needed: i32 = win.MultiByteToWideChar(win.CP_UTF8, 0, raw_data(s), i32(len(s)), nil, 0)
	if needed <= 0 {
		dst[0] = 0
		return false
	}
	if int(needed) + 1 > len(dst) {
		dst[0] = 0
		return false
	}

	written: i32 = win.MultiByteToWideChar(win.CP_UTF8, 0, raw_data(s), i32(len(s)), &dst[0], needed)
	if written != needed {
		dst[0] = 0
		return false
	}
	dst[int(needed)] = 0
	return true
}

wide_z_to_utf8 :: proc(wz: cstring16) -> (s: string, ok: bool) {
	if wz == nil {
		return "", false
	}

	// Pass -1 to include the trailing '\0' in the count.
	needed_with_nul: i32 = win.WideCharToMultiByte(win.CP_UTF8, 0, wz, -1, nil, 0, nil, nil)
	if needed_with_nul <= 0 {
		return "", false
	}

	needed: i32 = needed_with_nul - 1
	if needed <= 0 {
		return "", true
	}

	buf: []u8 = make([]u8, int(needed))
	written_with_nul: i32 = win.WideCharToMultiByte(win.CP_UTF8, 0, wz, -1, &buf[0], needed_with_nul, nil, nil)
	if written_with_nul != needed_with_nul {
		return "", false
	}

	return string(buf), true
}

// --- Missing Win32 bindings (declared locally, still isolated to this file) ---

foreign import kernel32 "system:Kernel32.lib"

@(default_calling_convention="system")
foreign kernel32 {
	GetLogicalDrives :: proc() -> u32 ---
	GetDriveTypeW :: proc(lpRootPathName: cstring16) -> u32 ---
	GetVolumeInformationW :: proc(
		lpRootPathName: cstring16,
		lpVolumeNameBuffer: cstring16,
		nVolumeNameSize: u32,
		lpVolumeSerialNumber: ^u32,
		lpMaximumComponentLength: ^u32,
		lpFileSystemFlags: ^u32,
		lpFileSystemNameBuffer: cstring16,
		nFileSystemNameSize: u32,
	) -> win.BOOL ---

	// https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getphysicallyinstalledsystemmemory
	GetPhysicallyInstalledSystemMemory :: proc(totalMemoryInKilobytes: ^u64) -> win.BOOL ---
}

// --- Registry helpers ---

reg_get_sz :: proc(hive: win.HKEY, subkey: string, value_name: string) -> (value: string, ok: bool) {
	subkey_w: [260]u16
	value_w:  [128]u16
	ok_sub: bool = utf8_to_wide_z(subkey_w[:], subkey)
	ok_val: bool = utf8_to_wide_z(value_w[:], value_name)
	if !ok_sub || !ok_val {
		return NA_STRING, false
	}

	// Value buffer in UTF-16 code units.
	buf_w: [512]u16
	buf_bytes: u32 = u32(len(buf_w) * size_of(u16))
	vtype: u32 = 0

	err: win.LSTATUS = win.RegGetValueW(
		hive,
		cast(cstring16)&subkey_w[0],
		cast(cstring16)&value_w[0],
		win.RRF_RT_REG_SZ,
		&vtype,
		&buf_w[0],
		&buf_bytes,
	)
	if u32(err) != win.ERROR_SUCCESS {
		return NA_STRING, false
	}

	s: string
	ok_s: bool
	s, ok_s = wide_z_to_utf8(cast(cstring16)&buf_w[0])
	if !ok_s {
		return NA_STRING, false
	}
	if len(s) == 0 {
		return NA_STRING, false
	}
	return s, true
}

reg_get_dword :: proc(hive: win.HKEY, subkey: string, value_name: string) -> (value: u32, ok: bool) {
	subkey_w: [260]u16
	value_w:  [128]u16
	ok_sub: bool = utf8_to_wide_z(subkey_w[:], subkey)
	ok_val: bool = utf8_to_wide_z(value_w[:], value_name)
	if !ok_sub || !ok_val {
		return 0, false
	}

	out: u32 = 0
	out_bytes: u32 = u32(size_of(u32))
	vtype: u32 = 0
	err: win.LSTATUS = win.RegGetValueW(
		hive,
		cast(cstring16)&subkey_w[0],
		cast(cstring16)&value_w[0],
		win.RRF_RT_REG_DWORD,
		&vtype,
		&out,
		&out_bytes,
	)
	if u32(err) != win.ERROR_SUCCESS {
		return 0, false
	}
	return out, true
}

// --- Public API (Windows-only) ---

get_os_info :: proc() -> OS_Info {
	info: OS_Info = {}

	username: string = NA_STRING
	pc_name: string = NA_STRING
	arch: string = NA_STRING

	env_buf: [256]u8
	env_value: string = os.get_env_buf(env_buf[:], "USERNAME")
	if len(env_value) > 0 {
		username = strings.clone(env_value);
	}

	env_value = os.get_env_buf(env_buf[:], "COMPUTERNAME")
	if len(env_value) > 0 {
		pc_name = strings.clone(env_value);
		fmt.println("Computer Name:", pc_name)
	}

	env_value = os.get_env_buf(env_buf[:], "PROCESSOR_ARCHITECTURE")
	if len(env_value) > 0 {
		// Common Windows values: "AMD64", "x86", "ARM64"
		switch env_value {
		case "AMD64":
			arch = "64-bit"
		case "x86":
			arch = "32-bit"
		case "ARM64":
			arch = "ARM64"
		case:
			arch = env_value
		}
	}

	os_name: string = NA_STRING
	edition: string = NA_STRING
	reg_value: string
	ok_reg: bool

	reg_value, ok_reg = reg_get_sz(win.HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", "ProductName")
	if ok_reg {
		os_name = reg_value
	}
	reg_value, ok_reg = reg_get_sz(win.HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", "EditionID")
	if ok_reg {
		edition = reg_value
	}

	info.username = username
	info.pc_name = pc_name
	info.os_name = os_name
	info.edition = edition
	info.architecture = arch
	return info
}

get_cpu_info :: proc() -> CPU_Info {
	out: CPU_Info = {}
	out.name = NA_STRING
	out.core_count = -1
	out.thread_count = -1
	out.base_clock = 0.0

	cpu_name: string = sysinfo.cpu_name()
	if len(cpu_name) > 0 {
		out.name = cpu_name
	}

	physical: int = 0
	logical: int = 0
	ok_counts: bool = false
	physical, logical, ok_counts = sysinfo.cpu_core_count()
	if ok_counts {
		out.core_count = physical
		out.thread_count = logical
	}

	// Registry fallback for name and base clock.
	reg_name: string
	ok_name: bool
	reg_name, ok_name = reg_get_sz(win.HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", "ProcessorNameString")
	if ok_name && reg_name != NA_STRING {
		out.name = reg_name
	}

	mhz: u32
	ok_mhz: bool
	mhz, ok_mhz = reg_get_dword(win.HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", "~MHz")
	if ok_mhz && mhz > 0 {
		out.base_clock = f32(f64(mhz) / 1000.0)
	}

	return out
}

get_ram_info :: proc() -> RAM_Info {
	out: RAM_Info = {}
	out.total_gb = 0.0
	out.usable_gb = 0.0
	out.reserved_mb = 0.0
	out.available_gb = 0.0
	out.in_use_gb = 0.0
	out.usage_percent = 0.0

	installed_kb: u64 = 0
	ok_installed: win.BOOL = GetPhysicallyInstalledSystemMemory(&installed_kb)
	if ok_installed != win.FALSE && installed_kb > 0 {
		out.total_gb = kb_to_gib_f32(installed_kb)
	}

	ms: win.MEMORYSTATUSEX = {}
	ms.dwLength = u32(size_of(win.MEMORYSTATUSEX))
	ok_ms: win.BOOL = win.GlobalMemoryStatusEx(&ms)
	if ok_ms != win.FALSE {
		out.usable_gb = bytes_to_gib_f32(ms.ullTotalPhys)
		out.available_gb = bytes_to_gib_f32(ms.ullAvailPhys)
		out.in_use_gb = out.usable_gb - out.available_gb
		if out.in_use_gb < 0.0 {
			out.in_use_gb = 0.0
		}
		if out.usable_gb > 0.0 {
			out.usage_percent = out.in_use_gb / out.usable_gb
			if out.usage_percent < 0.0 {
				out.usage_percent = 0.0
			}
			if out.usage_percent > 1.0 {
				out.usage_percent = 1.0
			}
		}
	}

	// Hardware reserved in MiB (derived).
	if out.total_gb > 0.0 && out.usable_gb > 0.0 && out.total_gb >= out.usable_gb {
		reserved_gb: f32 = out.total_gb - out.usable_gb
		out.reserved_mb = reserved_gb * 1024.0
	}

	return out
}

get_gpu_info :: proc() -> GPU_Info {
	out: GPU_Info = {}
	out.name = NA_STRING
	out.vram_gb = 0.0

	// Preferred path: DXGI adapter 0.
	factory_raw: rawptr = nil
	hr: win.HRESULT = dxgi.CreateDXGIFactory1(dxgi.IFactory1_UUID, &factory_raw)
	if win.FAILED(hr) || factory_raw == nil {
		return out
	}
	factory: ^dxgi.IFactory1 = cast(^dxgi.IFactory1)factory_raw

	adapter: ^dxgi.IAdapter1 = nil
	hr = factory.EnumAdapters1(factory, 0, &adapter)
	if win.FAILED(hr) || adapter == nil {
		return out
	}

	desc: dxgi.ADAPTER_DESC1 = {}
	hr = adapter.GetDesc1(adapter, &desc)
	if win.FAILED(hr) {
		return out
	}

	// Description is a UTF-16 fixed array.
	name: string
	ok_name: bool
	name, ok_name = wide_z_to_utf8(cast(cstring16)&desc.Description[0])
	if ok_name && len(name) > 0 {
		out.name = name
	}

	out.vram_gb = bytes_to_gib_f32(u64(desc.DedicatedVideoMemory))
	return out
}

// --- Drive helpers (SSD/HDD heuristic) ---

drive_root_w :: proc(letter: u8) -> (root: [4]u16, ok: bool) {
	// Produces "C:\\" as UTF-16 null-terminated.
	if letter < 'A' || letter > 'Z' {
		return [4]u16{}, false
	}
	r: [4]u16 = {}
	r[0] = u16(letter)
	r[1] = u16(':')
	r[2] = u16('\\')
	r[3] = 0
	return r, true
}

drive_device_path_w :: proc(letter: u8) -> (path: [8]u16, ok: bool) {
	// Produces "\\\\.\\C:" as UTF-16 null-terminated.
	if letter < 'A' || letter > 'Z' {
		return [8]u16{}, false
	}
	p: [8]u16 = {}
	p[0] = u16('\\')
	p[1] = u16('\\')
	p[2] = u16('.')
	p[3] = u16('\\')
	p[4] = u16(letter)
	p[5] = u16(':')
	p[6] = 0
	p[7] = 0
	return p, true
}

get_drive_kind_string :: proc(letter: u8) -> string {
	// Returns "HDD" or "SSD" based on seek penalty property; "N/A" if unknown.
	path: [8]u16
	ok_path: bool
	path, ok_path = drive_device_path_w(letter)
	if !ok_path {
		return NA_STRING
	}

	handle: win.HANDLE = win.CreateFileW(
		cast(cstring16)&path[0],
		win.GENERIC_READ,
		win.FILE_SHARE_READ | win.FILE_SHARE_WRITE,
		nil,
		win.OPEN_EXISTING,
		0,
		nil,
	)
	if handle == win.INVALID_HANDLE_VALUE {
		return NA_STRING
	}
	defer win.CloseHandle(handle)

	// Minimal storage-query structs/constants (not exposed by `core:sys/windows` yet).
	STORAGE_PROPERTY_QUERY :: struct {
		PropertyId: u32,
		QueryType:  u32,
		AdditionalParameters: [1]u8,
	}
	DEVICE_SEEK_PENALTY_DESCRIPTOR :: struct {
		Version: u32,
		Size:    u32,
		IncursSeekPenalty: win.BOOL,
	}
	StorageDeviceSeekPenaltyProperty: u32 : 7
	PropertyStandardQuery: u32 : 0
	// CTL_CODE(IOCTL_STORAGE_BASE=0x2D, 0x500, METHOD_BUFFERED=0, FILE_ANY_ACCESS=0)
	IOCTL_STORAGE_QUERY_PROPERTY: u32 : (0x2D << 16) | (0 << 14) | (0x500 << 2) | 0

	query: STORAGE_PROPERTY_QUERY = {}
	query.PropertyId = StorageDeviceSeekPenaltyProperty
	query.QueryType = PropertyStandardQuery

	desc: DEVICE_SEEK_PENALTY_DESCRIPTOR = {}
	returned: u32 = 0

	ok_ioctl: win.BOOL = win.DeviceIoControl(
		handle,
		IOCTL_STORAGE_QUERY_PROPERTY,
		&query,
		u32(size_of(STORAGE_PROPERTY_QUERY)),
		&desc,
		u32(size_of(DEVICE_SEEK_PENALTY_DESCRIPTOR)),
		&returned,
		nil,
	)
	if ok_ioctl == win.FALSE {
		return NA_STRING
	}

	if desc.IncursSeekPenalty != win.FALSE {
		return "HDD"
	}
	return "SSD"
}

get_drive_infos :: proc() -> [dynamic]Drive_Info {
	out: [dynamic]Drive_Info = nil

	mask: u32 = GetLogicalDrives()
	if mask == 0 {
		return out
	}

	letter: u8
	for letter = 'A'; letter <= 'Z'; letter += 1 {
		bit_index: u32 = u32(letter - 'A')
		if (mask & (1 << bit_index)) == 0 {
			continue
		}

		root_w: [4]u16
		ok_root: bool
		root_w, ok_root = drive_root_w(letter)
		if !ok_root {
			continue
		}

		DRIVE_FIXED :: u32(3)
		dtype: u32 = GetDriveTypeW(cast(cstring16)&root_w[0])
		if dtype != DRIVE_FIXED {
			continue
		}

		di: Drive_Info = {}
		di.letter = fmt.tprintf("%c:", letter)
		di.label = NA_STRING
		di.format = NA_STRING
		di.drive_type = NA_STRING
		di.total_gb = 0.0
		di.free_gb = 0.0

		vol_name: [256]u16
		fs_name: [64]u16
		serial: u32 = 0
		max_comp_len: u32 = 0
		fs_flags: u32 = 0

		ok_vol: win.BOOL = GetVolumeInformationW(
			cast(cstring16)&root_w[0],
			cast(cstring16)&vol_name[0],
			u32(len(vol_name)),
			&serial,
			&max_comp_len,
			&fs_flags,
			cast(cstring16)&fs_name[0],
			u32(len(fs_name)),
		)
		if ok_vol != win.FALSE {
			s: string
			ok_s: bool

			s, ok_s = wide_z_to_utf8(cast(cstring16)&vol_name[0])
			if ok_s && len(s) > 0 {
				di.label = s
			}

			s, ok_s = wide_z_to_utf8(cast(cstring16)&fs_name[0])
			if ok_s && len(s) > 0 {
				di.format = s
			}
		}

		free_bytes_avail: win.ULARGE_INTEGER = {}
		total_bytes:      win.ULARGE_INTEGER = {}
		total_free_bytes: win.ULARGE_INTEGER = {}
		ok_space: win.BOOL = win.GetDiskFreeSpaceExW(
			cast(cstring16)&root_w[0],
			&free_bytes_avail,
			&total_bytes,
			&total_free_bytes,
		)
		if ok_space != win.FALSE {
			di.total_gb = bytes_to_gib_f32(u64(total_bytes))
			di.free_gb = bytes_to_gib_f32(u64(total_free_bytes))
		}

		di.drive_type = get_drive_kind_string(letter)

		append(&out, di)
	}

	return out
}

// --- Clipboard + Shell helpers (Windows-only) ---

set_clipboard_text_utf8 :: proc(text: string) -> bool {
	// Copies UTF-8 text into the Windows clipboard as CF_UNICODETEXT.
	if len(text) == 0 {
		return false
	}

	ok_open: win.BOOL = win.OpenClipboard(nil)
	if ok_open == win.FALSE {
		return false
	}
	defer win.CloseClipboard()

	_ = win.EmptyClipboard()

	needed: i32 = win.MultiByteToWideChar(win.CP_UTF8, 0, raw_data(text), i32(len(text)), nil, 0)
	if needed <= 0 {
		return false
	}

	// +1 for null terminator.
	wchar_count: int = int(needed) + 1
	bytes: win.SIZE_T = win.SIZE_T(wchar_count * size_of(u16))

	hmem_ptr: win.LPVOID = win.GlobalAlloc(win.GMEM_MOVEABLE, bytes)
	if hmem_ptr == nil {
		return false
	}

	hmem: win.HGLOBAL = cast(win.HGLOBAL)hmem_ptr
	mem: win.LPVOID = win.GlobalLock(hmem)
	if mem == nil {
		_ = win.GlobalFree(hmem_ptr)
		return false
	}

	wbuf: [^]u16 = cast([^]u16)mem
	written: i32 = win.MultiByteToWideChar(win.CP_UTF8, 0, raw_data(text), i32(len(text)), cast(^u16)wbuf, needed)
	wbuf[int(needed)] = 0

	_ = win.GlobalUnlock(hmem)

	if written != needed {
		_ = win.GlobalFree(hmem_ptr)
		return false
	}

	set: win.HANDLE = win.SetClipboardData(win.CF_UNICODETEXT, cast(win.HANDLE)hmem)
	if set == nil {
		_ = win.GlobalFree(hmem_ptr)
		return false
	}

	// On success, clipboard owns the memory handle.
	return true
}

shell_open_url :: proc(url: string) -> bool {
	// Opens a URL in the default browser using ShellExecuteW.
	if len(url) == 0 {
		return false
	}

	url_w: [512]u16
	ok_w: bool = utf8_to_wide_z(url_w[:], url)
	if !ok_w {
		return false
	}

	operation_w: [8]u16
	_ = utf8_to_wide_z(operation_w[:], "open")

	hinst: win.HINSTANCE = win.ShellExecuteW(nil, cast(cstring16)&operation_w[0], cast(cstring16)&url_w[0], nil, nil, 1)
	// Per docs: values <= 32 indicate error.
	return uintptr(hinst) > 32
}

