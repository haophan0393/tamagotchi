# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do the three round device buttons feel tactile and satisfying (press visual + haptic + beep as one click)?
# Date: 2026-09-18

Throwaway concept prototype for Pocket Pal. Never import into `src/`.

## Run (desktop)
    godot --path prototypes/device-button-feel-concept

Or open the folder in the Godot 4.7.1 project manager and press F5.
Desktop has no haptics — mouse clicks emulate touch; only visual + beep are testable here.

## Run (phone — the real test)
Haptic sync is the riskiest assumption, so test on a device:
- Android: Project > Export > Android, "One-click deploy" with USB debugging on.
- iOS: export requires Xcode + signing; if that's too heavy for a throwaway, Android first.

## What to observe
Hand the phone to someone without explanation. Watch for playful repeat presses in the first 30 s
(the on-screen counter records "presses in first 30s"). Then ask only: "What was confusing?"

## Tuning knobs
All constants at the top of `main.gd`: press depth/scale/timing, haptic ms/amplitude, beep pitch/length.
