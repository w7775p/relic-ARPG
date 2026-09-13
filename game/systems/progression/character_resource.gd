class_name CharacterResource
extends SaveModule
## 角色成长、装配和角色级偏好；不包含生命、冷却或场景节点。
@export var level: int = 1
@export var experience: int = 0
@export var minimum_quality: int = 0
@export var loadout: LoadoutResource = LoadoutResource.new()

## 初始化稳定模块 ID。
func _init() -> void:
	module_id = "character"

## 校验成长范围和当前内容可解释的技能选择。
func validate() -> SaveResult:
	var result: SaveResult = super.validate()
	if not result.ok:
		return result
	if level < 1 or level > 1000000 or experience < 0 or experience >= level * 60:
		return invalid("level/experience", "角色等级或经验不合法")
	if minimum_quality < 0 or minimum_quality > 2:
		return invalid("minimum_quality", "掉落过滤设置不合法")
	if loadout == null or not loadout.valid():
		return invalid("loadout", "技能或被动缺失、重复或槽位不匹配")
	return SaveResult.success()
