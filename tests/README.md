# Test Infrastructure

| Field | Value |
|---|---|
| **Engine** | Godot 4.7.1 (stable, official `a13da4feb`) |
| **Test framework** | gdUnit4 **v6.2.1**, vendored at `addons/gdUnit4/` |
| **Upstream** | `godot-gdunit-labs/gdUnit4` — note the org moved from `MikeSchulze/` |
| **CI** | `.github/workflows/tests.yml` (triggers on `master`) |
| **Setup date** | 2026-09-22 |

## Running tests

```bash
godot --headless --script tests/gdunit4_runner.gd
```

This is the command pinned in `.claude/docs/technical-preferences.md`. With no
arguments it runs `tests/unit` and `tests/integration`. To scope a run, pass
gdUnit4 arguments after a `--` separator:

```bash
godot --headless --script tests/gdunit4_runner.gd -- -a tests/unit/time_service
```

Exit codes are gdUnit4's own — `0` pass, non-zero fail (`100` = test failures).
Verified 2026-09-22 in both directions; CI relies on this.

### Two things that are not obvious

1. **gdUnit4 v6 refuses `--headless` by default**, exiting with
   `RETURN_ERROR_HEADLESS_NOT_SUPPORTED`. `tests/gdunit4_runner.gd` always passes
   `--ignoreHeadlessMode`. Our suites are pure logic with no UI interaction, so
   the restriction does not apply. Godot does not deliver `InputEvent`s in
   headless mode — **a suite needing real input must live in `tests/integration/`
   and run on a non-headless CI job.**
2. **The runner is `addons/gdUnit4/bin/GdUnitCmdTool.gd`**, not the
   `addons/gdunit4/GdUnitRunner.gd` that older docs and the `/test-setup` skill
   template reference. That path is stale for v6 (note also the capital `U`).

## Directory layout

```
tests/
  unit/            # Isolated logic tests — one subdirectory per system
    time_service/
  integration/     # Cross-system and save/load round-trip tests
  smoke/           # Critical path list read by /smoke-check
  gdunit4_runner.gd
```

Manual evidence lives at **`production/qa/evidence/`**, not `tests/evidence/`.
This deviates from the `/test-setup` skill template deliberately:
`.claude/docs/coding-standards.md` is a project instruction and wins.

## Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `time_service_contract_test.gd` → `test_get_elapsed_seconds_clamps_rolled_back_clock_to_zero()`

## Story type → required evidence

| Story type | Required evidence | Location | Gate |
|---|---|---|---|
| Logic (formulas, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration (multi-system) | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + sign-off | `production/qa/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `production/qa/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

## Determinism

Per `.claude/docs/coding-standards.md`, tests must produce the same result every
run: no random seeds, no wall-clock assertions, no ordering dependencies.

For anything time-dependent this means **injecting the clock**, never sleeping.
`tests/unit/time_service/time_service_contract_test.gd` is the worked example —
its `FakeTimeSource` injects both the current time *and* the timezone offset, so
date-boundary assertions hold identically on any CI machine in any locale.

## Specification-first tests

`time_service_contract_test.gd` runs against a reference implementation declared
inside the test file, because Time Service has no production code yet. When the
real implementation lands during `/dev-story`, the story changes **one line** —
the `ServiceUnderTest` constant — and every assertion carries over. Do not fork
these tests into a second copy.

## CI

`.github/workflows/tests.yml` runs two jobs on every push and PR to `master`:

- **`test`** — the gdUnit4 suite via `godot-gdunit-labs/gdUnit4-action@v1.3.2`,
  pinned to gdUnit4 `v6.2.1` to match the vendored copy. **Bump both together.**
- **`clock-discipline`** — a lint gate enforcing Time Service Core Rule 1 (no
  system reads the engine clock directly outside `SystemTimeSource`). This is
  the enforceable half of the Time Service GDD's AC #9; the assertion cannot be
  expressed as a unit test, because a test can only prove the code it calls is
  deterministic, never that some other file is.

A failed suite blocks merging. Never skip or disable a failing test to make CI
pass — fix the cause.
