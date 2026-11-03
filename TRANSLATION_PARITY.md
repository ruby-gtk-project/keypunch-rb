# Translation parity — keypunch

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` |
| Port | `ruby` @ `41f3144` |
| Domain | `keypunch` — the name upstream's `po/meson.build` passes to `i18n.gettext`. The port keeps it as the catalogue directory's identity; it binds no gettext domain (see **Open items**). |
| Upstream messages | 87 |
| Ported | 62 |
| Gaps | 25 |
| Extra (untranslated) | 0 |
| Upstream occurrences | 103 across 87 messages (18 reused) |
| Port occurrences | 80 across 62 messages (15 reused) |
| Upstream languages | 37 `.po` files, 3,065 translated, 33 untranslated, 1 fuzzy |
| Languages shipped by the port | 37 `.po` files, 2,080 translated, 91 untranslated, 123 fuzzy — `LINGUAS` matches the files |
| Build command | none: `lib/translations.rb` reads `po/<locale>.po` at run time, and the flake copies `po/` into the installed tree |
| Regeneration | the three commands in the header comment of `lib/translations.rb` (`rxgettext` → `msgcat` → `msgmerge`) |

All 37 languages upstream ships are present and reach the user. The 25 gaps are
one body of work: upstream keeps 25 of its 87 messages in three files this port
does not have — a GSettings schema, a desktop entry and an AppStream metainfo
file — plus two accessibility labels the Ruby bindings cannot set. No gap is a
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
keypunch devshell — ruby 3.4.9
run the app:   xvfb-run ruby exe/keypunch
drive the app: xvfb-run ruby test/drive_*.rb
run the specs: ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'

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

## data/no.bragefuglseth.Keypunch.gschema.xml.in → lib/settings.rb (16 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 59 | — | `"en"` | single | 1 → 1 | `lib/settings.rb:51` | ported | — |
| 60 | — | `"The quick brown fox jumps over the lazy dog."` | single | 1 → 1 | `lib/settings.rb:54` | ported | — |
| 61 | — | `Custom Text` | single | 3 → 2 | `lib/custom_text_dialog.rb:35`, `lib/custom_text_dialog.rb:116` | ported | — |
| 62 | — | `Languages shown in the list of recent ones in the text language dialog` | single | 1 → 0 | — | **gap** | `Languages shown in the list of recent ones in the text language dialog` |
| 63 | — | `Personal Best` | single | 1 → 0 | — | **gap** | `Personal Best` |
| 64 | — | `Recent Languages` | single | 1 → 0 | — | **gap** | `Recent Languages` |
| 65 | — | `Session Duration` | single | 1 → 0 | — | **gap** | `Session Duration` |
| 66 | — | `Session Type` | single | 1 → 0 | — | **gap** | `Session Type` |
| 67 | — | `Text displayed when “Custom” is chosen from the session menu` | single | 1 → 0 | — | **gap** | `Text displayed when “Custom” is chosen from the session menu` |
| 68 | — | `Text Language` | single | 5 → 4 | `lib/results_view.rb:259`, `lib/text_language_dialog.rb:52`, `lib/text_language_dialog.rb:102`, `lib/text_language_dialog.rb:137` | ported | — |
| 69 | — | `The code of the language used for automatically generated text` | single | 1 → 0 | — | **gap** | `The code of the language used for automatically generated text` |
| 70 | — | `The current highest amount of WPM received for each session type / duration and language` | single | 1 → 0 | — | **gap** | `The current highest amount of WPM received for each session type / duration and language` |
| 71 | — | `The duration of time-based sessions` | single | 1 → 0 | — | **gap** | `The duration of time-based sessions` |
| 72 | — | `Window Height` | single | 1 → 0 | — | **gap** | `Window Height` |
| 73 | — | `Window Maximization` | single | 1 → 0 | — | **gap** | `Window Maximization` |
| 74 | — | `Window Width` | single | 1 → 0 | — | **gap** | `Window Width` |

## data/no.bragefuglseth.Keypunch.desktop.in.in → — (the port ships no desktop entry) (3 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 75 | — | `Keypunch` | single | 3 → 2 | `lib/about_dialog.rb:24`, `lib/window.rb:119` | ported | — |
| 76 | — | `Practice your typing skills` | single | 2 → 1 | `lib/about_dialog.rb:27` | ported | — |
| 77 | — | `typing;trainer;touch typing;keyboard;speed;wpm;words per minute;accuracy;test;` | single | 1 → 0 | — | **gap** | `typing;trainer;touch typing;keyboard;speed;wpm;words per minute;accuracy;test;` |

## data/no.bragefuglseth.Keypunch.metainfo.xml.in.in → — (the port ships no metainfo file) (10 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 78 | — | `Custom text entry` | single | 1 → 0 | — | **gap** | `Custom text entry` |
| 79 | — | `Get ready to accelerate your typing!` | single | 1 → 0 | — | **gap** | `Get ready to accelerate your typing!` |
| 80 | — | `If you are already a racer at typing, Keypunch still has something for you. Try practici…` | single | 1 → 0 | — | **gap** | `If you are already a racer at typing, Keypunch still has something for you. Try practicing with numbers and punctuation, or choose your own text to type out as fast as you can.` |
| 81 | — | `In the middle of a session` | single | 1 → 0 | — | **gap** | `In the middle of a session` |
| 82 | — | `Keypunch is proudly part of GNOME Circle, an initiative that champions the great softwar…` | single | 1 → 0 | — | **gap** | `Keypunch is proudly part of GNOME Circle, an initiative that champions the great software that is available for the GNOME platform. For more information, visit the GNOME Circle website.` |
| 83 | — | `Keypunch lets you practice typing. Thanks to fast-paced sessions with instant feedback a…` | single | 1 → 0 | — | **gap** | `Keypunch lets you practice typing. Thanks to fast-paced sessions with instant feedback afterwards and a plethora of available languages, you might even have a little fun doing so. With determination, proper technique and some time, you will observe a noticeable increase in both the speed and the accuracy of which your thoughts and ideas are put into words on the screen.` |
| 84 | — | `Language selection` | single | 1 → 0 | — | **gap** | `Language selection` |
| 85 | — | `Ready for typing` | single | 1 → 0 | — | **gap** | `Ready for typing` |
| 86 | — | `Session results` | single | 1 → 0 | — | **gap** | `Session results` |
| 87 | — | `There is no doubt that typing on a keyboard is an essential skill in the digital age. Ty…` | single | 1 → 0 | — | **gap** | `There is no doubt that typing on a keyboard is an essential skill in the digital age. Typing fast and accurately gives you more opportunities, more time for what matters to you, and a sense of self-accomplishment.` |

## Why the 25 gaps are open

| Gap group | Count | What it waits on |
|---|---|---|
| GSettings schema summaries and descriptions | 16 | The port has no schema: `lib/settings.rb` stores the same keys as JSON under `XDG_CONFIG_HOME`, because a compiled schema would have to be installed before the app could start from a checkout. These 16 messages are the schema's own `<summary>`/`<description>` text, which GLib shows in tools like dconf-editor; nothing in the port's UI displays them. Two of the schema's messages are *not* in this group — the translatable `<default>` values — because `lib/settings.rb` does carry those, and a German install starts on the German word list with a German pangram. Closing the rest needs a `data/schemas/*.gschema.xml` with `gettext-domain="keypunch"`, which is a component-parity item. |
| AppStream metainfo | 10 | The port ships no `metainfo.xml`. These are the app description paragraphs, the release-notes caption and the five screenshot captions. Closing them needs the file plus `msgfmt --xml` at install time. |
| Desktop entry `Keywords` | 1 | The port ships no `.desktop` file. Its `Name` and `Comment` are already ported through the window title and the about dialog; the search keywords have no other home. |
| Accessibility labels (`Text View`, `Search Results`) | 2 | `Gtk::Accessible#update_property` raises `NotImplementedError` in these bindings — there is no converter for an array of `GtkAccessibleProperty` — so no Ruby code can set an accessible label. `lib/text_view.rb` documents the same limitation for the word-boundary announcement. The msgids stay owed; the fix is in the bindings. |

Counts in that table are gaps by **group**, so the GSettings row is 16 of the
schema's 18 messages and the desktop row is 1 of 3.

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

Its `summary` reads `ported: 54`, `extra: 8` where this ledger says 62 and 0.
The whole difference is the eight hand-censused messages above: the scan cannot
see them upstream, so each one counts as a port-only key there and as a
non-match here. `gaps: 25`, `kind_mismatch: 0` and `languages_missing: []`
agree with this ledger exactly.

`summary.parity` is therefore **false**, and it stays false until the schema,
desktop and metainfo files exist and the bindings can set an accessible label.
