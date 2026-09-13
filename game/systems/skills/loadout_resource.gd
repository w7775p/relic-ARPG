class_name LoadoutResource
extends Resource
## 角色长期装配，只记录稳定技能和被动 ID；技能数值来自静态配置。
@export var slots: Dictionary[String, String] = {"basic":"primary", "main":"whirlwind", "auxiliary":""}
@export var passives: Array[String] = []

## 校验技能槽、被动上限和重复选择。
func valid() -> bool:
	return LoadoutState.valid({"slots":slots, "passives":passives})
