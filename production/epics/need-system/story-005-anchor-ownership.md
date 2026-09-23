# Story 005: Anchor set copy semantics for Save

> **Epic**: Need System
> **Status**: Ready (accessor names provisional)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~1–2 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/need-system.md`
**Requirement**: `TR-need-system-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — untraced; the accessor shape Save uses is owed by ADR-0003 (save format), which does not exist yet. The copy semantics are fixed by the GDD and implemented now.
**ADR Decision Summary**: —

**Engine**: Godot 4.7.1 | **Risk**: MEDIUM (inherits ADR-0001's injection pattern; no post-cutoff APIs)
**Engine Notes**: A copy must be a real copy: build a new object; don't hand out the internal arrays or inner-class instances.

**Control Manifest Rules (this layer)**:
- Required: Need System owns the live anchors; only it mutates them (Core Rule 13)
- Forbidden: handing Save a live reference to internal state
- Guardrail: loading an anchor set is a mutation — it resets `last_observed_state` (Story 004)

---

## Acceptance Criteria

*From GDD `design/gdd/need-system.md` Acceptance Criteria (Anchor ownership):*

- [ ] A Need System with non-default anchors on all four needs; its anchor set read out and a fresh instance constructed from it with the same `TimeService` → every need's value and state identical between the two
- [ ] Modifying the read-out set afterwards does not change the original instance's values
- [ ] Modifying the original afterwards (via `apply_care`) does not change the read-out set

---

## Implementation Notes

- **Provisional names** (to be renamed when the Save GDD / ADR-0003 fixes the contract): `class_name NeedAnchorSet extends RefCounted` holding `anchor_value` and `anchor_utc` per `Need.Id`; `NeedSystem.get_anchor_set() -> NeedAnchorSet` (returns a new copy) and `NeedSystem.load_anchor_set(set: NeedAnchorSet) -> void` (copies in, then initialises `last_observed_state` from each anchor value per Story 004).
- Put `NeedAnchorSet` in `src/gameplay/needs/need_anchor_set.gd`. Keep it plain data with no validation — Save & Persistence validates anchors on load (GDD Edge Cases: corrupt anchors are healed on read but stay corrupt until the next mutation).
- Don't add serialisation (`to_dict` etc.) — the save format is ADR-0003's.
- Mark both methods and the class with a `## PROVISIONAL (TR-need-system-013 → ADR-0003)` doc comment so the rename is easy to find.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Save & Persistence / ADR-0003: file format, versioning, validation on load, when saves happen
- Time Service Story 004: the save-on-background slot

---

## QA Test Cases

*From the GDD's Acceptance Criteria (qa-lead consulted at GDD authoring, lean mode). The developer implements against these — do not invent new test cases during implementation.*

Setup: `FakeTimeSource`, one `TimeService` shared by both instances, factory profiles.

- **AC-1** Round-trip: instance A with hunger 28, cleanliness 55, fun 100, sleep 0 (via decay + care); `var s := a.get_anchor_set()`; instance B constructed, `b.load_anchor_set(s)` → for each need, `b.get_value == a.get_value` and `b.get_state == a.get_state`, at `now` and again after advancing the clock 3600 s
- **AC-2** Copy out is detached: after AC-1, change `s`'s hunger anchor → `a.get_value(HUNGER)` unchanged
- **AC-3** Copy in is detached: `b.load_anchor_set(s)` then change `s` → `b` unchanged
- **AC-4** Later mutation doesn't leak back: `a.apply_care(FEED)` after `get_anchor_set()` → `s` unchanged
- **AC-5** Load resets crossing state: A with hunger `CONTENT`; a set with hunger's anchor at 100 and an anchor time 100000 s in the past; `load_anchor_set` then `check_crossings()` → one `need_became_sad(HUNGER)`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/need_system/anchor_ownership_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 and 004 must be DONE (AC-5 uses crossing detection)
- Unlocks: Save & Persistence epic (when it exists)
