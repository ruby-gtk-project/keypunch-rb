# Accountability ensurance — keypunch-rb

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` |
| Port | `ruby` @ `de7f6a3` |
| Scan | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` over the whole tree, plus a manual `grep -rniE 'TODO|FIXME|not implemented|for now|in a future|placeholder|stub'` over `lib/`, `exe/`, `.reports/` and the repo root (no `PORTING.md` exists on this branch). |

## Scanner hits

`find-excuses.sh` returned three hits:

```
.reports/component-inventory.md:34  N/A
lib/discord_rpc.rb:17                no Ruby equivalent
lib/text_generation.rb:38            not needed
```

The plain-TODO grep returned **zero** hits in `lib/`, `exe/`, `.reports/` and
the repo root: no `TODO`, `FIXME`, `not implemented`, `for now`, `in a
future`, `placeholder`, or `stub` anywhere in the port's code or reports.

## Each hit, read in context

1. **`.reports/component-inventory.md:34`** — `src/widgets/window/ui_state.rs`
   row: *"empty file (0 bytes) — no logic, no component ... N/A, nothing
   upstream to port."* Verified independently:
   `git show origin/main:src/widgets/window/ui_state.rs | wc -c` → `0`. There
   is no behaviour behind this upstream file to have omitted — it is
   genuinely empty. The scanner is right to flag the literal string "N/A" on
   principle (it is exactly the construction the skill bans, and banning it
   unconditionally is the point: a reader should never have to trust that
   *this* "N/A" was the honest kind), but there is no feature loss hiding
   behind it here. **Verdict: phrasing to clean up, not a real gap.** It
   should still be reworded to something that does not use the banned
   construction at all (e.g. "upstream's file is 0 bytes; there is nothing
   to port"), so that the next reader does not have to re-verify it the way
   this audit just did.

2. **`lib/discord_rpc.rb:17`** — *"speaks the Discord IPC protocol over the
   local socket directly, because there is no Ruby equivalent of the
   crate."* Read the whole file: this is not a dropped feature. The port
   reimplements the same worker-thread-plus-queue shape upstream's
   `discord-presence` crate provides, speaking the same wire protocol
   (opcode-0 handshake, opcode-1 `SET_ACTIVITY` frames, little-endian
   length-prefixed JSON) directly over the IPC socket, including the
   reconnect-and-resend-last-activity behaviour. Nothing upstream does with
   Discord presence is missing from this file on inspection. **Verdict: a
   true statement about implementation strategy, not an excuse for missing
   behaviour** — but the phrase "no Ruby equivalent" is exactly the
   construction the skill flags, and it reads differently out of context
   than in it. Worth rewording to lead with what *was* built ("this port
   speaks the protocol directly because no gem wraps it") so it cannot be
   skimmed as "we didn't do this."

3. **`lib/text_generation.rb:38`** — *"the house style caps a call at three
   arguments, so the sets are data here and the two convenience constructors
   are not needed."* This is about upstream's `Punctuation::suffix` /
   `Punctuation::wrapping` helper constructors, not about the punctuation
   *behaviour*. The port keeps the same `Punctuation` fields
   (`prefix`/`suffix`/`ends_sentence`/`weight`) and the same data for every
   punctuation set — it just expresses the two constructors as a shared
   `punctuation_set(rows)` array literal instead of two methods, a
   code-shape choice with no behavioural consequence. **Verdict: a true
   statement about a refactor, not an excused omission** — no upstream
   behaviour is missing — but again, "not needed" is on the banned list for
   good reason (it is indistinguishable, on a skim, from "we decided to skip
   this"), and should be reworded to name the refactor rather than use that
   phrase.

## Verdict

No instance found in this scan is laundering an actual missing feature as a
decision — each of the three was checked against upstream's actual behaviour
and the behaviour is present. That is a materially different finding from
`console-rb`'s "Dropped deliberately" section, which sat on top of 40 unported
tests and multiple real behavioural regressions. **This port has not done
that.**

That said, this is not "clean" by the letter of the skill: three sentences
exist, today, in committed files, that use constructions the skill
unconditionally bans (`N/A`, "no Ruby equivalent", "not needed"), regardless
of whether the underlying claim checks out. The skill's own position is that
reasonableness is not a mitigation — a future reader has no way to tell, by
reading the sentence alone, that this round verified it. All three should be
reworded (not deleted) to describe the behaviour and the substitution
directly, without the banned phrasing, so the next reader does not have to
re-derive what this audit just did by hand. This is logged as a gap in this
report rather than silently fixed, per the instruction to report findings
rather than resolve them unasked.

Separately, and more substantively: **no `PORTING.md` exists on this branch
at all.** That means there is no single place on `ruby` where a future agent
could write a laundered excuse in the first place — which is good — but it
also means there is no running architecture/cursor document for this port,
which the `test-parity` skill's cross-reference table expects to exist
alongside `TEST_PARITY.md`/`COMPONENT_PARITY.md`/`TRANSLATION_PARITY.md`.
Its absence is noted here as a navigation gap, not an accountability one —
nothing in this round found a sentence trying to stand in for it.
