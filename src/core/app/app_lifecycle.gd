## Translates OS application-lifecycle notifications into two edge-detected
## signals.
##
## ADR-0001 §4: one [AppLifecycle] node, a child of [GameRoot], maps
## [constant Node.NOTIFICATION_APPLICATION_PAUSED] and
## [constant Node.NOTIFICATION_APPLICATION_FOCUS_OUT] to [signal
## app_backgrounded], and [constant Node.NOTIFICATION_APPLICATION_RESUMED]
## and [constant Node.NOTIFICATION_APPLICATION_FOCUS_IN] to [signal
## app_resumed]. A private edge-detect bool guarantees each transition emits
## exactly once even when the OS delivers both notifications for the same
## transition (e.g. Android/iOS deliver PAUSED and FOCUS_OUT together).
##
## This class holds no other logic and reads no clock (TR-time-service-005;
## Story 004 Control Manifest: "AppLifecycle contains no logic and no time
## reads; it only translates notifications into two signals").
##
## [b]Engine risk (unverified here):[/b] whether these notifications actually
## propagate to a non-root child [code]Node[/code] — as opposed to only the
## scene root — is [b]inferred, not documented[/b] for Godot 4.7.1
## (ADR-0001 Risks: "NOTIFICATION_APPLICATION_* does not reach a non-root
## child"). That is verified on real Android/iOS devices in Story 005, not
## here. If verification fails, ADR-0001 §4's stated fallback is to move
## [method _notification] into [code]GameRoot[/code] itself; the two signals
## below and every consumer are unaffected.
##
## [b]Example[/b]:
## [codeblock]
## var lifecycle := AppLifecycle.new()
## add_child(lifecycle)
## lifecycle.app_backgrounded.connect(_on_app_backgrounded)
## lifecycle.app_resumed.connect(_on_app_resumed)
## [/codeblock]
class_name AppLifecycle extends Node

## Emitted exactly once when the app transitions from foreground to
## background: mobile [constant Node.NOTIFICATION_APPLICATION_PAUSED], or
## [constant Node.NOTIFICATION_APPLICATION_FOCUS_OUT] on any platform.
signal app_backgrounded

## Emitted exactly once when the app transitions from background back to
## foreground: mobile [constant Node.NOTIFICATION_APPLICATION_RESUMED], or
## [constant Node.NOTIFICATION_APPLICATION_FOCUS_IN] on any platform.
signal app_resumed

## Edge-detect flag. Starts [code]false[/code] (foreground), so a spurious
## [code]FOCUS_IN[/code] at launch emits nothing (Implementation Notes).
var _in_background: bool = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not _in_background:
				_in_background = true
				app_backgrounded.emit()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _in_background:
				_in_background = false
				app_resumed.emit()
