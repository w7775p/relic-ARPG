class_name PassiveDefinition
extends Resource
## 被动节点采用固定加值，资源只保存定义。
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var stat: String = ""
@export var value: float = 0.0

## 同一被动的第二属性可为负值，表达生存与速度/资源取舍。
@export var secondary_stat: String = ""
@export var secondary_value: float = 0.0

## 新被动从真实配置产生单位说明；旧被动沿用已发布文本。
func describe() -> String:
	if id not in ["momentum", "heavy_hand", "bulwark", "breath"]:
		return description
	var text: String = _stat_text(stat, value)
	if not secondary_stat.is_empty():
		text += "；" + _stat_text(secondary_stat, secondary_value)
	return text

## 格式化本轮被动的实际数值与单位。
func _stat_text(key: String, amount: float) -> String:
	match key:
		"charge_damage_multiplier": return "冲锋伤害 %+.0f%%" % (amount * 100.0)
		"heavy_damage_multiplier": return "重击伤害 %+.0f%%" % (amount * 100.0)
		"armor": return "护甲 %+.0f" % amount
		"move_speed_mps": return "移动速度 %+.1f 米/秒" % amount
		"max_health": return "生命上限 %+.0f" % amount
		"idle_energy_regen": return "停止施放回能 %+.0f/秒" % amount
	return description
