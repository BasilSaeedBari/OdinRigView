package pc_info

import rl "vendor:raylib"

// Palette (restricted to exactly these 5 colors).
COLOR_ONYX       : rl.Color : { 0,   15,  8,   255 }
COLOR_JET_BLACK  : rl.Color : { 28,  55,  56,  255 }
COLOR_CHARCOAL   : rl.Color : { 77,  72,  71,  255 }
COLOR_MINT_CREAM : rl.Color : { 244, 255, 248, 255 }
COLOR_COOL_STEEL : rl.Color : { 139, 170, 173, 255 }

Theme_Colors :: struct {
	bg:            rl.Color,
	bg_menu:       rl.Color,
	text_primary:  rl.Color,
	text_secondary: rl.Color,
	accent:        rl.Color,
	accent_text:   rl.Color,
	ram_bar_fill:  rl.Color,
	ram_bar_empty: rl.Color,
}

get_theme_colors :: proc(theme: Theme) -> Theme_Colors {
	out: Theme_Colors = {}
	switch theme {
	case .Dark:
		out.bg = COLOR_ONYX
		out.bg_menu = COLOR_JET_BLACK
		out.text_primary = COLOR_MINT_CREAM
		out.text_secondary = COLOR_COOL_STEEL
		out.accent = COLOR_COOL_STEEL
		out.accent_text = COLOR_ONYX
		out.ram_bar_fill = COLOR_COOL_STEEL
		out.ram_bar_empty = COLOR_CHARCOAL
	case .Light:
		out.bg = COLOR_MINT_CREAM
		out.bg_menu = COLOR_COOL_STEEL
		out.text_primary = COLOR_ONYX
		out.text_secondary = COLOR_CHARCOAL
		out.accent = COLOR_JET_BLACK
		out.accent_text = COLOR_MINT_CREAM
		out.ram_bar_fill = COLOR_JET_BLACK
		out.ram_bar_empty = COLOR_COOL_STEEL
	}
	return out
}

get_font_base :: proc(size: Font_Size) -> i32 {
	switch size {
	case .Small:
		return 12
	case .Medium:
		return 14
	case .Large:
		return 18
	}
	return 14
}

get_font_header :: proc(size: Font_Size) -> i32 {
	switch size {
	case .Small:
		return 17
	case .Medium:
		return 18
	case .Large:
		return 24
	}
	return 18
}

