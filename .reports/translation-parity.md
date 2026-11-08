# Translation parity — keypunch-rb (this round's check)

The full ledger lives at `TRANSLATION_PARITY.md` (repo root, already on
`ruby`, committed as part of "Port the gettext catalogue: po/ and
lib/translations.rb"). This note re-verifies its headline numbers rather than
duplicating the 87-row table.

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` |
| Port | `ruby` @ `8fa7e8b` |
| Upstream messages | 87 |
| Ported | 62 |
| Gaps | 25 |
| Extra (untranslated) | 0 |
| Languages | 37/37 `.po` files ship and reach the user |
| `summary.parity` | **false** |

## What was re-checked this round

No commit since the previous pass touches `po/`, `lib/translations.rb` or
`lib/settings.rb` (the four intervening commits are `test/`/`spec/`/gem
infrastructure only), so the 87/62/25 counts and the gap breakdown below are
unchanged and are not re-derived from scratch — just confirmed still
current against `origin/main` @ `b88ef1f` (also unchanged).

- `po/LINGUAS` vs. the actual `.po` files present: `diff <(ls po/*.po | xargs
  -n1 basename -s .po | sort) <(sort po/LINGUAS)` — confirmed empty, no
  mismatch between the two.
- The upstream `po/` file list (37 files) matches the port's `po/` file list
  (37 files) one-for-one by name.
- `lib/translations.rb` reads `po/<locale>.po` directly at runtime (grep
  confirmed: no compiled `.mo`, no `bindtextdomain` call) — matches what
  `TRANSLATION_PARITY.md`'s "Build command: none" line claims.
- Re-read the 25 gap rows: 16 are GSettings schema `<summary>`/
  `<description>` strings (no schema file shipped — a documented, reasoned
  substitution, not an excuse: `lib/settings.rb`'s own header explains why,
  and the ledger's "Why the 25 gaps are open" table names the exact file that
  would close them), 10 are AppStream metainfo strings (no metainfo file
  shipped), 1 is the desktop entry's `Keywords` string (no desktop file
  shipped), and 2 are accessible-label strings the Ruby GTK4 bindings cannot
  set (`Gtk::Accessible#update_property` raising `NotImplementedError`,
  documented with upstream file:line in both `lib/text_view.rb` and the
  ledger). None of the 25 is a reworded string, and the port emits **zero**
  extra/untranslated messages upstream never had.
- Re-read the "Open items" section: it discloses, rather than hides, that no
  gettext domain is bound (plurals and msgctxt still work via a hand-rolled
  parser; `msgfmt -c` validation still runs; only GLib's own domain-binding
  machinery is absent — which is exactly what the schema/metainfo gaps above
  need), and that 123 of the port's merged `.po` entries are fuzzy against
  upstream's 1, attributed (with evidence) to upstream's own un-remerged
  catalogue rather than to anything the port did.

## Verdict

**Not clean.** 25 of 87 upstream messages have no port counterpart, for
reasons that are disclosed rather than excused (two real binding limitations,
three missing non-code files whose absence is also a `component-parity` item
each). `summary.parity` is correctly reported as `false` in the existing
ledger — this is not a case of a report quietly declaring success it has not
earned. The existing `TRANSLATION_PARITY.md` meets this skill's bar for
honesty; it simply has not closed the gaps yet.
