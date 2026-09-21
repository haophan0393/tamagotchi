# Review Log: Pet Definition Data

Document: `design/gdd/pet-definition-data.md`

## Review — 2026-09-21 — Verdict: NEEDS REVISION
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (senior)
Blocking items: 4 | Recommended: 7
Summary: PDD is structurally complete (8/8 sections) and correctly scoped as a read-only content schema, but three contract-level defects — the missing species-level `retired` field and its `get_all_species()`/Graduation & Album conflict (fix: add the field and split into `get_all_species()` + `get_hatchable_species()`), an untestable immutability AC (Core Rule 3 is unenforceable on GDScript `@export` Resources — mechanism must be chosen and recorded in the Open Question #2 ADR), and an unspecified StringName-vs-String boundary at Save & Persistence — would each become ADR-priced schema changes once the first dependent exists. Fourth blocker: decide the venue for the unreachable-FormRule check (Open Question #6) now; CD recommends load-time warning + unit-test fixture. Recommended: Rule 12 additions (`floor < sad_threshold`, non-egg `days_to_advance ≥ 1`, `egg == 0`, `default_form_id` non-retired, `min_share > 0`; `total_arc_days` upper bound rejected), set bloop `window_days = 4`, never retire an unrevealed hidden form, flag mid-arc care-share legibility as a downstream requirement on LCD Renderer / Pet Animation, add ACs for `hidden+retired` and `default_form_id`→retired, split AC 12 dev/release, give AC 17 a boot budget.
Prior verdict resolved: First review
Disposition: User chose to stop and revise in a separate session.

## Revision — 2026-09-21 — Status: Revised (pending re-review)
Addresses: all 4 blocking items from the 2026-09-21 review. Recommended items (7) deferred to a follow-up pass.
- **B1 species `retired` / lookup conflict** → `retired: bool` added to Core Rule 4; Core Rule 13 split into `get_all_species()` (includes retired, for Graduation & Album) and `get_hatchable_species()` (excludes retired, for new eggs). Interactions/Dependencies tables, Tuning Knobs, Edge Cases and ACs updated; Open Question #7 closed.
- **B2 untestable immutability AC** → Core Rule 3 now requires an enforcement mechanism chosen in the Open Question #2 ADR (candidates: setter guards, read-only wrapper, convention + CI lint). AC split into a testable reference-identity check and a mechanism-agnostic "write attempt is rejected or detected" check. Open Question #2 widened.
- **B3 StringName vs String boundary** → Core Rule 2 defines the id grammar (`^[a-z][a-z0-9_]*$`, ≤32 ASCII chars) and the boundary: `StringName` in memory, plain `String` persisted, Save & Persistence converts; never persist hash/pointer. Grammar added to Core Rule 12; round-trip AC added.
- **B4 unreachable-FormRule venue** → per CD recommendation: Core Rule 11 requires distinct actions per rule (makes reachability decidable: sum of `min_share` > 1.0); Core Rule 12 logs a non-rejecting warning; CI-blocking unit-test fixture in `tests/unit/pet_definition_data/` is the shipping gate. Open Question #6 closed.
Next: re-run `/design-review design/gdd/pet-definition-data.md`.
