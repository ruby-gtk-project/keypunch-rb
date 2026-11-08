# Component inventory — keypunch-rb

Upstream: `origin/main` (gtk-rs / Blueprint, Rust). Port: `ruby` branch, `lib/`.

Method: `component-identification` skill. Upstream has no symbol table built on
this machine (no `.gir` for a Rust/gtk-rs tree was generated), so this pass is
a manual read of every `.rs`, `.blp`, `.ui`, the gschema and the metainfo file,
cross-checked against `lib/`. Per the skill's file-union rule, each upstream
`.rs`/`.blp` pair that backs one widget subclass is listed as a single
component row, and a Rust file that only extends a `impl` block in `super::*`
(`window/*.rs`, `text_view/*.rs`) is unioned into the component it belongs to
rather than listed as its own row.

## Application-level unit

| Upstream file(s) | Kind | Port file | Exists |
|---|---|---|---|
| `src/application.rs` | application class (`KpApplication`); installs `app.quit`, `app.shortcuts`, `app.text-language` | `lib/keypunch/application.rb` | Yes |
| `src/main.rs` | entry point | `exe/` / `bin/` (gem entry point) | Yes (gem exe, not a widget) |
| `src/config.rs.in` | build-time constants (APP_ID, VERSION, …) | `lib/keypunch/rb/version.rb` | Yes |
| `src/settings.rs` + `data/no.bragefuglseth.Keypunch.gschema.xml.in` | GSettings wrapper: `window-width/height/maximized`, `session-type` enum, `session-duration` enum, `text-language`, `recent-languages`, `custom-text`, `personal-best` | `lib/settings.rb` | Yes |
| `src/discord_rpc.rs` | Discord Rich Presence integration | `lib/discord_rpc.rb` | Yes |

## Window unit — `KpWindow`

One component split by upstream across five files, unioned here.

| Upstream file(s) | Kind | Port file | Exists |
|---|---|---|---|
| `src/widgets/window.rs` + `src/widgets/window.blp` | main window: `Adw.ApplicationWindow`, `Adw.ToastOverlay`, `Adw.MultiLayoutView` (2 layouts: status-top / status-bottom), `Adw.HeaderBar`, session-type/duration `DropDown`s, `custom_button`, stop button, status stack (ready/countdown/elapsed/cancelled), bottom stack, About dialog (`Adw.AboutDialog`, incl. `add_other_app` entry for Fretboard), `win.about`/`win.text-language-dialog`/`win.cancel-test` actions | `lib/window.rb` | Yes |
| `src/widgets/window/focus.rs` | focus-follow behavior for the text entry | `lib/window_focus.rb` | Yes |
| `src/widgets/window/inhibit.rs` | session-inhibit (logout) cookie while a test is running | `lib/session_inhibitor.rb` | Yes |
| `src/widgets/window/typing_test.rs` | the typing-test state machine: start/cancel/finish, excessive-invalid-keystrokes cancellation, countdown/elapsed timer, results handoff | `lib/typing_test_session.rb` | Yes |
| `src/widgets/window/ui_state.rs` | **empty file** (0 bytes) — no logic, no component | — | The upstream file has 0 bytes in it; there is no behaviour in it to port |

## Dialog units

| Upstream file(s) | Kind | Port file | Exists |
|---|---|---|---|
| `src/widgets/custom_text_dialog.rs` + `.blp` | `Adw.Dialog` with a `Gtk.TextView` for editing the Custom-session text, Save button | `lib/custom_text_dialog.rb` | Yes |
| `src/widgets/text_language_dialog.rs` + `.blp` | `Adw.Dialog`: search entry, Recent/Other `Gtk.ListBox` sections, "No Matches" empty state, "Create Request" link | `lib/text_language_dialog.rb` | Yes |
| `data/resources/shortcuts-dialog.ui` | `Gtk.ShortcutsWindow` (General group: Open Menu, Text Language, Cancel Test, Keyboard Shortcuts, Close Window) | `lib/shortcuts_dialog.rb` | Yes |
| (inline in `window.rs::show_about_dialog`) | `Adw.AboutDialog` | `lib/about_dialog.rb` | Yes |

## Page / row units

| Upstream file(s) | Kind | Port file | Exists |
|---|---|---|---|
| `src/widgets/results_view.rs` + `.blp` | results page: WPM, accuracy, elapsed-time labels, "New Personal Best" banner, Test Type/Duration/Language `DropDown`s for re-run | `lib/results_view.rb` | Yes |
| (row inside `text_language_dialog.blp`'s `Gtk.ListBox`) | `Adw.ActionRow`-based language row | `lib/language_row.rb` | Yes |
| (menu model inside `window.blp`'s `menu_button`) | `Gio.Menu` / primary menu popover (`Text _Language`, `_Keyboard Shortcuts`, `_About Keypunch`) | `lib/primary_menu.rb` | Yes |

## Text-entry widget — `KpTextView`

One component split by upstream across five files, unioned here.

| Upstream file(s) | Kind | Port file | Exists |
|---|---|---|---|
| `src/widgets/text_view.rs` + `.blp` | custom `Gtk.Widget` subclass that draws the typing text, caret, highlighting | `lib/text_view.rb` | Yes |
| `src/widgets/text_view/colors.rs` | correct/incorrect/untyped color computation | `lib/text_view_colors.rb` | Yes |
| `src/widgets/text_view/caret.rs` | caret position/animation | unioned into `lib/text_view.rb` | Yes (folded in; verify caret animation specifically during parity pass) |
| `src/widgets/text_view/input.rs` | `Gtk.IMMulticontext` input handling, grapheme/word deletion | unioned into `lib/text_view.rb` | Yes (folded in; verify during parity pass) |
| `src/widgets/text_view/scrolling.rs` | `Adw.TimedAnimation`-driven auto-scroll | unioned into `lib/text_view.rb` | Yes (folded in; verify during parity pass) |
| `src/widgets/text_view/accessibility.rs` | `Gtk.AccessibleText`/current-word accessible state updates | unioned into `lib/text_view.rb` | Yes (folded in; verify during parity pass) |

## Supporting logic (no widgets of their own, but feed the components above)

| Upstream file | Port file | Exists |
|---|---|---|
| `src/typing_test_utils.rs` | `lib/typing_test_utils.rb` | Yes |
| `src/text_generation.rs` + `data/word_lists/*.txt` | `lib/text_generation.rb` | Yes |
| `src/text_utils.rs` | `lib/text_utils.rb` | Yes |
| `data/resources/style.css` | `lib/style.rb` | Yes |
| `po/*.po`, `po/keypunch.pot` | `lib/translations.rb` | Yes |

## Not components (reference-only upstream files)

- `data/no.bragefuglseth.Keypunch.metainfo.xml.in.in` — AppStream metadata/screenshots text, not a widget; its strings (`Get ready to accelerate your typing!`, `Session results`, etc.) belong to `translation-parity`, not this inventory.
- `data/no.bragefuglseth.Keypunch.desktop.in.in` — desktop entry (name/comment/keywords), same as above.
- `data/artwork/**`, `data/resources/icons/**`, `data/resources/assets/multilingual.svg` — icon/image assets, no widget behavior.
- `build-aux/*.json`, `meson.build`, `Cargo.toml/.lock`, `subprojects/blueprint-compiler.wrap` — build system, not UI.

## Summary

Every upstream user-facing widget file (window, its five behavior files, two
dialogs, the shortcuts window, the results page, the text-entry widget and
its four behavior files, the language row, the primary menu, the About
dialog) already has a corresponding file in `lib/` on `ruby`. The structural
survey found no missing component **files**.

This is a file-existence inventory, not a parity proof: `component-parity`
still needs to run per unit to confirm each file reproduces the **same
widgets, in the same counts, with the same CSS classes, signals and
actions** — the union columns above (caret/input/scrolling/accessibility
folded into `lib/text_view.rb`) are exactly the places a silent gap is most
likely to hide, since four upstream files' worth of signal/controller wiring
has to show up inside one Ruby file.
