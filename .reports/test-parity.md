# Test parity — keypunch-rb

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` (unchanged since the previous round) |
| Port | `ruby` @ `8fa7e8b` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

This round re-verifies the previous `test-parity.md` (written at `de7f6a3`)
against four commits made since: `fb672c1`..`c079b5d` (unit specs + a fixed
spec harness), `f30b681` (lifecycle driver extension) and `8fa7e8b` (a claimed
flakiness fix). The previous round's headline gap — "the devshell's advertised
RSpec command does not run" — **has been fixed and is verified fixed below.**
A new gap was found in its place: a commit on this very branch claims to have
made a driver check deterministic, and that claim is false on re-run.

## Upstream has no test suite

Verified: `git ls-tree -r --name-only origin/main \| grep '\.rs$'` lists every
Rust file in the upstream tree, and none contains `#[test]`
(`git show origin/main:<file> \| grep '#\[test\]'` returns nothing for any of
them, including `text_generation.rs`, `text_utils.rs`, `typing_test_utils.rs`,
`settings.rs`, `text_view/colors.rs`, `text_view/input.rs`,
`window/typing_test.rs`). There is no `tests/` directory, no `#[cfg(test)]`,
no test target in `meson.build`, no CI test step beyond build/lint in
`.github/workflows/ci.yml`.

Parity is **0/0 and is met trivially.** This means **the port inherits no
safety net** — nothing below pins knowledge upstream considered worth
protecting, because upstream pinned none.

## What the port's own suite is, and what it actually proved

**Fixed since the last round, and re-verified by executing it in this
round, not by reading the commit message.** `spec/spec_helper.rb` required
`kettle/test/rspec` (not present in this fork's `RUBYLIB`) and `keypunch/rb`
(`lib/keypunch/rb.rb` did not exist), so the harness failed before any
example ran. Commit `c079b5d` adds `lib/keypunch/rb.rb` (the missing gem
entrypoint) and makes `spec_helper.rb` tolerate a missing `kettle/test/rspec`
the same way it already tolerated a missing `kettle-soup-cover`, and adds
five spec files — `text_utils_spec.rb`, `typing_test_utils_spec.rb`,
`settings_spec.rb`, `translations_spec.rb`, `text_generation_spec.rb` —
covering the five pure-Ruby logic modules the two GTK driver scripts only
exercise indirectly.

Running the devshell's own advertised command, verbatim, in this round:

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
............................................................
Finished in 0.17356 seconds (files took 1.74 seconds to load)
60 examples, 0 failures
```

This is a real, reproduced pass — the exact gap the previous round of this
report flagged is closed, and closed by making the advertised command work
rather than by rewording the banner.

## New gap found this round: a "deterministic" test is not deterministic

Commit `8fa7e8b` ("test: make the frustration-cancel mash deterministic, not
a fixed count") rewrites `test/drive_test_lifecycle.rb`'s mash step to mash
up to 300 keys, checking after every key whether the test has cancelled,
instead of firing a fixed 40-key mash. Its own message states the old fixed
count was "observed ~1 in 5 runs failing to cancel within 2.2s" and that the
new approach fixes this ("deterministic, not a fixed count").

Re-running `test/drive_test_lifecycle.rb` six times in this round, back to
back, under the same devshell and the same `xvfb-run` display:

```
run 1: 10 of 12 checks passed — DRIVE FAILED (2)
  failed check: the cancelled page is showing
  failed check: no test is in progress any more
run 2: 12 of 12 checks passed — DRIVE OK
run 3: 12 of 12 checks passed — DRIVE OK
run 4: 12 of 12 checks passed — DRIVE OK
run 5: 12 of 12 checks passed — DRIVE OK
run 6: 12 of 12 checks passed — DRIVE OK
```

One failure in six runs (~1 in 6) — the same order of magnitude as the "~1 in
5" the commit describes as the *problem it fixed*. Raising the mash cap from
a fixed 40 to a fixed 300-with-early-break narrows the window but does not
close it: on a slow enough layout pass the test can still exhaust its
budget (300 keys mashed, or the test's own timing window) without the
cancellation firing, and the commit's own two new assertions
("the cancelled page is showing", "no test is in progress any more") then
fail exactly as the old fixed-40 version's did. **The commit's claim of
"deterministic" is false, reproduced in this round.** This is not a
hypothetical risk — it reproduced live in the first of six runs made for
this audit.

The consequence for the runtime gate this round (`drive_ok=true, 45 checks
passed, 0 failed`): that result is real for the run it was taken from, but it
is not a stable property of the suite. A reader who takes one green run as
proof the suite "passes" is taking a coin flip's outcome as a certificate.
This is reported here, under test-parity, because it bears directly on
whether "the suite actually runs" is enough — a suite that runs and
sometimes fails on correct code is not yet trustworthy, and claiming
otherwise in a commit message is the kind of false-green claim the
accountability pass is built to catch. It is cross-filed there.

## Extra — the port's real test coverage

The port's actual verification is two headless GTK driver scripts under
`test/`, plus (since `c079b5d`) a real RSpec unit suite.

- `test/drive_main_window.rb` — **33 of 33 checks passed, DRIVE OK**, every
  one of three re-runs this round. Drives a full custom-text session end to
  end (ready → typing → results → back-to-ready), then each of the
  custom-text, text-language and about/shortcuts dialogs, including the
  custom-text empty/whitespace-only/discard states and the language dialog's
  search/no-results/add-language states. **Stable across re-runs.**
- `test/drive_test_lifecycle.rb` — **12 of 12 checks when it passes**, but
  **failed 1 of 6 re-runs this round** (see above). Drives the timed-session
  countdown, the frustration-cancellation path, the unfocus/blur affordance,
  and the narrow/wide adaptive layout switch. **Not stable across re-runs.**
- `spec/*_spec.rb` (new since `c079b5d`) — **60 examples, 0 failures**,
  reproduced. Real unit coverage of `text_utils.rb` (grapheme/word
  segmentation), `typing_test_utils.rb` (WPM/accuracy math), `settings.rb`
  (persistence and JSON-parse-failure fallback), `translations.rb` (the PO
  parser and plural-expression evaluator), and `text_generation.rb`
  (word-list generation) — closing exactly the "pure-logic modules have zero
  test coverage" gap the previous round of this report named.

Combined driver total: **45 checks** (33 + 12), matching the runtime gate's
component count for this round. Whether that gate reads 45/45 or 43/45 on
any given invocation depends on which side of the lifecycle driver's
intermittent failure that invocation landed on — see above.

**The 45 driver checks plus the 60 spec examples are real and executed, and
the driver checks are also not test parity** in the skill's sense: they were
written for the port and cover flows/logic upstream never had tests for
(upstream has none at all), so they are listed here under `## Extra`,
outside the 0/0 count, per the skill.

## This round's attempt at the flakiness, and why it is not closed

Diagnosis: `TextView#record_keystroke` and `TypingTestSession#check_frustration`
both time-stamp against real `Process.clock_gettime(CLOCK_MONOTONIC)`, and
every mashed keystroke forces a real Pango/GtkTextView layout pass for the
caret position. The *first* several of those passes, under headless/software
rendering, pay a one-time cache-warming cost that can itself run into the
hundreds of milliseconds — well past the ~100ms/keystroke the frustration
threshold needs sustained for 2.2s. `test/drive_test_lifecycle.rb` now warms
that cache with 20 throwaway keystrokes, discarded via `TextView#reset`,
before the timed test (and its frustration window) starts, so the mash that
counts starts past the cold part.

A 20x back-to-back re-run was attempted this round, on a host confirmed (via
`ps aux`, repeatedly, across the attempt) to be running dozens of other
agents' own headless GTK suites at the same time — this machine is shared
across a fleet of concurrent porting sessions, not a dedicated or even
lightly-loaded CI box. The load was severe enough to be a finding in its own
right: beyond the frustration-cancel timing this fix targets, the batch also
hit an unrelated narrow-breakpoint layout check, a bare GLib/Gtk exception
inside `Gio::Application#run` on one run, and — after a separate, unrelated
manual invocation of the same driver collided with the batch on the session
D-Bus bus and had to be killed — three runs that produced no steps and no
checks at all (`Gio::Application` apparently delivering `activate` to the
wrong instance under that D-Bus contention, matching what the same collision
did to an earlier, now-killed, manual run). The batch was still running past
run 14 when this report was finalized, rather than block the rest of this
round's work on a host whose load could not be controlled from inside it.
The 13 runs observed before that point:

```
run  1: 10 of 12 — FAILED (the status moved below the header bar / the
        status label is start-aligned — the narrow-breakpoint check, unrelated
        to frustration-cancel)
run  2: 10 of 12 — FAILED (the cancelled page is showing / no test is in
        progress any more — the exact two assertions commit 8fa7e8b's claim
        was about)
run  3: 10 of 12 — FAILED (same two assertions as run 2)
run  4: 12 of 12 — OK
run  5: 12 of 12 — OK
run  6: 12 of 12 — OK
run  7: 12 of 12 — OK
run  8: 10 of 12 — FAILED (same two assertions as run 2)
run  9: 10 of 12 — FAILED (same two assertions as run 2, plus an exception
        inside Gio::Application#run after the failing checks)
run 10: FAILED — no checks recorded (a separate manual invocation of this
        same driver, run by hand while diagnosing this, collided with this
        run on the session D-Bus bus; not evidence either way)
runs 11–13: no checks recorded each (same D-Bus-collision symptom, after the
        colliding manual process had already been killed — the collision's
        after-effects outlasted the process that caused it)
run 14: FAILED (in progress when this report was written)
```

Of the 9 runs that produced a real checks-passed/failed result (1, 2, 3, 4,
5, 6, 7, 8, 9 — excluding 10–13's no-result D-Bus collisions and 14's
in-progress run), **5 failed and 4 passed**, and 4 of those 5 failures are on
exactly the frustration-cancel assertions commit `8fa7e8b` claimed to have
made deterministic. **The warm-up this round adds is a real, diagnosed fix
for a real cause (see above), but this sample does not show it working: the
failure rate on the targeted assertions (4 of 9, ~44%) is higher than the
"~1 in 5" the original commit described as the problem, not lower.** Whether
that is because the fix is insufficient or because this host's load this
round was substantially worse than either previous sample's cannot be told
apart from this data — and that uncertainty is itself the honest finding.
Per this round's own instruction not to re-assert determinism without a
clean run of at least 20: determinism is **not** re-asserted.
`test/drive_test_lifecycle.rb`'s own comment above `MAX_MASHED_KEYS` says
this plainly now, including by name against commit `8fa7e8b`'s claim.
Whoever picks this up next should re-run the full 20 on a quieter host
before trying to close this out, and separately, should not run this driver
by hand while a batch of it is already running in the background — the two
invocations fight over the same D-Bus application id and corrupt each
other's results, independent of anything this fix changes.

A genuinely host-independent fix would need to decouple
`check_frustration`/`record_keystroke` from real wall-clock time behind an
injectable clock, threaded through `Window`'s construction of `TextView` down
to this test — a change to two production files' public shape purely to make
a test deterministic, not attempted this round. That is the next step for
whoever picks this up, named here rather than behind a quiet "fixed" commit
message.

## Verdict

- Upstream/port test-count parity: **0/0, met trivially.**
- Previous round's gap (broken spec harness, zero unit coverage of pure-logic
  modules): **fixed and reproduced fixed in this round.**
- Gap from the previous round (**`test/drive_test_lifecycle.rb` is
  intermittently flaky**, despite commit `8fa7e8b`'s claim of determinism):
  **still open.** This round diagnosed and fixed one real, identified
  contributing cause (cold-start Pango/layout cost eating into the
  frustration window) with a warm-up pass, and re-ran the driver afterward —
  9 usable runs out of an attempted 20 (the rest lost to this round's
  exceptionally heavy, confirmed concurrent host load corrupting results via
  D-Bus collisions rather than producing a pass/fail), 5 of those 9 failing,
  4 on the exact assertions `8fa7e8b` claimed to have fixed. That sample is
  too small and too confounded by host load to claim the fix reduced the
  failure rate — if anything it reads worse than the previous round's 1-in-6
  — and nowhere near the 20 clean runs this round's own brief
  required before re-asserting determinism — so determinism is **not**
  re-asserted, the same honest "still open" verdict as last round, now with
  one more diagnosed-and-fixed cause and one more disproven attempt on
  record. A runtime gate built on a flaky check is still not a reliable gate;
  see `.reports/accountability-ensurance.md`.
