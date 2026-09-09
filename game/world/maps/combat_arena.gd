extends "res://world/maps/test_arena.gd"
## M1 场地扩展：装配战斗、技能、触发、遭遇与真实战斗 HUD。

@export var auto_spawn: bool = true

@onready var combat: CombatSystem = $CombatSystem
@onready var skills: SkillRunner = $SkillRunner
@onready var effects: EffectResolver = $EffectResolver
@onready var feedback: CombatFeedback = $Feedback
@onready var encounters: EncounterDirector = $EncounterDirector

var _hud_remaining: float = 0.0
var _hurt_remaining: float = 0.0
var _player_material: StandardMaterial3D


## 装配本次会话的依赖，保留 M0 场地、暂停和导航能力。
func _ready() -> void:
	super._ready()
	combat.player = player
	skills.actor = player
	skills.combat = combat
	skills.feedback = feedback
	player.skills = skills
	player.max_health = 300.0
	player.armor = 15.0
	player.reset_health()
	_player_material = player.get_node("VisualRoot/Body").mesh.material.duplicate()
	player.get_node("VisualRoot/Body").material_override = _player_material
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	effects.combat = combat
	effects.skills = skills
	effects.feedback = feedback
	combat.hit_resolved.connect(effects.enqueue)
	combat.hit_resolved.connect(feedback.on_hit)
	encounters.combat = combat
	encounters.feedback = feedback
	encounters.enemy_root = $Enemies
	encounters.projectile_root = $Projectiles
	skills.build_changed.connect(_on_build_changed)
	skills.equip(SkillRunner.BASIC)
	status.text = "清理四角怪群与精英；按 2 试穿雷霆旋风"
	if auto_spawn:
		encounters.start_wave()
	if OS.get_cmdline_user_args().has("--smoke-combat"):
		print("M1_COMBAT_BOOT_READY")


## 每 0.1 秒刷新 HUD，暂停期间保持已有数值。
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_hud_remaining -= delta
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_player_material.albedo_color = Color(1.0, 0.3, 0.25) if _hurt_remaining > 0.0 else Color(0.12, 0.7, 0.75)
	if _hud_remaining > 0.0:
		return
	_hud_remaining = 0.1
	$Interface/Hud/Rows/Position.text = "生命 %.0f / %.0f　能量 %.0f / %.0f　闪避 %.1f 秒" % [player.health, player.max_health, skills.energy, skills.max_energy, player.cooldown_remaining_sec]
	$Interface/CombatInfo/Rows/Stats.text = "敌人 %d　击杀 %d　闪电 %d　爆炸 %d\n帧率 %d　物理 %.2f 毫秒" % [combat.enemies.size(), combat.kills, effects.lightning_count, effects.explosion_count, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
	if combat.enemies.is_empty() and not player.is_dead:
		status.text = "本轮清理完成！按 R 开始下一轮，或按 1 / 2 比较装备"


## 接入预设、重开和 100 怪压力入口，其余菜单输入沿用基础场地。
func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused:
		if event.is_action_pressed("basic_build"):
			skills.equip(SkillRunner.BASIC)
		elif event.is_action_pressed("thunder_build"):
			skills.equip(SkillRunner.THUNDER)
		elif event.is_action_pressed("restart_encounter"):
			restart(24)
		elif event.is_action_pressed("stress_encounter"):
			restart(100)
	super._unhandled_input(event)


## 清除待结算触发和旧敌人，恢复玩家状态后开始同条件新遭遇。
func restart(count: int) -> void:
	effects.reset()
	combat.kills = 0
	combat.damage_dealt = 0.0
	combat.rng.seed = 1701
	player.reset_health()
	player.restore_position(Vector3.ZERO)
	skills.reset()
	$FollowCamera.snap_to_target()
	encounters.maintain_population = false
	encounters.start_wave(count)
	status.text = "新一轮：%d 名敌人；当前装备 %s" % [count, skills.build.display_name]


## 暂停时隐藏下方战斗说明，避免遮住先创建的暂停菜单。
func _set_paused(value: bool) -> void:
	super._set_paused(value)
	$Interface/CombatInfo.visible = not value


## 预设说明直接取自生效参数。
func _on_build_changed() -> void:
	$Interface/CombatInfo/Rows/Build.text = skills.build.describe()


## 玩家受击短暂变色，当前场景禁止用换装恢复生命。
func _on_player_health_changed(_current: float, _maximum: float) -> void:
	_hurt_remaining = 0.12


## 死亡停止玩家技能和敌人行动，保留重开与菜单操作。
func _on_player_died() -> void:
	status.text = "你已倒下。按 R 重新挑战，按 Esc 打开菜单"
	effects.reset()


## M1 尚未实现完整战斗存档，明确仅保存位置，继续时重建遭遇。
func _save_position() -> Error:
	var error: Error = super._save_position()
	if error == OK:
		status.text = "已保存位置；继续时重新生成怪群，装备预设恢复基础"
		$Interface/Pause/Center/Rows/Status.text = "已保存位置（战斗进度尚未保存）"
	return error
