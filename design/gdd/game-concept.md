# Game Concept: Pocket Pal

*Created: 2026-09-18*
*Status: Draft*

---

## Elevator Pitch

> It's a colorful, guilt-free reimagining of the classic Tamagotchi for phones: a virtual pocket device with three round buttons and a boxy pixel screen, where you spend two minutes a day feeding, cleaning, and playing with a tiny creature to see which grown-up form your care shapes it into.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Virtual pet / cozy daily check-in |
| **Platform** | Mobile (iOS / Android), portrait |
| **Target Audience** | Nostalgic 90s kids (25–40) and cozy casual players who want a kind daily ritual — see Player Profile |
| **Player Count** | Single-player |
| **Session Length** | 1–3 minutes, once a day |
| **Monetization** | Undecided — no ads, energy timers, or loot boxes (anti-pillar). Candidates: one-time premium price, or free with optional cosmetic shell packs post-launch. Decide before v1.0. |
| **Estimated Scope** | Small (7–8 weeks to v1.0, solo; full vision 3–6 months of post-launch updates, solo) |
| **Comparable Titles** | Tamagotchi Original (1996 / 2017 re-release), Neko Atsume, Pou, My Tamagotchi Forever, Finch |

---

## Core Fantasy

"My little creature is alive in my pocket and is always glad to see me."

The player carries a tiny, colorful gadget in their phone. Something lives inside its screen and depends on them — but gently. Opening the app is like flipping open a toy from childhood, except the toy never scolds you. The fantasy is stewardship without anxiety: you shape a small life through consistent kindness, and it grows into something that reflects how you cared for it.

---

## Unique Hook

It's like the original Tamagotchi, AND ALSO the *device itself* is the star — a vivid, tactile, swappable gadget rendered on your phone with pressable round buttons, haptic clicks, and an LCD you can almost feel flicker — with a pet that never dies, only graduates.

- Explainable in one sentence: yes (above).
- Novel: the skeuomorphic device frame + colorful reinterpretation + no-death design is not what the official app or clones do.
- Connected to the fantasy: the device *is* the "toy in your pocket."
- Affects gameplay: every interaction is routed through three buttons and a menu, which constrains and defines the whole feel.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 1 | Saturated candy-colored shells, haptic button clicks, chirpy LCD beeps, pixel-grid screen flicker |
| **Submission** (relaxation, comfort zone) | 2 | Forgiving real-time decay, no fail state, a clear "done for today" state |
| **Fantasy** (make-believe, role-playing) | 3 | A living creature in your pocket that greets you and grows with you |
| **Discovery** (exploration, secrets) | 4 | Which adult form will emerge from your care habits? Hidden forms, later shells and species |
| **Expression** (self-expression, creativity) | 5 | Choosing device shells (post-launch: personality shaped by your routine) |
| **Narrative** (drama, story arc) | 6 | The life arc of each pet — egg to graduation — and the photo album of graduates |
| **Challenge** (obstacle course, mastery) | 7 | Minimal — a tiny left/right mini-game; care consistency, not difficulty |
| **Fellowship** (social connection) | N/A | Not in v1 (anti-pillar) |

### Key Dynamics (Emergent player behaviors)

- Players build a daily ritual (morning coffee + check on the pet) and feel a small "done" satisfaction when all need icons clear.
- Players experiment with care patterns to discover new adult forms ("what if I play with it more than I feed it?").
- Players keep graduated pets in the album and talk about them as individuals ("my first one was a Bloop").
- Players want to see the pet in a new shell — creating natural pull for post-launch shell content.
- Players returning after a long absence are relieved rather than ashamed — and come back more often because of it.

### Core Mechanics (Systems we build)

1. **Device Frame & Button Input** — three round buttons (menu cycle / select / cancel) drive every interaction; the boxy LCD renders the pet at low resolution with a visible pixel grid.
2. **Need System** — four needs (hunger, cleanliness, fun, sleep) decay slowly in real time, tuned so one check-in per day keeps the pet content; needs cap at "sad/messy," never fatal.
3. **Care Actions** — feed, clean, play (one mini-game), lights on/off; each triggers a pet reaction animation, beep, and haptic.
4. **Life Stage & Growth** — egg → baby → child → adult over ~7–10 real days; cumulative care quality selects among adult forms; the adult graduates into an album and a new egg arrives.
5. **Offline Time Simulation** — on resume, elapsed real time is applied to needs and growth (with a forgiving floor), so the pet feels alive when the app is closed.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Which need to tend first, whether to play or skip the game, which egg to hatch next, which shell to display | Supporting |
| **Competence** (mastery, skill growth) | Learning what the pet responds to; steering toward a healthy or rare adult form through consistent care | Supporting |
| **Relatedness** (connection, belonging) | The pet greets you, idles with personality, and remembers you in the album of graduates | Core |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: complete the daily check-in, collect every adult form, later collect every shell.
- [x] **Explorers** (discovery, understanding systems, finding secrets) — How: discover which care patterns lead to which forms; hidden forms.
- [ ] **Socializers** (relationships, cooperation, community) — How: not in v1; the relationship is with the pet, not other players.
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How: N/A.

**Who this is NOT for**: players seeking depth, challenge, or mini-game variety; players wanting Nintendogs-style direct pet interaction; players who want the tension of a pet that can die.

### Flow State Design

- **Onboarding curve**: the first session is the egg hatching — the device shows one blinking button; pressing it cycles the menu; the pet's first need appears with an icon. No text tutorial; the three buttons teach themselves within 60 seconds.
- **Difficulty scaling**: none in the traditional sense. Depth comes from the growth system revealing that *how* you care matters, not from harder tasks.
- **Feedback clarity**: need icons clear one at a time; the pet's idle animation shifts from sad to content; a stage-up animation marks growth; the album records outcomes.
- **Recovery from failure**: there is no failure. Extended neglect leaves the pet sad and messy but two minutes of care fully restores it. Care quality affects which adult emerges, never whether one emerges.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Open app → the device fills the screen → glance at the LCD for the pet and its need icons → press a round button to cycle the menu → press to select an action → pet reacts with a bouncy sprite animation, an LCD-style chirp, and a haptic click → need icon clears. Every press must feel physical: sound + haptic + screen flicker, every time.

### Short-Term (5-15 minutes)
The daily session: clear needs in whatever order (feed → clean → play → lights). Each cleared need moves the pet toward "content." When all icons are gone the pet performs its happy idle — the game's explicit "you're done for today" signal. Optional: replay the mini-game a couple of times for fun.

### Session-Level (30-120 minutes)
Deliberately inverted for this genre: the *whole* session is 1–3 minutes, once a day. Natural stopping point is the happy idle. Reason to return: a single gentle daily notification, and the open question of what the pet is becoming.

### Long-Term Progression
Egg → baby → child → adult over ~7–10 real days. Consistency of care across the arc selects the adult form (2 forms in MVP, 4+ at v1.0). The adult graduates — waves goodbye, moves into the album — and a new egg arrives. Long-term goal: complete the album. Post-launch layers slot in here: device shells unlock per graduation, personality quirks emerge from routine, new species arrive as new eggs.

### Retention Hooks
- **Curiosity**: which adult form is this one becoming? Which forms haven't I seen?
- **Investment**: the current pet's arc in progress; the album of past graduates.
- **Social**: none in v1 (intentional).
- **Mastery**: learning the care patterns that lead to specific or rare forms.

---

## Game Pillars

### Pillar 1: The Device Is Real
The phone shows a physical gadget. Every interaction goes through its round buttons and boxy LCD screen.

*Design test*: If we're debating a slick modern UI overlay vs. doing it through the three buttons, we choose the buttons.

### Pillar 2: Never Guilt, Always Welcome
The pet is glad to see you however long you've been gone. Neglect softens outcomes; it never punishes.

*Design test*: If a feature adds pressure, shame, or penalty for absence, we cut it or soften it.

### Pillar 3: Two Minutes of Joy
A complete, satisfying session fits in two minutes.

*Design test*: If a feature requires longer engagement to be worthwhile, we make it optional.

### Pillar 4: Color Is the Character
Vivid, saturated color is what separates this from the grey originals.

*Design test*: If we're debating period-accurate monochrome vs. colorful, we choose colorful, always.

### Pillar 5: Simple Core, Infinite Shells
The three-button loop never changes. Growth comes through art and content layers, not new mechanics.

*Design test*: If a new feature changes how the buttons work or adds a fourth input, we reject it.

**Pillar tensions (where interesting decisions live)**: 1 vs 4 (authenticity vs. color); 2 vs progression (care must matter without neglect punishing); 3 vs 5 (adding content without lengthening sessions).

### Anti-Pillars (What This Game Is NOT)

- **NOT a pressure-monetized game**: no loot boxes, energy timers, interstitial ads, or paid shells that nag. It would compromise *Never Guilt, Always Welcome*.
- **NOT a death simulator**: the pet never dies or runs away; it graduates. Death would compromise *Never Guilt*.
- **NOT a full-screen touch-the-pet sim**: no free camera, no petting gestures, no room decoration outside the LCD. It would compromise *The Device Is Real*.
- **NOT a social or multiplayer game in v1**: no friends, visiting, or sharing systems. It would compromise *Two Minutes of Joy* and the timeline.
- **NOT a mini-game collection**: games exist to serve the pet's "fun" need; more than one or two would compromise *Simple Core, Infinite Shells*.

---

## Visual Identity Anchor

**Direction name**: Candy Gadget

**One-line visual rule**: Everything on screen is a bright physical toy — glossy, saturated plastic shells wrapped around a warm, visibly pixelated LCD.

**Supporting visual principles**:

1. **Two layers, never mixed** — the shell layer is smooth (vector or painted, soft highlights, rounded forms); the screen layer is chunky pixel art with a visible grid. *Design test*: if an element could live on either layer, decide which one it belongs to — nothing straddles both.
2. **Toy-store palette** — shells use saturated, translucent-plastic hues (90s Game Boy Color, gel-pen, jelly-shoe colors). *Design test*: muted vs. saturated → saturated.
3. **Motion means alive** — the pet always idles, buttons always depress, the LCD always has a faint flicker. *Design test*: if an element is static, give it a tick.

**Color philosophy**: shells carry the loud, saturated color and vary infinitely; the LCD uses a restrained 4–8 color palette so the pet stays readable at tiny size and looks right inside *any* shell. Color is the shell's job; clarity is the screen's job.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Tamagotchi Original (1996 / 2017) | The device frame, three buttons, need icons, life stages, tiny pixel pet | Full color, no death, graduation + album, swappable shells | Proves the core loop and the nostalgia audience are real |
| Neko Atsume | Guilt-free check-in, "come back whenever" tone, collection as the long game | One pet you raise vs. many cats you host; the device frame | Validates that removing punishment doesn't remove retention |
| Pou | Mobile virtual pet longevity, customization as a hook | Strict device frame, no mini-game sprawl, no ads | Shows customization sells but warns against feature bloat |
| Finch | Kind, encouraging tone; a pet as a companion for daily ritual | It's a game, not a habit tracker; no self-care prompts | Validates the "kind daily ritual" emotional register |
| Wordle | The single daily "done" state | Ongoing pet arc instead of a fresh puzzle | Validates once-a-day cadence with strong retention |

**Non-game inspirations**: 90s translucent toy plastics (Game Boy Color, iMac G3), gel pens and jelly shoes, LCD watch faces, Nintendo/Muji product-design cleanliness, the sound of a tiny piezo speaker.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 25–40 core (grew up with the original); secondary 16–25 cozy-game players |
| **Gaming experience** | Casual |
| **Time availability** | 1–3 minutes a day, often first thing in the morning or before bed |
| **Platform preference** | Phone, portrait, one-handed |
| **Current games they play** | Neko Atsume, Animal Crossing: Pocket Camp, Wordle / NYT Games, Finch, Pou |
| **What they're looking for** | A tiny, kind daily ritual with nostalgia and zero guilt; something charming to show a friend |
| **What would turn them away** | Energy timers, interrupting ads, pet death, complex menus, sessions that demand more than a couple of minutes |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 — the user's engine; strong 2D, lightweight, exports to iOS and Android; version already pinned in `docs/engine-reference/godot/` |
| **Key Technical Challenges** | Offline time simulation from saved timestamps; local push notifications (requires a third-party Godot plugin on both platforms); haptics via `Input.vibrate_handheld`; low-res LCD rendering (SubViewport + pixel-grid shader); iOS signing and store submission |
| **Art Style** | 2D, two-layer: smooth vector/painted device shells + ~32×32 pixel-art pet |
| **Art Pipeline Complexity** | Low — pixel art keeps each new form/animation to minutes; shells are recolorable shapes |
| **Audio Needs** | Minimal — a small set of piezo-style chirps and beeps, no music required for MVP |
| **Networking** | None |
| **Content Volume** | MVP: 1 shell, 1 species, egg + baby + child + 2 adult forms (~6 sprites × ~6 animations), 4 care actions, 1 mini-game. v1.0: 3 shell colorways, 4+ adult forms. Full vision: 10+ shells, 3+ species, seasonal palettes |
| **Procedural Systems** | None — adult form selection is a simple rule table over care stats |

---

## Risks and Open Questions

### Design Risks
- A 1–3 minute session may feel *too* thin — there may be nothing to linger on once needs are cleared.
- A 7–10 day growth arc may feel slow to first-time players before they've bonded with the pet.
- Adult-form selection may be illegible: if players can't tell how care influenced the outcome, the discovery aesthetic collapses.
- "Graduation" instead of death is untested emotionally — it might feel hollow rather than warm.

### Technical Risks
- Local notifications in Godot 4.6 depend on community plugins whose maintenance and 4.6 compatibility must be verified.
- Offline time simulation must be robust to clock changes, timezone shifts, and long absences without producing absurd states.
- iOS builds require a Mac and a $99/year Apple Developer account; store review adds calendar time.
- First game in Godot: tooling and export pipeline learning curve.

### Market Risks
- Saturated space: the official *My Tamagotchi Forever*, plus many clones. Differentiation rests on the device presentation and the no-guilt tone.
- Store discoverability for a tiny indie title is poor without a marketing hook (the colorful device screenshot must do the work).

### Scope Risks
- Shell art creep: every new shell is an asset; roadmap cost is entirely art time.
- "Add features later" becomes "add features before launch" — personality, species, and shells all tempt pre-launch inclusion. The anti-pillars and MVP definition are the guardrail.
- Solo first game on a weeks timeline leaves no slack for tooling surprises.

### Open Questions
- Does pressing an on-screen button with haptics + beep actually feel satisfying on glass? → **Resolve with `/prototype`** (1–3 days): a device frame, three buttons, one pet sprite, one need.
- What decay rate makes once-a-day feel right without guilt? → tune in the prototype with a compressed time scale.
- Is graduation emotionally satisfying? → playtest at the vertical slice with 3–5 people.
- Which notification plugin works on Godot 4.6 for both iOS and Android? → research spike during `/setup-engine` / architecture.
- Monetization model → decide before v1.0; the anti-pillars constrain the options.

---

## MVP Definition

**Core hypothesis**: Pressing a colorful on-screen Tamagotchi button and watching the pet react is satisfying enough that players want to do it again tomorrow.

**Required for MVP**:
1. Device frame with three working round buttons (haptic + beep + visual depress) and a low-res LCD area.
2. One pet species with egg → baby → child → adult stages and 2 adult forms selected by care quality.
3. Four needs (hunger, cleanliness, fun, sleep) with forgiving real-time decay and a non-fatal floor.
4. Four care actions (feed, clean, play via one left/right mini-game, lights) with reaction animations.
5. Offline time simulation and local save/load.
6. Happy-idle "done for today" state.

**Explicitly NOT in MVP** (defer to later):
- Multiple device shells (v1.0: 3 colorways; full vision: 10+)
- Graduation ceremony + album (vertical slice)
- Daily notification (vertical slice)
- Personality quirks from routine (post-launch)
- Additional species (post-launch)
- Any social, sharing, or monetization features

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 shell, 1 species, 2 adult forms | Core loop, offline time sim, local save | ~3 weeks |
| **Vertical Slice** | 4 adult forms | + haptics/SFX/LCD polish, graduation + album, daily notification, hatching onboarding | ~5 weeks total |
| **Alpha / v1.0** | 3 shell colorways | + settings (sound/haptics toggle), store assets, iOS + Android submission | ~7–8 weeks total |
| **Full Vision** | 10+ shells, 3+ species, seasonal palettes | + personality quirks, shell unlocks per graduation, hidden forms | 3–6 months of post-launch updates |

---

## Next Steps

- [ ] Fill in CLAUDE.md technology stack based on engine choice (`/setup-engine` — Godot 4.6, mobile)
- [ ] **Prototype core idea** (`/prototype device-button-feel`) — validate the pressable device is satisfying before writing GDDs
- [ ] Create the art bible (`/art-bible`) from the Candy Gadget visual anchor
- [ ] Validate this concept doc (`/design-review design/gdd/game-concept.md`)
- [ ] If prototype PROCEEDS: decompose concept into systems (`/map-systems`)
- [ ] Design each system (`/design-system [system-name]`) — use prototype learnings in Tuning Knobs and Formulas sections
- [ ] Build vertical slice in Pre-Production (`/vertical-slice`)
- [ ] Validate core loop with playtest (`/playtest-report`)
- [ ] Plan first milestone (`/sprint-plan new`)
