## Test-only [DefinitionResource] subclass with a single guarded field.
##
## Used by both AC-2 (in-memory, `tests/unit/pet_definition_data/`) and
## ADR-0002 Verification #1 (loaded from
## `tests/fixtures/pet_data/probe_definition.tres`). Never referenced from
## `src/` — this script lives entirely under `tests/`.
##
## [member setter_call_count] is a plain, non-exported counter incremented
## only when a write actually applies (the guard did not reject it).
## Verification #1 uses it to prove [method ResourceLoader.load] runs this
## setter while [member DefinitionResource._locked] is still [code]false[/code].
class_name ProbeDefinition extends DefinitionResource

## Non-exported — proves the guarded setter ran; never touched by
## [method DefinitionResource.lock] (not [constant PROPERTY_USAGE_STORAGE]).
var setter_call_count: int = 0

@export var value: int = 0:
	set(new_value):
		if _reject_write(&"value"):
			return
		value = new_value
		setter_call_count += 1
