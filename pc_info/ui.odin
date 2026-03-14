package pc_info

import fmt "core:fmt"
import strings "core:strings"
import rl "vendor:raylib"

UI_Action :: enum {
	None,
	Copy,
	Toggle_Font,
	Toggle_Theme,
	Nav_System,
	Nav_Drives,
	Nav_Help,
	Close_Menu,
	Open_Changelog,
	Open_Update,
	Open_Website,
}

UI_Result :: struct {
	actions:      [16]UI_Action,
	action_count: int,
}

ui_push_action :: proc(r: ^UI_Result, a: UI_Action) {
	if r == nil || r.action_count >= len(r.actions) {
		return
	}
	r.actions[r.action_count] = a
	r.action_count += 1
}

ui_mouse_in_rect :: proc(x: f32, y: f32, w: f32, h: f32) -> bool {
	m := rl.GetMousePosition()
	return m.x >= x && m.x <= x+w && m.y >= y && m.y <= y+h
}

// ── Low-level helpers: take rl.Font directly, never ^Font_Atlas ──────────────

ui_measure_text_w :: proc(font: rl.Font, s: string, font_size: i32) -> i32 {
	cs := strings.clone_to_cstring(s)
	defer delete(cs)
	return i32(rl.MeasureTextEx(font, cs, f32(font_size), 0).x)
}

ui_draw_text :: proc(font: rl.Font, s: string, pos: rl.Vector2, font_size: i32, tint: rl.Color) {
	cs := strings.clone_to_cstring(s)
	defer delete(cs)
	rl.DrawTextEx(font, cs, pos, f32(font_size), 0, tint)
}

ui_button :: proc(x: f32, y: f32, w: f32, h: f32, label: string, font: rl.Font, font_size: i32, colors: Theme_Colors) -> bool {
	hover   := ui_mouse_in_rect(x, y, w, h)
	clicked := hover && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)

	bg := colors.bg_menu
	if hover { bg = colors.accent }
	rl.DrawRectangle(i32(x), i32(y), i32(w), i32(h), bg)

	tw := ui_measure_text_w(font, label, font_size)
	th := font_size + 2
	tx := i32(x) + (i32(w)-tw)/2
	ty := i32(y) + (i32(h)-th)/2

	tcol := colors.text_primary
	if hover { tcol = colors.accent_text }
	ui_draw_text(font, label, rl.Vector2{f32(tx), f32(ty)}, font_size, tcol)

	return clicked
}

ui_text_kv :: proc(x: f32, y: f32, label: string, value: string, font: rl.Font, base_size: i32, colors: Theme_Colors, value_x: f32) -> f32 {
	ui_draw_text(font, label, rl.Vector2{x, y}, base_size, colors.text_secondary)
	ui_draw_text(font, value, rl.Vector2{value_x, y}, base_size, colors.text_primary)
	return y + f32(base_size) + 6
}

// ── Draw procedures: receive ^Font_Atlas, resolve rl.Font upfront ─────────────

ui_draw_top_bar :: proc(state: ^App_State, fa: ^Font_Atlas, colors: Theme_Colors, w: i32, result: ^UI_Result) {
	bar_h: f32 = 48
	rl.DrawRectangle(0, 0, w, i32(bar_h), colors.bg_menu)

	body_font, base_size   := font_get_body(fa, state.font_size)
	hdr_font,  header_size := font_get_header(fa, state.font_size)

	if ui_button(8, 4, 40, 40, "≡", hdr_font, header_size, colors) {
		state.menu_open = !state.menu_open
	}

	title := "System Information"
	switch state.current_view {
	case .System_Info: title = "System Information"
	case .Drives:      title = "Drives"
	case .Help:        title = "Help & Info"
	}
	title_w := ui_measure_text_w(hdr_font, title, header_size)
	ui_draw_text(hdr_font, title, rl.Vector2{f32((w-title_w)/2), 12}, header_size, colors.text_primary)

	btn_w: f32 = 80
	btn_h: f32 = 40
	gap:   f32 = 40
	right_x: f32 = f32(w) - 8 - btn_w

	if ui_button(right_x, 4, btn_w, btn_h, "Theme", body_font, base_size, colors) {
		ui_push_action(result, .Toggle_Theme)
	}
	right_x -= btn_w + gap
	if ui_button(right_x, 4, btn_w, btn_h, "Font Size", body_font, base_size, colors) {
		ui_push_action(result, .Toggle_Font)
	}
	right_x -= btn_w + gap
	if ui_button(right_x, 4, btn_w, btn_h, "Copy", body_font, base_size, colors) {
		ui_push_action(result, .Copy)
	}
}

ui_draw_drawer :: proc(state: ^App_State, fa: ^Font_Atlas, colors: Theme_Colors, w: i32, h: i32, result: ^UI_Result) {
	if !state.menu_open { return }

	drawer_w: f32 = f32(w) * 0.60
	bar_h:    f32 = 48
	rl.DrawRectangle(0, i32(bar_h), i32(drawer_w), h-i32(bar_h), colors.bg_menu)

	hdr_font, header_size := font_get_header(fa, state.font_size)

	row_h: f32 = 64
	y:     f32 = bar_h + 12

	if ui_button(12, y, drawer_w-24, row_h, "System Information", hdr_font, header_size, colors) {
		ui_push_action(result, .Nav_System)
	}
	y += row_h + 10
	if ui_button(12, y, drawer_w-24, row_h, "Drives", hdr_font, header_size, colors) {
		ui_push_action(result, .Nav_Drives)
	}
	y += row_h + 10
	if ui_button(12, y, drawer_w-24, row_h, "Help & Info", hdr_font, header_size, colors) {
		ui_push_action(result, .Nav_Help)
	}

	close_h: f32 = 52
	close_y: f32 = f32(h) - close_h - 12
	if ui_button(12, close_y, drawer_w-24, close_h, "Close Menu", hdr_font, header_size, colors) {
		ui_push_action(result, .Close_Menu)
	}
}

ui_draw_view_system :: proc(state: ^App_State, fa: ^Font_Atlas, colors: Theme_Colors, content_x: f32, content_y: f32, content_w: f32) -> f32 {
	body_font, base_size   := font_get_body(fa, state.font_size)
	hdr_font,  header_size := font_get_header(fa, state.font_size)

	x:       f32 = content_x + 16
	y:       f32 = content_y + 16 - state.scroll_offset
	value_x: f32 = x + 220

	ui_draw_text(hdr_font, "Operating System:", rl.Vector2{x, y}, header_size, colors.text_primary)
	y += f32(header_size) + 10
	y = ui_text_kv(x, y, "PC Name:",      state.data.os.pc_name,      body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Username:",     state.data.os.username,     body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "OS Name:",      state.data.os.os_name,      body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Edition:",      state.data.os.edition,      body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Architecture:", state.data.os.architecture, body_font, base_size, colors, value_x)

	y += 10
	ui_draw_text(hdr_font, "Processor:", rl.Vector2{x, y}, header_size, colors.text_primary)
	y += f32(header_size) + 10
	y = ui_text_kv(x, y, "CPU Name:",   state.data.cpu.name,                               body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Cores:",      fmt.tprintf("%d",    state.data.cpu.core_count),   body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Threads:",    fmt.tprintf("%d",    state.data.cpu.thread_count), body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Base Clock:", fmt.tprintf("%.2f GHz", state.data.cpu.base_clock),body_font, base_size, colors, value_x)

	y += 10
	ui_draw_text(hdr_font, "Motherboard:", rl.Vector2{x, y}, header_size, colors.text_primary)
	y += f32(header_size) + 10
	y = ui_text_kv(x, y, "Manufacturer:",   state.data.mobo.manufacturer,                          body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Product:",        state.data.mobo.product,                               body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "TPM Version:",    state.data.mobo.tpm_version,                           body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "RAM Slots Used:", fmt.tprintf("%d", state.data.mobo.ram_slot_used),      body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "RAM Slots Free:", fmt.tprintf("%d", state.data.mobo.ram_slot_available), body_font, base_size, colors, value_x)

	y += 10
	ui_draw_text(hdr_font, "Memory (RAM):", rl.Vector2{x, y}, header_size, colors.text_primary)
	y += f32(header_size) + 10
	y = ui_text_kv(x, y, "Total:",    fmt.tprintf("%.1f GB", state.data.ram.total_gb),   body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Usable:",   fmt.tprintf("%.1f GB", state.data.ram.usable_gb),  body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "Reserved:", fmt.tprintf("%.0f MB", state.data.ram.reserved_mb),body_font, base_size, colors, value_x)

	bar_y: f32 = y + 6
	bar_h: f32 = 20
	bar_w: f32 = content_w - 32
	rl.DrawRectangle(i32(x), i32(bar_y), i32(bar_w), i32(bar_h), colors.ram_bar_empty)
	fill_w: f32 = bar_w * state.data.ram.usage_percent
	rl.DrawRectangle(i32(x), i32(bar_y), i32(fill_w), i32(bar_h), colors.ram_bar_fill)

	y = bar_y + bar_h + 10
	ui_draw_text(body_font, fmt.tprintf("Available: %.1f GB", state.data.ram.available_gb), rl.Vector2{x, y}, base_size, colors.text_secondary)
	right_txt := fmt.tprintf("In Use: %.1f GB", state.data.ram.in_use_gb)
	right_w   := ui_measure_text_w(body_font, right_txt, base_size)
	ui_draw_text(body_font, right_txt, rl.Vector2{(content_x+content_w)-16-f32(right_w), y}, base_size, colors.text_secondary)
	y += f32(base_size) + 12

	ui_draw_text(hdr_font, "Graphics:", rl.Vector2{x, y}, header_size, colors.text_primary)
	y += f32(header_size) + 10
	y = ui_text_kv(x, y, "GPU Name:", state.data.gpu.name,                           body_font, base_size, colors, value_x)
	y = ui_text_kv(x, y, "VRAM:",     fmt.tprintf("%.1f GB", state.data.gpu.vram_gb),body_font, base_size, colors, value_x)

	return y + 16 + state.scroll_offset
}

ui_draw_view_drives :: proc(state: ^App_State, fa: ^Font_Atlas, colors: Theme_Colors, content_x: f32, content_y: f32, content_w: f32) -> f32 {
	body_font, base_size   := font_get_body(fa, state.font_size)
	hdr_font,  header_size := font_get_header(fa, state.font_size)

	x:         f32 = content_x + 16
	y:         f32 = content_y + 16 - state.scroll_offset
	card_w:    f32 = content_w - 32
	card_h_min:f32 = 160

	for i := 0; i < len(state.data.drives); i += 1 {
		d := state.data.drives[i]

		card_h: f32 = card_h_min
		rect := rl.Rectangle{x, y, card_w, card_h}
		rl.DrawRectangleRounded(rect, 0.10, 8, colors.bg_menu)
		rl.DrawRectangleRoundedLinesEx(rect, 0.10, 8, 1, COLOR_CHARCOAL)

		tx: f32 = x + 12
		ty: f32 = y + 12

		title := fmt.tprintf("%s  %s", d.letter, d.label)
		ui_draw_text(hdr_font, title, rl.Vector2{tx, ty}, header_size, colors.text_primary)
		ty += f32(header_size) + 10

		ui_draw_text(body_font, "Format:",      rl.Vector2{tx, ty},       base_size, colors.text_secondary)
		ui_draw_text(body_font, d.format,       rl.Vector2{tx+160, ty},   base_size, colors.text_primary)
		ty += f32(base_size) + 6
		ui_draw_text(body_font, "Type:",        rl.Vector2{tx, ty},       base_size, colors.text_secondary)
		ui_draw_text(body_font, d.drive_type,   rl.Vector2{tx+160, ty},   base_size, colors.text_primary)
		ty += f32(base_size) + 6
		ui_draw_text(body_font, "Total Space:", rl.Vector2{tx, ty},       base_size, colors.text_secondary)
		ui_draw_text(body_font, fmt.tprintf("%.1f GB", d.total_gb), rl.Vector2{tx+160, ty}, base_size, colors.text_primary)
		ty += f32(base_size) + 6
		ui_draw_text(body_font, "Free Space:",  rl.Vector2{tx, ty},       base_size, colors.text_secondary)
		ui_draw_text(body_font, fmt.tprintf("%.1f GB", d.free_gb),  rl.Vector2{tx+160, ty}, base_size, colors.text_primary)

		y += card_h + 12
	}

	return y + 16 + state.scroll_offset
}

Font_Picker_Entry :: struct {
	label: string,
	value: Font_Size,
}

ui_draw_view_help :: proc(
	state:     ^App_State,
	fa:        ^Font_Atlas,
	colors:    Theme_Colors,
	content_x: f32, content_y: f32,
	content_w: f32, content_h: f32,
	result:    ^UI_Result,
) -> f32 {
	body_font, base_size   := font_get_body(fa, state.font_size)
	hdr_font,  header_size := font_get_header(fa, state.font_size)

	x: f32 = content_x + 16
	y: f32 = content_y + 16 - state.scroll_offset

	title   := "OdinRigView System Info"
	title_w := ui_measure_text_w(hdr_font, title, header_size+4)
	ui_draw_text(hdr_font, title, rl.Vector2{content_x + (content_w-f32(title_w))/2, y}, header_size+4, colors.text_primary)
	y += f32(header_size+4) + 6

	ver   := "Version 1.1.0"
	ver_w := ui_measure_text_w(body_font, ver, base_size)
	ui_draw_text(body_font, ver, rl.Vector2{content_x + (content_w-f32(ver_w))/2, y}, base_size, colors.text_secondary)
	y += f32(base_size) + 14

	para := "This app helps you quickly read and share your PC specs when selling your computer. Use Copy to paste specs into a listing."
	ui_draw_text(body_font, para, rl.Vector2{x, y}, base_size, colors.text_primary)
	y += f32(base_size)*3 + 24

	// ── Font size picker ─────────────────────────────────────────────────────
	ui_draw_text(hdr_font, "Font Size", rl.Vector2{x, y}, header_size, colors.text_secondary)
	y += f32(header_size) + 8

	picker_sizes := [3]Font_Picker_Entry{
		{"Small",  .Small},
		{"Medium", .Medium},
		{"Large",  .Large},
	}

	btn_gap: f32 = 8
	btn_w:   f32 = (content_w - 32 - btn_gap*2) / 3
	btn_h:   f32 = 44
	bx:      f32 = x

	for entry in picker_sizes {
		is_active := state.font_size == entry.value
		hover     := ui_mouse_in_rect(bx, y, btn_w, btn_h)
		clicked   := hover && rl.IsMouseButtonPressed(rl.MouseButton.LEFT)

		bg := colors.bg_menu
		if is_active || hover { bg = colors.accent }
		rl.DrawRectangle(i32(bx), i32(y), i32(btn_w), i32(btn_h), bg)

		tw   := ui_measure_text_w(body_font, entry.label, base_size)
		th   := base_size + 2
		tx   := i32(bx) + (i32(btn_w)-tw)/2
		ty   := i32(y)  + (i32(btn_h)-th)/2
		tcol := colors.text_primary
		if is_active || hover { tcol = colors.accent_text }
		ui_draw_text(body_font, entry.label, rl.Vector2{f32(tx), f32(ty)}, base_size, tcol)

		if clicked {
			state.font_size     = entry.value
			state.scroll_offset = 0
		}

		bx += btn_w + btn_gap
	}
	y += btn_h + 20

	// ── Action buttons ───────────────────────────────────────────────────────
	full_btn_w: f32 = content_w - 32
	full_btn_h: f32 = 52

	if ui_button(x, y, full_btn_w, full_btn_h, "Changelog", hdr_font, header_size, colors) {
		ui_push_action(result, .Open_Changelog)
	}
	y += full_btn_h + 10
	if ui_button(x, y, full_btn_w, full_btn_h, "Update", hdr_font, header_size, colors) {
		ui_push_action(result, .Open_Update)
	}
	y += full_btn_h + 10
	if ui_button(x, y, full_btn_w, full_btn_h, "Website", hdr_font, header_size, colors) {
		ui_push_action(result, .Open_Website)
	}

	_ = content_h
	return y + full_btn_h + 16 + state.scroll_offset
}

// ── Top-level render ─────────────────────────────────────────────────────────

ui_render :: proc(state: ^App_State, fa: ^Font_Atlas, colors: Theme_Colors, w: i32, h: i32) -> UI_Result {
	res: UI_Result

	rl.ClearBackground(colors.bg)

	ui_draw_top_bar(state, fa, colors, w, &res)
	ui_draw_drawer (state, fa, colors, w, h, &res)

	bar_h:     f32 = 48
	content_x: f32 = 0
	if state.menu_open { content_x = f32(w) * 0.60 }
	content_y: f32 = bar_h
	content_w: f32 = f32(w) - content_x
	content_h: f32 = f32(h) - content_y

	wheel := rl.GetMouseWheelMove()
	if wheel != 0 {
		state.scroll_offset -= wheel * 30
		if state.scroll_offset < 0 { state.scroll_offset = 0 }
	}

	end_y: f32
	switch state.current_view {
	case .System_Info:
		end_y = ui_draw_view_system(state, fa, colors, content_x, content_y, content_w)
	case .Drives:
		end_y = ui_draw_view_drives(state, fa, colors, content_x, content_y, content_w)
	case .Help:
		end_y = ui_draw_view_help  (state, fa, colors, content_x, content_y, content_w, content_h, &res)
	}

	max_scroll := end_y - (content_y + content_h)
	if max_scroll < 0 { max_scroll = 0 }
	if state.scroll_offset > max_scroll { state.scroll_offset = max_scroll }

	return res
}