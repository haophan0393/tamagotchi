# Prototypes Index

Complete history of what was tried and what was learned. Code in these folders is
throwaway — never import into `src/`.

## Concept Prototypes

| Concept | Date | Path | Verdict | Report | Notes |
|---------|------|------|---------|--------|-------|
| device-button-feel | 2026-09-18 | Engine (Godot 4.7.1) | PROCEED | [REPORT.md](device-button-feel-concept/REPORT.md) | Haptic sync untested on device — open risk |
| lcd-rendering | 2026-09-22 | Engine (Godot 4.7.1) | PROCEED (Approach A) | [REPORT.md](lcd-rendering-spike/REPORT.md) | `DrawableTexture2D` is blit-only, no `draw_*` — rejected. On-device perf untested |
