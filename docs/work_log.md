# 工作日志

| 日期 | 任务 | 实际改动 | 验证 | 遗留与下一项 |
| --- | --- | --- | --- | --- |
| 2026-09-09 | M0-01～05 | 从空仓库编写工程、四个服务、主菜单、设置、3D 操控场地、导航、位置存档、中文规范、阶段任务、Windows 导出和工作流 | Godot 4.7.2 无窗口导入、启动与 20 项断言通过；Windows 模板导出成功 | Windows 桌面试玩与视觉未验证；后续 M1 战斗与雷霆旋风 |

工作流的最终执行结果见对应提交的 Actions 页面，不能将已写入的流程视为已通过。

| 日期 | 任务 | 实际改动 | 验证 | 遗留与下一项 |
| --- | --- | --- | --- | --- |
| 2026-09-09 | M1-01～06 | 生命护甲、普攻旋风、能量、三类敌人与精英、闪电感电爆炸、两套预设、战斗 HUD、基础音画、重开与压力脚本 | 原 M0 20 项及 M1 26 项回归；3 分钟 100 怪数据见 m1_performance.md；Windows 状态见 M1 PR | 画面和手感待实机；M2 随机装备、掉落与完整存档 |

| 日期 | 任务 | 实际改动 | 验证 | 遗留与下一项 |
| --- | --- | --- | --- | --- |
| 2026-09-10 | M2-01～04 | 10 底材、12 词条、3 独特资源，实例生成、地面掉落、六槽装备、背包仓库、锁定出售、升级难度、整备循环、版本 2 完整探险存档 | Linux 实际场景回归；M0/M1 保留，M2 新增 46 项；Windows 导出与启动状态见本阶段 PR | 原生几何体占位；目标机视觉、手感、经济与每趟时长待试玩，Demo 后续 D1～D3 |

## P1_Task1：技能装配与被动

从最新 main 313ac7f 创建 feat/p1-task1-loadout，带入任务分支 5945669 的规范与任务卡。完成三个主动槽、六项固定被动、据点调整与属性显示、v3 存档和 v2 迁移。当前功能范围仅本卡。

完成检查：差异与中文注释检查通过；资源、UID 及新场景已纳入；123 项自动回归完成，旧档完整状态及下一次随机一致；保留原 M2 收益/身份回归。图形服务无法建立套接字，可见试玩未验收。架构、README、任务总表、任务卡与验证记录同步；新增真实 JSON 版本比较陷阱。Windows 导出与独立启动通过，结果见下方交付记录。

本轮交付：功能提交 `aaf8b2e7512c491601bc1426b890cd0cb7c9c6ba`，[PR #5](https://github.com/w7775p/relic-ARPG/pull/5)。对应 [Windows 工作流](https://github.com/w7775p/relic-ARPG/actions/runs/34543081309) 的回归、导出与独立启动全部通过；[下载 Windows 构建](https://github.com/w7775p/relic-ARPG/actions/runs/34543081309/artifacts/10178021093)。产物沿用工作流名称 relic-arpg-m2-windows，实际包含本卡功能。本次后续提交仅补验证交接文档，代码与已验证提交相同。可见试玩仍待验收。

## P1_Task2：流血横扫、战吼与恢复药剂

2026-09-11 从 P1_Task1 head `1ff89c7` 建立堆叠分支 `feat/p1-task2-bleed-skills`。完成流血横扫、三层有界流血快照、F 战吼、Q 恢复药剂、HUD 与基础反馈，并将完整探险存档升级到 v4；v2/v3 均可迁移到 v4。实际发现战吼临时护甲会被经验或装备属性重算覆盖，已修复并记录 `P1-02`。

功能验证提交 `0dc446a8fdcce1d014aba6ef8c82457afa3b60c3`。Windows GitHub Actions 使用官方 Godot `4.7.2.stable.official.ed1daf0bf`，M0 20、M1 26、M2 46、P1_Task1 31、P1_Task2 36，共 159 项回归全部通过；Windows 导出成功，导出包独立启动进入 `M2_EXPEDITION_BOOT_READY`。工作流：[run 34552955127](https://github.com/w7775p/relic-ARPG/actions/runs/34552955127)；构建：[artifact 10181489752](https://github.com/w7775p/relic-ARPG/actions/runs/34552955127/artifacts/10181489752)。

本轮交付：[PR #6](https://github.com/w7775p/relic-ARPG/pull/6)，base 为 `feat/p1-task1-loadout`。PR #5 合入后再将 base 调整为 `main`。可见画面、中文排版、声音和实际操作手感待人工试玩，任务状态为待验收。

### P1_Task2 人工验收：保存失败诊断补丁

2026-09-11 用户在 Windows 发布包点击保存后实际看到“保存失败”。自动回归此前只能证明 CI 临时用户目录可写，无法解释用户机器上的具体失败阶段，因此新增 F3 游戏内 DebugLog，常驻于 SceneRouter 下并读取 `user://logs/godot.log`；SaveManager 逐步输出结构校验、临时文件写入/flush、rename、绝对存档路径与错误码。首次实现放在 `debug/` 后被导出过滤规则排除，发布包独立启动捕获 preload 缺失，随后迁到 `ui/debug/`。

修正后的 [run 34557223053](https://github.com/w7775p/relic-ARPG/actions/runs/34557223053) 使用官方 Godot 4.7.2：原 159 项保持通过，新增 DebugLog 6 项通过，共 165 项；Windows 导出与发布包独立启动通过。构建：[artifact 10183010207](https://github.com/w7775p/relic-ARPG/actions/runs/34557223053/artifacts/10183010207)，SHA256 `e84b77a7188f6e79feb6beeff40fc58660501bebbcd22845048325a71d3d4cd4`。用户机器上的原始保存失败原因仍需使用此新包复现并读取 `[DEBUGLOG][ERROR]` 行后定位。

## Hub / in_town 场景拆分

2026-09-11 从最新 main `37750a5` 建立 `refactor/hub-scene`。按可独立验证子任务分别提交：InventoryPanel 地点能力接口、SceneRouter 一次性角色状态交接、独立 Hub 场景、Hub 驱动的 ExpeditionRuntime、正式路由切换、旧 JSON 自动保存解耦、HubFlow 回归和发行 smoke 适配。

正常新角色流程已使用 `MainMenu → Hub → ExpeditionRuntime → Hub`。Hub 负责背包、装备、仓库、出售、技能与被动整备；ExpeditionRuntime 负责战斗世界。撤离和死亡结束当前探险场景并切换回 Hub。旧 `expedition.gd` 中的 `in_town` 与 v4 JSON 据点快照仅保留给旧档兼容、历史回归和下一轮迁移输入，新据点服务禁止继续接入该分支。

代码验证提交 `fba5f85e423c5273e950dbc3e8a4b622ad01b2b9`。Windows [run 34574865158](https://github.com/w7775p/relic-ARPG/actions/runs/34574865158) 的全量场景回归、Windows 导出及导出包独立启动全部通过；构建 [artifact 10189231734](https://github.com/w7775p/relic-ARPG/actions/runs/34574865158/artifacts/10189231734)，SHA256 `e6a0b9a7dfc16a61c8b6b0a20ee27e1757042f3b2a4de87298d6b23151d9ae87`。

下一步为 Resource 存档重构：拆分 `PlayerProfileResource`、`RunStateResource`、`SaveGameResource`，将旧 `session.json` 作为一次性迁移输入；迁移和 Resource 回归完成后删除 `LEGACY_EXPEDITION`、运行期 `in_town` 及仅服务 JSON v4 的兼容代码。详细边界见 `docs/hub_refactor.md`。

## Resource 存档重构 S1（2026-09-11）

从 `30b85f0` 建立 `feat/resource-save`。新增角色、物品、经济、进度、据点五个 Resource 模块、嵌套实例/词条/装配、GameSession 和按依赖恢复的注册协议。基线原有回归通过；Godot 4.7.2 导入与 ResourceModel 13 项通过。现有玩法暂未切换；下一步为完整检查点存储和多槽位。

## Resource 存档重构 S2（2026-09-12）

新增 SaveStore、可重建索引、槽位摘要、读回字段摘要；真实 Resource 写入/读回、多角色和手动槽隔离、自动最近三版、无效模块拒绝覆盖、索引重建通过。保存使用同目录 pending 文件，替换前保留旧文件恢复副本。旧系统仍运行，下一阶段统一接入正式业务和场景。

## Resource 存档重构 S3～S5（2026-09-12）

InventoryState 和 LoadoutState 改为所属 Resource 的事务入口；实例表以 ID 保存唯一归属，独特装备使用稳定内容 ID，掉落种子/状态/计数归物品模块。SceneRouter 一次性交接 GameSession。Hub 接入手动槽、自动保存、回退和保存后离场；正式探险直接继承 combat_arena，结算一次后切回 Hub。移除旧 expedition、SaveValidator、SessionSnapshot 及 JSON 保存。

模块类型切换与场景/回归存在编译依赖，因此 S3～S5 作为可运行集成提交。Godot 4.7.2 的九个实际场景验证全部通过（ResourceModel、ResourceStore、M0、M1、M2、Loadout、BleedSkills、HubFlow、DebugConsole）。保留物品、收益、技能时序规则测试；退休旧位置/战斗恢复及 JSON 迁移断言，新增完整 Hub 回退、新探险重建与去抖断言。后续故障、规模、Windows 与可见 UI 验证尚待执行。

## Resource 存档重构 S6a（2026-09-12）

新增七个隔离进程，实际制造临时文件不可写、正式文件替换失败、损坏正文、缺失内容 ID、索引失败、未提交 pending 和正常探险退出。验证失败时保留当前状态和旧档、手动选择回退、重试成功后离场、索引重建及读取不自动覆盖。补充旧模块版本一真实文件升级为版本二，保留原文件；索引成功路径直接更新摘要，避免每次保存重读全部正文。

实际发现 `.tres` 的浮点十进制舍入会误判读回失败，以及默认版本值被 ResourceSaver 省略会使后续升级失效；修复和回归见 `known_trap.md` SAVE-01/02。完整 `tools/verify.py` 在 Godot 4.7.2 通过导入、启动、10 个常规场景与 7 个故障进程。另测 10000 件装备：约 5.88 MB，保存 4869.63 ms，读取 2349.67 ms，测量时保留堆内存增量 95598572 字节（包含快照与恢复对象，不是峰值）。当前同步 `.tres` 在该规模存在明显停顿，后续大数据需求需另做性能阶段验证；可见 UI 和 Windows 验证待执行。

## Resource 存档重构 S6b：文档与 Windows 验证（2026-09-12）

代码提交 `dc6ab380a7e11ef1a10039dcaaaef370876aad26` 已同步远端；Windows [run 34716201490](https://github.com/w7775p/relic-ARPG/actions/runs/34716201490) 的全量回归、同版模板导出、独立包启动与上传全部成功。构建 [artifact 10304449478](https://github.com/w7775p/relic-ARPG/actions/runs/34716201490/artifacts/10304449478)，压缩产物 SHA256 `ccb21cb034526a1b13a2235bf5565591f24f9dc9a1a90edaacdc110e2db0944b`。

新增 save_system.md，同步 README、工程、Hub、总体计划、任务总表、验证与后续任务卡；将旧 JSON/战斗恢复要求改为已冻结的 Resource Hub 检查点、整体回退和新探险重建。已完成 P1 卡和历史验证保留历史标识；本轮未提前实现后续玩法。字段、路径、版本说明与代码核对，文档差异/链接检查后单独提交；人工可见验收仍待执行，下一项为最终差异检查和 PR。

## Resource 最终反馈修正（2026-09-12）

最终差异检查发现 Hub 的出发业务接口在保存失败时仍返回“已出发”，与底部失败状态冲突。改为只有场景切换开始才返回成功，否则返回实际失败消息。真实 pending 写入阻塞覆盖整备面板出发入口，五项故障断言通过；原菜单重试和旧文件保持继续通过。该修复单独提交，之后重新运行 Windows 全量回归和导出，最终交付以新包为准。

## Resource 最终交付（2026-09-12）

最终代码提交 `95d3a0f2269f237c84982eb2f90820db67b87299`，[PR #8](https://github.com/w7775p/relic-ARPG/pull/8)，base main、head feat/resource-save，未合并。对应 [Windows run 34716912163](https://github.com/w7775p/relic-ARPG/actions/runs/34716912163) 全量场景/故障回归、Windows 导出和独立包启动全部通过；构建 [artifact 10305120887](https://github.com/w7775p/relic-ARPG/actions/runs/34716912163/artifacts/10305120887)，压缩产物 SHA256 `048274d00ecab047fdb6523d21a62ddf9b6b082bce1f610aca3a184153a8f848`。

最终差异、脚本中文注释/制表符、资源引用、UID、文档相对链接检查通过；运行代码与测试入口不再引用旧 JSON/in_town/旧探险。功能子任务已分别提交；本次提交仅记录交付，已验证代码未变。可见界面、中文排版、音效听感和操作手感仍待 Windows 人工验收；万件规模同步文本停顿为已知性能限制，详见 save_system.md。下一步使用本轮新包按 validation.md 验收，评审及合并由用户决定。

## 横扫游玩时 E 拾取反馈跟进（2026-09-13）

用户报告 E 拾取无反应，并补充已将技能换为横扫。真实引擎复现 Hub 换装配→右键直接/流血击杀→按住右键时 E 拾取，近处物品入包正常；确认超出 2.5 米无反馈及满包提示被逐帧 HUD 覆盖。新增统一数秒反馈，保留候选与常规状态；无候选给出距离/遮挡/过滤条件，成功显示物品名，异常物品独立提示并写 F3 诊断。用户原始故障是否由满包或距离造成仍未确认。

修复前真实输入用例的五项反馈断言失败，修复后新增异常身份用例共 23 项通过；覆盖物品身份、满包保留、腾格重试、GUI 暂停/关闭、重复按键，以及撤离后 Resource 文件读回。M2 改用真实 E 事件，新场景接入统一验证。Godot 4.7.2 Linux 的 `python3 tools/verify.py --godot <引擎路径>` 全量通过：导入、主入口、11 个常规场景和 7 个故障进程。代码先提交，随后 Windows 全量验证和新包另行记录。`save_system.md` 已在 `9b2fe71` 提交并同步到 PR #8，本轮核对确认没有遗漏。

拾取跟进交付：代码 `708160e834cd1b36d4031ad83f2e30310ed9e47e` 的 [Windows run 34745672581](https://github.com/w7775p/relic-ARPG/actions/runs/34745672581) 全量回归、Windows 导出及独立包启动全部通过。新包 [artifact 10314221276](https://github.com/w7775p/relic-ARPG/actions/runs/34745672581/artifacts/10314221276)，压缩产物 SHA256 `7718cc2b69fdd0cde0bd35c1d159166f4b49222fd98b97caf97b7a627074b67e`。文档与代码分别提交，[PR #8](https://github.com/w7775p/relic-ARPG/pull/8) 已更新，main 仍为 `30b85f0`，未合并。本次仅记录已完成的验证，不新增代码改动；无窗口结果不代替用户原始现场和可见验收。

## 词条数量拒绝的导出根因（2026-09-13）

用户提交 F3 日志，明确物品 ID 2 不重复但词条数量非法。源码池和数量要求一致，改查导出资源：所有词条适用部位 PackedStringArray 在 PCK 中变为空。种子 8912 的 1000 次生成，源码 0 失败、旧导出 762 失败。普通 ResourceSaver 二进制往返正常，显式默认构造和脚本源码导出无效；仅关闭导出资源自动二进制转换即可修复。保留实例校验与已有 Resource 存档版本。

拾取回归迁入 app/validation 并保留 UID，测试场景与 Boot 的 --smoke-loot 共用；补静态部位、1000 件生成、完整物品模块读回和下一次随机断言，共 27 项。tools/verify.py 增加隔离 PCK 验证，Windows 工作流对真正交付的 exe 执行同一套玩法检查。Linux 统一入口的导入、启动、11 个场景、7 个故障进程及 PCK 内 27 项全部通过。隔离副本改回旧转换设置，新成品回归捕获两项失败、退出码 1。代码和后续 Windows 交付分别提交；前次“包能启动”证据无法证明掉落配置完整。

根因修复交付：`992532a08bef65d4b07f148bcab297bafe110ba5` 的 [Windows run 34757117119](https://github.com/w7775p/relic-ARPG/actions/runs/34757117119) 完成全量源码/PCK 回归、导出及实际 exe 的 27 项检查。修正包 [artifact 10317558351](https://github.com/w7775p/relic-ARPG/actions/runs/34757117119/artifacts/10317558351)，压缩产物 SHA256 `5a29494cbd9b1126b6128aebbc6336e2f83bf79b8c6d681b941b62f4dc91cd09`；[成品日志](https://github.com/w7775p/relic-ARPG/actions/runs/34757117119/artifacts/10317927889)。PR #8 已替换下载入口，工作分支 feat/resource-save，main 仍为 30b85f0，未合并。本次提交仅记录交付；实际画面和用户试玩仍需复核，有效 Resource 存档可继续使用。

## TASK 与合入状态同步（2026-09-13）

远端 PR #8 已合入 main `3cdc6122e66b1aa16eb4c8b52d98b80cf4141aec`，合并树与 `3784f21` 一致；从该节点建立 `docs/task-save-sync`。核对全部 21 张任务卡，更新 19 张待执行卡的基线、成品验收入口和子任务 commit 规则。装备扩容、随机区域、宝箱、输入、引导及阶段交付补充对应检查，拆解/重铸的服务路径改为真实 Hub；总表和重构记录同步合入状态。P1_Task1/2 的历史验收与后续玩法状态保持。

检查结果：文档差异、21 张卡状态、302 个相对链接/锚点和新增引用路径通过；game/、tools/、.github/ 与已验证代码 `992532a` 无差异。此次仅改文档，玩法、存档及可见专项不适用，未重跑 Godot；已有实际 Windows 成品证据对应 run 34757117119。本子任务独立 commit，提交以 Git 历史为准，文档 PR 使用 `docs/task-save-sync → main`。下一张玩法任务为 P1_Task3，新包画面与手感继续待人工验收。

## P1_Task3：D1 装备池、精英修饰与地图变体（2026-09-14）

从最新 main `55529f7` 建立 `feat/p1-task3-d1-content`。累计装备池扩至 14 底材、18 普通随机词条和 4 独特；新增 `blood_echo`，把流血伤害倍率接入横扫真实结算，并实现 4 米内最多 3 目标、65% 伤害、最多 1 代的击杀传播。新增坚韧/迅捷两种精英修饰，运行属性只落在敌人实例；固定场地增加 `corner_grid` / `cross_lanes` 两种本趟布局，正式探险每次选择并显示布局与精英修饰。

独立提交：`82901c5` 装备内容，`5722c9d` 清理备用词条，`592c1c1` 有限流血传播，`07747f3` 精英修饰，`de4f176` 场地变体，`377b508` 成品包 D1 内容门禁。没有新增持久字段，五模块 Resource 版本保持原样；变体、精英修饰和本趟种子均为探险运行态。

首次完整代码 head `377b508f6978209a5747269914fbe3dd4d98c0bd` 的 [Windows run 34803499160](https://github.com/w7775p/relic-ARPG/actions/runs/34803499160) 使用官方 Godot 4.7.2、PowerShell/Python CLI：全量源码场景/故障/PCK 回归通过，Windows exe 导出通过，实际成品拾取、14/18/4 内容、存档读回和下一件掉落验证通过。

人工试玩确认地图变体、坚韧/迅捷功能、装备掉落拾取和保存重开正常；坚韧/迅捷数值体感留待后期平衡。Blood Echo 首次试玩出现传播持续表现疑似继承源剩余时间的反馈，随后增加完整时长回归、fresh bleed 接收入口和暗红状态表现。最终交付 head `de0f22e2a3664ab4ef5ce48e17892b19368cfad8` 的 [Windows run 34808913642](https://github.com/w7775p/relic-ARPG/actions/runs/34808913642) 全量源码/PCK 回归、Windows exe 导出及实际成品包验证通过；最终构建 [artifact 10334056782](https://github.com/w7775p/relic-ARPG/actions/runs/34808913642/artifacts/10334056782)，SHA256 `e2a0a23545f4806bbece9a5734d000f361c8f0c781b88a7af8a1c5a938443318`。

用户于 2026-09-14 完成最终修补包复测并明确确认验收通过。[PR #10](https://github.com/w7775p/relic-ARPG/pull/10) 已合入 main `48479ed9ec67c1943d9cf590b8e430976547ed79`。P1_Task3 状态更新为已完成，下一张玩法任务为 P1_Task4。

## P1_Task4：据点拆解与材料循环（2026-09-14）

从最新 main `2cc76de` 建立 `feat/p1-task4-salvage`。新增 `SalvageRules` 与 `.tres` 集中配置拆解收益：普通/魔法/稀有/独特基础材料为 `1/2/4/7`，物品等级从 1 级起每跨 3 级增加 1 材料。`SalvageService` 负责 Hub 地点、锁定和归属失败原因；`InventoryState.salvage()` 最终按稳定实例 ID 重新定位并提交删除实例与材料入账。装备已穿戴、位于仓库、锁定、已不存在或处于探险时均拒绝且保持原值。

Hub 背包操作区新增拆解按钮，选中装备时并列展示“出售 X 金｜拆解 Y 材料”；出售仍沿原金币规则。拆解点击先捕获稳定实例 ID，再由服务和库存事务入口重新查询，因此背包顺序变化或同一 ID 连续请求不会改错目标或重复发材料。拆解、出售、入仓连续操作继续触发原 GameSession 变更和 Hub 去抖保存，没有增加持久字段或提升 Resource 版本。

第一轮新回归中四品质及全部失败事务前 27 项通过，最后模块合法性断言因独立测试直接 `new()` 的模块版本为 0 失败；该行为属于既有 SAVE-02，改为正式当前模块版本初始化后通过，本轮没有新增 `known_trap.md` 条目。`p1_salvage.tscn` 覆盖四品质、重复请求、列表重排和地点/归属失败；`hub_flow.tscn` 额外覆盖真实 UI、拆解/出售/入仓、手动检查点和文件读回。

最终代码 head `4a6c5e21aec0151782d9d00ec915cc1fd547b2c7` 的 [Windows run 34813005120](https://github.com/w7775p/relic-ARPG/actions/runs/34813005120) 已通过官方 Godot 4.7.2 的全量源码场景、存储故障、隔离 PCK、Windows exe 导出与实际成品包拾取/存档回归。构建 [artifact 10335855806](https://github.com/w7775p/relic-ARPG/actions/runs/34813005120/artifacts/10335855806)，SHA256 `160230324f9d1455a90483c090b5ed04bd11224fa18c7b322f968433f3bd760a`；启动日志 [artifact 10335855812](https://github.com/w7775p/relic-ARPG/actions/runs/34813005120/artifacts/10335855812)。用户于 2026-09-14 完成人工试玩并确认验收通过；[PR #11](https://github.com/w7775p/relic-ARPG/pull/11) 已合入 main `4798f7b83dcb01405e1e8b7ab175a4c2b6c63284`，拆解数值与交互优化留待后期。

## P1_Task5：单词条位置重铸（2026-09-14）

从最新 main `77948dcd` 建立 `feat/p1-task5-reforge`。`ItemInstanceResource` 新增 `reforge_index=-1`；items 模块升为 v2，加入独立 `reforge_rng_seed/state`。v1→v2 从原掉落种子确定性派生重铸序列并保持原 `rng_seed/state`，旧装备初始化为未选择位置。`ItemGenerator` 抽出合法候选和加权抽取供掉落/重铸共用，`ReforgeService` 与 `InventoryState.reforge()` 完成 Hub 规则、费用、固定位置、单次扣费、独立 RNG 和失败原子性。

Hub 对未锁定的魔法/稀有背包装备显示位置、当前词条、合法候选范围、材料费用和结果；首次成功后位置选择器锁定。当前费用为魔法基础 2、稀有基础 4，每 4 个物品等级档再加 1。相同词条或相同数值允许再次出现；独特装备、穿戴/仓库、探险、材料不足、零候选和失效实例拒绝提交。

独立提交：`261e8a0d` 持久状态与 items v2；`3b50f2e0` 共用候选/抽取规则；`b472ee23` 重铸事务；`a92035cd` Hub UI；`527c7d46` 专项回归；`a921da3f` 发布包 Hub 重铸 smoke；`6753e618` 修正 smoke 在生成下一件掉落后才核对保存前 RNG 的测试顺序。专项回归覆盖小候选池、等级/部位/互斥、零候选、重复请求、材料不足、同底材实例隔离、静态定义不变、穿戴属性生效、下一件掉落不受影响、真实检查点和 v1→v2 确定性迁移。

最终代码 head `6753e61811cbb041892408e86b30bddd13f030ea` 的 [Windows run 34826805034](https://github.com/w7775p/relic-ARPG/actions/runs/34826805034) 全量源码场景、专项重铸、存储故障、隔离 PCK、Windows exe 导出和实际成品 Hub 重铸/检查点读回均通过。构建 [artifact 10340134660](https://github.com/w7775p/relic-ARPG/actions/runs/34826805034/artifacts/10340134660)，SHA256 `84fbaa2d5b228482bd094e3ea32a244987c01880a761bb6089c625f193417f8d`。当前状态待人工试玩；通过并合入后进入 P1_Task6。本轮没有新增项目级 `known_trap`。

## P1_Task5：Hub UI 模块化修正（2026-09-15）

人工试玩暴露重铸详情动态注入背包后挤压原页面的问题。本轮保留 `ReforgeService`、`InventoryState` 与 items v2 的已验证业务事务，重构据点展示层：新增 `HubHUD` 母控件，将背包、已装备、仓库、技能与被动、重铸拆为独立 `.tscn + .gd` 页面；背包只保留轻量重铸入口并传递稳定 item ID，`ReforgePage` 独立承载位置、候选、费用与结果。标题及保存/读取/退出工具栏同时归入 `HubHUD`，`hub.gd` 只处理会话、服务、保存和场景切换。

新增 `hub_ui_modularity` 12 项结构回归，覆盖选中可重铸装备时背包尺寸不变、重铸页独占固定 PageHost、返回恢复原稳定实例选择以及四个主页面互斥。`p1_loadout`、`hub_flow`、发布包 smoke 和保存故障探针迁到 HUD 公开接口；探险继续使用原 `InventoryPanel`。旧 Hub/HUD 临时 UI 兼容别名已经删除。

重构期间两次失败均属于测试耦合：旧装配测试直接调用 `InventoryPanel._on_tab()`；保存故障测试迁移 Toolbar 时一度误删正常退出信号探针。均恢复覆盖并迁移到公开接口，没有新增玩法或引擎级 `known_trap`。最终代码 head `8f8fbb56f46cd7ff5d7fc2dcb773f6eaf0094456` 的 [Windows run 34952323992](https://github.com/w7775p/relic-ARPG/actions/runs/34952323992) 全绿，覆盖全量源码、7 类保存故障、隔离 PCK、Windows 导出和实际 EXE。最终构建 [artifact 10389985816](https://github.com/w7775p/relic-ARPG/actions/runs/34952323992/artifacts/10389985816)，SHA256 `bacb887f079bc81e35ca16bf252cb0863e1199915da626ae17f2244b4c85a414`；启动日志 artifact `10390005719`。当前仍待用户试玩新页面结构，通过后再合并 PR 并进入 P1_Task6。

## P1_Task6：D1 过滤、属性解释与阶段验收（2026-09-17）

从最新 main `a0b382ebad4d610e5671965f1ed1816fe5d7753d` 建立 `feat/p1-task6-d1-integration`。`e9105df` 完善装备属性单位、技能标签、直接命中/持续伤害边界、独特机制和重铸位置说明；`b42c58f` 建立 D1 跨系统回归；在发现同一测试进程反复切换大场景会造成退出期资源残留后，按任务边界将新增用例收敛为业务事务与 Resource 恢复，真实路由/E/Tab/满包/成品流程继续由已有专项回归负责，形成 `ed37928`；`7b9fc26` 将 UI 药剂说明改为从轻量 `LoadoutState.POTION` 读取同一 `potion.tres`，避免显示层加载 `SkillRunner` 整条战斗执行资源链。

失败排查中的场景清理顺序、延迟退出和 UI workaround 均已回滚，未进入最终分支历史。当前 branch 相对 main 只保留四个独立有效代码/测试 commit；本卡没有新增持久字段，Resource 模块版本保持不变。

最终代码 head `7b9fc26db4d91d8f0f83f89f4ab152319b4369a2` 的 [Windows run 35187722075](https://github.com/w7775p/relic-ARPG/actions/runs/35187722075) 全绿：官方 Godot 4.7.2 的源码/实际场景回归、存储故障、隔离 PCK、Windows exe 导出及实际成品包拾取/存档全部通过。构建 [artifact 10482424579](https://github.com/w7775p/relic-ARPG/actions/runs/35187722075/artifacts/10482424579)，SHA256 `ca196adb5812e661f535dc4a89281844670e91565218ef9544ae24ceccdbd00f`。交付 [PR #13](https://github.com/w7775p/relic-ARPG/pull/13)。

自动证据覆盖 14/18/4 内容额度、两套构筑固定精英击杀、药剂/战吼/流血、锁定保护、拆解→重铸、过滤偏好、Resource 捕获恢复、真实 E/Tab、满包重试、Hub 保存读回和下一件掉落。2026-09-21 用户确认 D1 阶段验收通过；P1_Task6 更新为已完成，P2_Task1 解锁。此次仅记录用户给出的阶段验收结论，没有新增逐项设备、帧率或画面测量数据；PR #13 已于 2026-09-21 合入 main `6781dd8`。


## 2026-09-21 P2_Task1 冲锋子任务

基于 main `6781dd8`，分支 `feat/p2-task1-charge-build`。新增 ChargeAttack 规则模块，PlayerController 用 move_and_collide 执行扫掠移动；撞墙/敌人停止，同次目标去重，真实命中后提供一次 3 秒重击增益。Godot 4.7.2 冲锋实际物理回归 22 项通过。后续重击和四被动继续本分支；本步未声明全任务完成。


## 2026-09-21 P2_Task1 重击子任务

新增独立 HeavyAttack，前摇范围与举刀动作、命中击退、恢复期和一次组合增益接通；死亡与闪避通过信号取消。Godot 4.7.2 重击 22 项通过：规定伤害时点、暂停、取消不退费、换装快照、一次组合伤害、视线/范围及离场清理。


## 2026-09-21 P2_Task1 被动与保存接入

四个被动接入统一属性汇总，第二属性表达生存/资源取舍，十被动最多选三。正式 Hub 与探险界面读取配置说明，HUD 按实际装配显示技能名。Godot 4.7.2 的 p2_loadout 29 项全部通过，包含真实输入、Hub 保存、旧选择与新 ID 恢复、新探险清理。持久结构及版本保持。

## 2026-09-21 P2_Task1 遭遇与成品覆盖

新增第三构筑测试装备与保留敌人 AI 的普通怪群/单精英场景，5 项通过；精英战 14.62 秒，能量最低 0.10，低于重击费用 763 帧后仍完成击杀。共用成品 smoke 接入冲锋→重击→精英掉落→真实 E→Hub 保存读回，源码 47 项通过。选择框使用技能短名，完整规则在自动换行说明中展示；装配回归 31 项和 Hub 模块化 12 项通过。SkillRunner 的失效角色取消入口同时修正空引用。最终全量及 Windows 验证随后执行；当前环境没有可用图形服务，可见画面、声音及操作手感仍待人工验收。


## 2026-09-21 P2_Task1 交付记录

远端代码 `4a389e5afd148bc4d85f7d2b31c38e9898ee834d` 与本地 `65f632a` 文件树一致。官方 Godot 4.7.2 的本地统一入口退出码 0：22 个源码场景、7 类存储故障、隔离 PCK 全部通过。新增专项合计 80 项；共用拾取/保存源码与包内 47 项通过。退出音频对象警告的实际范围见 validation.md，未将其记为已修复。

[Windows run 35584816275](https://github.com/w7775p/relic-ARPG/actions/runs/35584816275) 全绿，完成全量、导出和实际 exe 内 47 项；[构建 artifact 10631808873](https://github.com/w7775p/relic-ARPG/actions/runs/35584816275/artifacts/10631808873)，ZIP SHA256 `37f68e21122c03fd7b8d77573f5fae04c20cf2912ab3e92580790b92ea745366`。同步 README、工程/存档边界、任务总表与验收记录；P1_Task6 的 PR #13 合入事实也已更新。

[PR #14](https://github.com/w7775p/relic-ARPG/pull/14) 交付评审，当前任务待验收、未合并。没有可用图形服务，中文排版可见效果、范围辨识、声音与键鼠手感留给 Windows 人工试玩。通过并合入后从最新 main 接续 P2_Task2；没有提前实现后续卡或专属装备。
