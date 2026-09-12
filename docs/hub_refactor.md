# Hub 与探险场景边界

Hub 拆分在 main `30b85f01bae318ea0088d0c096e36637798ab513`（PR #7）完成。本文同步 Resource 存档重构后的当前实现；存档规则见 [save_system.md](save_system.md)，执行与交付见 [resource_save_task.md](resource_save_task.md)。

## 场景与状态归属

正式流程为 `MainMenu → Hub → ExpeditionRuntime → Hub`。Hub 是独立场景，负责背包、装备、仓库、出售、技能与被动整备以及保存界面。ExpeditionRuntime 直接继承 combat_arena，负责战斗世界、敌人、地面掉落和本趟状态。

当前场景持有 GameSession；角色、物品、经济、据点、进度五个长期 Resource 模块随会话跨场景保持。SceneRouter 仅一次性交接引用，目标领取后清空。InventoryPanel 查询地点能力决定据点服务是否可用，保存由 `can_save_checkpoint()` 判断，UI 不读取内部地点布尔值。

## 出发、回城与退出

Hub 出发前保存成功才进入探险；没有持久变化时跳过重复写入。撤离、通关或死亡排空当前有限结算队列，保留已拾取收益，销毁探险后回到真实 Hub 并保存。通关/难度进度只结算一次，重复离场请求不会重复奖励。

普通探险退出或返回菜单同样经过撤离、Hub 结算和成功保存，保存失败停留 Hub 允许重试。强制结束进程只能恢复最后成功检查点。本趟地图、敌人、地面对象、战斗 RNG、技能冷却和持续状态不持久化，下次出发重新建立。

## 旧路径处理

按已冻结方案，旧 expedition 场景/脚本、运行期 `in_town`、SaveValidator、SessionSnapshot 及 JSON v1～v4 兼容已移除，不再恢复旧探险或迁移旧 `session.json`。旧文件不由新系统自动删除。后续拆解、重铸、难度和区域选择统一接入 Hub 与所属 Resource 模块。

此前 Hub 拆分文档中的 PlayerProfileResource / RunStateResource 和旧 JSON 一次性迁移设想已经由本轮冻结方案替代。当前正式存档为五模块完整 Hub 检查点。

## 验证

`game/tests/hub_flow.tscn` 当前覆盖真实路由、新角色起装、自动保存去抖、多槽选择、跨场景会话保持、探险拒绝保存、回城结算一次、坏档保留当前状态、手动整体回退、读取不写档及界面边界。存储故障由 `save_faults.tscn` 七个独立进程验证。

PR #7 的历史 Windows 证据为 run `34574865158`。本轮需要使用 Resource 分支对应的全量回归和 Windows 包，结果见 [validation.md](validation.md)；无窗口布局检查不替代可见试玩。
