class_name HubResource
extends SaveModule
## 据点位置和出发区域选择；地图布局及本趟房间进度归运行场景。
@export var hub_id: String = "camp"
@export var region_id: String = "arena"

## 初始化稳定模块 ID。
func _init() -> void:
	module_id = "hub"

## 据点入口依赖角色进度完成恢复。
func dependencies() -> Array[String]:
	return ["progression"]

## 当前只有一个真实据点和一个固定探险区域。
func validate() -> SaveResult:
	var result: SaveResult = super.validate()
	if not result.ok:
		return result
	if hub_id != "camp" or region_id != "arena":
		return invalid("hub_id/region_id", "存档引用的据点或区域内容缺失")
	return SaveResult.success()
