package pc_info

import os "core:os"
import fmt "core:fmt"
// Justification: formatting large multi-line text requires a Builder; raylib needs `cstring` paths.
import strings "core:strings"
import rl "vendor:raylib"

CHANGELOG_URL :: "https://github.com/BasilSaeedBari/OdinRigView/releases"
UPDATE_URL    :: "https://github.com/BasilSaeedBari/OdinRigView/releases/latest"
WEBSITE_URL   :: "https://github.com/BasilSaeedBari/OdinRigView"

format_specs_text :: proc(data: System_Data) -> string {
	sb: strings.Builder = strings.builder_make()

	strings.write_string(&sb, "PC Specifications\n")
	strings.write_string(&sb, "=================\n")

	_ = fmt.sbprintf(&sb, "OS:            %s (%s)\n", data.os.os_name, data.os.architecture)
	_ = fmt.sbprintf(&sb, "Computer:      %s / %s\n", data.os.pc_name, data.os.username)
	strings.write_string(&sb, "\n")

	_ = fmt.sbprintf(&sb, "Processor:     %s\n", data.cpu.name)
	_ = fmt.sbprintf(&sb, "Cores/Threads: %d / %d\n", data.cpu.core_count, data.cpu.thread_count)
	_ = fmt.sbprintf(&sb, "Base Clock:    %.2f GHz\n", data.cpu.base_clock)
	strings.write_string(&sb, "\n")

	_ = fmt.sbprintf(&sb, "RAM:           %.1f GB Total  |  %.1f GB Usable\n", data.ram.total_gb, data.ram.usable_gb)
	_ = fmt.sbprintf(&sb, "               Hardware Reserved: %.0f MB\n", data.ram.reserved_mb)
	strings.write_string(&sb, "\n")

	_ = fmt.sbprintf(&sb, "GPU:           %s\n", data.gpu.name)
	_ = fmt.sbprintf(&sb, "VRAM:          %.1f GB\n", data.gpu.vram_gb)
	strings.write_string(&sb, "\n")

	strings.write_string(&sb, "Drives:\n")
	i: int
	for i = 0; i < len(data.drives); i += 1 {
		d: Drive_Info = data.drives[i]
		_ = fmt.sbprintf(&sb, "  %s (%s)  —  %s  |  %s  |  Total: %.1f GB  |  Free: %.1f GB\n",
			d.letter, d.label, d.format, d.drive_type, d.total_gb, d.free_gb)
	}

	return strings.to_string(sb)
}

copy_specs_to_clipboard :: proc(data: System_Data) -> bool {
    // 1. Build the string using the temp_allocator
    // This memory is automatically managed and won't leak
    text := format_specs_text(data)
	fmt.printfln(text)
    defer delete(text) // Clean up the string returned by format_specs_text

    if len(text) == 0 do return false

    // 2. Raylib requires a null-terminated C-string (cstring)
    // We clone it to a cstring using the temp_allocator for safety
    cstr := strings.clone_to_cstring(text, context.temp_allocator)
    
    // 3. Hand it off to Raylib
    rl.SetClipboardText(cstr)
    
    return true
}

open_url_changelog :: proc() -> bool {
	return shell_open_url(CHANGELOG_URL)
}

open_url_update :: proc() -> bool {
	return shell_open_url(UPDATE_URL)
}

open_url_website :: proc() -> bool {
	return shell_open_url(WEBSITE_URL)
}

