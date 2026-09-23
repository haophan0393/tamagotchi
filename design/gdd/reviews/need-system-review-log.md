# Need System — Review Log

## Review — 2026-09-22 — Verdict: NEEDS REVISION → revised same session → Accepted (Approved)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director (senior)
Blocking items: 3 | Recommended: 8
Summary: The anchor model (time-derived value, no tick, one decay rule online/offline) was judged solid. The blockers were all in two places. First, the sleep/dark rate-switch mechanic: it had no way back to lights-on, "done for today" could fire beside a lit icon, sleep had no reaction beat, and it depended on a `recover_per_hour` field missing from PDD. Second, the Core Rule 14 timer, which could not be tested against a FakeTimeSource. The state rules also had holes: an overlap when floor > sad_threshold, and "done for today" became unreachable at sad_threshold == 100.
Resolution: The user chose press-restored sleep (creative-director recommendation). Core Rule 14 was split into pure `check_crossings()` / `on_resumed()` plus a `NeedCrossingScheduler` adapter with one ADVISORY on-device AC. Core Rule 10 now has a state precedence. The proposed PDD validation was tightened to `floor < sad_threshold < 100` and `decay_per_hour ≥ 0.01`. All recommended AC and GDScript items were fixed. Changes owed by other GDDs (PDD validation, Device Frame lights/cursor contract, Care Actions) are recorded in Open Questions. The user accepted without a re-review.
Disagreements: game-designer said sleep's 1.5/hr falls outside the safe band; creative-director called it a legitimate occasional need that only needs a stated exemption (adopted). systems-designer corrected the main review: floor > sad_threshold does not block "done for today", but sad_threshold == 100 does.
Prior verdict resolved: First review
