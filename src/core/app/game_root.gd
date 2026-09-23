## Composition root for Pocket Pal.
##
## Root node of [code]GameRoot.tscn[/code], the project's main scene. This is
## the only script that reads [code]TimeProvider.service[/code] (ADR-0001 §2)
## and, as later stories land, the only place that constructs the game's
## logic objects and wires their signals together. Adding a system means
## editing this one file.
##
## Construction order (ADR-0001 §2, §4-5) — later stories slot into this list
## in order:
##   1. TimeProvider.service                          (this story)
##   2. Pet catalog load                               (Pet Definition Data epic)
##   3. NeedSystem construction                        (Need System epic)
##   4. NeedCrossingScheduler / AppLifecycle adapters   (Story 004; Need System epic)
##   5. Signal connections between the above
##
## [b]Example[/b]:
## [codeblock]
## # GameRoot.tscn is set as the main scene; Godot instantiates it and calls
## # _ready() automatically. No other code constructs GameRoot directly,
## # except tests instantiating the scene to assert on _ready()'s result.
## [/codeblock]
class_name GameRoot extends Node

var _time_service: TimeService

## The [TimeService] instance this root read from [code]TimeProvider[/code] at
## boot. Read-only — assigning is rejected with [method @GlobalScope.push_error].
## Exposed for later construction steps and for tests that verify GameRoot
## holds the same instance as the Autoload.
var time_service: TimeService:
	get:
		return _time_service
	set(_value):
		push_error("GameRoot.time_service is read-only; ignoring assignment.")


@onready var _app_lifecycle: AppLifecycle = $AppLifecycle


func _ready() -> void:
	_time_service = TimeProvider.service

	_app_lifecycle.app_backgrounded.connect(_on_app_backgrounded)
	_app_lifecycle.app_resumed.connect(_on_app_resumed)


## Handles [signal AppLifecycle.app_backgrounded] (ADR-0001 §4). iOS allows
## only ~5 s after [constant Node.NOTIFICATION_APPLICATION_PAUSED] before the
## process may be suspended, so whatever fills this slot must stay
## synchronous and small (Story 004 Control Manifest guardrail).
func _on_app_backgrounded() -> void:
	# ADR-0003 (planned, not yet designed): request a save here. Out of
	# scope for Story 004 — left as a no-op slot.
	pass


## Handles [signal AppLifecycle.app_resumed]. This is the single definition
## of resume order (ADR-0001 §4) — slot order is fixed and must not be
## reordered: the offline cap re-anchors before needs check crossings, and
## the scheduler re-arms last. Every slot is a no-op until its collaborator
## exists; none of them are implemented by Story 004.
func _on_app_resumed() -> void:
	# 1. offline_sim.reanchor_with_cap(...) — Offline Time Simulation has no
	#    GDD yet; no-op until then.
	# 2. needs.on_resumed() — pure; fires any crossing that happened while
	#    suspended. Idempotent, so a spurious resume (focus flicker) is
	#    harmless by design (Need System GDD).
	# 3. crossing_scheduler.rearm() — re-arms the one-shot Timer last.
	pass
