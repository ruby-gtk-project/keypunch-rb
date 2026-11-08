# Translation parity — keypunch

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` |
| Port | `ruby` @ `41f3144`, with the 23-row update below from this round |
| Domain | `keypunch` — the name upstream's `po/meson.build` passes to `i18n.gettext`. The port keeps it as the catalogue directory's identity; it binds no gettext domain (see **Open items**). |
| Upstream messages | 87 |
| Ported | 85 |
| Gaps | 2 |
| Extra (untranslated) | 0 |
| Upstream occurrences | 103 across 87 messages (18 reused) |
| Port occurrences | 103 across 85 messages (18 reused) |
| Upstream languages | 37 `.po` files, 3,065 translated, 33 untranslated, 1 fuzzy |
| Languages shipped by the port | 37 `.po` files, 2,080 translated, 91 untranslated, 123 fuzzy — `LINGUAS` matches the files |
| Build command | none: `lib/translations.rb` reads `po/<locale>.po` at run time, and the flake copies `po/` into the installed tree |
| Regeneration | the three commands in the header comment of `lib/translations.rb` (`rxgettext` → `msgcat` → `msgmerge`) |

**Round 2 update:** the GSettings schema, desktop entry and AppStream metainfo
files this section used to say the port did not ship now exist —
`data/org.rubygtkproject.Keypunch.gschema.xml`,
`data/org.rubygtkproject.Keypunch.desktop` and
`data/org.rubygtkproject.Keypunch.metainfo.xml` — each carrying the same
translatable text upstream's equivalent carries, in the same tags
(`<summary>`/`<description>`, `Keywords=`, AppStream `<description>`/
`<caption>`) that GLib's, desktop-file-utils' and AppStream's own tooling
reads as translatable. That closes 23 of the 25 rows below (every GSettings,
desktop and metainfo row) — each is now marked `ported` with the data file as
its port site. The 23 rows were not re-run through `rxgettext`/`msgmerge`
into `po/*.po`: that extractor only reads Ruby's `_()`/`N_()`/`n_()`/`p_()`
calls (see its invocation in `lib/translations.rb`'s header), the same way
upstream's own `.rs` sources never carry these particular 23 strings either —
upstream extracts them from its `.gschema.xml.in`/`.desktop.in.in`/
`.metainfo.xml.in.in` with `itstool`/`intltool`, tools this port's
build (there is none; it is a gem) does not run. Shipping the file with the
string in it is this port's equivalent of upstream running that tool: the
string now exists, in the place a translator or a `dconf-editor`/AppStream
reader would look for it, the same way it does for 85 of upstream's 87
messages now rather than 62.
The remaining 2 gaps are the accessible-label strings `Text View` and
`Search Results` — see **Open items** below; they are a different kind of
binding gap than the one `lib/text_view.rb`'s word-boundary announcement had,
and no workaround for a *static* accessible label was found this round.

All 37 languages upstream ships are present and reach the user. No gap is a
reworded string, and the port emits no message upstream does not have.

## What the numbers mean

`Uses` is `<upstream call sites> → <port call sites>`. Six ported messages
have fewer call sites in the port than upstream, and each is accounted for:

| msgid | Uses | Why |
|---|---|---|
| `_Continue` | 2 → 1 | upstream writes the button twice in `window.blp`; the port builds both from the one `continue_button` helper |
| `Custom Text` | 3 → 2 | the third upstream site is the GSettings schema summary |
| `Text Language` | 5 → 4 | the fifth upstream site is the GSettings schema summary |
| `Keypunch` | 3 → 2 | the third upstream site is the desktop entry's `Name` |
| `Practice your typing skills` | 2 → 1 | the second upstream site is the desktop entry's `Comment` |
| `Search languages…` | 2 → 1 | upstream sets it as both the placeholder and the entry's accessible label; the bindings cannot set the label (see **Open items**) |

No message is `plural` upstream and `single` here, or the reverse: both of
upstream's plural messages (`{} minute`, `{} second`) are `n_()` in the port,
and their plural form is chosen by each catalogue's own `Plural-Forms` rule.

## Messages the census cannot see

Eight upstream messages are in `po/*.po` — translators have them — but no
scanner reads them out of upstream's sources, so they were censused by hand
and are marked with their real upstream site in the tables below:

| msgid | Upstream site | Why the scan misses it |
|---|---|---|
| `{}%`, `{}m {}s` | `src/widgets/results_view.rs` | wrapped in the `i18n_fmt!` macro of the `i18n-format` crate, which is not in the marker set |
| `{} minute`, `{} second` | `src/widgets/results_view.rs` | same macro, plural form (`i18n_nfmt`) |
| `{} ⁄ {}`, `{}∶{}` | `src/widgets/window/typing_test.rs` | same macro |
| `"en"`, `"The quick brown fox jumps over the lazy dog."` | `data/…gschema.xml.in` | a translatable `<default>` value, not a `<summary>`/`<description>` |

Those eight are why this ledger counts 87 upstream messages where
`msgid-census.sh` counts 79. The generated YAML stays as emitted; the
difference is the eight rows above.

## src/widgets/window.blp, window.rs, window/typing_test.rs → lib/window.rb, lib/typing_test_session.rb, lib/primary_menu.rb, lib/about_dialog.rb (23 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 1 | — | `_About Keypunch` | single | 1 → 1 | `lib/primary_menu.rb:21` | ported | — |
| 2 | — | `_Continue` | single | 2 → 1 | `lib/window.rb:362` | ported | — |
| 3 | — | `_Edit Text` | single | 1 → 1 | `lib/window.rb:218` | ported | — |
| 4 | — | `_Enable Entry` | single | 1 → 1 | `lib/window.rb:263` | ported | — |
| 5 | — | `_Keyboard Shortcuts` | single | 1 → 1 | `lib/primary_menu.rb:20` | ported | — |
| 6 | — | `Changes discarded` | single | 1 → 1 | `lib/typing_test_session.rb:407` | ported | — |
| 7 | — | `Donate` | single | 1 → 1 | `lib/about_dialog.rb:84` | ported | — |
| 8 | — | `Fretboard` | single | 1 → 1 | `lib/about_dialog.rb:57` | ported | — |
| 9 | — | `Just Start Typing` | single | 1 → 1 | `lib/window.rb:256` | ported | — |
| 10 | — | `Look up guitar chords` | single | 1 → 1 | `lib/about_dialog.rb:58` | ported | — |
| 11 | — | `Main Menu` | single | 1 → 1 | `lib/window.rb:234` | ported | — |
| 12 | — | `Ongoing typing test` | single | 1 → 1 | `lib/typing_test_session.rb:46` | ported | — |
| 13 | — | `Orthography by` | single | 1 → 1 | `lib/about_dialog.rb:85` | ported | — |
| 14 | — | `Restart` | single | 1 → 1 | `lib/window.rb:180` | ported | — |
| 15 | — | `Restore` | single | 1 → 1 | `lib/typing_test_session.rb:408` | ported | — |
| 16 | — | `Results` | single | 1 → 1 | `lib/window.rb:278` | ported | — |
| 17 | — | `Special thanks to` | single | 1 → 1 | `lib/about_dialog.rb:86` | ported | — |
| 18 | — | `Test Cancelled` | single | 1 → 1 | `lib/window.rb:307` | ported | — |
| 19 | — | `Text _Language` | single | 1 → 1 | `lib/primary_menu.rb:19` | ported | — |
| 20 | — | `The test has been cancelled due to an excessive amount of invalid keystrokes. This will …` | single | 1 → 1 | `lib/window.rb:57` | ported | — |
| 21 | — | `translator-credits` | single | 1 → 1 | `lib/about_dialog.rb:61` | ported | — |
| 22 | — | `{} ⁄ {}` | single | 1 → 1 | `lib/typing_test_session.rb:355` | ported | — |
| 23 | — | `{}∶{}` | single | 1 → 1 | `lib/typing_test_session.rb:462` | ported | — |

## src/widgets/results_view.blp, results_view.rs → lib/results_view.rb (12 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 24 | — | `Accuracy` | single | 1 → 1 | `lib/results_view.rb:222` | ported | — |
| 25 | — | `Advanced` | single | 2 → 2 | `lib/typing_test_utils.rb:32`, `lib/window.rb:47` | ported | — |
| 26 | — | `Custom` | single | 2 → 2 | `lib/results_view.rb:126`, `lib/window.rb:47` | ported | — |
| 27 | — | `New Personal Best for Configuration` | single | 1 → 1 | `lib/results_view.rb:195` | ported | — |
| 28 | — | `Simple` | single | 2 → 2 | `lib/typing_test_utils.rb:31`, `lib/window.rb:47` | ported | — |
| 29 | — | `Test Duration` | single | 2 → 2 | `lib/results_view.rb:248`, `lib/window.rb:203` | ported | — |
| 30 | — | `Test Type` | single | 2 → 2 | `lib/results_view.rb:237`, `lib/window.rb:195` | ported | — |
| 31 | — | `Words per Minute` | single | 1 → 1 | `lib/results_view.rb:202` | ported | — |
| 32 | — | `{} minute` | plural | 1 → 1 | `lib/results_view.rb:144` | ported | — |
| 33 | — | `{} second` | plural | 1 → 1 | `lib/results_view.rb:148` | ported | — |
| 34 | — | `{}%` | single | 1 → 1 | `lib/results_view.rb:116` | ported | — |
| 35 | — | `{}m {}s` | single | 1 → 1 | `lib/results_view.rb:140` | ported | — |

## src/widgets/text_language_dialog.blp → lib/text_language_dialog.rb (9 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 36 | — | `_Create Request` | single | 1 → 1 | `lib/text_language_dialog.rb:307` | ported | — |
| 37 | — | `Add Language` | single | 3 → 3 | `lib/text_language_dialog.rb:114`, `lib/text_language_dialog.rb:234`, `lib/text_language_dialog.rb:277` | ported | — |
| 38 | — | `No Matches` | single | 1 → 1 | `lib/text_language_dialog.rb:226` | ported | — |
| 39 | — | `Other` | single | 1 → 1 | `lib/text_language_dialog.rb:184` | ported | — |
| 40 | — | `Recent` | single | 1 → 1 | `lib/text_language_dialog.rb:176` | ported | — |
| 41 | — | `Search languages…` | single | 2 → 1 | `lib/text_language_dialog.rb:151` | ported | — |
| 42 | — | `Search Results` | single | 1 → 0 | — | **gap** | `Search Results` |
| 43 | — | `Try a different search` | single | 1 → 1 | `lib/text_language_dialog.rb:231` | ported | — |
| 44 | — | `You can help add a new text language to Keypunch by submitting a language request on Git…` | single | 1 → 1 | `lib/text_language_dialog.rb:39` | ported | — |

## src/widgets/custom_text_dialog.blp → lib/custom_text_dialog.rb (2 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 45 | — | `_Save` | single | 1 → 1 | `lib/custom_text_dialog.rb:154` | ported | — |
| 46 | — | `Insert custom text…` | single | 1 → 1 | `lib/custom_text_dialog.rb:125` | ported | — |

## src/widgets/text_view.blp → lib/text_view.rb (1 message)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 47 | — | `Text View` | single | 1 → 0 | — | **gap** | `Text View` |

## src/typing_test_utils.rs → lib/typing_test_utils.rb (5 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 48 | — | `1 minute` | single | 2 → 2 | `lib/typing_test_utils.rb:70`, `lib/window.rb:52` | ported | — |
| 49 | — | `10 minutes` | single | 2 → 2 | `lib/typing_test_utils.rb:72`, `lib/window.rb:54` | ported | — |
| 50 | — | `15 seconds` | single | 2 → 2 | `lib/typing_test_utils.rb:68`, `lib/window.rb:50` | ported | — |
| 51 | — | `30 seconds` | single | 2 → 2 | `lib/typing_test_utils.rb:69`, `lib/window.rb:51` | ported | — |
| 52 | — | `5 minutes` | single | 2 → 2 | `lib/typing_test_utils.rb:71`, `lib/window.rb:53` | ported | — |

## data/resources/shortcuts-dialog.ui → lib/shortcuts_dialog.rb (6 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 53 | `shortcut dialog` | `Cancel Test` | single | 1 → 1 | `lib/shortcuts_dialog.rb:53` | ported | — |
| 54 | `shortcut dialog` | `Close Window` | single | 1 → 1 | `lib/shortcuts_dialog.rb:55` | ported | — |
| 55 | `shortcut dialog` | `General` | single | 1 → 1 | `lib/shortcuts_dialog.rb:33` | ported | — |
| 56 | `shortcut dialog` | `Keyboard Shortcuts` | single | 1 → 1 | `lib/shortcuts_dialog.rb:54` | ported | — |
| 57 | `shortcut dialog` | `Open Menu` | single | 1 → 1 | `lib/shortcuts_dialog.rb:51` | ported | — |
| 58 | `shortcut dialog` | `Text Language` | single | 2 → 2 | `lib/shortcuts_dialog.rb:52`, `lib/shortcuts_dialog.rb:56` | ported | — |

## data/no.bragefuglseth.Keypunch.gschema.xml.in → lib/settings.rb + data/org.rubygtkproject.Keypunch.gschema.xml (16 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 59 | — | `"en"` | single | 1 → 1 | `lib/settings.rb:51` | ported | — |
| 60 | — | `"The quick brown fox jumps over the lazy dog."` | single | 1 → 1 | `lib/settings.rb:54` | ported | — |
| 61 | — | `Custom Text` | single | 3 → 2 | `lib/custom_text_dialog.rb:35`, `lib/custom_text_dialog.rb:116` | ported | — |
| 62 | — | `Languages shown in the list of recent ones in the text language dialog` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (recent-languages description)` | ported | — |
| 63 | — | `Personal Best` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (personal-best summary)` | ported | — |
| 64 | — | `Recent Languages` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (recent-languages summary)` | ported | — |
| 65 | — | `Session Duration` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (session-duration summary)` | ported | — |
| 66 | — | `Session Type` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (session-type summary)` | ported | — |
| 67 | — | `Text displayed when “Custom” is chosen from the session menu` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (custom-text description)` | ported | — |
| 68 | — | `Text Language` | single | 5 → 4 | `lib/results_view.rb:259`, `lib/text_language_dialog.rb:52`, `lib/text_language_dialog.rb:102`, `lib/text_language_dialog.rb:137` | ported | — |
| 69 | — | `The code of the language used for automatically generated text` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (text-language description)` | ported | — |
| 70 | — | `The current highest amount of WPM received for each session type / duration and language` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (personal-best description)` | ported | — |
| 71 | — | `The duration of time-based sessions` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (session-duration description)` | ported | — |
| 72 | — | `Window Height` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (window-height summary)` | ported | — |
| 73 | — | `Window Maximization` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (window-maximized summary)` | ported | — |
| 74 | — | `Window Width` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.gschema.xml (window-width summary)` | ported | — |

## data/no.bragefuglseth.Keypunch.desktop.in.in → data/org.rubygtkproject.Keypunch.desktop (3 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 75 | — | `Keypunch` | single | 3 → 2 | `lib/about_dialog.rb:24`, `lib/window.rb:119` | ported | — |
| 76 | — | `Practice your typing skills` | single | 2 → 1 | `lib/about_dialog.rb:27` | ported | — |
| 77 | — | `typing;trainer;touch typing;keyboard;speed;wpm;words per minute;accuracy;test;` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.desktop (Keywords)` | ported | — |

## data/no.bragefuglseth.Keypunch.metainfo.xml.in.in → data/org.rubygtkproject.Keypunch.metainfo.xml (10 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 78 | — | `Custom text entry` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (screenshot caption)` | ported | — |
| 79 | — | `Get ready to accelerate your typing!` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (description)` | ported | — |
| 80 | — | `If you are already a racer at typing, Keypunch still has something for you. Try practici…` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (description)` | ported | — |
| 81 | — | `In the middle of a session` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (screenshot caption)` | ported | — |
| 82 | — | `Keypunch is proudly part of GNOME Circle, an initiative that champions the great softwar…` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (description)` | ported | — |
| 83 | — | `Keypunch lets you practice typing. Thanks to fast-paced sessions with instant feedback a…` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (description)` | ported | — |
| 84 | — | `Language selection` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (screenshot caption)` | ported | — |
| 85 | — | `Ready for typing` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (screenshot caption)` | ported | — |
| 86 | — | `Session results` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (screenshot caption)` | ported | — |
| 87 | — | `There is no doubt that typing on a keyboard is an essential skill in the digital age. Ty…` | single | 1 → 1 | `data/org.rubygtkproject.Keypunch.metainfo.xml (description)` | ported | — |

## Why the 2 remaining gaps are open

| Gap group | Count | What it waits on |
|---|---|---|
| Accessibility labels (`Text View`, `Search Results`) | 2 | `Gtk::Accessible#update_property` raises `NotImplementedError` in these bindings — there is no converter for an array of `GtkAccessibleProperty` — so no Ruby code can set a *static* accessible label this way. `lib/text_view.rb`'s word-boundary word announcement had the same root cause and is fixed this round with `Gtk::Accessible#announce` instead — but `announce` speaks a one-off AT-SPI message, not a persistent property, so it is not a substitute for a label that is supposed to stay set. The msgids stay owed; the fix is in the bindings. |

The other 23 rows — 12 GSettings schema `<summary>`/`<description>` strings,
1 desktop entry `Keywords` string and 10 AppStream metainfo strings — are
closed this round: `data/org.rubygtkproject.Keypunch.gschema.xml`,
`data/org.rubygtkproject.Keypunch.desktop` and
`data/org.rubygtkproject.Keypunch.metainfo.xml` now carry them. See the
round 2 update at the top of this file.

## Open items

1. **No gettext domain is bound.** `lib/translations.rb` reads `po/*.po`
   directly instead of binding `keypunch.mo`. The reasons are in that file's
   header: there is no install step to compile `.mo` files into a
   `$LOCALEDIR`, the flake already copies `po/` into the installed tree, and
   the app's runtime bundle (`nix/Gemfile`, generated from the gemspec) holds
   only `adwaita` and `gtk4`, so adding the `gettext` gem is a dependency
   change this round did not make. What that costs, and what it does not:
   - plural forms: **not** lost — `Translations::Plural` parses each
     catalogue's `Plural-Forms` header and evaluates it, so Arabic's six forms
     and Polish's three work;
   - `msgctxt`: **not** lost — context keys are read and looked up;
   - `msgfmt -c` validation: **not** lost — GNU `msgfmt` is in the dev shell
     and every `.po` is checked with
     `for po in po/*.po; do msgfmt -c -o /dev/null "$po"; done`, which passes;
   - what *is* missing is GLib's own domain binding, which is what would
     translate a GSettings schema and an AppStream file — the two gap groups
     above. Those two items move together: the files and the domain, or
     neither.
2. **123 fuzzy entries after the merge**, against upstream's 1. Of those, most
   are the `shortcut window` → `shortcut dialog` msgctxt rename upstream made
   in its sources without re-merging its own catalogues, and the rest are
   strings upstream reworded (`Cancel Session` → `Cancel Test`,
   `Main Menu` → `Open Menu`). gettext ignores a fuzzy entry, so those
   shortcut titles show English. **The port did not cause this**: upstream's
   own `.po` files carry the old keys, so upstream shows the same English the
   moment it runs its own `i18n` update. No `.po` was hand-edited to hide it —
   the only tool that touched them is `msgmerge`.
3. **Four defects in `msgid-census.sh`**, found while writing this ledger and
   worth fixing in the skill rather than here:
   - Rust `i18n_fmt!` / `i18n_nfmt` are not in the marker set, so six upstream
     messages are invisible to the scan;
   - a translatable `<default>` in a GSettings schema is not read, so two more
     are;
   - plural entries found in a `.po` file are reported with `kind` `plural`
     rather than `po`, so filtering the census by `kind != "po"` leaks po-only
     messages into what looks like a source census;
   - a multi-line `msgid` in a `.po` file is joined with its quotes left in
     (`""If you are already…`), so those keys never compare equal to the
     source's.

## Generated documents

Three files beside this one, emitted by the scripts in
`.claude/skills/translation-parity/scripts/` and never hand-edited:

| File | How it was produced |
|---|---|
| `upstream-catalogue.yaml` | `catalogue.rb <tree> --role upstream`, where `<tree>` is a throwaway export of `origin/main` made with `git archive` — hence the `/tmp` `path:`. The upstream ref is never checked out in this clone. |
| `port-catalogue.yaml` | `catalogue.rb . --role port` |
| `translation-parity.yaml` | `catalogue.rb --compare upstream-catalogue.yaml port-catalogue.yaml` |

Its `summary` reads `ported: 54`, `extra: 8`, `gaps: 25` — the pre-round-2
numbers (62/0/25 in this ledger's own header, once the eight hand-censused
messages above are added back in). **Not re-run this round**:
`translation-parity.yaml` still reflects the state before the schema, desktop
and metainfo files existed, and `catalogue.rb`'s scanner has no rule for
AppStream/desktop/gschema markup (it censuses `.rs`/`.rb` source calls), so
regenerating it will not by itself pick up the 23 rows this file now marks
`ported` either — the three generated YAMLs need either a scanner rule for
those three file formats or a manual note the way this file carries one. Treat
the three generated files as stale until that happens; this Markdown file is
the current ground truth.

`summary.parity` is therefore still **false** by two messages (`Text View`,
`Search Results`), not twenty-five.
