## Test-only [DefinitionResource] subclass holding a nested [DefinitionResource],
## an [code]Array[DefinitionResource][/code] and an [code]Array[StringName][/code],
## for AC-3 (recursive [method DefinitionResource.lock]). Never referenced from
## `src/` — this script lives entirely under `tests/`.
class_name ProbeContainerDefinition extends DefinitionResource

@export var nested: DefinitionResource:
	set(new_value):
		if _reject_write(&"nested"):
			return
		nested = new_value

@export var items: Array[DefinitionResource] = []:
	set(new_value):
		if _reject_write(&"items"):
			return
		items = new_value

## Non-definition array — lock() must make it read-only and skip its elements.
@export var tags: Array[StringName] = []:
	set(new_value):
		if _reject_write(&"tags"):
			return
		tags = new_value
