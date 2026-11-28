# Toggle redesign, round 2: grid and Settings directions

Design only. The list view and dropdowns from round 1 are unchanged. The sample data is the real 16 toggles plus the 4 quick actions.

## Grid directions (each in light and dark)

### A: Dense, icon-only (`grid-A-*`)
6 columns of 42 pt glass circles, with no section dividers. The 4 quick actions move into a glass capsule in the header, and the app title is dropped. A footer line names the focused or hovered tile and its value ("Keep Awake · 1 hr left").
- Scan speed: fast once icons are learned, but there are no labels, so first-time users have to hover.
- Density: highest. About 310 × 300 pt for 16 toggles + 4 actions.
- Discoverability: lowest. State is shown by tint only, and names appear only on hover or focus.
- 16+ toggles / hidden: scales best, since extra rows are only about 48 pt each. Hiding a toggle removes its circle. Sections are not visible, so order matters more.
- Implementation cost: lowest. Same tiles as today with a different column count, a header capsule and a footer.
- Control Center fit: weak. It keeps today's icon-only look.

### B: Labeled, Control Center–style mixed sizes (`grid-B-*`)
A 4 × n grid of 72 pt units:
- A 2×2 Connectivity module: Wi-Fi, Bluetooth and AirDrop with their values.
- A wide Keep Awake tile with a time-left ring.
- 1×1 labeled tiles.
- Wide AirPods and Sound tiles (the Sound tile has a slider).
- The quick actions are the last row, as dashed ghost tiles.
- Scan speed: very good. Labels and values are visible, and size signals importance.
- Density: medium. About 340 × 560 pt, the tallest of the three.
- Discoverability: highest. Rich tiles show state (value, time left) without opening anything.
- 16+ toggles / hidden: the weakest. Big modules are hand-placed, so the layout needs fixed slots for Connectivity, Keep Awake, AirPods and Sound. Reordering and hiding must reflow around those modules, and extra toggles all become 1×1 rows at the bottom. Reorder needs rules, such as "special tiles keep their size, order only changes position".
- Implementation cost: highest. It needs a size per toggle (1×1, 2×1, 2×2), a flow layout, and tile content types (slider, ring).
- Control Center fit: best. It is the closest to the system's visual language.

### C: Section glass cards with labeled tiles (`grid-C-*`)
Each section is a glass card with a caption and 4 labeled flat tiles. Tiles inside the cards are flat fills (glass is not stacked on glass). Sections can be collapsed to one line of status glyphs (Finder & Dock is collapsed in the render). The quick actions are a labeled glass strip at the bottom.
- Scan speed: good. Grouping and labels make it easy to read.
- Density: medium-low. About 340 × 520 pt with one section collapsed.
- Discoverability: high. Labels are always visible, and the collapsed row still shows state.
- 16+ toggles / hidden: good. Cards are the unit, extra toggles add rows within a section, and collapse keeps the panel short. A hidden toggle simply disappears from its card. Per-section order is easy to explain in Settings.
- Implementation cost: medium. Section model plus a collapsed state, which is persisted per user.
- Control Center fit: partial. It uses card grouping and labels, but all tiles are the same size.

## Settings directions

### A: Sidebar (`settings-A-sidebar-*`: toggles light and dark, keep awake, permissions)
A sidebar with General, Toggles, Keep Awake, Permissions and About.
- Toggles page: the default-view picker, the full reorder list with show/hide checkboxes, and a live preview of the panel that updates as you reorder or hide.
- Keep Awake page: a checkbox per duration (shown in the dropdown or not), one "Default" duration, and the Prevent mode.
- Permissions page: a status pill per permission with an "Open Settings" button.
- Pros: room for the 16+ item list and the preview, and each topic has its own page. It matches the macOS 26 System Settings pattern.
- Cons: five pages for little content, so some pages (Keep Awake, About) look sparse. The most work.

### B: One scrolling glass form (`settings-B-form-light`)
Panel, Toggles, Keep Awake (chips for durations, a star for the default), Permissions and the footer, all in one narrow column.
- Pros: nothing is hidden and everything is found by scrolling. It is the fewest clicks. Small window.
- Cons: the reorder list pushes everything else off-screen, and a long list scrolls inside the window. There is no room for a preview.

### C: Tabs, the round-1 version for comparison (`settings-C-tabs-*`)
- Pros: familiar and cheapest, and it uses the system toolbar tabs.
- Cons: the Toggles tab becomes very tall (about 850 pt) with 16 rows, and there is no preview.

## Recommendation
- **Grid: C (section cards)** as the default. It is the best balance of scan speed, state visibility and handling 16+ or hidden toggles, at medium cost. Add two pieces of B: a time-left ring on the Keep Awake tile, and optionally a wide Connectivity group. Keep A's header quick actions as an option if bro wants maximum density (a "Compact" density setting could reuse A's tiles). Full B is the most Control Center-like, but its mixed sizes make reorder and hide rules complicated.
- **Settings: A (sidebar)**. Its live preview is the main benefit, since you can see the effect of reorder and hide immediately, and it makes the long list comfortable. B is the cheaper fallback if bro wants less work.

## Render caveats (public-safe)
- Live screen capture wasn't possible because the Mac's screen was locked, so these are offscreen renders:
  - Grid images are SwiftUI ImageRenderer output at 2x. Liquid Glass (`glassEffect`) does render, but the glass is not refracting a live desktop. The backgrounds are sample gradients.
  - Settings images are real SwiftUI/AppKit windows drawn offscreen at 2x. Native checkboxes, segmented pickers and switches are real, but offscreen drawing shows the toolbar and titlebar without the live macOS 26 glass treatment.
- The Settings A sidebar is hand-drawn, because a real `NavigationSplitView` sidebar doesn't draw offscreen. The real one would be a glass floating sidebar.
- The live preview inside Settings A is a rendered image of the panel (round-1 grid), not a live view.
- The wide tiles' values ("Home 5G", "Not connected", "Speakers", "1 hr left") and the slider are sample data. Sound and the Connectivity module are new tile types that don't exist in today's app.
- The sizes are estimates at 1x points. The `small/` folder has about 60% JPEG copies.
