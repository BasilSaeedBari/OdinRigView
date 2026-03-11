package pc_info

// Platform-neutral orchestration of system data collection.
// This file must not import any Windows-specific packages.

collect_static_system_data :: proc() -> System_Data {
	out: System_Data = {}

	out.os = get_os_info()
	out.cpu = get_cpu_info()
	out.gpu = get_gpu_info()
	out.drives = get_drive_infos()

	// RAM: take a full snapshot at startup.
	out.ram = get_ram_info()

	return out
}

refresh_ram_usage :: proc(ram: ^RAM_Info) {
	if ram == nil {
		return
	}

	latest: RAM_Info = get_ram_info()

	// Preserve installed totals if we already have them, but accept better values if found.
	if ram.total_gb <= 0.0 && latest.total_gb > 0.0 {
		ram.total_gb = latest.total_gb
	}
	if ram.usable_gb <= 0.0 && latest.usable_gb > 0.0 {
		ram.usable_gb = latest.usable_gb
	}
	if ram.reserved_mb <= 0.0 && latest.reserved_mb > 0.0 {
		ram.reserved_mb = latest.reserved_mb
	}

	ram.available_gb = latest.available_gb
	ram.in_use_gb = latest.in_use_gb
	ram.usage_percent = latest.usage_percent
}
