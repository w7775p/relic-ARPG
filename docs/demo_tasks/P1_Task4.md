# P1_Task 4：据点拆解与材料循环

仓库：[w7775p/relic-ARPG](https://github.com/w7775p/relic-ARPG)。工程入口：`game/project.godot`。技术栈：Godot 4.7.2 标准版、GDScript、3D 俯视即时动作、Windows 键鼠。

阶段：D1。状态：已完成。任务 ID：`P1_Task4`。工作分支：`feat/p1-task4-salvage`。

前置任务：[P1_Task 3](P1_Task3.md)。本次从最新 `main` `2cc76de50a526c06a3a1e398fbd0a29abcbf143e` 开始；前置任务已验收并通过 PR #10 合入，Resource 存档与词条导出修复也已在 main。

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

历史 M2 已完成战斗、随机装备、背包仓库和整备循环。当前存档基线为独立 Hub 与五模块 Resource 检查点；仅 Hub 保存，旧 JSON 和旧探险恢复已退休。P1_Task3 已把装备池扩至 D1 额度，并完成有限流血传播、精英修饰和固定场地双变体。

InventoryState 已管理背包、仓库、锁定与出售；材料余额归 economy 模块，可通过战斗掉落获得。本卡在该边界上新增据点拆解，不增加持久字段。

## 本次要做的任务

① 在据点为背包物品提供单件拆解：显示目标、拆解材料数与执行结果；产出按品质和物品等级计算，规则集中配置。

② 使用当前材料资源，拆解成功删除一个装备实例并增加一次材料；遵守锁定、地点和物品持有规则。已穿戴装备须先卸下，仓库装备须先移入背包。

③ 操作按稳定实例 ID 重新定位物品，避免列表排序或连续点击拆错对象。锁定、物品已不存在、战斗中调用等失败保持物品与材料原值。

④ 保留出售为金币来源；在界面并列显示出售和拆解收益，让玩家能做选择。执行后使用现有保存反馈和刷新流程。

## 修改范围与 Godot 实现

| 主要路径 | 实现落点 |
| --- | --- |
| `game/systems/town/、game/systems/inventory/inventory_state.gd` | `SalvageRules` 集中计算收益，`SalvageService` 处理地点与失败原因，最终按稳定实例 ID 交给 InventoryState 提交归属与材料事务。 |
| `game/world/hub/hub.gd` | 在现有背包操作区增加拆解按钮和出售/拆解并列收益；点击时捕获稳定实例 ID，再由服务重新定位。 |
| `game/content/town/salvage_rules.tres、game/tests/` | 配置品质/等级收益，并覆盖四品质、失败路径、重复请求、列表重排、Hub/探险与保存往返。 |

共用存档格式没有变化；相关回归已接入 `tools/verify.py`。新增类、函数、回调与功能均写简明中文注释。

## 存档与兼容

复用已持久化的 `items` 与 `economy.materials`，没有新增存档字段，也没有提升模块版本。拆解成功后物品实例从 items 模块消失、材料进入 economy 模块；Hub 现有变更去抖与手动/自动检查点负责持久化。保存失败仍沿现有 SaveResult 反馈和重试入口处理，当前会话保持可继续保存。

## 验收标准

① 分别拆普通、魔法、稀有和独特物品，产出与界面一致；锁定物品、穿戴物品及战斗地点均无法拆解。

② 对同一个实例连续发两次请求，只拆一次；背包排序变化后仍只修改选定实例。

③ 出售/拆解/仓库转移连续操作后保存重启，物品归属、金币和材料正确；失败条件余额不变。

功能验证通过 `python tools/verify.py --godot <引擎路径>` 执行，包含源码场景、存储故障及隔离 PCK 的拾取/存档回归；新增 `P1_SALVAGE_RESULT` 场景已实际运行到完成标记。Windows 成品继续通过 `python tools/verify_package.py --executable builds/windows/relic_arpg.exe --log package-smoke.log`。显示、中文排版和实际操作感受已由用户试玩确认通过；细节优化后置。

## 要求

1. 先检查当前项目状态：分支、工作区、最新 main、前置合入、实际代码与验证入口；保护现有未提交修改。
2. 不要实现与本任务无关的系统。只参考本仓库与所需官方资料，沿用本项目约定，无需使用 `global-work-rules`。
3. 优先最小可用实现，以本卡验收为完成边界；从当前主入口可以观察到功能，必要存档与基础反馈同批完成。
4. 完成后按 AGENTS.md「完成任务前必须检查」逐条执行，更新本卡状态、任务总表和工作日志；实际遇到新坑才更新 `known_trap.md`。每完成一个独立且验证通过的子任务立即 commit，再同步任务分支和 PR；合并按用户当前授权执行。
5. 最后按下表汇报，并附分支/提交、测试命令与实际结果、PR 和可用构建链接。

| 汇报项 | 必须包含 |
| --- | --- |
| 改了哪些文件 | 主要文件及用途；文档、资源、存档版本变化。 |
| 当前能做什么 | 从哪个入口操作，得到什么结果，哪些验收已经实际通过。 |
| 还不能做什么 | 未完成项、失败项、未验证项及对应影响。 |
| 下一步建议做什么 | 已解锁的下一张任务卡、待合入依赖或具体阻塞。 |

## 执行记录

2026-09-14 从 `main` `2cc76de` 建立 `feat/p1-task4-salvage`。拆解收益使用集中资源：普通/魔法/稀有/独特基础材料分别为 `1/2/4/7`，物品等级从 1 级起每跨 3 级额外增加 1 材料。界面与实际事务读取同一 `SalvageRules`，出售仍使用原 `ItemGenerator.price()` 金币规则。

独立提交包括：`4fc5afe` 新增拆解收益规则；`4e142ec` 补规则 UID；`ab2d150` 增加 D1 收益资源；`ce11721` 实现稳定 ID 拆解服务；`3fe9efc` 补服务 UID；`dc46039` 增加四品质与失败事务回归；`e5dc6ff` / `de5d8b6` 补测试 UID 与场景；`7f860bd` 接入统一验证；`98266f7` 在真实 Hub 接入拆解按钮及出售/拆解收益预览；`c050605` 修正独立测试的正式模块版本初始化；`f32e2b5` 覆盖 Hub 中拆解、出售、入仓、手动保存及文件读回；`e96857d` 将拆解最终提交纳入 InventoryState；`4a6c5e2` 令 SalvageService 通过库存事务入口提交。

第一次 Windows 回归中，拆解行为前 27 项均通过，最后模块合法性断言因测试直接 `new()` 的 SaveModule 版本仍为 0 失败；该行为已记录在既有 `known_trap.md` 的 SAVE-02，本轮没有新增项目级陷阱。改为使用正式当前模块版本后回归通过。

最终 PR head `180f52403a959e885e03d69bbc47dc78290830cd` 的 Windows [run 34813475464](https://github.com/w7775p/relic-ARPG/actions/runs/34813475464) 使用 `windows-latest`、PowerShell/Python 与官方 Godot 4.7.2：全量源码场景、存储故障、隔离 PCK 回归通过；Windows `.exe` 导出通过；实际成品包拾取与存档验证通过。最终构建：[artifact 10336200563](https://github.com/w7775p/relic-ARPG/actions/runs/34813475464/artifacts/10336200563)，SHA256 `c6a324c3f543fc5cec30622cc2fa0a7ef15d3f281c3172a0b484b88ed6fd9a6e`。

用户于 2026-09-14 完成人工试玩并确认验收通过，拆解数值与交互细节优化留到后期统一处理。[PR #11](https://github.com/w7775p/relic-ARPG/pull/11) 已合入 main `4798f7b83dcb01405e1e8b7ab175a4c2b6c63284`。P1_Task4 已完成，下一张任务为 P1_Task5。
