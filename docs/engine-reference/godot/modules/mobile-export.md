# Godot Mobile Export (Android / iOS) — Quick Reference

Last verified: 2026-09-18 | Engine: Godot 4.7.1

Scope: what changed for mobile targets since ~4.3, plus the open items this
project must verify before architecture. Only items confirmed against the 4.7
release notes / migration guide / 4.7.1 notes are listed as facts.

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 / 4.7.1
- **Standalone Android export via GABE** (Godot Android Build Environment) — stable; standard export path no longer requires a full Android Studio setup
- **Custom splash screens** configurable in the Android export preset
- **Selective export template download** — fetch only the platforms you ship (iOS, Android)
- **Java interfaces implementable from GDScript** — small platform hooks without a Kotlin plugin
- **Picture-in-picture** and embedded/movable game window on Android
- **Perfetto tracing** default for Android debug builds
- **HDR output on iOS** (and visionOS)
- **iOS game controllers** via SDL3
- **4.7.1**: Android soft-keyboard backspace fixed; virtual keyboard no longer auto-opens on popup menus; touchscreen drag-and-drop regression fixed

### 4.5 / 4.6
- **Android 16 KB page-size support** — required for Google Play targeting Android 15+
- **Android edge-to-edge display** and camera feed access
- **visionOS** export target added (4.5)

## Project Defaults That Matter for Portrait Mobile (4.7)
```
display/window/stretch/mode   = canvas_items   (new default)
display/window/stretch/aspect = expand         (new default)
display/window/handheld/orientation = portrait (set explicitly)
rendering/renderer/rendering_method.mobile = mobile
```
Verify the device-frame layout under `expand` on both 19.5:9 and 16:9 screens.

## OPEN — Verify Before Architecture (not yet confirmed for 4.7)
| Topic | Why it matters | How to verify |
|-------|----------------|---------------|
| `Input.vibrate_handheld()` signature and amplitude support on iOS/Android | Haptic click on every button press is Pillar 1 | Read 4.7 class ref for `Input`; test on device in `/prototype` |
| Local push notifications | Daily reminder (vertical slice) | Godot has no built-in API; survey Asset Store plugins for 4.7 compatibility on BOTH platforms — record in an ADR |
| Background time / `NOTIFICATION_APPLICATION_PAUSED` / `_RESUMED` behavior | Offline time simulation on resume | Read 4.7 `MainLoop` notifications; test app suspend/resume on device |
| iOS export signing flow in 4.7 | Store submission at v1.0 | Follow 4.7 "Exporting for iOS" docs; needs Apple Developer account |
| Safe-area API (`DisplayServer.get_display_safe_area()`) | Notched phones | Confirm in 4.7 class ref; apply to device-frame margins |

## Common Mistakes
- Assuming Android export still needs the full Android Studio path (GABE handles the standard case in 4.7)
- Downloading all export templates when only iOS + Android are needed (4.7 supports selective download)
- Writing a custom touch joystick when `VirtualJoystick` exists (not needed for this project, but do not reinvent)
- Forgetting `display/window/handheld/orientation` — stretch defaults alone do not lock portrait
