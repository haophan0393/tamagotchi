# Systems Index: Pocket Pal

> **Status**: Draft
> **Created**: 2026-09-18
> **Last Updated**: 2026-09-19
> **Source Concept**: design/gdd/game-concept.md (revised 2026-09-18 after `/design-review`)

---

## Overview

Pocket Pal is mechanically small by design: a skeuomorphic three-button device wrapping a low-res LCD, a pet with four slowly decaying needs, four care actions, and a growth arc that reads the *style* of recent care to pick an adult form. Pillar 5 ("Simple Core, Infinite Shells") means the system set below is close to final for the life of the project — growth comes through data (species, forms, shells) rather than new systems. The 30-second loop (open → greeting → press → reaction → need clears) touches Device Frame, LCD Renderer, Need System, Care Actions and Pet Animation; the day-to-day loop adds Offline Time Simulation and Life Stage & Growth; the long arc adds Graduation & Album and Device Shells. Two foundation systems the concept never names — an injectable Time Service and data-driven Pet Definition resources — exist because the coding standards demand testable logic and no hardcoded gameplay values, and because every post-launch content layer depends on the pet being data.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Time Service (inferred) | Core | MVP | Approved (as-is) | design/gdd/time-service.md | — |
| 2 | Pet Definition Data (inferred) | Core | MVP | Not Started | — | — |
| 3 | Device Frame & Button Input | Gameplay | MVP | Not Started | — | — |
| 4 | Need System | Gameplay | MVP | Not Started | — | Time Service, Pet Definition Data |
| 5 | Save & Persistence | Persistence | MVP | Not Started | — | Time Service, Pet Definition Data |
| 6 | Life Stage & Growth | Progression | MVP | Not Started | — | Time Service, Pet Definition Data, Save & Persistence |
| 7 | LCD Screen Renderer (inferred) | UI | MVP | Not Started | — | Device Frame & Button Input, Pet Definition Data |
| 8 | Care Actions | Gameplay | MVP | Not Started | — | Need System, Device Frame & Button Input, Pet Definition Data, Life Stage & Growth |
| 9 | Offline Time Simulation | Gameplay | MVP | Not Started | — | Time Service, Need System, Save & Persistence |
| 10 | Pet Animation & Reactions (inferred) | UI | MVP | Not Started | — | LCD Screen Renderer, Pet Definition Data, Need System, Care Actions, Life Stage & Growth, Offline Time Simulation |
| 11 | Graduation & Album | Progression | Vertical Slice | Not Started | — | Life Stage & Growth, Save & Persistence, Pet Animation & Reactions |
| 12 | Hatching Onboarding | Meta | Vertical Slice | Not Started | — | Device Frame & Button Input, Life Stage & Growth, Pet Animation & Reactions |
| 13 | Daily Notification | Meta | Vertical Slice | Not Started | — | Need System, Time Service |
| 14 | Settings | Persistence | Alpha | Not Started | — | Device Frame & Button Input, Save & Persistence |
| 15 | Device Shells | Progression | Alpha | Not Started | — | Graduation & Album, Device Frame & Button Input, Save & Persistence |
| 16 | Personality Quirks | Progression | Full Vision | Not Started | — | Care Actions, Pet Animation & Reactions |

**Scope notes (folded systems):**
- *Device Frame & Button Input* includes the menu navigation state machine (cycle / select / cancel, ≤3-press budget), safe-area layout, and **Sensory Feedback** (piezo SFX pools, stingers, haptics) — with the visual-alone principle enforced.
- *Care Actions* includes the **Play Mini-Game** (left/right); its input model must be resolved inside that GDD.
- *Life Stage & Growth* owns the **care-history rolling log** that Care Actions writes to and form selection reads from.
- *LCD Screen Renderer* includes the **LCD HUD & Menu Icons** (need icons, menu cursor, "done for today" signal).

**Deliberately excluded:** analytics/telemetry (nothing needs it; cuts against the cozy tone), monetization/IAP (shells are earned, never sold), social/sharing, "Species" as a system (species are Pet Definition Data).

---

## Categories

| Category | Description | Systems Here |
|----------|-------------|--------------|
| **Core** | Foundation everything depends on | Time Service, Pet Definition Data |
| **Gameplay** | The systems that make the pet feel alive | Device Frame & Button Input, Need System, Care Actions, Offline Time Simulation |
| **Progression** | How the pet (and the collection) grows | Life Stage & Growth, Graduation & Album, Device Shells, Personality Quirks |
| **Persistence** | Save state and continuity | Save & Persistence, Settings |
| **UI** | What is drawn on the LCD layer | LCD Screen Renderer, Pet Animation & Reactions |
| **Meta** | Outside the core loop | Hatching Onboarding, Daily Notification |

Audio is folded into Device Frame & Button Input (sensory feedback) — the game has no music manager or adaptive audio in scope. Narrative and Economy categories do not apply.

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the falsifiable hypothesis (press → reaction → ≥70% return tomorrow). | First playable, ~3 weeks (verify via `/sprint-plan`) | Design FIRST |
| **Vertical Slice** | The full emotional arc: hatching, graduation, and the daily pull. | ~5 weeks total | Design SECOND |
| **Alpha / v1.0** | Store-ready: settings, 3 shell colourways. | ~7–8 weeks total | Design THIRD |
| **Full Vision** | Post-launch content layers. | 3–6 months post-launch | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. Time Service — the only code that reads the wall clock; injectable so Need decay and Offline Sim are deterministic under test
2. Pet Definition Data — species, forms, animations, thresholds, palettes as resources; the content pipeline for every later layer
3. Device Frame & Button Input — the input framework every interaction routes through; owns its own feedback defaults so it never depends on Settings

### Core Layer (depends on foundation)

1. Need System — depends on: Time Service, Pet Definition Data
2. Save & Persistence — depends on: Time Service, Pet Definition Data
3. Life Stage & Growth — depends on: Time Service, Pet Definition Data, Save & Persistence
4. LCD Screen Renderer — depends on: Device Frame & Button Input, Pet Definition Data

### Feature Layer (depends on core)

1. Care Actions — depends on: Need System, Device Frame & Button Input, Pet Definition Data, Life Stage & Growth (care-history log)
2. Offline Time Simulation — depends on: Time Service, Need System, Save & Persistence
3. Pet Animation & Reactions — depends on: LCD Screen Renderer, Pet Definition Data, Need System, Care Actions, Life Stage & Growth, Offline Time Simulation
4. Graduation & Album — depends on: Life Stage & Growth, Save & Persistence, Pet Animation & Reactions
5. Daily Notification — depends on: Need System, Time Service

### Presentation Layer (wraps features)

1. Hatching Onboarding — depends on: Device Frame & Button Input, Life Stage & Growth, Pet Animation & Reactions
2. Settings — depends on: Device Frame & Button Input, Save & Persistence
3. Device Shells — depends on: Graduation & Album, Device Frame & Button Input, Save & Persistence

### Polish Layer (depends on everything)

1. Personality Quirks — depends on: Care Actions, Pet Animation & Reactions

**Bottleneck systems** (most dependents — get these right first): Pet Definition Data (8), Device Frame & Button Input (6), Time Service (5), Need System (5), Life Stage & Growth (5).
**Leaf systems** (no dependents — safe to design late): Device Shells, Hatching Onboarding, Settings, Daily Notification, Personality Quirks.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Time Service | MVP | Foundation | systems-designer, godot-gdscript-specialist | S |
| 2 | Pet Definition Data | MVP | Foundation | systems-designer, godot-specialist | M |
| 3 | Device Frame & Button Input | MVP | Foundation | game-designer, ux-designer, audio-director, godot-specialist | L |
| 4 | Need System | MVP | Core | systems-designer, game-designer | M |
| 5 | Save & Persistence | MVP | Core | systems-designer, godot-specialist | S |
| 6 | Life Stage & Growth | MVP | Core | game-designer, systems-designer | L |
| 7 | LCD Screen Renderer | MVP | Core | godot-specialist, godot-shader-specialist, art-director | M |
| 8 | Care Actions | MVP | Feature | game-designer, ux-designer | M |
| 9 | Offline Time Simulation | MVP | Feature | systems-designer, godot-specialist, qa-lead | M |
| 10 | Pet Animation & Reactions | MVP | Feature | game-designer, art-director | M |
| 11 | Graduation & Album | Vertical Slice | Feature | game-designer, narrative-director | M |
| 12 | Hatching Onboarding | Vertical Slice | Presentation | ux-designer, game-designer | S |
| 13 | Daily Notification | Vertical Slice | Feature | godot-specialist, ux-designer | S |
| 14 | Settings | Alpha | Presentation | ux-designer | S |
| 15 | Device Shells | Alpha | Presentation | art-director, game-designer | S |
| 16 | Personality Quirks | Full Vision | Polish | game-designer | M |

Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions. Systems 1–2 are independent and may be designed in parallel; 3 is independent of both.

---

## Circular Dependencies

- **Device Frame & Button Input ↔ Settings** — the frame reads sound/haptic toggles; the settings menu is navigated through the frame. *Resolution*: Device Frame owns its feedback-enable flags with defaults on and exposes a setter; Settings writes them one-way. Device Frame's GDD must not reference Settings as a dependency.
- No other cycles. Care Actions → Life Stage & Growth is one-way (Care writes to the care log Growth owns); Pet Animation listens to signals from gameplay systems and nothing depends on it except Graduation, Onboarding and Quirks.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| LCD Screen Renderer | Technical | Rendering approach unvalidated — SubViewport + pixel-grid shader vs. 4.7's `DrawableTexture2D`; Pillar-1-critical and never prototyped (button-feel prototype cut the LCD) | Spike both approaches before the GDD's Formulas section; record the choice as an ADR |
| Offline Time Simulation | Technical / Design | No fail state means a broken sim produces *silently* absurd states; depends on `NOTIFICATION_APPLICATION_PAUSED/_RESUMED` behaviour unconfirmed for 4.7 | Boundary unit tests (negative, zero, DST, multi-year delta) are BLOCKING; verify suspend/resume on device early |
| Life Stage & Growth | Design | Rolling-window care-style selection is the load-bearing answer to Pillar 2 vs. Discovery — window length, style axes and tie-breaks are all unspecified; 2 MVP forms means Discovery cannot be tested until v1.0 | Define the rule table with explicit example calculations; playtest legibility at the vertical slice |
| Daily Notification | Technical / Scope | Godot has no built-in local-notification API; no plugin identified or verified for 4.7 on both platforms; gates the Vertical Slice tier | Research spike during architecture → ADR; scope fallback is shipping the slice without it |
| Device Frame & Button Input | Design / Technical | Cycle-then-select vs. touch affordances (≤3-press budget); haptic amplitude untested on device; first-run teachability asserted, not designed | `/ux-design` for the navigation scheme; on-device haptic test; onboarding designed in system 12 |
| Pet Definition Data | Scope | 8 systems depend on its schema — a late schema change ripples everywhere | Design second, review hard, treat schema changes as ADR-worthy |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 16 |
| Design docs started | 1 |
| Design docs reviewed | 1 |
| Design docs approved | 1 |
| MVP systems designed | 1/10 |
| Vertical Slice systems designed | 0/3 |

---

## Next Steps

- [x] Review and approve this systems enumeration (2026-09-18)
- [ ] Design MVP-tier systems first (use `/design-system [system-name]` or `/map-systems next`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Validate the highest-risk systems (LCD Renderer, Offline Sim, Notification) with `/vertical-slice` before committing to Production
