class_name SkillRunner
extends Node
## 运行普攻、主要技能、战吼与恢复药剂；攻击快照在施放时确定。

signal build_changed

const BASIC: BuildDefinition = preload("res://content/builds/basic.tres")
const THUNDER: BuildDefinition = preload("res://content/builds/thunder.tres")
const SWEEP: SkillDefinition = preload("res://content/skills/sweep.tres")
const WARCRY: SkillDefinition = preload("res://content/skills/warcry.tres")
const POTION: SkillDefinition = preload("res://content/skills/potion.tres")

var loadout: LoadoutState = LoadoutState.new()
var build: BuildDefinition = BASIC
var energy: float = 100.0
var max_energy: float = 100.0
var is_channeling: bool = false
var channel_requested: bool = false
var primary_requested: bool = false
var auxiliary_requested: bool = false
var potion_requested: bool = false
var input_enabled: bool = true
var actor: PlayerController
var combat: CombatSystem
var feedback: CombatFeedback
var _attack_remaining: float = 0.0
var _whirlwind_remaining: float = 0.0
var _sweep_remaining: float = 0.0
var _warcry_remaining: float = 0.0
var _warcry_cooldown_remaining: float = 0.0
var _warcry_applied: bool = false
var _potion_remaining: float = 0.0
var _exhausted: bool = false


## 换装直接重算移动属性，保留当前生命、能量与技能冷却。
func equip(preset: BuildDefinition) -> void:
	build = preset
	energy = clampf(energy, 0.0, max_energy)
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
		auxiliary_requested = Input.is_action_just_pressed("auxiliary_skill")
		potion_requested = Input.is_action_just_pressed("use_potion")
	advance(delta)


## 推进攻击、增益和药剂冷却；持续施法期间停止闲置回能。
func advance(delta: float) -> void:
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	_whirlwind_remaining = maxf(0.0, _whirlwind_remaining - delta)
	_sweep_remaining = maxf(0.0, _sweep_remaining - delta)
	_warcry_cooldown_remaining = maxf(0.0, _warcry_cooldown_remaining - delta)
	_potion_remaining = maxf(0.0, _potion_remaining - delta)
	if _warcry_applied:
		_warcry_remaining = maxf(0.0, _warcry_remaining - delta)
		if _warcry_remaining <= 0.0:
			_remove_warcry()
	if not channel_requested:
		_exhausted = false
	var main_id: String = str(loadout.slots.main)
	is_channeling = main_id == "whirlwind" and channel_requested and not _exhausted and actor.dodge_remaining_sec <= 0.0
	var main_active: bool = channel_requested and (main_id == "whirlwind" or main_id == "sweep")
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
	elif main_id == "sweep" and channel_requested and not _exhausted and actor.dodge_remaining_sec <= 0.0 and _sweep_remaining <= 0.0:
		if energy < SWEEP.energy_cost:
			_exhausted = true
		else:
			energy -= SWEEP.energy_cost
			_sweep_remaining = SWEEP.cooldown_sec
			cast_sweep()
	elif not main_active:
		restore_energy(build.idle_energy_regen * delta)
	if loadout.slots.basic == "primary" and primary_requested and not main_active and _attack_remaining <= 0.0 and actor.dodge_remaining_sec <= 0.0:
		_attack_remaining = build.attack_interval_sec
		cast_primary()
	if auxiliary_requested and loadout.slots.auxiliary == "warcry":
		cast_warcry()
	if potion_requested:
		use_potion()
	auxiliary_requested = false
	potion_requested = false


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


## 横扫只命中前方范围；存活目标获得施放时属性快照的有界流血。
func cast_sweep() -> void:
	var root_id: int = combat.next_attack_id()
	var facing: Vector3 = -actor.visual_root.global_basis.z
	feedback.slash(actor.global_position, facing, Color(0.95, 0.25, 0.18))
	for target: CombatActor in combat.targets_in_range(actor.global_position, SWEEP.range_m):
		var direction: Vector3 = (target.global_position - actor.global_position).normalized()
		if direction.dot(facing) < SWEEP.facing_dot_min:
			continue
		var event: DamageEvent = combat.hit(target, build.damage * SWEEP.damage_multiplier, &"sweep", root_id, build)
		if event != null and not target.is_dead:
			target.apply_bleed(_bleed_snapshot(root_id), SWEEP.bleed_max_stacks)
			feedback.ring(target.global_position, 0.35, Color(0.8, 0.06, 0.06), 0.22)
		target.push_back(direction, 1.6)


## 创建可序列化流血层；伤害和击杀触发参数固定为本次横扫施放时的值。
func _bleed_snapshot(root_id: int) -> Dictionary:
	return {
		"source":"player:sweep",
		"root_attack_id":root_id,
		"damage":build.damage * SWEEP.bleed_damage_multiplier,
		"remaining_sec":SWEEP.bleed_duration_sec,
		"next_tick_sec":SWEEP.bleed_tick_sec,
		"tick_interval_sec":SWEEP.bleed_tick_sec,
		"kill_energy":build.kill_energy,
		"death_explosion":build.death_explosion,
		"explosion_radius_m":build.explosion_radius_m,
		"explosion_damage":build.explosion_damage,
	}


## 战吼恢复能量并提供单层护甲增益；重复施放只刷新持续时间，不叠加护甲。
func cast_warcry() -> bool:
	if _warcry_cooldown_remaining > 0.0 or not is_instance_valid(actor) or actor.is_dead:
		return false
	if not _warcry_applied:
		actor.armor += WARCRY.armor_bonus
		_warcry_applied = true
	_warcry_remaining = WARCRY.duration_sec
	_warcry_cooldown_remaining = WARCRY.cooldown_sec
	restore_energy(WARCRY.energy_restore)
	feedback.ring(actor.global_position, 2.2, Color(0.95, 0.72, 0.18), WARCRY.duration_sec)
	AudioManager.play_cue(0.6)
	return true


## 移除战吼的单层护甲增益；重置、到期和回据点共用该入口。
func _remove_warcry() -> void:
	if _warcry_applied and is_instance_valid(actor):
		actor.armor = maxf(0.0, actor.armor - WARCRY.armor_bonus)
	_warcry_applied = false
	_warcry_remaining = 0.0


## Q 药剂按最大生命比例治疗；满血、死亡、暂停或冷却中均保持状态不变。
func use_potion() -> bool:
	if not is_instance_valid(actor) or actor.is_dead or actor.health >= actor.max_health or _potion_remaining > 0.0:
		return false
	if is_inside_tree() and get_tree().paused:
		return false
	var restored: float = actor.restore_health(actor.max_health * POTION.heal_ratio)
	if restored <= 0.0:
		return false
	_potion_remaining = POTION.cooldown_sec
	feedback.ring(actor.global_position, 1.0, Color(0.2, 0.9, 0.35), 0.35)
	AudioManager.play_cue(1.15)
	return true


## 回复能量并限制在上限，触发来源由 EffectResolver 筛选。
func restore_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)


## 新遭遇或据点整备清空技能瞬态，药剂冷却同时重置。
func reset() -> void:
	_remove_warcry()
	energy = max_energy
	is_channeling = false
	channel_requested = false
	primary_requested = false
	auxiliary_requested = false
	potion_requested = false
	_exhausted = false
	_attack_remaining = 0.0
	_whirlwind_remaining = 0.0
	_sweep_remaining = 0.0
	_warcry_cooldown_remaining = 0.0
	_potion_remaining = 0.0
