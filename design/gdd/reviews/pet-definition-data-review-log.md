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

## Review — 2026-09-22 — Verdict: NEEDS REVISION
Scope signal: L (up from M — 7 hard dependents, 2 formulas, 2 firm ADRs now required: OQ#1 storage/versioning; OQ#2 wiring + immutability + export inclusion)
Specialists: game-designer, systems-designer, qa-lead, godot-specialist, creative-director (senior)
Blocking items: 5 | Recommended: 10
Summary: The revision closed all four prior blockers with real fixes (B3 airtight; B2 resolved as scoped; B1 and B4 partial). Three of the five new blockers are consequences of the B1 fix — adding `retired` at two levels created guarantees the older Rule 12 validation now contradicts. The most important fix is that Rule 12's "≥1 non-retired adult form" evicts a fully-retired species that Rules 2/13 promise the album can resolve forever. Every blocking fix is a short edit to Core Rules 7, 11, 12, 13 and the ACs.
Prior verdict resolved: Partial — B2, B3 resolved; B1, B4 partial (residuals are blockers 1 and 4 below)
Disposition: User chose to stop and revise in a separate session.

**Blocking (fix in the GDD):**
1. Fully-retired species evicted — scope Rule 12: non-retired species need ≥1 non-retired form; retired species need ≥1 form of any status. [game-designer][systems-designer]
2. Unknown-id lookup ambiguous ("null or explicit error") — pin `null` in Rule 13 and the AC. [qa-lead]
3. Empty `get_hatchable_species()` in a shipped build is a silent outage — make "Ready with 0 hatchable species" an explicit terminal failure state or named signal Hatching Onboarding must handle. [systems-designer][godot-specialist]
4. `min_share` range must be `(0, 1]` — `0.0` always matches and shadows every later rule and the default; update Rule 11 range, Rule 12 check, add AC. [systems-designer][game-designer]
5. 32×32 sprite constant owned by a dependent (LCD Renderer) while PDD claims no upstream deps — PDD declares the constant (value provisional per OQ#3); LCD Renderer reads it. [systems-designer][godot-specialist]

**Recommended (CD asks for 1–3 in the same pass):**
1. Make the Rule 12 CI gate implementable: injectable build-type flag for dev/release ACs; move the shipped-catalog fixture out of `tests/unit/` (file I/O forbidden) to Integration evidence or an in-memory factory. [qa-lead]
2. Rule 12 cross-checks deferred from review 1: `floor < sad_threshold`, non-egg `days_to_advance ≥ 1`, `egg == 0`, `default_form_id` non-retired. [systems-designer][game-designer][qa-lead]
3. CI shadowing detector (earlier rule's match-set ⊇ later rule's); warn on single `min_share` near 1.0. [systems-designer][game-designer]
4. Forbid `duplicate()`/`duplicate_deep()` on definitions in Rule 3, lint-checkable. [godot-specialist]
5. Retiring a hidden form forces `hidden = false` (album: "retired — never obtained"). [game-designer]
6. Clarify Rule 14: additive optional fields are a minor schema revision, not a full ADR. [game-designer][creative-director]
7. Missing ACs: Rule 14 authoring/manifest; `hidden+retired`; `default_form_id`→retired. Reclassify the two bloop-content ACs as Config/Data smoke checks. [qa-lead]
8. Numeric boot budget (ms, reference hardware); name the venue for Rule 8 palette conformance (`@tool` import check or CI script). [qa-lead][godot-specialist]
9. Set bloop `window_days = 4`; state the MVP rule table as an open playtest question. [game-designer]
10. Species-prefixed form ids as authoring convention; edge case for `window_days` exceeding pet age. [systems-designer]

**Route to ADR (OQ#1/#2 inputs, not GDD changes):** nested definitions Resource vs plain data (adds `make_read_only()` as a candidate); export inclusion of manifest-driven dynamic paths in the mobile PCK (add a one-line Edge Case naming the risk); sprite asset type (`SpriteFrames`?) and frame-size validation cost model; `Color`/sub-resource encoding; cached vs catalog-held lookup returns; verify for 4.7: `make_read_only()`, `StringName == String` key equality, `@export var id: StringName`. [godot-specialist]

**Route downstream:** `n = 0` empty-window rule → Life Stage & Growth (mainline path, raise priority); care-share legibility → LCD Renderer / Pet Animation; album copy so "default" never reads as consolation → Graduation & Album; confirm 32×32 value → LCD Renderer.

**Disagreement rulings [creative-director]:** hidden+retired → recommended not blocking (authoring policy, Full Vision tier); 32×32 → blocking (self-contradiction on "no upstream deps"); B4 → PARTIAL (`min_share > 0` blocking, superset detector recommended, knife-edge `sum == 1.0` a warning); B2 → RESOLVED as scoped (Resource-or-not belongs to the storage ADR); qa-lead's three → split (null contract blocking; AC12 split and file-I/O fixture recommended, same pass; file-I/O should have been caught in review 1); single-species outage → blocking with the lighter named-state fix; revision log → accurate, process note only (list deferred items individually).

---

## Disposition — 2026-09-22 — Accepted with notes

Decision: the user chose a compressed design→code path for the project and accepted this GDD as-is rather than running a third revision/review cycle. No content changes were made to the Core Rules.

All 5 blocking items and the batch of 10 recommended items from the 2026-09-22 review were converted into Open Questions #8–#13 in `design/gdd/pet-definition-data.md`, each carrying its owner and the design session or implementation moment where it must be resolved. Status changed to "Approved (accepted with notes)"; systems index updated to match.

Rationale: review mode is `solo`, so `/design-review` is advisory. Four of the five blockers (Rule 12 scoping, `null` lookup contract, `min_share` range, 32×32 constant ownership) are one-line contract fixes whose natural resolution point is the dependent design session or the catalog implementation itself; the fifth ("0 hatchable species" failure state) is a real design decision routed to Hatching Onboarding. None of them block the foundation-layer code that comes first.

Carried risk: this GDD is the schema 7 systems depend on. If OQ#8–#12 are still open when the catalog is implemented, they must be closed in that implementation session, not deferred again. The ADR inputs listed in the 2026-09-22 entry still stand and feed OQ#1/#2.
