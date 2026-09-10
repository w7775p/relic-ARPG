class_name SkillRunner
extends Node
## 普攻、移动旋风及能量运行；装备预设在下一次攻击时生效。

signal build_changed

const BASIC: BuildDefinition = preload("res://content/builds/basic.tres")
const THUNDER: BuildDefinition = preload("res://content/builds/thunder.tres")

var build: BuildDefinition = BASIC
var energy: float = 100.0
var max_energy: float = 100.0
var is_channeling: bool = false
var channel_requested: bool = false
var primary_requested: bool = false
var input_enabled: bool = true
var actor: PlayerController
var combat: CombatSystem
var feedback: CombatFeedback
var _attack_remaining: float = 0.0
var _whirlwind_remaining: float = 0.0
var _exhausted: bool = false


## 换装直接重算移动属性，保留当前生命与能量，避免热切换回满。
func equip(preset: BuildDefinition) -> void:
	build = preset
	actor.move_speed_mps = build.move_speed_mps
	build_changed.emit()


## 分开处理输入与技能结算，使自动回归可以设置相同的施放意图。
func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_dead:
		is_channeling = false
		return
	if input_enabled:
		channel_requested = Input.is_action_pressed("channel_skill")
		primary_requested = Input.is_action_pressed("primary_attack")
	advance(delta)


## 持续消耗按时间计算，耗尽锁定至松开施放键；闲置时回复能量。
func advance(delta: float) -> void:
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	_whirlwind_remaining = maxf(0.0, _whirlwind_remaining - delta)
	if not channel_requested:
		_exhausted = false
	is_channeling = channel_requested and not _exhausted and actor.dodge_remaining_sec <= 0.0
	if is_channeling:
		var cost: float = build.energy_cost_per_sec * delta
		if energy < cost:
			energy = 0.0
			is_channeling = false
			_exhausted = true
		else:
			energy -= cost
			if _whirlwind_remaining <= 0.0:
				_whirlwind_remaining = build.whirlwind_interval_sec
				cast_whirlwind()
	else:
		restore_energy(build.idle_energy_regen * delta)
	if primary_requested and not is_channeling and _attack_remaining <= 0.0 and actor.dodge_remaining_sec <= 0.0:
		_attack_remaining = build.attack_interval_sec
		cast_primary()


## 普攻使用正前方 120 度扇形，命中后轻微击退。
func cast_primary() -> void:
	var root_id: int = combat.next_attack_id()
	var facing: Vector3 = -actor.visual_root.global_basis.z
	feedback.slash(actor.global_position, facing)
	for target: CombatActor in combat.targets_in_range(actor.global_position, 2.8):
		var direction: Vector3 = (target.global_position - actor.global_position).normalized()
		if direction.dot(facing) >= 0.5:
			combat.hit(target, build.damage * 1.5, &"primary", root_id, build)
			target.push_back(direction, 2.5)


## 旋风查询完整范围，沿用同一根编号，每个目标只命中一次。
func cast_whirlwind() -> void:
	var root_id: int = combat.next_attack_id()
	feedback.ring(actor.global_position, build.whirlwind_radius_m, Color(0.15, 0.8, 0.95), 0.2)
	for target: CombatActor in combat.targets_in_range(actor.global_position, build.whirlwind_radius_m):
		combat.hit(target, build.damage, &"whirlwind", root_id, build)
		target.push_back((target.global_position - actor.global_position).normalized(), 0.8)


## 回复能量并限制在上限，触发来源由 EffectResolver 筛选。
func restore_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)


## 新遭遇时清空技能瞬态。
func reset() -> void:
	energy = max_energy
	is_channeling = false
	channel_requested = false
	primary_requested = false
	_exhausted = false
	_attack_remaining = 0.0
	_whirlwind_remaining = 0.0
