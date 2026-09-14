class_name EffectResolver
extends Node
## 排队处理命中、击杀与有限传播，派生伤害重新入队，避免同步递归。

var combat: CombatSystem
var skills: SkillRunner
var feedback: CombatFeedback
var queue: Array[DamageEvent] = []
var lightning_count: int = 0
var explosion_count: int = 0
var bleed_tick_count: int = 0
var bleed_spread_count: int = 0
var peak_queue_size: int = 0
var _next_lightning_sec: float = 0.0


## 接收快照；每帧最多处理 256 个事件，剩余事件留待后续帧完整结算。
func enqueue(event: DamageEvent) -> void:
	queue.append(event)
	peak_queue_size = maxi(peak_queue_size, queue.size())


## 先按战斗时间推进流血，再处理本帧产生的有限事件队列。
func _physics_process(delta: float) -> void:
	advance_bleeds(delta)
	drain()


## 推进所有存活敌人的有界流血；跳伤使用施加时保存的攻击属性。
func advance_bleeds(delta: float) -> void:
	for target: CombatActor in combat.enemies.duplicate():
		for entry: Dictionary in target.advance_bleeds(delta):
			if target.is_dead:
				break
			bleed_tick_count += 1
			feedback.ring(target.global_position, 0.45, Color(0.85, 0.08, 0.08), 0.18)
			combat.hit(target, float(entry.damage), &"bleed", int(entry.root_attack_id), _bleed_build(entry))


## 从流血条目重建本次跳伤属性，包含有限传播需要的原始持续参数与代数。
func _bleed_build(entry: Dictionary) -> BuildDefinition:
	var result: BuildDefinition = BuildDefinition.new()
	result.kill_energy = float(entry.get("kill_energy", 0.0))
	result.death_explosion = bool(entry.get("death_explosion", false))
	result.explosion_radius_m = float(entry.get("explosion_radius_m", result.explosion_radius_m))
	result.explosion_damage = float(entry.get("explosion_damage", result.explosion_damage))
	result.bleed_spread_radius_m = float(entry.get("bleed_spread_radius_m", 0.0))
	result.bleed_spread_max_targets = int(entry.get("bleed_spread_max_targets", 0))
	result.bleed_spread_damage_ratio = float(entry.get("bleed_spread_damage_ratio", 0.0))
	result.bleed_spread_max_generation = int(entry.get("bleed_spread_max_generation", 0))
	result.bleed_spread_generation = int(entry.get("bleed_spread_generation", 0))
	result.bleed_snapshot_damage = float(entry.get("damage", 0.0))
	result.bleed_snapshot_duration_sec = float(entry.get("bleed_duration_sec", entry.get("remaining_sec", 0.0)))
	result.bleed_snapshot_tick_sec = float(entry.get("bleed_tick_sec", entry.get("tick_interval_sec", 0.0)))
	return result


## 每个死亡事件只出现一次；流血传播和感电爆炸均受明确上限约束。
func drain(budget: int = 256) -> void:
	var processed: int = 0
	while not queue.is_empty() and processed < budget:
		var event: DamageEvent = queue.pop_front()
		processed += 1
		var direct: bool = CombatSystem.is_direct_skill(event.skill_id)
		if direct:
			skills.restore_energy(event.build.hit_energy)
		if event.killed:
			skills.restore_energy(event.build.kill_energy)
			if event.skill_id == &"bleed" and event.build.bleed_spread_generation < event.build.bleed_spread_max_generation:
				_spread_bleed(event)
			if event.was_shocked and event.build.death_explosion:
				_explode(event)
		if direct and event.is_critical and event.build.chain_count > 0 and combat.clock_sec >= _next_lightning_sec:
			_next_lightning_sec = combat.clock_sec + event.build.lightning_cooldown_sec
			_chain_lightning(event)


## 流血击杀按距离选择有限目标并施加一层衰减流血；传播代数递增后不会无限放大。
func _spread_bleed(event: DamageEvent) -> void:
	if event.build.bleed_spread_max_targets <= 0 or event.build.bleed_spread_radius_m <= 0.0 or event.build.bleed_spread_damage_ratio <= 0.0:
		return
	var candidates: Array[CombatActor] = combat.targets_in_range(event.origin, event.build.bleed_spread_radius_m)
	var limit: int = mini(event.build.bleed_spread_max_targets, candidates.size())
	for index: int in range(limit):
		var target: CombatActor = _nearest_target(event.origin, candidates)
		if target == null:
			break
		candidates.erase(target)
		var spread: Dictionary = {
			"source":"unique:blood_echo",
			"root_attack_id":event.root_attack_id,
			"damage":event.build.bleed_snapshot_damage * event.build.bleed_spread_damage_ratio,
			"remaining_sec":event.build.bleed_snapshot_duration_sec,
			"next_tick_sec":event.build.bleed_snapshot_tick_sec,
			"tick_interval_sec":event.build.bleed_snapshot_tick_sec,
			"bleed_duration_sec":event.build.bleed_snapshot_duration_sec,
			"bleed_tick_sec":event.build.bleed_snapshot_tick_sec,
			"bleed_spread_radius_m":event.build.bleed_spread_radius_m,
			"bleed_spread_max_targets":event.build.bleed_spread_max_targets,
			"bleed_spread_damage_ratio":event.build.bleed_spread_damage_ratio,
			"bleed_spread_max_generation":event.build.bleed_spread_max_generation,
			"bleed_spread_generation":event.build.bleed_spread_generation + 1,
			"kill_energy":event.build.kill_energy,
			"death_explosion":event.build.death_explosion,
			"explosion_radius_m":event.build.explosion_radius_m,
			"explosion_damage":event.build.explosion_damage,
		}
		target.apply_bleed(spread, 1)
		bleed_spread_count += 1
		feedback.ring(target.global_position, 0.65, Color(0.72, 0.04, 0.16), 0.32)


## 从候选中找最近目标，保证同一场景与种子下传播顺序稳定。
func _nearest_target(origin: Vector3, candidates: Array[CombatActor]) -> CombatActor:
	var nearest: CombatActor = null
	var nearest_distance: float = INF
	for candidate: CombatActor in candidates:
		var distance: float = candidate.global_position.distance_squared_to(origin)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


## 每次连锁选择最近的可见未访问目标；已死亡起点只作为空间锚点。
func _chain_lightning(event: DamageEvent) -> void:
	lightning_count += 1
	var origin: Vector3 = event.origin
	var visited: Array[CombatActor] = []
	for index: int in range(event.build.chain_count):
		var target: CombatActor = null
		var distance: float = INF
		for candidate: CombatActor in combat.targets_in_range(origin, event.build.chain_range_m):
			if visited.has(candidate):
				continue
			var squared: float = candidate.global_position.distance_squared_to(origin)
			if squared < distance:
				target = candidate
				distance = squared
		if target == null:
			break
		visited.append(target)
		feedback.lightning(origin, target.global_position)
		origin = target.global_position
		combat.hit(target, event.build.lightning_damage, &"lightning", event.root_attack_id, event.build)


## 爆炸不施加感电；击杀原本已感电目标时可继续传播。
func _explode(event: DamageEvent) -> void:
	explosion_count += 1
	feedback.ring(event.origin, event.build.explosion_radius_m, Color(1.0, 0.55, 0.16), 0.32)
	for target: CombatActor in combat.targets_in_range(event.origin, event.build.explosion_radius_m):
		combat.hit(target, event.build.explosion_damage, &"explosion", event.root_attack_id, event.build)


## 重开时清空旧事件和计数，角色自身流血由遭遇回收或 reset_health 清理。
func reset() -> void:
	queue.clear()
	_next_lightning_sec = 0.0
	lightning_count = 0
	explosion_count = 0
	bleed_tick_count = 0
	bleed_spread_count = 0
	peak_queue_size = 0
