class_name ChargeAttack
extends RefCounted
## 冲锋规则子模块：冷却、攻击快照、同次去重与一次重击增益；运动交给玩家控制器。
const DEFINITION: SkillDefinition = preload("res://content/skills/charge.tres")
var runner: Node
var cooldown_sec: float = 0.0
var combo_remaining_sec: float = 0.0
var _combo_bonus: float = 0.0
var _snapshot: BuildDefinition
var _attack_id: int = 0
var _hit_ids: Dictionary = {}

## 绑定真实运动信号，按实际行进段结算。
func setup(owner: Node) -> void:
	runner = owner
	runner.actor.charge_advanced.connect(_on_advanced)
	runner.actor.charge_finished.connect(_on_finished)

## 仅接受存活、可操作且有足够能量的角色，施放时冻结构筑快照。
func cast() -> bool:
	if (runner.heavy != null and runner.heavy.phase != HeavyAttack.Phase.IDLE) or runner.actor.is_dead or runner.get_tree().paused or cooldown_sec > 0.0 or runner.energy < DEFINITION.energy_cost:
		return false
	var facing: Vector3 = -runner.actor.visual_root.global_basis.z
	if not runner.actor.start_charge(facing, DEFINITION.range_m, DEFINITION.speed_mps):
		return false
	runner.energy -= DEFINITION.energy_cost
	runner.is_channeling = false
	cooldown_sec = DEFINITION.cooldown_sec
	combo_remaining_sec = 0.0
	_hit_ids.clear()
	_snapshot = runner.build.duplicate()
	_attack_id = runner.combat.next_attack_id()
	runner.feedback.beam(runner.actor.global_position, runner.actor.global_position + facing * DEFINITION.range_m, Color(0.2, 0.75, 1.0), 0.2, 0.12)
	AudioManager.play_cue(0.65)
	return true

## 推进秒数；暂停由总控保证不调用。
func advance(delta: float) -> void:
	cooldown_sec = maxf(0.0, cooldown_sec - delta)
	combo_remaining_sec = maxf(0.0, combo_remaining_sec - delta)

## 以行进段最近点和地形视线检查目标，避免高速跨过目标和隔墙结算。
func _on_advanced(from: Vector3, to: Vector3) -> void:
	var segment: Vector3 = to - from
	for target: CombatActor in runner.combat.enemies.duplicate():
		if not is_instance_valid(target) or target.is_dead or _hit_ids.has(target.get_instance_id()):
			continue
		var weight: float = 0.0 if segment.length_squared() < 0.000001 else clampf((target.global_position - from).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var point: Vector3 = from + segment * weight
		if point.distance_to(target.global_position) > DEFINITION.hit_radius_m or not runner.combat.has_line_of_sight(point, target.global_position):
			continue
		_hit_ids[target.get_instance_id()] = true
		runner.combat.hit(target, _snapshot.damage * DEFINITION.damage_multiplier, &"charge", _attack_id, _snapshot)
	runner.feedback.beam(from, to, Color(0.2, 0.75, 1.0), 0.12, 0.15)

## 正常结束且确实命中过目标才发放一层增益；闪避取消清除增益。
func _on_finished(completed: bool) -> void:
	combo_remaining_sec = DEFINITION.combo_duration_sec if completed and not _hit_ids.is_empty() else 0.0
	_combo_bonus = DEFINITION.combo_bonus
	_hit_ids.clear()
	_snapshot = null

## 下一次重击起手消费增益，空挥或闪避取消同样消耗，不可叠层。
func consume_combo() -> float:
	var bonus: float = _combo_bonus if combo_remaining_sec > 0.0 else 0.0
	combo_remaining_sec = 0.0
	return bonus

## 新探险、死亡和离场清空全部瞬态。
func reset() -> void:
	runner.actor.cancel_charge()
	cooldown_sec = 0.0
	combo_remaining_sec = 0.0
	_hit_ids.clear()
	_snapshot = null
