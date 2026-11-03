# Keypunch — upstream component inventory

Survey of `origin/main` (Rust + blueprint, libadwaita 1.8) against `lib/` on the
`ruby` branch. The survey itself writes no app code; the presence column and the
blocker statuses are kept current as the port lands.

Upstream is 5 widget classes (`KpWindow`, `KpTextView`, `KpResultsView`,
`KpCustomTextDialog`, `KpTextLanguageDialog`), one application class, two
standalone declarative objects with no backing widget class (`primary_menu`,
`shortcuts-dialog.ui`), one dialog built entirely in source (the About dialog),
and five non-widget support modules.

`lib/` now holds every component below as its own flat file (22 files, ~4.7k
lines), following the pilot shape in `gnome-contacts-rb`: one upstream source
file (or `.rs` + `.blp` pair) per flat `lib/<thing>.rb`. The vendored data —
`data/style.css`, `data/word_lists/` (46 files), `data/assets/multilingual.svg`
and `data/icons/hicolor/` — is in place too. The translation layer landed with
`po/` (37 locales, `LINGUAS`, `POTFILES.in`, a regenerated `keypunch.pot`) and
`lib/translations.rb`; **62 of upstream's 87 messages are ported, and the 25
that are not are the GSettings schema, desktop entry and metainfo files this
port does not have, plus two accessibility labels the bindings cannot set.**
`TRANSLATION_PARITY.md` is the per-message ledger.

Dev-shell probe (`nix develop --command xvfb-run -a ruby`): GTK 4.22.4, and
every Adwaita and Gtk class upstream uses is present in the bindings —
`Adwaita::MultiLayoutView`, `Adwaita::Layout`, `Adwaita::LayoutSlot`,
`Adwaita::ShortcutsDialog`/`Section`/`Item`, `Adwaita::Breakpoint`,
`Adwaita::TimedAnimation`, `Adwaita::PropertyAnimationTarget`,
`Gtk::IMMulticontext`, `Gtk::UriLauncher`, `Gsk::PathBuilder`,
`Gtk::BinLayout`. Subclassing `Gtk::Widget` with `type_register` works.

---

## src/application.rs + src/main.rs — the application: actions, accels, settings

→ `lib/keypunch/application.rb` — **exists** (117 lines)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Application` (subclass `KpApplication`) | 1 | — | `activate` | presents the existing window or builds one `KpWindow` |

Actions installed: `app.quit`; `app.text-language` — a **stateful action created
from GSettings** (`settings.create_action("text-language")`), targeted by every
language row's `Gtk.CheckButton`. `app.shortcuts` is *not* installed by
upstream: libadwaita 1.8 installs it automatically because
`data/resources/shortcuts-dialog.ui` sits at the resource base path.

Accelerators: `win.text-language-dialog` → `<primary>comma`;
`win.cancel-test` → `Escape`; `window.close` → `<primary>w`;
`app.quit` → `<primary>q`.

Also owns the single `gio::Settings` instance and the `RpcWrapper` (Discord).

Repeaters: none. Conditional: none.

---

## src/widgets/window.blp + src/widgets/window.rs (+ `window/ui_state.rs`, empty) — the main window: three top-level screens

→ `lib/window.rb` — **exists** (525 lines)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (only when `APP_ID` ends `.Devel`), `hide-controls` (added while typing, removed on pointer motion/click) | `close-request` → saves window size | `title` _("Keypunch"), width-request 360, height-request 296 |
| `Adw.ToastOverlay` | 1 | — | — | host for the "Changes discarded" toast |
| `Gtk.Stack` `main_stack` | 1 | — | — | crossfade 200ms; pages `test`, `results`, `test-cancelled` |
| `Adw.MultiLayoutView` `test_view` | 1 | — | — | layouts `status-top` / `status-bottom`, switched by the breakpoint |
| `Adw.Layout` | 2 | — | — | `status-top`, `status-bottom` |
| `Adw.ToolbarView` | 4 | — | — | one per layout (both `extend-content-to-*-edge`), one for results, one for test-cancelled |
| `Adw.HeaderBar` | 4 | `test` (the two test headerbars) | — | `centering-policy: strict` on the test ones |
| `Adw.LayoutSlot` | 8 | — | — | `stop_button`, `test_status`, `menu_button`, `text_view`, `bottom_stack` — reused across both layouts |
| `Adw.Clamp` | 2 | — | — | max 800, tightening 400, 48px vertical margins |
| `Gtk.Button` `stop_button` | 1 | — | `clicked` → `ready()` | icon `arrow-circular-top-right-symbolic`, tooltip _("Restart"); hidden when not running; opacity hack (0 → 1 after 200ms) to stop it flashing |
| `Gtk.Stack` `status_stack` | 1 | — | — | crossfade 200ms; pages `ready`, `running` |
| `Gtk.DropDown` `test_type_dropdown` | 1 | `flat` **on its first child** (libadwaita workaround) | `notify::selected` via settings bind | `Gtk.StringList` _("Simple"), _("Advanced"), _("Custom"); bound to `session-type` |
| `Gtk.Stack` `secondary_config_stack` | 1 | — | — | shows duration dropdown or custom button per test config |
| `Gtk.DropDown` `duration_dropdown` | 1 | `flat` on first child | `notify::selected-item` → `update_time`, `focus_text_view` | `Gtk.StringList` of the five durations; bound to `session-duration` |
| `Gtk.Button` `custom_button` | 1 | `flat` | `clicked` → `show_custom_text_dialog(None)` | holds an `Adw.ButtonContent` |
| `Adw.ButtonContent` | 1 | — | — | icon `edit-symbolic`, label _("_Edit Text") |
| `Gtk.Label` `status_label` | 1 | `heading` | — | the timer / "n ⁄ total" word counter; `xalign: 0` under the breakpoint |
| `Gtk.MenuButton` `menu_button` | 1 | — | — | primary, `open-menu-symbolic`, tooltip _("Main Menu"), `menu-model: primary_menu`; hidden 200ms after a test starts |
| `$KpTextView` | 1 | — | `notify::running` → `start()`; `typed-text-changed` → finish / extend text / word counter / frustration score / hide cursor | the port's `lib/text_view.rb` |
| `Gtk.Stack` `bottom_stack` | 1 | `toolbar-thick` | — | crossfade, halign center; pages `just_start_typing`, `focus_button`, `bottom_stack_empty` |
| `Gtk.Label` `just_start_typing` | 1 | `dim-label` | — | _("Just Start Typing") |
| `Gtk.Button` `focus_button` | 1 | `pill`, `suggested-action` | `clicked` → `focus_text_view` | _("_Enable Entry") |
| `Adw.Bin` `bottom_stack_empty` | 1 | — | — | the blank third page shown while typing |
| `Adw.WindowTitle` | 1 | — | — | _("Results") on the results header bar |
| `Gtk.ScrolledWindow` | 1 | — | — | results page, `hscrollbar-policy: never` |
| `$KpResultsView` `results_view` | 1 | — | — | horizontal; flipped vertical by the breakpoint |
| `Gtk.Button` `results_continue_button` | 1 | `pill`, `suggested-action` | `clicked` → `ready()` | _("_Continue"); grabs focus 500ms after results appear |
| `Adw.StatusPage` | 1 | — | — | `warning-outline-symbolic`, _("Test Cancelled") + the invalid-keystroke description |
| `Gtk.Button` `frustration_continue_button` | 1 | `pill`, `suggested-action` | `clicked` → `ready()` | grabs focus 1000ms later so a stray keypress cannot activate it |
| `Gtk.Box` | 6 | `toolbar-thick` (the two bottom bars) | — | layout boxes |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 500sp` → `results_view.orientation: vertical`, `test_view.layout-name: "status-bottom"`, `status_label.xalign: 0` |

Controllers (behaviour, from `window/typing_test.rs`): `Gtk.EventControllerMotion`
(`motion` → show cursor, remove `hide-controls`) and `Gtk.GestureClick`
(`released` → same), both on the window.

Actions installed on the window: `win.about`, `win.text-language-dialog`,
`win.cancel-test` — all three `action_set_enabled`-toggled as a test starts and
ends.

Repeaters: none. Conditional: `devel` CSS class; the About / language / custom-text
dialogs all refuse to open while a test is running or another dialog is visible.

---

## src/widgets/window/typing_test.rs — test lifecycle: ready / start / finish / cancel

→ `lib/typing_test_session.rb` — **exists** (509 lines)

No widgets of its own; it drives `lib/window.rb`'s. Worth its own port file
because it is 733 lines of upstream's largest module.

| Component | Notes |
|---|---|
| `Adw.Toast` | _("Changes discarded") with button _("Restore") → reopens the custom-text dialog with the discarded text; added to `toast_overlay` |
| state machine | `ready` → `start` → `finish` (results) / `frustration_relief` (test-cancelled) |
| timer | 100ms tick; label `{}∶{}` with a special Unicode ratio colon, trailing zero below 10s |
| word counter | `{} ⁄ {}` (special Unicode fraction slash) for finite/custom tests |
| frustration detector | `FRUSTRATION_THRESHOLD = 2.2`; cancels the test when incorrect keystrokes in the last 2.2s exceed 22 |
| personal best | `personal-best` GSettings `a(sssu)` keyed by (difficulty, duration, language); only recorded above 90% accuracy; sets `results_view.show-personal-best` |
| settings watches | `session-type`, `text-language`, `custom-text` each refresh the original text and refocus the text view |
| session inhibit | _("Ongoing typing test") while a test runs |

---

## src/widgets/window/focus.rs — the "enable entry" focus affordance

→ `lib/window_focus.rb` — **exists** (74 lines)

| Component | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| window focus watcher | 1 | adds/removes `unfocused` on `$KpTextView` (blurs it 3px) | `notify::focus-widget` | after 2000ms unfocused, swaps `bottom_stack` to `focus_button`; the pending timeout is cancelled if focus returns inside the window |

---

## src/widgets/window/inhibit.rs — logout inhibitor

→ `lib/session_inhibitor.rb` — **exists** (41 lines)

No widgets. `Gtk.ApplicationInhibitFlags::LOGOUT` with a cookie, uninhibited on
test end. `Gtk::Application#inhibit` is present in the bindings.

---

## src/widgets/text_view.blp + text_view.rs + text_view/{input,colors,caret,scrolling,accessibility}.rs — the typing surface

→ `lib/text_view.rb` — **exists** (634 lines); the colour table was split out to `lib/text_view_colors.rb` (213 lines), **exists**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` subclass `KpTextView` | 1 | css-name `KpTextView`; `unfocused` (3px blur); `KpTextView { transition: filter 200ms }` | emits `typed-text-changed`; `notify::running`, `notify::has-focus` | focusable, `overflow: hidden`, accessible-role `text_box`, accessible label _("Text View") + multi-line; custom `measure` (vertical = 3 × 50px line height), `size_allocate`, `snapshot` |
| `Gtk.TextView` | 1 | `KpTextView > textview` — 1.5rem, 50px line-height, no background, ligatures off | — | monospace, not focusable, not editable, `wrap-mode: word_char`, accessible-role `presentation`, `can-target: false`, bottom margin 50 |

Properties: `caret-x`, `caret-y`, `caret-height`, `running`, `accepts-input`.

Controllers: `Gtk.IMMulticontext` (`commit`, `preedit-changed`,
`retrieve-surrounding`, `delete-surrounding`), `Gtk.EventControllerKey`
(`key-pressed` — BackSpace, Ctrl+BackSpace word delete, Escape),
`Gtk.GestureClick` (`released` → grab focus).

Caret: drawn with `Gsk::PathBuilder` + `Gsk::Stroke(1.0)` in `snapshot`, animated
by two `Adw.TimedAnimation` + `Adw.PropertyAnimationTarget` on `caret-x`/`caret-y`.
Scrolling: a third `Adw.TimedAnimation` (300ms) on the text view's vadjustment,
centring the caret line unless on line 1–2.

**16 `Gtk.TextTag`s** — `untyped`, `unfinished` (low underline), `typed`,
`mistake` (fg + bg) × 4 themes (light, light-HC, dark, dark-HC), reselected on
`Adw.StyleManager` `notify::dark` and `notify::high-contrast`. All tags are
removed and reapplied on every recolour.

Accessibility: the current word is pushed as the widget's accessible label each
time a word boundary is crossed.

---

## src/widgets/results_view.blp + results_view.rs — the WPM / accuracy readout

→ `lib/results_view.rb` — **exists** (284 lines)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Widget` subclass `KpResultsView` | 1 | css-name `KpResultsView` | — | `Gtk.BinLayout`; implements `Gtk.Orientable`; properties `show-personal-best`, `orientation` |
| `Gtk.Box` `wpm_accuracy_box` | 1 | — | — | orientation bound to the template's |
| `Gtk.Label` `wpm_label` | 1 | `key-number` (3.5rem, 700) | — | floored WPM |
| `Gtk.Label` `accuracy_label` | 1 | `key-number` | — | `{}%` |
| `Gtk.Image` `personal_best` | 1 | `accent` | — | `arrow3-up-symbolic`, tooltip _("New Personal Best for Configuration"); `visible` bound to `show-personal-best` |
| `Gtk.Image` `personal_best_balancer` | 1 | — | — | invisible spacer, same binding, role `presentation` |
| `Gtk.Separator` | 1 | — | — | between WPM and accuracy |
| `Gtk.Label` (static) | 2 | `dim-label` | — | _("Words per Minute"), _("Accuracy") |
| `Gtk.Box` `test_info_box` | 1 | — | — | homogeneous; orientation bound, and **spacing** bound through a transform (30 horizontal / 18 vertical) |
| `Gtk.Image` | 3 | — | — | `quotation-symbolic`, `timer-symbolic`, `language-symbolic`, all role `presentation` |
| `Gtk.Label` | 3 | — | — | `test_type_label`, `duration_label`, `language_label` |
| `Gtk.Box` `language_box` | 1 | — | — | hidden for custom tests |

Strings: _("Custom"/"Simple"/"Advanced"); durations `{}m {}s`, `{} minute(s)`,
`{} second(s)` (plural forms).

---

## src/widgets/custom_text_dialog.blp + custom_text_dialog.rs — editing the custom text

→ `lib/custom_text_dialog.rb` — **exists** (187 lines)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` `KpCustomTextDialog` | 1 | — | emits `discard` with the abandoned text on close | title _("Custom Text"), 450×500 |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | `show-title: false`, re-shown by binding the scrolled window's vadjustment value > 0 |
| `Gtk.ScrolledWindow` | 1 | — | — | `hscrollbar-policy: never`, `propagate-natural-height` |
| `Gtk.Label` (title) | 1 | `title-1` | — | _("Custom Text") |
| `Gtk.Overlay` | 1 | — | — | places the placeholder over the text view |
| `Gtk.Label` `placeholder` | 1 | `dim-label` | — | _("Insert custom text…"); `visible` bound to buffer text being empty; labels the text view |
| `Gtk.TextView` `text_view` | 1 | `card`, `card-text-view` (12px padding, card fg/bg) | — | `wrap-mode: word_char`, `accepts-tab: false`; initial text selected on open |
| `Gtk.Button` `save_button` | 1 | `pill`, `suggested-action` | `clicked` → writes `custom-text`, closes | _("_Save"); `sensitive` bound to the buffer holding non-whitespace |
| `Gtk.Box` (bottom bar) | 1 | `toolbar-thick` | — | |

---

## src/widgets/text_language_dialog.blp + text_language_dialog.rs — picking the text language

→ `lib/text_language_dialog.rb` — **exists** (459 lines); the repeated row was extracted to `lib/language_row.rb` (40 lines), **exists**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` `KpTextLanguageDialog` | 1 | — | `closed` → writes the 3 most recent languages to `recent-languages` | title _("Text Language"), 450×500, `focus-widget: search_entry` |
| `Adw.NavigationView` | 1 | — | — | pages `choose-language`, `add-language` |
| `Adw.NavigationPage` | 2 | — | — | _("Text Language"), _("Add Language") |
| `Adw.ToolbarView` | 2 | — | — | |
| `Adw.HeaderBar` | 2 | — | — | first reveals its title on scroll; second `show-title: false` |
| `Gtk.Button` (add) | 1 | — | `action-name: navigation.push`, target `'add-language'` | `plus-large-symbolic`, tooltip _("Add Language") |
| `Gtk.ScrolledWindow` | 2 | — | — | `hscrollbar-policy: never` |
| `Gtk.Label` (titles) | 2 | `title-1` | — | _("Text Language"), _("Add Language") |
| `Adw.Clamp` | 1 | — | — | max 360, wraps the search entry |
| `Gtk.SearchEntry` `search_entry` | 1 | `pill-entry` (9999px radius) | `search-changed` → `update_search_state`; `stop-search` → close dialog | placeholder + accessible label _("Search languages…") |
| `Gtk.Stack` `stack` | 1 | — | — | crossfade 100ms, `vhomogeneous: false`; pages `list`, `search-results`, `no-results` |
| `Adw.PreferencesGroup` `group_recent` | 1 | `background` (on the parent box) | — | _("Recent") |
| `Adw.PreferencesGroup` `group_other` | 1 | — | — | _("Other"), alphabetical |
| `Gtk.ListBox` `search_list` | 1 | `boxed-list` | — | `selection-mode: none`, accessible label _("Search Results") |
| `Adw.ActionRow` (language row) | **43 + repeat in search** | — | activatable via its check button | **repeater** over the 43 `Language` values |
| `Gtk.CheckButton` | one per row | — | `action-name: app.text-language`, target the language code | the row's prefix and activatable widget |
| `Gtk.Box` `no_results_box` | 1 | — | — | height locked/unlocked to stop the dialog jumping |
| `Gtk.Image` | 1 | `status-icon` (96px), `dim-label` | — | `language-symbolic` |
| `Gtk.Label` | 2 | `title-2` (first) | — | _("No Matches"), _("Try a different search") |
| `Gtk.Picture` | 1 | — | `realize` → `load_language_illustration` | loads `assets/multilingual.svg` |
| `Gtk.Label` `add_language_desc` | 1 | — | — | the GitHub language-request explainer; describes the button below |
| `Gtk.Button` (create request) | 1 | `suggested-action`, `pill` | `clicked` → `Gtk.UriLauncher` to the GitHub issue template | box with _("_Create Request") + `external-link-symbolic` |

Search normalises with `unidecode` + lowercase and sorts by display name.
43 languages, each needing `data/word_lists/<code>.txt`.

---

## src/widgets/window.blp (`menu primary_menu`) — the main menu

→ `lib/primary_menu.rb` — **exists** (31 lines, its own file rather than inline)

One section, three items: _("Text _Language") → `win.text-language-dialog`;
_("_Keyboard Shortcuts") → `app.shortcuts`; _("_About Keypunch") → `win.about`.

---

## data/resources/shortcuts-dialog.ui — the keyboard shortcuts dialog

→ `lib/shortcuts_dialog.rb` — **exists** (59 lines)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ShortcutsDialog` | 1 | — | — | no backing source file upstream; loaded by libadwaita's automatic `app.shortcuts` |
| `Adw.ShortcutsSection` | 1 | — | — | _("General") |
| `Adw.ShortcutsItem` | 6 | — | — | Open Menu `F10`; Text Language → `win.text-language-dialog`; Cancel Test → `win.cancel-test`; Keyboard Shortcuts → `app.shortcuts`; Close Window → `window.close`; **a second "Text Language" item wired to `app.quit`** — an upstream bug (should be Quit); the port should reproduce the entry with the correct label |

---

## src/widgets/window.rs (`show_about_dialog`) + data/…metainfo.xml.in.in — the About dialog

→ `lib/about_dialog.rb` — **exists** (81 lines)

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | `closed` → refocus the text view | built with `from_appdata` upstream; the port must set the fields itself |

Content: developer "Brage Fuglseth"; link _("Donate"); credit section
_("Orthography by") with 12 names; _("Special thanks to") acknowledgement;
translator credits; copyright "© 2024–2026 Brage Fuglseth"; other-app entry for
Fretboard (_("Fretboard") / _("Look up guitar chords")) with icon
`no.bragefuglseth.Fretboard.svg`.

---

## data/resources/style.css — the app stylesheet

→ `lib/style.rb` (a `Gtk::CssProvider` loading the vendored `data/style.css`) — **exists** (48 lines)

Nine rules defining `KpTextView` (+ `.unfocused`, `> textview`),
`KpResultsView .key-number`, the `headerbar.test .start/.end` fade under
`window.hide-controls`, `.card-text-view`, `.toolbar-thick`, `.status-icon`,
`.pill-entry`. Every class here is applied by one of the components above.

---

## Non-widget support modules (no UI, but the components do not work without them)

| Upstream | → port file | Kind | Present |
|---|---|---|---|
| `src/settings.rs` + `data/no.bragefuglseth.Keypunch.gschema.xml.in` | `lib/settings.rb` | settings schema + dropdown↔enum binding | **exists** (151 lines; file-backed shim, no compiled schema) |
| `src/typing_test_utils.rs` | `lib/typing_test_utils.rb` | test config / duration / summary, WPM + accuracy | **exists** (198 lines) |
| `src/text_utils.rs` | `lib/text_utils.rb` | grapheme validation, replacements, word/line offsets | **exists** (340 lines) |
| `src/text_generation.rs` + `data/word_lists/*.txt` (46 files) | `lib/text_generation.rb` + vendored `data/word_lists/` | 43-language word lists, punctuation/capitalisation generator, 400-grapheme chunks | **exists** (508 lines; all 46 lists vendored) |
| `src/discord_rpc.rs` | `lib/discord_rpc.rb` | Discord IPC rich presence (Ready / Typing / Results) | **exists** (220 lines) |
| `po/` (37 locales, `LINGUAS`, `keypunch.pot`, `POTFILES.in`) | `po/` + `lib/translations.rb` | gettext catalogue | **exists** (37 locales carried over, 62 of 87 messages ported; `lib/translations.rb` is 590 lines) |

GSettings keys: `window-width` (900), `window-height` (450),
`window-maximized`, `session-type` enum (Simple/Advanced/Custom, default
Simple), `session-duration` enum (Sec15/Sec30/Min1/Min5/Min10, default Sec30),
`text-language` (`"en"`, translatable), `recent-languages` (`as`),
`custom-text` (translatable pangram), `personal-best` (`a(sssu)`).

---

## Blockers

Status as of this revision of the inventory — the port has since been written,
so each blocker below carries how it was settled.

1. **`app.shortcuts` is libadwaita magic.** Upstream never installs it;
   libadwaita 1.8 auto-installs it because `shortcuts-dialog.ui` lives at the
   GResource base path. **Settled:** the port installs its own `app.shortcuts`
   and builds the dialog in Ruby (`lib/shortcuts_dialog.rb`).
2. **Custom GObject signals do not work as upstream uses them.**
   `GLib::Object.define_signal` fails in the dev shell (`g_signal_newv failed`).
   **Settled:** `KpTextView`'s `typed-text-changed` and `KpCustomTextDialog`'s
   `discard` are plain Ruby callback blocks passed in at construction.
3. **Two components are `Gtk.Widget` subclasses with custom vfuncs.**
   `KpTextView` overrides `measure`, `size_allocate` and `snapshot`;
   `KpResultsView` sets a `Gtk.BinLayout` and implements `Gtk.Orientable`.
   **Settled:** both are `Gtk::Widget` subclasses via `type_register` in
   `lib/text_view.rb` and `lib/results_view.rb`.
4. **No compiled GSettings schema.** **Settled:** `lib/settings.rb` is a
   file-backed shim with the same keys and defaults; nothing compiles a schema,
   so `personal-best` (`a(sssu)`) is stored as plain Ruby data rather than a
   GVariant. Worth re-checking if the app is ever packaged as a Flatpak.
5. **Blueprint property bindings and breakpoint setters.** **Settled:** wired by
   hand with `bind_property` and `notify::` handlers in `lib/window.rb` and
   `lib/results_view.rb`.
6. **Word lists are vendored data, not code.** **Settled:** all 46 `.txt` files
   copied to `data/word_lists/` and loaded from disk by `lib/text_generation.rb`.
7. **Discord rich presence has no Ruby equivalent in the lockfile.**
   **Settled:** `lib/discord_rpc.rb` speaks the IPC socket protocol directly;
   it degrades to a no-op when no Discord socket is present.
8. **No gettext wiring.**
   **Settled:** upstream's 37 `.po` files, `LINGUAS` and `POTFILES.in` (rewritten
   to the Ruby paths) are in `po/`, and `lib/translations.rb` reads the current
   locale's catalogue straight out of them — the app has no install step, so
   there is no `$LOCALEDIR` of compiled `.mo` files to bind. It implements the
   `Plural-Forms` engine and `msgctxt` lookups the `.po` files need, and the
   special Unicode characters (`⁄`, `∶`) and the plural duration forms sit
   inside their upstream msgids byte for byte. Still open: the GSettings
   schema, desktop entry and metainfo files, which hold the 25 messages the
   port does not emit, and GLib's own domain binding that would translate
   them. See `TRANSLATION_PARITY.md`.
