## Base class for every Pet Definition Data schema [Resource]
## (TR-pet-definition-data-003; ADR-0002 §1-2).
##
## Every [code]@export[/code] field on a subclass must be guarded by a setter
## that calls [method _reject_write] first and returns immediately if it does.
## Name the setter parameter [code]new_value[/code] so it never shadows the
## property:
## [codeblock]
## @export var decay_per_hour: float = 3.0:
##     set(new_value):
##         if _reject_write(&"decay_per_hour"):
##             return
##         decay_per_hour = new_value
## [/codeblock]
##
## [method lock] is called exactly once, by [code]PetCatalogLoader[/code]
## (Story 005) after validation succeeds. After that, every guarded write is
## rejected: [method @GlobalScope.push_error]-logged and ignored, never a
## crash, in every build type (Pillar 2).
##
## [member _locked] is a plain, non-exported [code]var[/code] — it must never
## serialise and must never survive [method Resource.duplicate]. Only
## [constant PROPERTY_USAGE_STORAGE] properties are copied by
## [method Resource.duplicate], so a duplicated definition is always unlocked;
## this is closed by CI lint (the [code]definition_duplicate[/code] forbidden
## pattern in [code]docs/registry/architecture.yaml[/code]), not by this class.
##
## [b]Example[/b]:
## [codeblock]
## var species := SpeciesDefinition.new()
## species.display_name = "Bloop"   # allowed — unlocked
## species.lock()
## species.display_name = "Oops"    # rejected: push_error, value unchanged
## [/codeblock]
class_name DefinitionResource extends Resource

## Not [code]@export[/code] — must not serialise and must not survive
## [method duplicate].
var _locked: bool = false


## Locks this definition and recurses into every stored
## ([constant PROPERTY_USAGE_STORAGE]) property: a nested [DefinitionResource]
## value is locked in turn; an [Array] value is made read-only with
## [method Array.make_read_only] and then each [DefinitionResource] element in
## it is locked. Skips [code]_locked[/code] itself and engine-owned
## properties ([code]resource_*[/code], [code]script[/code]).
##
## Returns immediately when already locked. That makes a second call a no-op
## and makes a cyclic graph (a definition reachable from itself) safe to lock.
##
## [b]Locked arrays fail differently from guarded fields[/b] (verified on
## 4.7.1, ADR-0002 Verification #4): [method Array.append] and
## [method Array.sort] on a locked array log an error and the caller carries
## on, but an indexed write ([code]arr[i] = v[/code]) raises a GDScript
## runtime error that [b]aborts the calling function[/b]. The array is
## unchanged either way. Never write into a definition's array by index.
##
## [b]Example[/b]:
## [codeblock]
## species.lock()
## species.lock()  # no-op — already locked
## [/codeblock]
func lock() -> void:
	if _locked:
		return
	_locked = true
	for property: Dictionary in get_property_list():
		var usage: int = property.usage
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var field_name: String = property.name
		if field_name == "_locked" or field_name == "script" or field_name.begins_with("resource_"):
			continue
		var field_value: Variant = get(field_name)
		if field_value is DefinitionResource:
			(field_value as DefinitionResource).lock()
		elif field_value is Array:
			var array_value: Array = field_value
			array_value.make_read_only()
			for element: Variant in array_value:
				if element is DefinitionResource:
					(element as DefinitionResource).lock()


## Returns [code]true[/code] and logs a [method @GlobalScope.push_error]
## naming [member Resource.resource_path] and [param field] when this
## definition is locked. A guarded setter must call this first and return
## immediately when it is [code]true[/code], leaving its backing field
## unchanged. Returns [code]false[/code] when unlocked, so the caller's
## setter may proceed. Never raises — a rejected write is always ignored,
## never a crash, in every build type (Pillar 2).
##
## [b]Example[/b]:
## [codeblock]
## set(new_value):
##     if _reject_write(&"value"):
##         return
##     value = new_value
## [/codeblock]
func _reject_write(field: StringName) -> bool:
	if not _locked:
		return false
	push_error("Definition is immutable after catalog Ready: %s.%s" % [resource_path, field])
	return true
