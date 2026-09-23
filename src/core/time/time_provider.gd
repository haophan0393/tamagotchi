## Autoload exposing the single production [TimeService] instance.
##
## Built in [method Object._init], not [method Node._ready], so the instance
## exists before any other Autoload or scene-tree node's [code]_ready()[/code]
## runs (ADR-0001 §2, TR-time-service-003). This node holds nothing but that
## one service — no other state, no helper methods.
##
## Only [code]src/core/app/[/code] and [code]src/core/time/[/code] may
## reference [code]TimeProvider[/code] by name; the [code]clock-discipline[/code]
## workflow's [code]TimeProvider[/code] lint step
## (.github/workflows/tests.yml) fails the build on any other reference
## (ADR-0001 Risks, [code]autoload_access_from_logic[/code]). In practice this
## means only [GameRoot], the composition root, reads [member service] — logic
## classes must receive [TimeService] via their own [code]_init()[/code]
## instead.
##
## Deliberately has no [code]class_name[/code] — one would collide with the
## Autoload singleton name [code]TimeProvider[/code] registered in
## [code]project.godot[/code].
##
## [b]Example[/b] (composition root only — see ADR-0001 §2):
## [codeblock]
## func _ready() -> void:
##     var time_service: TimeService = TimeProvider.service
## [/codeblock]
extends Node

var _service: TimeService

## The one production [TimeService], wired to [SystemTimeSource]. Read-only:
## assigning to this property is rejected with [method @GlobalScope.push_error]
## and the original instance is left in place.
var service: TimeService:
	get:
		return _service
	set(_value):
		push_error("TimeProvider.service is read-only; ignoring assignment.")


func _init() -> void:
	_service = TimeService.new(SystemTimeSource.new())
