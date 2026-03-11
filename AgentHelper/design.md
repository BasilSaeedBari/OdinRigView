# UI/UX Design & Styling Guide
**Project Name:** PC Seller System Info App
**Implementation Target:** Odin + `vendor:raylib` + `vendor:microui`

---

## 1. Color Palette

The app is restricted to the following 5 colors. Do not introduce new colors.
Define all of these as named constants in `ui_theme.odin`.

| Constant Name     | Hex       | RGBA (0–255)         | Primary Use Case |
| :---              | :---      | :---                 | :--- |
| `COLOR_ONYX`      | `#000f08` | (0, 15, 8, 255)      | Pure dark backgrounds; darkest text in light mode. |
| `COLOR_JET_BLACK` | `#1c3738` | (28, 55, 56, 255)    | Secondary dark backgrounds (menus, cards), borders. |
| `COLOR_CHARCOAL`  | `#4d4847` | (77, 72, 71, 255)    | Muted text, disabled buttons, subtle borders. |
| `COLOR_MINT_CREAM`| `#f4fff8` | (244, 255, 248, 255) | Pure light backgrounds; primary text in dark mode. |
| `COLOR_COOL_STEEL`| `#8baaad` | (139, 170, 173, 255) | Primary accent (buttons, highlights, RAM bar fill). |

```odin
// ui_theme.odin — define exactly as below, typed explicitly
COLOR_ONYX       : rl.Color : { 0,   15,  8,   255 }
COLOR_JET_BLACK  : rl.Color : { 28,  55,  56,  255 }
COLOR_CHARCOAL   : rl.Color : { 77,  72,  71,  255 }
COLOR_MINT_CREAM : rl.Color : { 244, 255, 248, 255 }
COLOR_COOL_STEEL : rl.Color : { 139, 170, 173, 255 }
```

---

## 2. Theme Mapping (Dark vs. Light Mode)

Expose a `get_theme_colors(theme: Theme) -> Theme_Colors` procedure in `ui_theme.odin`.
`Theme_Colors` is a flat struct of semantic color slots, resolved at call time from the palette above.

### Dark Mode (Default)

| Semantic Slot          | Resolved Color    |
| :---                   | :---              |
| `bg`                   | `COLOR_ONYX`      |
| `bg_menu`              | `COLOR_JET_BLACK` |
| `text_primary`         | `COLOR_MINT_CREAM`|
| `text_secondary`       | `COLOR_COOL_STEEL`|
| `accent`               | `COLOR_COOL_STEEL`|
| `accent_text`          | `COLOR_ONYX`      |
| `ram_bar_fill`         | `COLOR_COOL_STEEL`|
| `ram_bar_empty`        | `COLOR_CHARCOAL`  |

### Light Mode

| Semantic Slot          | Resolved Color    |
| :---                   | :---              |
| `bg`                   | `COLOR_MINT_CREAM`|
| `bg_menu`              | `COLOR_COOL_STEEL`|
| `text_primary`         | `COLOR_ONYX`      |
| `text_secondary`       | `COLOR_CHARCOAL`  |
| `accent`               | `COLOR_JET_BLACK` |
| `accent_text`          | `COLOR_MINT_CREAM`|
| `ram_bar_fill`         | `COLOR_JET_BLACK` |
| `ram_bar_empty`        | `COLOR_COOL_STEEL`|

---

## 3. Layout Structure

### 3.1 Top Bar
- **Fixed height:** 48px.
- Rendered as a filled rectangle spanning the full window width.
- Background color: `bg_menu` (from active theme).

| Position | Element | Notes |
| :--- | :--- | :--- |
| Left | Hamburger icon `≡` | Button; toggles side drawer open/close. |
| Center | Page Title text | Changes per active view: `"System Information"`, `"Drives"`, `"Help & Info"`. |
| Right | 4 action icon buttons | Copy `[📋]`, Screenshot `[📸]`, Font Size `[A^]`, Theme `[🌓]`. |

> **Raylib implementation note:** Draw the top bar as `rl.DrawRectangle`, then layer text and icon buttons on top. Use `rl.DrawText` for the title. Represent icons as short Unicode strings or small textures.

### 3.2 Side Menu (Drawer)
- Slides in from the left edge.
- Width: **60% of the window width**.
- Background: `bg_menu`.
- Contains three large, full-width, clickable row items:
  1. System Information
  2. Drives
  3. Help & Info
- Row height: `64px` minimum. Text should be `text_primary`. Entire row is the hit target.
- Bottom of drawer: a **"Close Menu"** button. Full-width. Background: `accent`. Text: `accent_text`.

> **Animation note:** Optionally slide the drawer in with a lerp over ~150ms using `core:time` delta. This is a polish feature — implement only after core functionality works.

### 3.3 Content Area
- Occupies the remaining space below the top bar (and to the right of the drawer, if open).
- Scrollable vertically when content overflows (important for Large font mode).

---

## 4. Content Views

### View 1: System Information

Displays four data groups: OS, CPU, RAM, GPU.

**Typography hierarchy (within each group):**
- **Category Header** (e.g., `Processor:`): Bold, `header_size` font. Color: `text_primary`.
- **Data Label** (e.g., `CPU Name:`): Normal weight, `base_size` font. Color: `text_secondary`.
- **Data Value** (e.g., `AMD Ryzen 5 2600`): Bold, `base_size` font. Color: `text_primary`.

> Draw label and value on the same row using two `rl.DrawText` calls — left-aligned label, value starts at a fixed column offset (e.g., 200px from left margin).

**RAM Visualizer:**
- A horizontal rectangle, full content-area width minus padding.
- Height: `20px`.
- Left portion (width = `usage_percent * total_width`): filled with `ram_bar_fill`.
- Right portion: filled with `ram_bar_empty`.
- Immediately below the bar:
  - Left-aligned: `Available: X.X GB`
  - Right-aligned: `In Use: X.X GB`
  - Font: `base_size`, color: `text_secondary`.

### View 2: Drives

Card-based layout. One card per detected drive.

**Card spec:**
- Background: `bg_menu`.
- Border: 1px, color `COLOR_CHARCOAL`.
- Corner radius: 4px (use `rl.DrawRectangleRounded`).
- Padding: 12px on all sides.
- Full width of content area minus horizontal padding.
- Vertical gap between cards: 12px.

**Card content (top to bottom):**
1. **Drive Letter / Label** — Bold, `header_size`. Color: `text_primary`. (e.g., `C:  Windows`)
2. Format — Label: `text_secondary`. Value: `text_primary`.
3. Type — Label: `text_secondary`. Value: `text_primary`.
4. Total Space — Label: `text_secondary`. Value: `text_primary`.
5. Free Space — Label: `text_secondary`. Value: `text_primary`.

### View 3: Help & Info

**Top section (centered):**
- App title: Bold, `header_size` + 4px. Color: `text_primary`.
- Version number: Normal, `base_size`. Color: `text_secondary`.

**Middle section:**
- A short paragraph of descriptive text. Normal weight, `base_size`. Color: `text_primary`. Wraps within content area width.

**Bottom section — three stacked full-width buttons:**

| Button | Action |
| :--- | :--- |
| `Changelog` | Open GitHub releases/changelog URL in default browser. |
| `Update` | Open latest GitHub release page in default browser. |
| `Website` | Open creator portfolio/website in default browser. |

- Button height: `52px`.
- Vertical gap between buttons: `10px`.
- Background: `accent`. Text: `accent_text`. Bold, `base_size`.
- Use `rl.DrawRectangleRounded` with radius `0.15f`.

---

## 5. Typography & Scaling

Define font sizes as constants in `ui_theme.odin`. Load the font once on startup; reload when size changes.

| Enum Value     | Base Size | Header Size |
| :---           | :---      | :---        |
| `.Small`       | 12px      | 16px        |
| `.Medium`      | 14px      | 18px        |
| `.Large`       | 18px      | 24px        |

```odin
Font_Size :: enum {
    Small,
    Medium,
    Large,
}

get_font_base :: proc(size: Font_Size) -> i32 {
    switch size {
        case .Small:  return 12
        case .Medium: return 14
        case .Large:  return 18
    }
    return 14
}

get_font_header :: proc(size: Font_Size) -> i32 {
    switch size {
        case .Small:  return 16
        case .Medium: return 18
        case .Large:  return 24
    }
    return 18
}
```

**Font family:** Load `Segoe UI` from `C:/Windows/Fonts/segoeui.ttf` at startup.
Fallback: if the file is not found, use raylib's default built-in font.

**Scrolling:** When the `Large` font is active, content may overflow the content area.
Implement vertical scrolling using a `scroll_offset: f32` value in `App_State`, adjusted by mouse wheel input (`rl.GetMouseWheelMove()`).

---

## 6. Action Buttons (Top Bar)

| Button | Icon | Behavior |
| :--- | :--- | :--- |
| Copy | `[C]` or clipboard icon | Copies all static hardware text to clipboard as plain text. |
| Screenshot | `[S]` or camera icon | Captures the app window and saves to `%TEMP%\pc_info_screenshot.png` or copies to clipboard. |
| Font Size | `[A]` | Cycles: Small → Medium → Large → Small. Reloads font. |
| Theme | `[T]` or half-moon icon | Toggles between Dark and Light mode. Flips all `Theme_Colors`. |

> Represent icons as simple ASCII labels inside small rounded buttons until proper icon textures are sourced. Each button is `40x40px`, placed 4px apart from the right edge.

---

## 7. Window & Rendering Defaults

| Property | Value |
| :--- | :--- |
| Default window size | 900 × 600 px |
| Minimum window size | 640 × 480 px |
| Target FPS | 60 |
| Window title | `"PC Info"` |
| Resizable | Yes (`rl.FLAG_WINDOW_RESIZABLE`) |
