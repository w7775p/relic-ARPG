class_name SaveSlotResource
extends Resource
## 可重建的槽位摘要，不承担角色数据真源职责。
@export var group_id: String = ""
@export var slot_id: String = ""
@export var checkpoint_id: String = ""
@export var saved_at: int = 0
@export var sequence: int = 0
@export var level: int = 1
@export var usable: bool = false
@export var problem: String = ""

## 用真实文件和校验结果生成摘要；坏文件仍可展示诊断。
static func from_result(group: String, slot: String, result: SaveResult) -> SaveSlotResource:
	var entry: SaveSlotResource = SaveSlotResource.new()
	entry.group_id = group
	entry.slot_id = slot
	entry.usable = result.ok
	entry.problem = result.message
	if result.ok:
		var save: SaveGameResource = result.value
		entry.checkpoint_id = save.checkpoint_id
		entry.saved_at = save.saved_at
		entry.sequence = save.sequence
		for module: SaveModule in save.modules:
			if module is CharacterResource:
				entry.level = module.level
	return entry

## 显示手动槽、自动历史与中断写入留下的恢复副本。
func label() -> String:
	var kind: String = "自动" if slot_id.begins_with("auto_") else "手动"
	var suffix: String = "（中断恢复副本）" if slot_id.ends_with(".rollback") else ""
	var state: String = Time.get_datetime_string_from_unix_time(saved_at).replace("T", " ") if usable else "不可读取：" + problem
	return "%s %s%s · 等级 %d · %s" % [kind, slot_id.get_slice("_", 1).get_slice(".", 0), suffix, level, state]
