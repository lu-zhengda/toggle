# Toggle redesign: UX note (design phase)

Mockups are real SwiftUI renders on macOS 27 with sample data (see "How these were rendered" at the end).

## Layout
- The popover keeps today's sections: Connectivity, Display & Sound, Focus & Power, Finder & Dock, then the momentary actions strip (Screen Saver, Lock, Sleep Display, More).
- Panel: a single `glassEffect(.regular)` surface. Tiles and rows sit in `GlassEffectContainer`s so neighbouring glass blends together. "On" state uses `.regular.tint(<toggle color>)`, with `.interactive()` for press feedback in the real build.
- Grid stays 4 columns, about 300 pt wide. List is about 320 pt wide, and its height is capped (about 640 pt) and then scrolls.

## View switch
- A small two-segment glass capsule (grid / list icons) in the header, left of Refresh and Settings.
- One click switches, with a crossfade plus a matched-geometry morph of the icons.
- The choice is remembered per user (`@AppStorage`). Settings > Toggles has the same "Default view" picker.

## List rows and dropdowns
- Each row has an icon in a glass circle, the name, an optional current value (for example "Contacts Only" or "1 hr left"), an optional chevron, and a switch.
- Rows with a dropdown:
  - AirDrop: Contacts Only / Everyone / Off
  - AirPods: pick the paired device, plus Bluetooth Settings…
  - Keep Awake: 15 min / 30 min / 1 h / 2 h / 5 h / Indefinitely
  - Mute: the audio output device (moves "Audio Output" out of the More menu)
- The switch always toggles directly and never opens the menu. The chevron, or a click on the row body, opens the menu.
- The menu expands inline under its row as a glass inset, with a spring (about 0.35 s, light bounce). The chevron rotates 180°.
- Only one menu is open at a time; opening another closes the first. Esc, picking an option, or clicking the chevron again closes it.
- Picking an option applies it immediately. For example, picking a Keep Awake duration also turns Keep Awake on.

## Keyboard
- Up/Down move focus between rows (in grid view, arrows move between tiles). Tab moves between the header controls and the content.
- Space toggles the focused row's switch.
- Return or Right opens the focused row's dropdown. Inside it, Up/Down move, Return picks, and Esc or Left closes and returns focus to the row.
- Cmd-, opens Settings. Cmd-1 and Cmd-2 switch between grid and list.

## Accessibility
- Every row and tile has a label (the toggle name), a value ("On", "Off", "Contacts Only", "On, 42 minutes remaining") and a hint. Rows with a dropdown also expose an "Options" action.
- Reduce Motion: the spring expand and the view morph fall back to a plain crossfade.
- Reduce Transparency: glass falls back to a solid system material/background (`.identity` glass plus an opaque fill).
- Increase Contrast: stronger borders on glass, and on/off isn't shown by tint alone (the switch position and the value text carry it).
- Hit targets are at least 28 pt. Text uses system sizes that respect the user's text-size setting.

## Settings > Toggles (new tab)
- One flat list of all toggles in panel order. Each row has a drag handle, the icon, the name, a "Dropdown" badge where relevant, and a Show checkbox.
- Drag and drop to reorder. The lifted row floats with a shadow and a dashed insertion slot shows where it will land. The grid and list share one order.
- Keyboard reorder: Move Up / Move Down buttons, also Option-Cmd-Up/Down on the selected row. VoiceOver gets "Move up" and "Move down" custom actions.
- Unchecked toggles are hidden from both views. Hidden toggles stay dimmed in this list so they can be turned back on. "Restore Default Order" resets the order and shows everything.
- Other tabs: General, Keep Awake, Permissions, About (today's sections, split into tabs).

## How these were rendered
- Popover images (01–05b) are real SwiftUI `glassEffect` / `GlassEffectContainer` output rendered offscreen at 2x.
  - On-screen window capture wasn't possible because the Mac's screen was locked.
  - The small switches in the list are drawn to match the system switch, because offscreen rendering can't draw AppKit-backed controls.
  - The background is a sample wallpaper-like gradient.
- Settings images (06–07b) are the real AppKit/SwiftUI window, with native checkboxes, segmented picker and toolbar tabs, drawn offscreen at 2x. Offscreen drawing shows the window chrome without its live Liquid Glass toolbar treatment.
- On a live screen, the glass will look more refractive and will react to what's behind it.
