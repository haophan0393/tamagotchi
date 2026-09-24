## Code enum for the four Need identifiers (TR-pet-definition-data-001;
## ADR-0002 §1). Fixed in code, never sourced from data — exactly four
## values, in this order (Core Rule 1).
##
## [b]File layout note (deviation from the story's single-file path):[/b]
## GDScript allows exactly one top-level [code]class_name[/code] per script,
## and the required access syntax is the bare [code]Need.Id[/code] (not
## [code]PetEnums.Need.Id[/code]) — that only a global class name provides.
## An inner class of a [code]class_name[/code] script cannot itself carry a
## [code]class_name[/code], so [code]Need.Id[/code], [code]CareAction.Id[/code]
## and [code]LifeStage.Id[/code] cannot all live in one file and still be
## reachable by their bare names. This file carries [code]Need[/code]; its
## siblings [code]care_action.gd[/code] and [code]life_stage.gd[/code] in this
## same directory carry [code]CareAction[/code] and [code]LifeStage[/code].
## See the story's completion notes for the full rationale.
##
## [b]Example[/b]:
## [codeblock]
## func get_params(need: Need.Id) -> NeedParams:
##     match need:
##         Need.Id.HUNGER: return hunger
##         _: return null
## [/codeblock]
class_name Need extends RefCounted

## The four needs, in GDD-authored order. Do not reorder — enum order is part
## of the urgency tie-break contract (need-system TR-need-system-011).
enum Id {
	HUNGER,
	CLEANLINESS,
	FUN,
	SLEEP,
}
