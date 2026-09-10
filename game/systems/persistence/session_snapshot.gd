class_name SessionSnapshot
extends RefCounted
## 显式字段快照，保存攻击动作、弹体和冷却；导航路径在恢复后重算。
const ACTOR: Array[String] = ["health", "max_health", "armor", "is_dead", "shock_remaining_sec", "stagger_remaining_sec", "knockback_velocity", "velocity"]
const ENEMY: Array[String] = ["state", "state_remaining", "_cooldown", "_locked_direction", "attacks_performed"]
const PLAYER: Array[String] = ["dodge_remaining_sec", "cooldown_remaining_sec", "_dodge_direction"]
const SKILL: Array[String] = ["energy", "_attack_remaining", "_whirlwind_remaining", "_exhausted"]
const PROJECTILE: Array[String] = ["direction", "damage", "lifetime_sec", "speed_mps"]

## 向量转换为 JSON 数组。
static func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

## 数组恢复三维向量。
static func unvector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

## 仅导出调用方列出的运行字段。
static func fields(object: Object, names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for key: String in names:
		var value: Variant = object.get(key)
		result[key] = vector(value) if value is Vector3 else value
	return result

## 根据对象字段类型恢复，整数保持整数类型。
static func apply(object: Object, data: Dictionary) -> void:
	for key: String in data:
		var old: Variant = object.get(key)
		var value: Variant = data[key]
		if old is Vector3:
			value = unvector(value)
		elif old is int:
			value = int(value)
		object.set(key, value)
