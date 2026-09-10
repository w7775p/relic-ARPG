class_name BuildDefinition
extends Resource
## M1 装备预设汇总值；M2 由真实穿戴装备生成同类属性快照。

@export var display_name: String = "基础装备"
@export var damage: float = 24.0
@export var attack_interval_sec: float = 0.42
@export var whirlwind_interval_sec: float = 0.22
@export var whirlwind_radius_m: float = 2.6
@export var move_speed_mps: float = 7.0
@export var critical_chance: float = 0.1
@export var critical_multiplier: float = 1.8
@export var energy_cost_per_sec: float = 25.0
@export var idle_energy_regen: float = 18.0
@export var hit_energy: float = 0.0
@export var kill_energy: float = 0.0
@export var chain_count: int = 0
@export var chain_range_m: float = 4.5
@export var lightning_damage: float = 30.0
@export var lightning_cooldown_sec: float = 0.12
@export var shock_duration_sec: float = 3.0
@export var explosion_radius_m: float = 3.8
@export var explosion_damage: float = 45.0
@export var death_explosion: bool = false


## 从真实参数生成预设说明，避免文本与计算分离。
func describe() -> String:
	var text: String = "%s｜伤害 %.0f｜暴击 %.0f%%｜旋风范围 %.1f 米" % [display_name, damage, critical_chance * 100.0, whirlwind_radius_m]
	if chain_count > 0:
		text += "\n直接暴击触发 %d 目标闪电（间隔 %.2f 秒）；闪电使存活目标感电 %.1f 秒" % [chain_count, lightning_cooldown_sec, shock_duration_sec]
	if death_explosion:
		text += "\n感电死亡爆炸 %.0f 伤害 / %.1f 米" % [explosion_damage, explosion_radius_m]
	if hit_energy > 0.0 or kill_energy > 0.0:
		text += "\n直接命中回能 %.1f，击杀回能 %.1f" % [hit_energy, kill_energy]
	text += "\n旋风消耗 %.0f 能量/秒；停止施放回复 %.0f/秒" % [energy_cost_per_sec, idle_energy_regen]
	return text
