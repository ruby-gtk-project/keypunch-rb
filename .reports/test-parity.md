# Test parity — keypunch-rb

| | |
|---|---|
| Upstream | `main` @ `b88ef1f` |
| Port | `ruby` @ `de7f6a3` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

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

The `ruby` branch has no RSpec example files. `spec/spec_helper.rb` and
`spec/README.md` are scaffolding from the `kettle-test`/`kettle-jem`
gem-template tooling, not app tests — there is not one `*_spec.rb` under
`spec/` for `text_generation.rb`, `text_utils.rb`, `typing_test_utils.rb`,
`settings.rb` or `translations.rb`, even though every one of those is pure
Ruby, needs no display, and is exactly the kind of logic upstream would have
unit-tested if it unit-tested anything.

**The devshell's advertised RSpec command does not run.** The flake banner
prints:

```
run the specs: ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Running it (verified, under `nix develop --command xvfb-run -a ruby -e ...`)
fails to even load `spec_helper.rb`:

```
LoadError: cannot load such file -- kettle/test/rspec
0 examples, 0 failures, 2 errors occurred outside of examples
```

`bundle exec rspec spec` also fails in the same devshell
(`rspec-core is not currently included in the bundle`). So the one command
the project's own tooling names as "run the specs" has never successfully
executed in this environment, and even if it did, it would run zero examples
against zero spec files. **This is a gap in its own right, independent of
the 0/0 upstream parity number**: a command printed in the devshell banner as
if it works, that does not run, is exactly the kind of false-green surface
the accountability pass looks for. It is called out there too.

## Extra — the port's real test coverage

The port's actual verification is two headless GTK driver scripts under
`test/`, run with `nix develop --command xvfb-run -a ruby test/drive_*.rb`.
Both were executed in this round, not just read:

- `test/drive_main_window.rb` — **33 of 33 checks passed, DRIVE OK.** Drives
  a full custom-text session end to end (ready → typing → results →
  back-to-ready), then each of the custom-text, text-language and about/
  shortcuts dialogs, including the custom-text empty/whitespace-only/discard
  states and the language dialog's search/no-results/add-language states.
- `test/drive_test_lifecycle.rb` — **8 of 8 checks passed, DRIVE OK.** Drives
  the timed-session countdown, the frustration-cancellation path (40 mashed
  keystrokes against the `FRUSTRATION_THRESHOLD`), and the narrow/wide
  adaptive layout switch.

Combined: **41 checks, 0 failed, both runs reporting `DRIVE OK`** — this
matches the runtime gate this round reported (`drive_ok=true`, 41 checks, 0
failed). Both numbers were independently reproduced in this audit, not taken
on faith.

**These 41 checks are real and executed, and they are also not test
parity.** They were written for the port, cover UI/behavioural flows upstream
never had tests for (upstream has none at all), and are listed here under
`## Extra`, outside the 0/0 count, per the skill. They do not substitute for
unit tests of the pure-Ruby logic modules, which remain completely
unexercised by any automated check — `text_generation.rb`'s word-list
selection and punctuation weighting, `typing_test_utils.rb`'s WPM/accuracy
math, `settings.rb`'s JSON parse-failure fallback, and `translations.rb`'s
plural-form evaluator have no test of any kind, upstream or ported, driver or
unit.

## Verdict

- Upstream/port test-count parity: **0/0, met trivially.**
- Runtime gate (the 41-check driver suite): **real, reproduced, green.**
- Gap: the port's nominal unit-test harness (`spec/`, `rake spec`) is empty
  and its advertised run command is broken in the dev shell; the pure-logic
  modules have zero test coverage of any kind. Treat the 41 driven checks as
  what they are — UI/integration coverage of 17 components, not unit
  coverage of the logic the UI depends on — and treat "spec/ exists" as
  scaffolding, not evidence of tests.
