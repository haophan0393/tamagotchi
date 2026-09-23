# Epics Index

Last Updated: 2026-09-23
Engine: Godot 4.7.1

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Time Service](time-service/EPIC.md) | Foundation | Time Service | design/gdd/time-service.md | Not yet created | Ready |
| [Pet Definition Data](pet-definition-data/EPIC.md) | Foundation | Pet Definition Data | design/gdd/pet-definition-data.md | Not yet created | Ready |
| [Need System](need-system/EPIC.md) | Core | Need System | design/gdd/need-system.md | Not yet created | Ready |

**Build order**: Time Service → Pet Definition Data → Need System. Need System's
stories depend on both foundation epics' interfaces.

**Compressed-path note**: no `architecture.md` or `control-manifest.md` exists.
Module boundaries come from ADR-0001 and ADR-0002 (both Accepted 2026-09-23).
TR-IDs were added to `docs/architecture/tr-registry.yaml` at `/create-epics` time,
one per GDD Core Rule, because `/architecture-review` has not run yet.
