extends "res://world/maps/expedition.gd"
## 正式探险运行场景：接收独立 Hub 的角色状态，撤离与死亡通过真实场景切换返回 Hub。

var _received_hub_state: bool = false


## 先复用旧探险初始化，再用 Hub 状态替换临时兼容角色并立即开始战斗。
func _ready() -> void:
	var transition: Dictionary = SceneRouter.take_character_state()
	_received_hub_state = not transition.is_empty()
	super._ready()
	if not _received_hub_state:
		return
	inventory = transition.inventory
	generator = transition.generator
	minimum_quality = int(transition.minimum_quality)
	inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()
	depart()


## 正式探险始终位于战斗场景；共用 UI 据此关闭据点专属服务。
func is_hub() -> bool:
	return false


## 从独立 Hub 开始新探险；当前正常场景流不再触发旧 JSON 据点自动保存。
func depart() -> void:
	if not in_town:
		return
	in_town = false
	wave_completed = false
	panel.hide()
	_set_paused(false)
	effects.reset()
	combat.kills = 0
	combat.damage_dealt = 0.0
	player.restore_position(Vector3.ZERO)
	player.reset_health()
	skills.reset()
	_clear_ground()
	encounters.clear()
	for index: int in range(48):
		var original: EnemyDefinition = EncounterDirector.ELITE if index == 47 else EncounterDirector.DEFINITIONS[index % 3]
		var definition: EnemyDefinition = original.duplicate()
		definition.health *= 1.0 + (inventory.difficulty - 1) * 0.25
		definition.damage *= 1.0 + (inventory.difficulty - 1) * 0.15
		var enemy: EnemyController = encounters.spawn_enemy(definition, encounters._spawn_position(index))
		enemy.set_meta("definition_path", original.resource_path)
	$FollowCamera.snap_to_target()


## 撤离结束本次世界，把长期角色状态交给独立 Hub；未拾取地面物品随场景销毁。
func return_to_town() -> void:
	if in_town:
		return
	effects.drain(1000000)
	if wave_completed:
		inventory.difficulty += 1
	wave_completed = false
	effects.reset()
	skills.reset()
	SceneRouter.stage_character_state(inventory, generator, minimum_quality)
	SceneRouter.open_hub()
