# Smoke Test: Critical Paths

**Purpose**: run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check`, which reads this file.
**Update**: add an entry when a new core system lands; mark the sprint it arrived in.

Checks are marked **[PENDING]** until the system they cover is implemented.
A pending check is not a failure — it is scope that does not exist yet.

## Core stability

1. **[PENDING]** App launches to the device screen without crash (cold start).
2. **[PENDING]** App survives background → foreground without crash or visual corruption.
3. **[PENDING]** All three device buttons respond to touch; none are dead or double-firing.

## Core loop — Pocket Pal

The loop under test: *open the app → read the pet's state off the LCD → clear a
need in ≤3 presses → get visible + audible + haptic confirmation → close.*

4. **[PENDING]** LCD renders the pet at the correct life stage for the current save.
5. **[PENDING]** Each of the pet's needs is legible from the LCD alone, with sound and
   haptics off. *(Pillar: the visual channel must carry the full experience alone.)*
6. **[PENDING]** A care action can be reached and performed in **≤3 button presses**.
7. **[PENDING]** Performing a care action clears the matching need and plays the
   press-visual + beep + haptic together, read as synced.
8. **[PENDING]** No care action can put the pet into a fail state — there is no death
   and no punishment screen anywhere in the loop. *(Pillar 2.)*

## Time and persistence

9. **[PENDING]** Save completes without error; `last_seen` is written as a UTC epoch.
10. **[PENDING]** Load restores pet stage, needs, and care history exactly.
11. **[PENDING]** Reopening after a multi-hour absence decays needs by the elapsed
    time, clamped at `MAX_OFFLINE`.
12. **[PENDING]** Reopening after a multi-day absence shows a **warm greeting**, never
    a penalty, and growth has not advanced for the absent days.
13. **[PENDING]** Moving the device clock backwards does not produce negative elapsed
    time, corrupt the save, or crash.

## Performance

14. **[PENDING]** Holds 60 fps on the low-end Android target during the full loop.
15. **[PENDING]** No memory growth across 5 minutes of continuous play
    (ceiling: ~150 MB resident).
