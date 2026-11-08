# Component identification — keypunch-rb (this round's check)

The full inventory lives at `.reports/component-inventory.md` (already on
`ruby`, committed as "Inventory upstream components"). This note re-verifies
it against the current tips of both branches rather than duplicating it.

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` |
| Port | `ruby` @ `8fa7e8b` |

## Re-check performed this round

Four commits landed on `ruby` since the previous round
(`fb672c1`..`8fa7e8b`): `bf0d79d` (gettext catalogue — covered in
`translation-parity.md`), `de7f6a3`/`f30b681` (driver script extensions,
test-only), `c079b5d` (new `spec/` unit suite plus `lib/keypunch/rb.rb`, the
gem entrypoint — covered in `test-parity.md`), and `8fa7e8b` (driver timing
fix — covered in `test-parity.md` and `accountability-ensurance.md`). Only
`lib/keypunch/rb.rb` is a new `lib/` file, and it is gem-infrastructure
(`Keypunch::Rb` namespace for `spec_helper.rb`'s `require "keypunch/rb"`),
not a port of any upstream widget. No upstream-facing component changed.

- Re-ran `git ls-tree -r --name-only origin/main` and confirmed the file list
  the inventory is built from is unchanged in shape: `src/application.rs`,
  `src/main.rs`, `src/config.rs.in`, `src/settings.rs`, `src/discord_rpc.rs`,
  `src/widgets/window.rs`+`.blp` and its four `window/*.rs` behaviour files,
  `src/widgets/custom_text_dialog.rs`+`.blp`,
  `src/widgets/text_language_dialog.rs`+`.blp`,
  `data/resources/shortcuts-dialog.ui`, `src/widgets/results_view.rs`+`.blp`,
  `src/widgets/text_view.rs`+`.blp` and its four `text_view/*.rs` behaviour
  files, `src/typing_test_utils.rs`, `src/text_generation.rs`,
  `src/text_utils.rs`, `data/resources/style.css`, `po/*`.
- Confirmed every port file the inventory names still exists on `ruby`:
  `lib/keypunch/application.rb`, `lib/keypunch/rb/version.rb`,
  `lib/discord_rpc.rb`, `lib/settings.rb`, `lib/window.rb`,
  `lib/window_focus.rb`, `lib/session_inhibitor.rb`,
  `lib/typing_test_session.rb`, `lib/custom_text_dialog.rb`,
  `lib/text_language_dialog.rb`, `lib/shortcuts_dialog.rb`,
  `lib/about_dialog.rb`, `lib/results_view.rb`, `lib/language_row.rb`,
  `lib/primary_menu.rb`, `lib/text_view.rb`, `lib/text_view_colors.rb`,
  `lib/typing_test_utils.rb`, `lib/text_generation.rb`, `lib/text_utils.rb`,
  `lib/style.rb`, `lib/translations.rb`, `exe/keypunch`.
- Confirmed `src/widgets/window/ui_state.rs` is still 0 bytes upstream
  (`git show origin/main:src/widgets/window/ui_state.rs | wc -c` → 0), so the
  inventory's "N/A, nothing upstream to port" row for it is still accurate —
  flagged and checked separately under the accountability-ensurance report,
  since the literal string "N/A" there trips that skill's scanner even though
  manual verification shows there is genuinely no behaviour behind it.
- Confirmed `data/` asset parity for the non-component files the inventory
  marks reference-only: `data/word_lists/*.txt` (46 files upstream, 46 in the
  port's `data/word_lists/`), `data/resources/style.css` ↔ `data/style.css`,
  icons present under `data/icons/hicolor/...` with the app ID renamed
  (`org.rubygtkproject.Keypunch` vs. upstream's `no.bragefuglseth.Keypunch`,
  expected for the fork's own bundle id).

## Conclusion

No upstream widget-bearing file is missing a port-side counterpart. This
confirms the existing inventory rather than superseding it; see
`.reports/component-inventory.md` for the full file-by-file table and the
`component-parity` report for whether each counterpart actually matches on
count/style/behaviour/text.
