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


func _ready() -> void:
	_time_service = TimeProvider.service
