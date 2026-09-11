class_name SkillDefinition
extends Resource
## 静态技能身份与适用槽；数值说明读取当前构筑，避免换装后说明过期。
@export var id: String = ""
@export var display_name: String = ""
@export var slot: String = ""
@export var tags: PackedStringArray = []

## 显示当前伤害、消耗与攻击间隔（秒）。
func describe(build: BuildDefinition) -> String:
	if id == "primary":
		return "%s｜%s｜伤害 %.1f｜无消耗｜间隔 %.2f 秒" % [display_name, " / ".join(tags), build.damage * 1.5, build.attack_interval_sec]
	return "%s｜%s｜伤害 %.1f｜消耗 %.1f/秒｜伤害间隔 %.2f 秒" % [display_name, " / ".join(tags), build.damage, build.energy_cost_per_sec, build.whirlwind_interval_sec]
