## Code enum for the four Care Action identifiers (TR-pet-definition-data-001;
## ADR-0002 §1). Fixed in code, never sourced from data — exactly four
## values, in this order (Core Rule 1).
##
## Sibling of [code]pet_enums.gd[/code] (which carries [Need]) and
## [code]life_stage.gd[/code] (which carries [LifeStage]) — split into three
## files so each enum is reachable by its bare [code]ClassName.Id[/code] name.
## See [code]pet_enums.gd[/code] for the full rationale.
##
## [b]Example[/b]:
## [codeblock]
## func get_restore_amount(action: CareAction.Id) -> int:
##     match action:
##         CareAction.Id.FEED: return feed
##         _: return 0
## [/codeblock]
class_name CareAction extends RefCounted

## The four care actions, in GDD-authored order.
enum Id {
	FEED,
	CLEAN,
	PLAY,
	LIGHTS,
}
