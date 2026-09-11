# 当前工程实现

引擎实测：`4.7.2.stable.official.ed1daf0bf`；导出模板：4.7.2 stable；语言：GDScript；插件：无。M0 使用兼容渲染器，原生几何体已足以验证操控与场景流程；M1 继续使用兼容渲染器，当前原生网格效果没有引入 Forward+ 专属功能；目标机结果决定后续选择。目标 Windows 电脑型号、显卡与驱动待提供。

`game/` 对应 `res://`。仓库文档放 `docs/`，辅助验证放 `tools/`，导出包放 Git 忽略的 `builds/`。其余功能目录随代码创建，完整目标结构见 `plan.md`。

| 实现 | 职责 |
| --- | --- |
| `app/boot/` | 启动后延迟进入主菜单；发行 smoke 沿正式 Hub 路由运行 |
| `app/services/scene_router.gd` | MainMenu / Hub / Expedition 场景切换、一次性跨场景角色状态交接、离场解除暂停 |
| `app/services/settings_manager.gd` | ConfigFile 设置与原生窗口、音频总线应用 |
| `app/services/audio_manager.gd` | 原生 WAV 短提示及 SFX 总线播放 |
| `app/services/save_manager.gd` | 旧 v1～v4 JSON 兼容与迁移输入；下一轮改为 Resource 存档 |
| `actors/player/` | CharacterBody3D、胶囊碰撞、独立视觉朝向与武器挂点 |
| `world/hub/` | 独立据点场景；装备、背包、仓库、出售、技能与被动整备 |
| `world/maps/expedition_runtime.*` | 正式新角色探险场景；接收 Hub 状态、运行战斗、撤离/死亡返回 Hub |
| `world/maps/expedition.*` | 旧 v4 JSON / in_town 兼容底座和历史回归，等待 Resource 迁移后删除兼容职责 |
| `world/camera/` | 正交镜头，固定朝向，指数平滑跟随 |
| `ui/menus/` | 主菜单与可复用设置面板 |
| `ui/inventory/` | Hub 与探险共用物品/装配面板，通过 `session.is_hub()` 查询地点能力 |
| `ui/theme/` | 原生 Theme、样式盒与中文系统字体候选 |
| `tests/` | 实际场景回归，发行导出排除；包含 HubFlow 场景边界验证 |

移动用 `Input.get_vector`，斜向速度保持一致，`move_and_slide` 处理墙体与地面。鼠标投向脚下水平面，仅转动视觉根。闪避没有无敌效果，当前只验证移动速度、持续时间、冷却和碰撞。

测试场地根节点持续处理暂停输入；玩家、镜头和导航区域明确使用可暂停模式。HUD 不拦截鼠标。设置面板和暂停菜单在暂停中保持响应。

M0 存档只保存 `version=1`、`map_id` 和 `player_position`。M2/D1 历史完整探险使用 JSON v2～v4。当前旧 JSON 继续服务 Continue、迁移样例和历史回归；正常新角色场景流已经与“据点出发自动写 JSON”解耦。下一轮必须用 Godot Resource 替换持久化，并将旧 JSON 降为一次性迁移输入。

自动化测试使用临时用户目录；正式模板保存在引擎标准目录。Git 远端地址使用普通 HTTPS 地址，认证信息由外部连接管理。

官方实现依据：[CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)、[命令行导入与导出](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)。实际 API 兼容性以本仓库 4.7.2 运行结果为准。

## M1 战斗实现

M1 延续兼容渲染器，无动态特效灯。`combat_arena.tscn` 继承 M0 场地，添加会话内 CombatSystem、SkillRunner、EffectResolver、EncounterDirector 和 CombatFeedback。M0 的场景回归保持独立。

| 模块 | 实际规则 |
| --- | --- |
| CombatActor | 独立生命、护甲、感电、硬直；死亡先标记，再通知移出目标集合 |
| CombatSystem | 独立固定种子 RNG；注册集合范围筛选与地形射线；直接攻击暴击、护甲减伤、感电增伤 |
| SkillRunner | 普攻前方 120 度扇形；旋风移动施放、按秒消耗、按间隔伤害；停止施放回复能量 |
| EffectResolver | 命中事件快照入队；每帧处理至多 256 件，余额保留；死亡有限传播 |
| EnemyController | 近战蓄力、远程扫掠弹体、锁向冲锋；NavigationAgent3D 导航与局部避让 |
| EncounterDirector | 24 怪包含三种类型及一名精英；F6 生成 100 怪；压力脚本持续补足目标数 |
| CombatFeedback | 原生网格挥砍、环形范围、闪电、颜色受击、死亡补间；最多 96 个短期视觉节点 |

直接攻击暴击才能触发闪电，触发有 0.12 秒间隔。闪电最多访问五个不同可见目标，存活目标感电三秒；感电使后续伤害提高 20%。击杀事先已感电的目标触发爆炸，爆炸可击杀其他已感电目标继续传播，自身不施加感电。每名角色只产生一次死亡事件。

预设定义保存在 `content/builds/`，静态 Resource 共享，换装仅替换属性引用；待处理事件继续使用攻击时的预设快照。真实装备生成与穿脱归 M2。能量回复分别接受直接命中及击杀，单体战斗也有命中回复。

范围目标来自会话注册集合，不受物理查询默认结果上限影响；LOS 射线只检测地形，弹体扫掠检测地形和玩家。尸体立即退出可命中集合，短动画后释放。重开清除尸体、在途弹体和触发队列。

局部避让与碰撞层：敌人碰撞层为 4，检测世界及玩家（掩码 3），相互通过原生导航避让，每名代理最多六个近邻。寻路目标每 0.4 秒错峰刷新，每个物理帧推进导航路径。

官方依据：[NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html)、[PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html)。

## M2 / D1 装备与探险实现

历史 `expedition.tscn` 继承 M1 场地并承载 M2/D1 逻辑。Hub 拆分后，正式新角色入口改为 `Hub → expedition_runtime.tscn`；`expedition_runtime.gd` 继承历史 Expedition 的战斗/掉落实现，并覆盖场景生命周期。M1 测试场景和压力测试保持独立。

| 模块 | 职责 |
| --- | --- |
| `systems/items/` | ItemBase、AffixDefinition、UniqueDefinition 资源，目录索引，独立 RNG 抽取与实例描述 |
| `content/items/` | 10 底材、12 词条、3 独特装备的可编辑 `.tres` |
| `systems/inventory/` | 单一持有归属、40 格背包、120 格仓库、6 槽穿戴、锁定、出售、属性汇总与基础经验成长 |
| `ui/inventory/` | 原生容器与列表、双列装备说明、服务按钮；通过场景能力接口判断 Hub 服务权限 |
| `world/hub/hub.gd` | 长期角色状态与据点服务；出发前把 InventoryState、ItemGenerator 和过滤设置交给 SceneRouter |
| `world/maps/expedition_runtime.gd` | 正式探险生命周期；领取 Hub 状态、生成 48 怪、战斗、撤离/死亡回 Hub |
| `world/maps/expedition.gd` | 战斗/掉落底层与旧 JSON 恢复；`in_town` 仅为兼容层 |
| `systems/persistence/` | 旧 JSON 显式运行字段快照、版本校验及迁移；后续改为 Resource 数据模型 |

实例结构：`id/base/level/quality/unique/affixes/locked`；每条词条记录 `id/value`。当前版本独特编号固定 0=雷鸣指环、1=余烬锁甲、2=噬能护手；更改映射必须迁移存档。词条描述来自实际抽取值，独特机制来自资源参数，技能默认数值来自 BuildDefinition。定义资源不承载每件装备的强化或抽取结果。

生成顺序：选底材→按来源抽品质→精英独特概率→按物品等级和部位过滤词条→加权抽取→排除整个互斥组→抽具体值。普通零条、魔法 1～2 条、稀有 3～4 条，独特固定机制加一条浮动词条。物品等级当前取角色等级。普通怪装备率 28%，精英必掉装备；精英随机独特概率 12%。前三次清场额外定向奖励三件机制装备。出售、掉落和成长数值目前均为原型参数。

普通怪经验 6，精英 35；升级需求为当前等级×60，每级基础伤害 +2、生命上限 +15。升级与换装不会直接回满生命。通关撤离使难度 +1，每档怪物生命 +25%、伤害 +15%，金币乘当前难度；额外掉落数和物品等级暂不随难度直接增加。

### Hub / Expedition 生命周期

新角色由主菜单进入 `Hub`。Hub 创建或接收 InventoryState 与 ItemGenerator，InventoryPanel 在此开放仓库、出售、技能和被动服务。点击出发后，SceneRouter 只临时持有这两个对象及 minimum_quality；`ExpeditionRuntime` 在 `_ready()` 领取后，SceneRouter 立即清空过渡引用。

探险场景运行时 `is_hub()` 固定返回 false，服务层拒绝出售、仓库和装配修改。撤离或死亡时清算当前战斗，已拾取长期状态继续保留，未拾取地面对象随场景销毁；随后把长期对象再次交给 SceneRouter，并加载真实 Hub 场景。正常新角色流程不会通过 `in_town=true` 模拟据点。

旧 `expedition.gd` 仍保留 `in_town`、旧 `depart()/return_to_town()` 和 JSON v4 快照，供旧 Continue、旧迁移测试及历史 M2/P1 回归使用。Resource 存档完成前禁止向该分支增加新的据点服务。

## 旧 JSON 持久化兼容层

当前旧完整探险存档版本为 4，同时读取 v2 与 v3。保存背包、仓库、穿戴、成长、装配、地面物品、活敌人的生命/护甲/感电/流血/硬直/击退/速度/状态/蓄力与攻击冷却/锁定方向、玩家闪避、技能间隔、战吼与药剂冷却、弹体位置方向寿命、战斗计时与触发冷却。随机状态用十进制字符串存储，避免 JSON 双精度丢失 64 位状态。实例计数随存档恢复，掉落与战斗序列互相独立。

旧保存是本物理阶段的结算检查点：先排空有限触发队列，然后记录所有结果。恢复不重放死亡事件，尸体只留下已经生成的战利品；纯视觉补间不保存，仍处于蓄力的敌人重建危险提示，导航路径由原生代理重算。按键意图重新采集，技能与闪避冷却继续保留。JSON 解析结果禁止直接整包写进任意节点。

该 JSON 路径将在下一轮转换为 Resource。目标结构为：`PlayerProfileResource` 持有长期角色状态，`RunStateResource` 持有本趟世界与战斗状态，`SaveGameResource` 持有版本、角色档、本趟档和迁移元数据。开发期优先 `user://save.tres`。旧 `session.json` 只作为一次性迁移输入；迁移完成后删除 `LEGACY_EXPEDITION`、运行期 `in_town` 和仅为 JSON v4 服务的兼容分支。详细说明见 `docs/hub_refactor.md`。

背包打开暂停探险世界；列表拥有焦点时全局 I/Esc/F5 仍可使用。装备掉落为原生小方块与 Label3D 名称，稀有以上增加环形反馈。当前标签没有屏幕空间防重叠排布，使用附近候选选择与过滤控制拾取；美术与标签视觉打磨仍需后续验收。

## D1 技能装配与流血技能

`LoadoutState` 由 InventoryState 持有并交给 SkillRunner，记录 basic/main/auxiliary 技能 ID 和最多三项被动 ID。静态 SkillDefinition 与 PassiveDefinition 资源显式预载；`inventory.build()` 和 `defense()` 分别叠加技能与防御属性。装配修改由 Hub 的 `loadout_action` 处理；探险中的共用面板只读。右键主要槽当前提供旋风与流血横扫，F 辅助槽提供战吼，Q 药剂使用独立语义动作。

横扫配置保存在 `content/skills/sweep.tres`：前方范围筛选继续复用 CombatSystem 的注册目标集合与地形 LOS。直接伤害属于 direct skill，可暴击并触发已有直接命中收益；流血以单独 `bleed` 来源进入伤害系统。每层保存攻击根编号、伤害、击杀回能与死亡爆炸参数、剩余时间和下一跳，最多三层；满层后替换剩余时间最短的一层。流血跳伤不属于 direct skill，因此没有暴击闪电或直接命中回能；死亡仍沿统一事件发放一次击杀收益。

战吼配置保存在 `content/skills/warcry.tres`，提供单层护甲增益、即时回能、持续时间和冷却。重复施放刷新持续时间，护甲只保留一层；属性重算会把这层临时护甲重新叠到装备基础值上，结束与 reset 通过同一入口移除。恢复药剂配置保存在 `content/skills/potion.tres`，Q 使用时按最大生命比例治疗；满血、死亡、暂停或冷却中拒绝，进入新探险时 reset 清零药剂冷却。

旧 JSON 中装配作为顶层 `expedition.loadout` 独立保存，原九字段 inventory 格式保持。v4 在 v3 上增加敌人流血数组和横扫、战吼、药剂运行计时。v2 先完成 v3 默认装配迁移，再迁移到 v4；v3 直接补空持续状态。上述格式只用于兼容与迁移，新的 Resource 数据模型建立后由对应 Resource 负责长期装配与本趟瞬态。
