# P1_Task 3：D1 装备池、精英修饰与地图变体

仓库：[w7775p/relic-ARPG](https://github.com/w7775p/relic-ARPG)。工程入口：`game/project.godot`。技术栈：Godot 4.7.2 标准版、GDScript、3D 俯视即时动作、Windows 键鼠。

阶段：D1。状态：已完成。任务 ID：`P1_Task3`。工作分支：`feat/p1-task3-d1-content`。

前置任务：[P1_Task 2](P1_Task2.md)。本次从最新 `main` `55529f73b907f548625316f9171d33a43b7ced3c` 开始；该基线已包含前置功能、Resource 重构及词条导出修复。

## 开始前先阅读以下文档

| 文档（仓库根目录相对路径） | 阅读目的 |
| --- | --- |
| [AGENTS.md](../../AGENTS.md) | 项目约束与「完成任务前必须检查」 |
| [README.md](../../README.md) | 当前入口、操作和已实现功能 |
| [docs/engineering.md](../../docs/engineering.md) | 当前模块、数据与存档规则 |
| [docs/save_system.md](../../docs/save_system.md) | 五模块、Hub 保存、版本升级与整体回退边界 |
| [docs/tasks.md](../../docs/tasks.md) | 任务状态与前置合入情况 |
| [known_trap.md](../../known_trap.md) | 实际问题，避免重复踩坑 |
| [docs/plan.md](../../docs/plan.md) | 第 10、11 节阶段额度与验收目标 |
| [docs/demo_tasks/README.md](../../docs/demo_tasks/README.md) | 基线、执行顺序、内容归属与交接约定 |
| [docs/validation.md](../../docs/validation.md) | 现有验证入口与历史结果 |

有前置任务时同时阅读对应任务卡的验收与实际交接记录；上表文档均应存在。运行代码的最新状态优先用于判断已实现内容。

## 已经实现的功能

历史 M2 已完成战斗、随机装备、背包仓库和整备循环。当前存档基线为独立 Hub 与五模块 Resource 检查点；仅 Hub 保存，旧 JSON 和旧探险恢复已退休。历史阶段结果不替代本卡验证。

M2 已有 10 底材、12 随机词条、3 独特装备、三类普通敌人和一名固定精英；独特实例已使用稳定字符串内容 ID。前置任务已提供横扫、流血、战吼与药剂。

## 本次要做的任务

① 把累计内容扩至 14 底材、18 普通随机词条、4 独特装备。新增部分明确提供流血输出、防御或能量取舍，所有属性有结算用途与中文说明。

② 第四件独特装备提供流血传播机制：流血敌人死亡向附近目标施加有限流血；限制传播来源或次数，防止无限放大。其掉落来源在当前精英池中可达。

③ 独特目录已经使用稳定字符串 ID，按目录扩充第四件并接入生成器、说明和验证；保持已有三个内容 ID 的含义。

④ 给现有精英新增两种可配置修饰，先做坚韧和迅捷，D1 每名精英最多一种；记录名称、参数、兼容规则和表现，保留固定精英原型。

⑤ 固定场地增加两个小幅布局/遭遇变体，复用现有墙体与三类敌人；每次出发选择并在本趟记录变体 ID。保持出生、通行和清场奖励正常，随机房间仍由 D2 接手。

## 修改范围与 Godot 实现

| 主要路径 | 实现落点 |
| --- | --- |
| `game/content/items/、game/systems/items/、game/systems/stats/` | Resource 作为配置来源；检查各部位在相应等级能抽到品质要求的词条数量。 |
| `game/content/enemies/、game/actors/enemies/、game/systems/encounters/` | 在实例上应用修饰，禁止改写共享 EnemyDefinition。 |
| `game/world/maps/expedition_runtime.gd、game/world/maps/、game/systems/effects/` | 接入变体 ID、有限流血传播和当前主流程，新增反馈沿用共享特效。 |

涉及路径以当前仓库检查为准；共用存档入口仅在本卡确有影响时修改。相关回归放 `game/tests/` 并接入 `tools/verify.py`。新增类、函数、回调与功能写简明中文注释。

## 存档与兼容

新独特实例随 items 模块保存；新目录与生成器、属性汇总、描述、掉落及模块校验同步接入。精英修饰和本趟变体留在探险运行态，回城后重建。保留前三个稳定独特 ID。此次没有新增持久字段，Resource 模块版本保持原样。

## 验收标准

① 在源码与实际 Windows 成品中核对累计 14/18/4 内容数、唯一编号、资源引用及词条部位/等级/互斥；覆盖各部位、品质和有效等级的生成样本，产物均通过实例与保存校验。沿用成品回归检查导出后的词条部位数组。

② 穿戴第四件独特能观察有限流血传播，卸下后后续攻击失去该机制；已有三件雷霆独特机制保持。

③ 两种精英修饰产生可测差异，生成两只同底材精英后修改其中一只不会污染另一只。

④ 两个变体都能清图、撤离、再次出发；回城保存重启保留成长与已拾取装备，下一趟重建变体；雷霆与流血构筑均能杀精英。

功能验证通过 `python tools/verify.py --godot <引擎路径>` 执行，包含源码场景、存储故障及隔离 PCK 的拾取/存档回归；Windows 交付包还需运行 `python tools/verify_package.py --executable builds/windows/relic_arpg.exe --log package-smoke.log`。显示、声音和手感由人工试玩验收。

## 要求

1. 先检查当前项目状态：分支、工作区、最新 main、前置合入、实际代码与验证入口；保护现有未提交修改。
2. 不要实现与本任务无关的系统。只参考本仓库与所需官方资料，沿用本项目约定。任务卡默认无需 `global-work-rules`；本次执行按用户当前指令额外采用该工作约束。
3. 优先最小可用实现，以本卡验收为完成边界；从当前主入口可以观察到功能，必要存档与基础反馈同批完成。
4. 完成后按 AGENTS.md「完成任务前必须检查」逐条执行，更新本卡状态、任务总表和工作日志；实际遇到新坑才更新 `known_trap.md`。每完成一个独立且验证通过的子任务立即 commit，再同步任务分支和 PR。
5. 最后按下表汇报，并附分支/提交、测试命令与实际结果、PR 和可用构建链接。

| 汇报项 | 必须包含 |
| --- | --- |
| 改了哪些文件 | 主要文件及用途；文档、资源、存档版本变化。 |
| 当前能做什么 | 从哪个入口操作，得到什么结果，哪些验收已经实际通过。 |
| 还不能做什么 | 未完成项、失败项、未验证项及对应影响。 |
| 下一步建议做什么 | 已解锁的下一张任务卡、待合入依赖或具体阻塞。 |

## 执行记录

2026-09-14 从 `main` `55529f7` 建立 `feat/p1-task3-d1-content`。独立提交依次为：`82901c5` 扩展装备池和第四独特；`5722c9d` 清理未索引备用词条并锁定 18 条普通词条口径；`592c1c1` 实现最多 3 目标、最多 1 代的流血击杀传播；`07747f3` 实现坚韧/迅捷精英修饰及实例隔离；`de4f176` 实现 `corner_grid` / `cross_lanes` 两套本趟场地变体；`377b508` 把 14/18/4、四个稳定独特 ID 和第四独特掉落可达检查加入源码/成品共用回归；`6e252e8` 显式验证雷霆与流血构筑均能通过真实技能结算击杀固定精英；`ee4a636` 补齐本卡新增 GDScript 的 `.gd.uid`。

装备累计达到 14 底材、18 普通词条、4 独特。第四独特稳定 ID 为 `blood_echo`，底材 `serrated_blade`；流血伤害倍率进入横扫真实结算，击杀传播半径 4 米、最多 3 个目标、继承 65% 流血伤害、最多传播 1 代。卸装后的新攻击快照传播参数归零。已有 `thunder_ring`、`ember_mail`、`energy_grips` ID 保持原含义。

精英修饰使用 `EliteModifierDefinition` 静态配置，`坚韧`提高生命/护甲，`迅捷`提高移动与攻击节奏；运行时只复制到当前敌人实例，未改写共享 `EnemyDefinition`。正式探险每趟选择一个场地变体和一个精英修饰，HUD 显示中文名称；布局、修饰和本趟种子均留在运行态，不进入长期存档。

Windows CLI 最终验证对应代码 head `ee4a636d7fd77106519aeb836a493472f5fb836e`：[run 34803911579](https://github.com/w7775p/relic-ARPG/actions/runs/34803911579) 使用 `windows-latest`、PowerShell、Python 与官方 Godot 4.7.2，同版导入与 `python tools/verify.py --godot <Godot.exe>` 全量场景/故障/PCK 回归通过；Windows `.exe` 导出通过；`python tools/verify_package.py --executable builds/windows/relic_arpg.exe --log package-smoke.log` 对实际成品的拾取、14/18/4 内容、存档读回和下一件掉落验证通过。构建：[artifact 10333135206](https://github.com/w7775p/relic-ARPG/actions/runs/34803911579/artifacts/10333135206)，SHA256 `9ea1a05e022e8ea511525377b061a373204bdd6cc17ae2fc4cffca573b02a967`；启动日志：[artifact 10332352054](https://github.com/w7775p/relic-ARPG/actions/runs/34803911579/artifacts/10332352054)。

交付 PR：[PR #10](https://github.com/w7775p/relic-ARPG/pull/10)。自动验收覆盖内容额度、随机生成合法性、有限传播、卸装、两种精英修饰、实例隔离、两种变体清场/撤离/再出发、Hub 长期进度、雷霆与流血构筑真实击杀固定精英，以及实际 Windows 成品。首次交付时可见画面、声音、中文排版和操作手感仍待人工试玩，因此当时状态保持“待验收”。本轮没有发现需要新增到 `known_trap.md` 的项目级陷阱。

## 人工验收与 Blood Echo 传播反馈修补（2026-09-14）

用户首次 Windows 试玩确认：地图变体正常；坚韧精英功能正常但当前血量偏厚，留待后期数值平衡；迅捷精英功能正常，留待后期数值平衡；装备掉落与拾取正常；保存重开正常；无其他异常。Blood Echo 能在流血击杀后传播，但用户观察到传播目标的流血表现疑似继承源目标剩余时间，因此本卡继续保持“待验收”。

针对该反馈先补 `25d28f6` 回归：让源流血推进到最后 1 秒再造成击杀，真实 Godot 4.7.2 断言显示传播目标内部 `remaining_sec` 会重新获得横扫完整 4 秒，`next_tick_sec` 也重新从 1 秒开始，说明原底层计时快照没有直接继承剩余 1 秒。为避免后续路径或已有状态带入旧计时，`b1f6093` 新增显式 `apply_fresh_bleed` 接收入口，`674e246` 令 Blood Echo 传播在发送端和接收端双重强制按原始持续时间与首跳间隔重新起算；`0cfb992` 增加持续流血期间的暗红状态色，`87b73ba` 清理该表现修改中的重复函数定义。传播上限、65% 伤害和最多 1 代规则保持。

修补代码 head `87b73ba4f7e50d25a9aa921ee02217031ded326a` 的 Windows [run 34808769641](https://github.com/w7775p/relic-ARPG/actions/runs/34808769641) 已通过官方 Godot 4.7.2 的全量场景回归、Windows 导出、实际成品包拾取与存档验证。修补构建：[artifact 10333832212](https://github.com/w7775p/relic-ARPG/actions/runs/34808769641/artifacts/10333832212)，SHA256 `9caa32eed9fcdfb2d3d49fbc09bf1fb55375cdf0962d5f4951a6309483f54a07`；启动日志：[artifact 10334171626](https://github.com/w7775p/relic-ARPG/actions/runs/34808769641/artifacts/10334171626)。

最终交付 head `de0f22e2a3664ab4ef5ce48e17892b19368cfad8` 的 Windows [run 34808913642](https://github.com/w7775p/relic-ARPG/actions/runs/34808913642) 同样通过全量场景回归、Windows 导出和成品包验证；最终构建：[artifact 10334056782](https://github.com/w7775p/relic-ARPG/actions/runs/34808913642/artifacts/10334056782)，SHA256 `e2a0a23545f4806bbece9a5734d000f361c8f0c781b88a7af8a1c5a938443318`。

用户于 2026-09-14 完成最终修补包复测并明确确认验收通过。PR #10 已合入 `main`，合并提交 `48479ed9ec67c1943d9cf590b8e430976547ed79`。P1_Task3 状态更新为“已完成”，下一张 P1_Task4 已解锁。