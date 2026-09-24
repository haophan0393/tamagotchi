## Code enum for the four Life Stage identifiers (TR-pet-definition-data-001;
## ADR-0002 §1). Fixed in code, never sourced from data — exactly four
## values, in this order (Core Rule 1).
##
## Sibling of [code]pet_enums.gd[/code] (which carries [Need]) and
## [code]care_action.gd[/code] (which carries [CareAction]) — split into three
## files so each enum is reachable by its bare [code]ClassName.Id[/code] name.
## See [code]pet_enums.gd[/code] for the full rationale.
##
## [b]Example[/b]:
## [codeblock]
## if pet.stage == LifeStage.Id.EGG:
##     play_hatch_animation()
## [/codeblock]
class_name LifeStage extends RefCounted

## The four life stages, in GDD-authored order.
enum Id {
	EGG,
	BABY,
	CHILD,
	ADULT,
}
