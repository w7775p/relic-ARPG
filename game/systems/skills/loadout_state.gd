class_name LoadoutState
extends RefCounted
## 会话拥有装配和被动；地点授权由探险会话统一检查。
const SKILLS: Array[SkillDefinition] = [preload("res://content/skills/primary.tres"), preload("res://content/skills/whirlwind.tres"), preload("res://content/skills/sweep.tres"), preload("res://content/skills/warcry.tres")]
const PASSIVES: Array[PassiveDefinition] = [preload("res://content/passives/might.tres"), preload("res://content/passives/precision.tres"), preload("res://content/passives/reach.tres"), preload("res://content/passives/vitality.tres"), preload("res://content/passives/guard.tres"), preload("res://content/passives/recovery.tres")]
const LIMIT: int = 3
var slots: Dictionary = {"basic":"primary", "main":"whirlwind", "auxiliary":""}
var passives: Array = []

## 稳定 ID 查询技能。
static func skill(id: String) -> SkillDefinition:
	for definition: SkillDefinition in SKILLS:
		if definition.id == id:
			return definition
	return null

## 稳定 ID 查询被动。
static func passive(id: String) -> PassiveDefinition:
	for definition: PassiveDefinition in PASSIVES:
		if definition.id == id:
			return definition
	return null

## 空槽合法；已装技能必须匹配槽位。
static func fits(slot: String, id: String) -> bool:
	return ["basic", "main", "auxiliary"].has(slot) and (id.is_empty() or (skill(id) != null and skill(id).slot == slot))

## 选择或取消节点，第四项失败时保持原选择。
func toggle(id: String) -> String:
	if passive(id) == null:
		return "未知被动"
	if passives.has(id):
		passives.erase(id)
	elif passives.size() >= LIMIT:
		return "最多选择三个被动，请先取消一项"
	else:
		passives.append(id)
	return ""

## 校验装配快照，包括数量、重复与未知字段。
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 2 or not data.get("slots") is Dictionary or not data.get("passives") is Array:
		return false
	if data.slots.size() != 3 or data.passives.size() > LIMIT:
		return false
	for slot: String in ["basic", "main", "auxiliary"]:
		if not data.slots.get(slot) is String or not fits(slot, data.slots[slot]):
			return false
	var seen: Array = []
	for id: Variant in data.passives:
		if not id is String or passive(id) == null or seen.has(id):
			return false
		seen.append(id)
	return true

## 创建独立存档数据。
func snapshot() -> Dictionary:
	return {"slots":slots.duplicate(), "passives":passives.duplicate()}

## 恢复经过校验的会话选择。
func restore(data: Dictionary) -> void:
	slots = data.slots.duplicate()
	passives = data.passives.duplicate()
