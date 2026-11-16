class_name CardEffect

extends Resource

func apply(_ctx: EffectContext) -> void:
	push_error("CardEffect.apply() not implemented by %s" % get_script().resource_path)

func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return ""

func describe_live(_battle, _source: int, _target: int, _targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return describe()

static func who_key(targeting: int) -> String:
	match targeting:
		CardTargeting.Mode.ALL_ENEMIES: return "target.all_enemies"
		CardTargeting.Mode.RANDOM_ENEMY: return "target.random_enemy"
		CardTargeting.Mode.SELF: return "target.self"
	return "target.enemy"

static func names_its_target(targeting: int) -> bool:
	return targeting == CardTargeting.Mode.ALL_ENEMIES \
		or targeting == CardTargeting.Mode.RANDOM_ENEMY

func faces_enemies() -> bool:
	return false

func upgraded_self(_by: int) -> CardEffect:
	return self
