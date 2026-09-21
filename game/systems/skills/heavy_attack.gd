class_name HeavyAttack
extends RefCounted
## 重击动作子模块：起手扣费，固定前摇后单次结算，再进入恢复期；仅闪避/死亡/离场取消。
const DEFINITION: SkillDefinition = preload("res://content/skills/heavy.tres")
enum Phase { IDLE, WINDUP, RECOVERY }
var phase: Phase = Phase.IDLE
var remaining_sec: float = 0.0
var runner: Node
var _snapshot: BuildDefinition
var _damage: float = 0.0
var _attack_id: int = 0
var _warning: MeshInstance3D

## 使用总控已绑定的战斗与角色依赖。
func setup(owner: Node) -> void:
	runner = owner

## 重复输入和能量不足不扣费；组合增益仅在合法起手时消费一次。
func cast() -> bool:
	if phase != Phase.IDLE or runner.actor.is_dead or runner.get_tree().paused or runner.actor.dodge_remaining_sec > 0.0 or runner.actor.charge_remaining_m > 0.0 or runner.energy < DEFINITION.energy_cost:
		return false
	runner.energy -= DEFINITION.energy_cost
	runner.is_channeling = false
	_snapshot = runner.build.duplicate()
	_damage = _snapshot.damage * DEFINITION.damage_multiplier * _snapshot.heavy_damage_multiplier * (1.0 + runner.charge.consume_combo())
	_attack_id = runner.combat.next_attack_id()
	phase = Phase.WINDUP
	remaining_sec = DEFINITION.windup_sec
	runner.actor.set_heavy_pose(0.0)
	_warning = runner.feedback.heavy_warning(runner.actor.global_position, DEFINITION.range_m)
	AudioManager.play_cue(0.55)
	return true

## 前摇在暂停中保持；大步长仅结算一次，超出前摇的时间进入恢复期。
func advance(delta: float) -> void:
	if runner.get_tree().paused:
		return
	if runner.actor.is_dead:
		cancel()
		return
	if phase == Phase.IDLE:
		return
	remaining_sec -= delta
	if phase == Phase.WINDUP:
		runner.actor.set_heavy_pose(clampf(1.0 - remaining_sec / DEFINITION.windup_sec, 0.0, 1.0))
		if remaining_sec > 0.000001:
			return
		phase = Phase.RECOVERY
		remaining_sec += DEFINITION.recovery_sec
		_clear_warning()
		_resolve()
	if phase == Phase.RECOVERY:
		runner.actor.set_heavy_pose(clampf(1.0 - remaining_sec / DEFINITION.recovery_sec, 0.0, 1.0), true)
		if remaining_sec <= 0.0:
			cancel()

## 只在前摇结束那一刻进入统一命中管线；快照免受升级和换装回调影响。
func _resolve() -> void:
	var origin: Vector3 = runner.actor.global_position
	runner.feedback.ring(origin, DEFINITION.range_m, Color(1.0, 0.55, 0.08), 0.25)
	for target: CombatActor in runner.combat.targets_in_range(origin, DEFINITION.range_m):
		var direction: Vector3 = (target.global_position - origin).normalized()
		runner.combat.hit(target, _damage, &"heavy", _attack_id, _snapshot)
		target.push_back(direction, DEFINITION.knockback_mps)
	AudioManager.play_cue(0.4)

## 取消前摇丢弃未结算攻击；恢复期取消不撤销已发生伤害，能量和增益不退还。
func cancel() -> void:
	phase = Phase.IDLE
	remaining_sec = 0.0
	_snapshot = null
	_clear_warning()
	if is_instance_valid(runner.actor):
		runner.actor.clear_attack_pose()

## 清理危险范围，兼容已经被场景回收的视觉节点。
func _clear_warning() -> void:
	if is_instance_valid(_warning):
		_warning.queue_free()
	_warning = null
