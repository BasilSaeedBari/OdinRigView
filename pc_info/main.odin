package pc_info

import os "core:os"
import rl "vendor:raylib"

WINDOW_TITLE :: "OdinRigView"
WINDOW_W: i32 : 900
WINDOW_H: i32 : 600
WINDOW_MIN_W: i32 : 640
WINDOW_MIN_H: i32 : 480

SEGOE_UI_PATH :: "C:/Windows/Fonts/consola.ttf"

load_ui_font :: proc(size: Font_Size) -> rl.Font {
	base: i32 = get_font_base(size)
	f: rl.Font = rl.LoadFontEx(SEGOE_UI_PATH, base, nil, 0)
	if f.texture.id == 0 {
		return rl.GetFontDefault()
	}
	return f
}

cycle_font_size :: proc(size: Font_Size) -> Font_Size {
	switch size {
	case .Small:
		return .Medium
	case .Medium:
		return .Large
	case .Large:
		return .Small
	}
	return .Medium
}

main :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags{.WINDOW_RESIZABLE})
	rl.InitWindow(WINDOW_W, WINDOW_H, WINDOW_TITLE)
	defer rl.CloseWindow()

	rl.SetWindowMinSize(WINDOW_MIN_W, WINDOW_MIN_H)
	rl.SetTargetFPS(60)

	state: App_State = {}
	state.current_view = .System_Info
	state.theme = .Dark
	state.font_size = .Medium
	state.menu_open = false
	state.scroll_offset = 0
	state.last_ram_tick = 0

	state.data = collect_static_system_data()

	font: rl.Font = load_ui_font(state.font_size)
	defer rl.UnloadFont(font)

	for !rl.WindowShouldClose() {
		// RAM refresh every ~1 second using raylib's monotonic timer.
		now_sec: f64 = rl.GetTime()
		now_ns: u64 = u64(now_sec * 1.0e9)
		if state.last_ram_tick == 0 || now_ns-state.last_ram_tick >= 1_000_000_000 {
			refresh_ram_usage(&state.data.ram)
			state.last_ram_tick = now_ns
		}

		colors: Theme_Colors = get_theme_colors(state.theme)

		rl.BeginDrawing()
		w: i32 = rl.GetScreenWidth()
		h: i32 = rl.GetScreenHeight()

		res: UI_Result = ui_render(&state, font, colors, w, h)

		// Handle UI actions
		i: int
		for i = 0; i < res.action_count; i += 1 {
			a: UI_Action = res.actions[i]
			switch a {
			case .None:
				// no-op
			case .Toggle_Theme:
				if state.theme == .Dark {
					state.theme = .Light
				} else {
					state.theme = .Dark
				}
			case .Toggle_Font:
				state.font_size = cycle_font_size(state.font_size)
				rl.UnloadFont(font)
				font = load_ui_font(state.font_size)
			case .Nav_System:
				state.current_view = .System_Info
				state.menu_open = false
				state.scroll_offset = 0
			case .Nav_Drives:
				state.current_view = .Drives
				state.menu_open = false
				state.scroll_offset = 0
			case .Nav_Help:
				state.current_view = .Help
				state.menu_open = false
				state.scroll_offset = 0
			case .Close_Menu:
				state.menu_open = false
			case .Copy:
				_ = copy_specs_to_clipboard(state.data)
			case .Open_Changelog:
				_ = open_url_changelog()
			case .Open_Update:
				_ = open_url_update()
			case .Open_Website:
				_ = open_url_website()
			case:
			}
		}

		rl.EndDrawing()
	}

	// Caller owns freeing drives dynamic array.
	delete(state.data.drives)
}

