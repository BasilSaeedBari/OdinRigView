package pc_info

import rl "vendor:raylib"

// One raylib Font loaded at the exact pixel height we will draw at.
// Drawing at a size other than the load size = blur.
Font_Atlas :: struct {
    small:   rl.Font,
    medium:  rl.Font,
    large:   rl.Font,
}

FONT_SIZE_SMALL  :: i32(14)
FONT_SIZE_MEDIUM :: i32(18)
FONT_SIZE_LARGE  :: i32(22)

// Header is always base + 6 px, loaded separately so it is also 1:1.
FONT_HEADER_DELTA :: i32(6)

font_load_all :: proc(path: cstring) -> Font_Atlas {
    fa: Font_Atlas

    fa.small  = rl.LoadFontEx(path, FONT_SIZE_SMALL,  nil, 0)
    fa.medium = rl.LoadFontEx(path, FONT_SIZE_MEDIUM, nil, 0)
    fa.large  = rl.LoadFontEx(path, FONT_SIZE_LARGE,  nil, 0)

    // Point filter = no blur when drawing at exactly the loaded size.
    rl.SetTextureFilter(fa.small.texture,  rl.TextureFilter.POINT)
    rl.SetTextureFilter(fa.medium.texture, rl.TextureFilter.POINT)
    rl.SetTextureFilter(fa.large.texture,  rl.TextureFilter.POINT)

    return fa
}

font_unload_all :: proc(fa: ^Font_Atlas) {
    rl.UnloadFont(fa.small)
    rl.UnloadFont(fa.medium)
    rl.UnloadFont(fa.large)
}

// Return the body font + its exact pixel size for the current setting.
font_get_body :: proc(fa: ^Font_Atlas, sz: Font_Size) -> (rl.Font, i32) {
    switch sz {
    case .Small:  return fa.small,  FONT_SIZE_SMALL
    case .Medium: return fa.medium, FONT_SIZE_MEDIUM
    case .Large:  return fa.large,  FONT_SIZE_LARGE
    }
    return fa.medium, FONT_SIZE_MEDIUM
}

// Header font is loaded separately at base+delta so it is also 1:1.
font_get_header :: proc(fa: ^Font_Atlas, sz: Font_Size) -> (rl.Font, i32) {
    #partial switch sz {
    case .Small:  return fa.small,  FONT_SIZE_SMALL  + FONT_HEADER_DELTA
    case .Large:  return fa.large,  FONT_SIZE_LARGE  + FONT_HEADER_DELTA
    }
    return fa.medium, FONT_SIZE_MEDIUM + FONT_HEADER_DELTA
}