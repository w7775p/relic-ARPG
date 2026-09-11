class_name SkillDefinition
extends Resource
## 静态技能身份、适用槽和可编辑规则参数；运行时状态由 SkillRunner 持有。
@export var id: String = ""
@export var display_name: String = ""
@export var slot: String = ""
@export var tags: PackedStringArray = []
@export var damage_multiplier: float = 1.0
@export var range_m: float = 0.0
@export var energy_cost: float = 0.0
@export var cooldown_sec: float = 0.0
@export var facing_dot_min: float = 0.0
@export var bleed_damage_multiplier: float = 0.0
@export var bleed_duration_sec: float = 0.0
@export var bleed_tick_sec: float = 0.0
@export var bleed_max_stacks: int = 0
@export var armor_bonus: float = 0.0
@export var energy_restore: float = 0.0
@export var duration_sec: float = 0.0
@export var heal_ratio: float = 0.0

## 显示当前伤害、消耗、持续时间与冷却，数值直接读取实际资源。
func describe(build: BuildDefinition) -> String:
	var tag_text: String = " / ".join(tags)
	match id:
		"primary":
			return "%s｜%s｜伤害 %.1f｜无消耗｜间隔 %.2f 秒" % [display_name, tag_text, build.damage * 1.5, build.attack_interval_sec]
		"whirlwind":
			return "%s｜%s｜伤害 %.1f｜消耗 %.1f/秒｜伤害间隔 %.2f 秒" % [display_name, tag_text, build.damage, build.energy_cost_per_sec, build.whirlwind_interval_sec]
		"sweep":
			return "%s｜%s｜伤害 %.1f｜范围 %.1f 米｜消耗 %.0f｜间隔 %.2f 秒｜流血 %.1f 秒×最多%d层" % [display_name, tag_text, build.damage * damage_multiplier, range_m, energy_cost, cooldown_sec, bleed_duration_sec, bleed_max_stacks]
		"warcry":
			return "%s｜%s｜护甲 +%.0f｜回能 %.0f｜持续 %.1f 秒｜冷却 %.1f 秒" % [display_name, tag_text, armor_bonus, energy_restore, duration_sec, cooldown_sec]
		"potion":
			return "%s｜恢复 %.0f%% 最大生命｜冷却 %.1f 秒" % [display_name, heal_ratio * 100.0, cooldown_sec]
	return display_name
