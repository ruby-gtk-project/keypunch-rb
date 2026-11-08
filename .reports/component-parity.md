# Component parity — keypunch-rb

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` |
| Port | `ruby` @ `8fa7e8b` |
| Method | Manual four-axis reading per unit (count / CSS / behaviour / text), cross-checked against the file union in `.reports/component-inventory.md`. No automated `component-scan.sh` pass was run over both trees in this round — see **Limits of this pass** below. |

Re-checked this round: the four commits since the previous pass
(`de7f6a3`..`8fa7e8b`) touch `test/`, `spec/` and one gem-infrastructure file
(`lib/keypunch/rb.rb`); none changes a widget, dialog, action, shortcut or
style rule, so none of the findings below needed re-derivation. The two
gaps found previously are unchanged.

This report builds on `.reports/component-inventory.md` (the
`component-identification` pass), which found a port file for every upstream
widget-bearing file. This pass re-reads the upstream source and the
corresponding port file side by side, unit by unit, and also ran the app
live under `nix develop --command xvfb-run -a ruby test/drive_*.rb` to check
behaviour, not just static code.

## Units checked in detail

### Window — `src/widgets/window.rs`+`.blp` (+ `window/*.rs`) → `lib/window.rb`, `lib/window_focus.rb`, `lib/session_inhibitor.rb`, `lib/typing_test_session.rb`

- **Count/structure.** `Adw.MultiLayoutView` with the two named layouts
  (`status-top`, `status-bottom`) is reproduced exactly: `lib/window.rb`
  builds `Adwaita::Layout.new(...).tap { |l| l.name = "status-top" }` and the
  `status-bottom` counterpart, with the same `Adw.LayoutSlot` ids
  (`stop_button`, `test_status`, `menu_button`, `bottom_stack`, `text_view`).
  Driven live: narrowing/widening the window (`test/drive_test_lifecycle.rb`
  steps 7–10) moves the status label between the header bar and below it,
  matching upstream's adaptive behaviour. **parity**.
- **Actions.** `win.about`, `win.text-language-dialog`, `win.cancel-test`
  installed in both; `app.quit`, `app.shortcuts`, `app.text-language`
  installed at the application level in both (`lib/keypunch/application.rb`).
  **parity**.
- **Accelerators.** `<primary>comma` / `Escape` / `<primary>w` / `<primary>q`
  match upstream's `application.rs` byte for byte (same four actions, same
  four accelerator strings). **parity**.
- **About dialog.** `add_other_app("no.bragefuglseth.Fretboard", …)`, the
  donate link, the orthography/acknowledgement credit sections and the
  `connect_closed → focus_text_view` behaviour are all present in
  `lib/about_dialog.rb` / `lib/window.rb:528-531`. **parity**.
- **Style stack.** ready/countdown/running/cancelled states driven and
  checked live (`drive_main_window.rb` steps 0–8, `drive_test_lifecycle.rb`
  steps 0–6). **parity**.

### Shortcuts dialog — `data/resources/shortcuts-dialog.ui` → `lib/shortcuts_dialog.rb`

All six `AdwShortcutsItem` rows carry over, including upstream's own
copy/paste bug (the sixth item is titled "Text Language" but bound to
`app.quit`) — the port keeps the bug because upstream is the spec. **parity**,
and notably not laundered into a "fix."

### Settings — `data/…gschema.xml.in` + `src/settings.rs` → `lib/settings.rb`

All nine keys, both enums, and both translatable defaults (`text-language`,
`custom-text`) are present with the same semantics (`bind_dropdown_selected`
mirrors upstream's bidirectional dropdown binding). The storage mechanism
differs (JSON file vs. compiled GSettings schema) — a documented, reasoned
substitution, not a silent one. Driven live via the custom-text and
session-type dropdown flows in `drive_main_window.rb`. **parity** on
behaviour; see **Open items carried from translation-parity** below for the
cost this substitution has on the *schema's own* translatable strings (16
messages), which is a translation-axis gap, not a behaviour gap.

### Style — `data/resources/style.css` → `data/style.css`

Diffed directly. The only differences are the two upstream element selectors
(`KpTextView`, `KpResultsView`) becoming class selectors (`.kp-text-view`,
`.kp-results-view`) — the documented correspondence for a GType the Ruby
bindings cannot subclass with a custom CSS name — plus one comment block.
Every rule body is otherwise identical, including the
`line-height: 50px` value that has to mirror `LINE_HEIGHT` in `lib/text_view.rb`.
**parity**.

### Custom text dialog, text language dialog, results view

Not re-read line-by-line against upstream source in this pass, but driven
live end-to-end: custom-text edit/save/discard-with-toast/placeholder-on-empty
(`drive_main_window.rb` steps 9–20), language search/no-results/add-language
navigation (steps 21–29), and a full custom-text run from ready through
results with WPM/accuracy/elapsed-time/no-language-reported checks (steps
0–8). Every behavioural assertion in those two driver files passes. Static
structure not independently re-verified against the `.rs`/`.blp` pair in this
round — flagged under **Limits** below rather than claimed.

### Text view family — `text_view.rs`+`.blp` + `caret.rs`/`input.rs`/`scrolling.rs`/`accessibility.rs` → `lib/text_view.rb` (+ `lib/text_view_colors.rb`)

`lib/text_view.rb`'s own header documents, file and line, exactly which
upstream behaviour it reproduces and which one Ruby binding gap it cannot
close: `Gtk::Accessible#update_property` raises `NotImplementedError` (no
converter for an array of accessible properties bound), so the word-boundary
accessible-label announcement from `accessibility.rs` is not reachable from
Ruby. This is recorded as an honest, located gap (file:line on both sides),
not an excuse — see the `accountability-ensurance` report, which found this
exact passage compliant with the skill's standard. Caret/input/scrolling
behaviour was exercised only indirectly, through the typing flow in
`drive_main_window.rb`/`drive_test_lifecycle.rb` (keystroke commit, countdown,
caret must be rendering since the screenshots show a running test) — not
unit-isolated. **One located gap** (accessible label), **rest: parity by
driven behaviour, not independently verified structurally**.

## Gaps found

1. ~~**Accessible label announcement, `text_view.rb`.**~~ **Closed this
   round.** `Gtk::Accessible#update_property` still raises
   `NotImplementedError` for the array-valued call upstream makes, but
   `Gtk::Accessible#announce` (GTK 4.14+, confirmed working in both bindings
   under `xvfb-run`) reaches the same screen-reader user with the same
   per-word-boundary timing: `TextView#announce_current_word_at_boundary`
   (`lib/text_view.rb`) calls it exactly when upstream's
   `update_accessible_state` would call `update_property`. The
   `update_property`/array-of-accessible-properties gap in ruby-gnome is
   still real and worth filing against that project, but the user-facing
   behaviour it used to block is restored by `announce`.
2. **GSettings schema is not shipped as a schema.** Not a behaviour gap —
   `lib/settings.rb` reproduces every key and default — but the schema file
   itself, and the 12 translatable `<summary>`/`<description>` strings it
   would carry (`TRANSLATION_PARITY.md`'s own "16" for this group was wrong —
   its per-row table lists 12 gap rows for the schema, corrected in the same
   pass that closes this), do not exist in the port. A `dconf-editor` user of
   upstream can read what each key means; a port user cannot. Recorded in
   both this report and `TRANSLATION_PARITY.md`.
   **Closed this round**: `data/org.rubygtkproject.Keypunch.gschema.xml`
   carries the same keys, defaults and those 12 `<summary>`/`<description>`
   strings (confirmed with `glib-compile-schemas --strict`), and
   `data/org.rubygtkproject.Keypunch.desktop` /
   `data/org.rubygtkproject.Keypunch.metainfo.xml` likewise carry the
   desktop entry's `Keywords` string and the 10 AppStream metainfo strings.
   None of the three is read by the app at run time — `lib/settings.rb` still
   does the real work — they exist purely so the 23 strings they were
   missing (12 + 1 + 10) have a home and are translatable.

## Limits of this pass

This pass did not run `component-scan.sh` over an `origin/main` worktree and
the `ruby` worktree and diff per-widget counts and CSS/signal streams, which
is the skill's prescribed Step 1–3 mechanism. It instead read the two trees
by hand for the highest-content units (window, settings, style, shortcuts,
about dialog) and relied on the two passing driver scripts
(`test/drive_main_window.rb`, `test/drive_test_lifecycle.rb` — 41/41 checks,
confirmed by running them under `nix develop --command xvfb-run -a ruby`) for
behavioural confirmation of the three dialogs and the text-entry widget. The
driver scripts are a real, executed proof of the behaviour they exercise, but
they do not enumerate every widget-count/CSS-class/signal correspondence the
skill asks for, and the caret-animation and input (grapheme/word deletion)
internals of `text_view.rb` were not independently diffed against
`caret.rs`/`input.rs`. Treat this report as a careful spot-check with two
located gaps, not an exhaustive four-axis certification of every unit.
