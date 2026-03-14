package pc_info

import rl "vendor:raylib"

WINDOW_TITLE  :: "OdinRigView"
WINDOW_W:     i32 : 900
WINDOW_H:     i32 : 600
WINDOW_MIN_W: i32 : 640
WINDOW_MIN_H: i32 : 480
FONT_PATH     :: "C:/Windows/Fonts/consola.ttf"

cycle_font_size :: proc(size: Font_Size) -> Font_Size {
	switch size {
	case .Small:  return .Medium
	case .Medium: return .Large
	case .Large:  return .Small
	}
	return .Medium
}

main :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags{.WINDOW_RESIZABLE})
	rl.InitWindow(WINDOW_W, WINDOW_H, WINDOW_TITLE)
	defer rl.CloseWindow()
	rl.SetWindowMinSize(WINDOW_MIN_W, WINDOW_MIN_H)
	rl.SetTargetFPS(60)

	// Font atlas must be loaded after InitWindow so the GPU is ready.
	fa := font_load_all(FONT_PATH)
	defer font_unload_all(&fa)

	state: App_State
	state.current_view  = .System_Info
	state.theme         = .Dark
	state.font_size     = .Medium
	state.menu_open     = false
	state.scroll_offset = 0
	state.last_ram_tick = 0
	state.data          = collect_static_system_data()

	for !rl.WindowShouldClose() {
		// RAM refresh every ~1 second using raylib's monotonic timer.
		now_ns := u64(rl.GetTime() * 1.0e9)
		if state.last_ram_tick == 0 || now_ns-state.last_ram_tick >= 1_000_000_000 {
			refresh_ram_usage(&state.data.ram)
			state.last_ram_tick = now_ns
		}

		colors := get_theme_colors(state.theme)
		w := rl.GetScreenWidth()
		h := rl.GetScreenHeight()

		rl.BeginDrawing()
		res := ui_render(&state, &fa, colors, w, h)

		for i := 0; i < res.action_count; i += 1 {
			switch res.actions[i] {
			case .None:
				// no-op
			case .Toggle_Theme:
				state.theme = .Light if state.theme == .Dark else .Dark
			case .Toggle_Font:
				// Cycles font size; no reload needed — atlas covers all sizes.
				state.font_size = cycle_font_size(state.font_size)
			case .Nav_System:
				state.current_view  = .System_Info
				state.menu_open     = false
				state.scroll_offset = 0
			case .Nav_Drives:
				state.current_view  = .Drives
				state.menu_open     = false
				state.scroll_offset = 0
			case .Nav_Help:
				state.current_view  = .Help
				state.menu_open     = false
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

	delete(state.data.drives)
}