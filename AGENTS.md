# RayPortal 工程开发约束

## 1. 适用范围与目的

本文是 RayPortal 仓库级开发执行规范，适用于本仓库中的调查、设计、编码、测试、文档和构建工作。

目标是让功能开发始终服从以下原则：

- 精确且可验证的时间语义。
- 清晰的代码层级和单向依赖。
- 显式的线程、资源和 Session 所有权。
- 可恢复的离线逐帧状态机。
- 不依赖特定渲染器的核心能力。
- 小步、可编译、可测试、可回退的阶段性交付。

本文是执行政策，不是当前项目事实清单。不得在这里记录临时版本号、文件行号、当前 Bug、阶段完成度、测试结果或发布声明。这些事实必须从当前源码、构建配置、测试和对应文档中读取。

## 2. 信息来源与冲突处理

按以下顺序确认事实：

1. 当前用户指令。
2. 本 `AGENTS.md`。
3. 当前源码、资源、构建配置和序列化契约。
4. 当前测试与实际运行证据。
5. [正式架构规范](docs/architecture.md)。
6. [基础调查文档](docs/architecture-investigation.md)。
7. 历史对话、旧阶段记录和外部参考项目。

每次工作前必须检查当前仓库，不得从旧对话推断路径、Minecraft/NeoForge 版本、Gradle 任务、包结构、Schema、功能状态或运行结果。

正式架构规范定义长期方向，但不能掩盖当前实现事实。若源码、配置或运行结果与 Accepted 架构决定发生实质冲突，停止修改并报告冲突；不得静默选择一方。

Aperture、Minema、BBS、Cycles 和 Blender 只提供设计参考。不得复制其命令、依赖、数据格式或内部实现，除非已验证许可证、适用版本和 RayPortal 的边界。

## 3. 开发所有权与工作树

默认采用串行、单写者开发：

- 同一时间只有一个任务拥有源码写入、构建输出、Git 索引和提交。
- 未经用户明确许可，不启动并行实现任务来修改同一仓库。
- 调查任务只允许只读检查，不得顺手生成资源、格式化代码或修复发现的问题。
- 写入前检查仓库根目录、当前分支和 `git status`。
- 未知的已修改或未跟踪文件视为用户所有，不得覆盖、删除、格式化、暂存或提交。
- 目标文件可能被外部修改时，编辑前重新读取。
- 不能安全拆分不同所有者的重叠修改时，停止并请求交接。

仓库尚未建立可靠基线提交时，不得把“所有文件均为未跟踪”误判为允许重建或清理脚手架。

## 4. 变更计划与范围控制

只实施满足当前目标所需的最小完整变更。

以下任一情况属于非小型变更，编辑前必须给出计划并获得确认：

- 可能修改超过 3 个文件或新增超过 1 个文件。
- 跨越一个以上逻辑层或运行时生命周期。
- 修改公共 API、Project Schema、稳定 ID、类型 ID、枚举值或默认值。
- 修改时间语义、帧推进条件、状态机转换或输出提交规则。
- 修改 Minecraft Hook、Mixin、世界推进或相机所有权。
- 引入、移除或升级依赖。
- 移动、重命名、删除文件或批量生成资源。
- 修改 RayPortal 与 Cycles 的集成边界。

计划必须说明：目标、预计文件、保持不动的区域、需保持的行为、稳定契约与风险、实际验证方法。

若实际工作超出已确认范围，立即停止并说明原因。不要把功能、重构、格式化、依赖升级和无关文档整理混在同一阶段。

## 5. 目标代码层级

代码按责任和依赖方向组织。下列名称可在架构确认后调整，但层级职责和依赖方向不可为局部便利而反转：

```text
dev.rayportal
├── RayPortalMod                 薄 Mod 入口与装配
├── core
│   ├── time                     精确时间、帧率、范围和快门
│   ├── camera                   相机变换、镜头、约束和值对象
│   ├── timeline                 Track/Clip/Keyframe、编译和求值
│   └── cinematic                Cut、Marker 和电影控制状态
├── application                  Project/Preview/Record/Render 会话编排
├── capture                      相机采样、重采样、简化和轨道生成
├── render
│   ├── api                      后端能力、请求、票据、进度和结果
│   └── vanilla                  Vanilla 图片输出适配
├── runtime.minecraft            Minecraft 相机、时间和世界适配
├── integration.cycles           可选 Cycles 公共 API 适配
├── persistence                  Codec、迁移、原子保存和 Job Manifest
├── editor                       命令、选择、视图模型和 UI
└── diagnostics                  结构化诊断与可观测性支持
```

不要提前创建空包、接口或抽象层来追求目录完整。只有当前阶段出现明确责任、调用者和验证边界时才新增类型。

## 6. 包依赖规则

以下依赖方向是稳定约束：

- `core.*` 只依赖 Java 标准库及经明确批准的纯数学基础库。
- `core.*` 不得导入 Minecraft、NeoForge、GUI、文件 IO、Cycles 或 native 类型。
- `core.time` 不依赖其他业务包。
- `core.camera` 可使用精确时间和值类型，但不拥有 Timeline、玩家实体或渲染后端。
- `core.timeline` 依赖核心值对象，通过只读上下文求值，不读取 Minecraft 全局状态。
- `render.api` 可引用不可变的核心输出值，但不得引用可变编辑模型、Widget、Minecraft Entity 或 Cycles 私有类型。
- `application` 编排核心能力和端口，不承载曲线算法、Minecraft Hook 或文件编码细节。
- `runtime.minecraft` 负责平台对象与核心 DTO 的双向转换，不解释 Project 文件格式。
- `persistence` 保存领域语义，不依赖活动线程、Session、Future、native handle 或 Minecraft 实例。
- `editor` 通过命令修改 Project，通过发布新 snapshot 影响预览；不得直接修改编译后缓存。
- `capture` 产生通用相机/轨道数据，不依赖输出渲染器实现。
- Cycles 类型和导入只能出现在 `integration.cycles` 或经批准的窄兼容边界内。

禁止通过全局 Service Locator、静态可变单例、反射字符串或通用 `Map<String, Object>` 绕过依赖规则。

Mod 入口只负责注册、能力发现和顶层装配。时间线求值、持久化、渲染状态机、相机算法和 UI 状态不得堆入入口类。

## 7. 四时钟与精确时间

Wall Clock、Timeline Clock、Simulation Clock、Sample/Shutter Clock 必须保持分离：

- Wall Clock 只用于超时、ETA、性能统计和日志。
- Timeline Clock 由 Project/Sequence 和显式播放、调度操作推进。
- Simulation Clock 只由选定的 `WorldStepPolicy` 推进。
- Sample/Shutter Clock 只存在于当前锁存帧及其子样本内。

禁止：

- 使用 `System.nanoTime()`、真实帧率或客户端卡顿推进项目时间。
- 用 `double time += 1.0 / fps` 作为规范帧时间。
- 用无单位的 `long`、`double` 同时表达帧号、tick 和秒。
- 将 Minecraft partial tick 当作项目时间真相。

帧时间必须由 Frame Index 和 Frame Rate 直接计算。精确值使用有理数或等价无损表示；浮点数只允许在曲线计算及 Minecraft/后端边界出现，并明确转换点、单位和舍入规则。

所有时间类型必须校验分母、符号、范围和溢出。边界统一采用明确的闭/开区间，不依赖调用者猜测最后一帧是否包含。

## 8. 领域模型、身份与不可变性

- Project 元素使用持久、稳定 ID；显示名称、数组下标、文件顺序和对象 hash 不得作为身份。
- 可变编辑 Project 与不可变 `CompiledTimelineSnapshot` 必须分离。
- Preview 和 Offline Render 只能读取已发布 snapshot。
- 活动离线帧锁存后，不得因编辑、资源刷新或 GUI 操作原地变化。
- Camera、Timeline、World、Settings、Job 和 Ticket revision 必须语义清晰，不能混用。
- 跨线程数据使用不可变 DTO；集合在构造时防御性复制或暴露只读视图。
- 值对象在构造边界校验不变量，不把非法状态延迟到渲染线程发现。
- 结果不能依赖 `HashMap`、文件遍历或注册顺序等不稳定迭代顺序；平局使用明确顺序和稳定 ID 解决。

顺序播放优化可以使用 snapshot 私有游标，但同一 snapshot、时间和只读上下文的随机 seek 必须得到相同结果。

## 9. 相机与时间线实现规则

- `CameraState` 是不可变领域值，不是 Minecraft Camera、Entity 或 Cycles Camera。
- 核心旋转使用规范化 Quaternion；Euler 角只作为 UI/导入导出表达。
- 坐标系、轴方向、角度单位、FOV 方向和矩阵约定必须在边界显式记录并测试。
- 物理镜头字段属于通用相机；后端特有采样、降噪和 Pass 设置不得污染它。
- 电影相机不得通过移动玩家、发送传送命令或永久改变玩家状态实现。
- Camera Cut 必须是显式时间线语义，不能通过连续曲线中的隐藏跳变模拟。
- 约束和 Modifier 的顺序必须固定；循环依赖在编译阶段失败。
- 时间线编译负责排序、索引、引用解析和曲线预计算；运行求值不得偷偷修复坏 Project。
- 纯求值路径不得执行文件 IO、网络请求、资源注册或日志洪泛。

只有性能分析证明存在瓶颈时才引入并行求值或复杂缓存；优化前先保持结果确定、可随机 seek、可测试。

## 10. Session、线程和生命周期

每个 Session 或资源必须明确：创建者、所有者线程、有效状态、允许转换、取消语义、恢复动作和销毁者。

- Minecraft client/render thread：UI、相机应用和客户端状态机驱动。
- Integrated server thread：世界 tick 与服务端状态。
- Backend worker：渲染、采样和降噪。
- Output IO worker：编码、临时文件写入和最终提交。
- Compile worker：仅在大型 Project 需要时执行 snapshot 编译。

硬性规则：

- 不在 client/render thread 或 integrated server thread 阻塞等待 Future、文件 IO 或离线渲染。
- 后台线程不得直接修改 Minecraft 对象、Editor 模型或活动 Project。
- 回调进入主线程前校验 Session generation、Job ID、Frame Index 和 Ticket。
- `close`、`cancel` 和宿主状态恢复在正常重复调用场景下必须幂等。
- 同一时刻只有一个 Session 拥有 Minecraft 主 Camera；切换必须显式仲裁。
- 每次进入特殊相机、暂停、冻结或输入接管状态，都必须有对称恢复路径。
- 首个底层错误必须保留；后台异常不得静默吞掉或只替换成“渲染失败”。

不要用一组松散布尔值表达复杂生命周期。存在三个以上相互约束状态时，优先使用显式状态机和合法转换表。

## 11. Minecraft 运行时边界

- Minecraft/NeoForge 版本相关代码集中在 `runtime.minecraft` 和薄启动装配层。
- Mixin 或底层 Hook 只应截取最窄的稳定语义点，并说明注入时机、前置条件、失败降级和目标版本证据。
- 不得用宽泛 Mixin 修改无关渲染路径，也不得把 Mixin 类型泄漏进核心 API。
- Camera 必须在 culling/extract 前应用；具体 Hook 未经运行验证前保持 Provisional。
- `DeltaTracker`、partial tick 和 GUI 刷新不得反向驱动 Timeline Clock。
- 世界准备必须由可诊断的 `WorldReadinessBarrier` 条件组成，禁止依靠固定 sleep 猜测区块或场景已准备。
- 进入、切换世界、断线、崩溃恢复、取消 Job 和关闭客户端都必须释放相机及世界控制权。
- 专用服务端与多人场景不在第一阶段确定性承诺内；不支持时明确拒绝或降级，不伪装为成功。

任何相机 Hook 或世界推进修改都必须经过 `runClient` 实际验证，单纯编译不能作为通过证据。

## 12. 离线逐帧状态机

Offline Render 必须通过有限、可观测、非阻塞状态机推进。

- 每个输出帧先生成不可变 `FramePlan`，再提交给 Backend。
- `FramePlan` 锁存 Timeline、Simulation、Camera、World、Settings revision 和 seed。
- Backend 返回唯一 `FrameTicket`；重试同一 `FramePlan` 使用新 Ticket 和 attempt。
- 等待 Backend 时不推进 Timeline、Simulation 或 Camera。
- 渐进预览可用不等于离线帧完成。
- 只有质量条件、Pass、降噪、编码、原子文件提交和 Job Manifest 更新全部完成后才能推进 Frame Index。
- 迟到、重复或已取消 Ticket 的回执必须丢弃并记录诊断。
- 每次客户端循环只执行有限工作，不使用忙等或长时间同步等待。
- 取消不删除已安全提交输出；未提交临时文件由其所有者清理。
- 重试、暂停、取消、失败和恢复必须有独立测试，不只覆盖成功路径。

状态转换语义属于稳定契约。调整转换或“完成”定义前，必须更新设计决定和合同测试。

## 13. Render Backend 与 Cycles 集成

Render Backend 负责渲染和输出，不拥有 Timeline Clock、世界推进权或 Project 编辑模型。

- Backend 请求和结果使用不可变、版本明确的 DTO。
- 能力通过 `BackendCapabilities` 协商；缺失能力必须禁用选项或明确报错，不能静默忽略。
- 后端特有设置按 Backend ID 与 Schema Version 隔离，并由适配器校验和迁移。
- Null、Vanilla 和 Cycles Backend 必须服从同一套 Frame/Ticket/Commit 合同测试。
- Backend 进度仅用于 UI 和诊断，不作为输出完成屏障。

Cycles 集成方向固定为：

```text
RayPortal integration.cycles -> Cycles public offline API
Cycles                       -X-> RayPortal
```

- RayPortal 未安装 Cycles 或 API 不兼容时必须仍能加载和使用通用功能。
- 不得导入 Cycles 私有实现、解析其内部状态或让 Cycles 读取 RayPortal Project。
- 可选适配器不得因类验证或入口静态初始化导致缺失 Cycles 时崩溃。
- 不使用脆弱反射字符串协议绕过公共 API；若平台机制确实要求反射，先通过独立 spike 和架构确认。
- Cycles 的可显示帧、generation 或 samples 只代表进度；最终完成仍受 RayPortal 输出提交屏障约束。

## 14. 持久化与文件安全

Project、Backend Settings 和 Job Manifest 是稳定持久化契约：

- 顶层格式必须有显式 format、Schema Version 和稳定 Project ID。
- 不序列化 Java 类全名作为类型身份；使用稳定类型 ID。
- 精确时间保存为无损整数分子/分母或等价表示。
- 不序列化线程、Future、Session、Minecraft 对象、native handle、缓存或编译游标。
- Schema 迁移按版本逐级执行，并为每一级提供 golden fixture。
- 读取未知较新版本时不得覆盖原文件。
- 自动迁移前保留可恢复副本，失败时保留原始错误和输入。
- 保存采用同目录临时文件、关闭/刷新、可读性校验和原子替换；不直接覆盖唯一副本。
- 输出路径解析后必须位于用户选择的输出根目录，拒绝路径穿越。
- 默认不覆盖不匹配文件；恢复任务必须校验 Job、revision、Backend 设置和现有输出。

稳定字段、枚举值、类型 ID 和 Schema Version 不得因“排序更整齐”而重编号。

## 15. Editor 与 Capture 边界

- Editor 使用 Command 修改 Project，并生成对应 Undo Entry。
- 连续拖动可合并为一个逻辑命令；编译缓存和运行 Session 不进入 Undo 栈。
- 选择、悬停、面板展开、临时拖动和播放状态属于 Editor Session，不自动持久化。
- Scrub 必须明确显示 camera-only、forward synchronized 或其他世界同步模式。
- UI 不直接调用 Cycles 私有 API，也不直接推进世界或修改 Backend worker 状态。
- Capture 分离原始样本、滤波/重采样、关键帧简化和最终轨道提交。
- 简化与平滑必须有位置、角度和镜头误差上限，不能只凭视觉感觉覆盖原始数据。
- 原始录制数据在最终提交前应可恢复；失败不得破坏已有 Project。

第一条实现主线优先打通精确时间、两点相机、snapshot、Vanilla 预览、Null Backend 和 Vanilla 输出；不要从完整编辑器或 Cycles 特化开始。

## 16. 代码质量与文件职责

文件大小是审计信号，不是机械指标：

- 超过 500 行的源文件必须审查责任、依赖、生命周期和测试边界。
- 超过 800 行且承担多项责任的源文件应拆分。
- 单一、稳定职责的表、Codec 或生成内容可保持较大，但必须说明来源和验证方式。
- 不为满足行数目标拆散稳定契约，也不把多个小文件误认为自然解耦。

编码规则：

- 一个类型和方法只承担一个可命名的责任。
- 名称包含单位和语义，例如 `timelineNanos`、`frameIndex`、`partialTick`，避免模糊的 `time`、`value`、`state`。
- 共享策略、Schema、类型 ID、超时和误差阈值集中定义；纯局部且显然的字面量可以保留。
- 避免布尔参数迷宫；当模式影响生命周期或契约时使用语义类型或枚举。
- 缺失值、失败和降级必须显式表达；不要用 `null` 同时表示未配置、不可用和失败。
- 不捕获宽泛异常后继续运行；在拥有恢复策略的边界转换为结构化错误。
- 日志包含 Session/Job/Frame/Ticket/revision 等必要上下文；高频进度日志必须节流。
- 注释解释不明显的不变量、所有权、兼容性和取舍，不复述代码。
- 不添加无调用者的抽象、通用工具包、框架或依赖。
- 不在功能修改中顺手格式化整文件、重命名无关类型或清理其他警告。

## 17. 稳定契约与架构变更

以下内容视为稳定契约：

- 四时钟关系、帧到时间映射和输出推进条件。
- Project/Sequence/Track/Clip/Keyframe 的稳定 ID 与 Schema。
- `CameraState`、`FramePlan`、`FrameRequest`、`FrameTicket` 和 Backend 能力语义。
- Session generation、revision、状态转换和取消/恢复语义。
- 输出命名、覆盖、原子提交和 Job 恢复规则。
- 资源命名空间、注册 ID、配置键、枚举值和持久化默认值。
- RayPortal/Cycles 的依赖方向和可选加载行为。

修改稳定契约前必须：

1. 找出所有生产者和消费者。
2. 说明兼容、迁移和拒绝行为。
3. 单独确认变更阶段。
4. 同时更新直接调用方与失败路径。
5. 增加或更新合同、迁移或集成测试。
6. 更新正式架构规范或新增架构决策记录。

不得用局部兼容分支长期维持两个隐含真相来源。

## 18. 测试组织与确定性

测试包应镜像生产责任，并按能力独立报告：

- `core.time`：约分、比较、溢出、长序列无漂移和 20 TPS 映射。
- `core.timeline`：区间边界、随机 seek、顺序游标一致性、曲线和依赖环。
- `core.camera`：Quaternion、坐标转换、镜头换算、Cut 和 Constraint 顺序。
- `application`：Session、状态机、revision、迟到 Ticket、重试、取消和恢复。
- `persistence`：round-trip、未知版本、逐级迁移、原子保存和 golden fixture。
- `render.api`：所有 Backend 共用的能力与 Frame/Ticket/Commit 合同。
- `runtime.minecraft`：虚拟相机、culling 时机、世界冻结/单步和宿主恢复。
- `integration.cycles`：缺失、版本不兼容、锁存、质量完成和输出提交。

纯核心测试不得启动 Minecraft。状态机测试使用 Fake/Null Backend 和可控时钟，不用真实一分钟 sleep 制造慢帧。随机测试必须记录 seed，失败后可重放。

修复生命周期或持久化问题前，优先添加能证明旧行为的 characterization/contract 测试。不得通过放宽断言、增加任意 sleep 或忽略异常让测试变绿。

## 19. 验证门槛

执行验证前先从当前 Gradle 配置发现可用任务，不从旧记录猜测任务名。

最低验证要求：

- 仅文档：检查链接、路径、Markdown 结构、空白和实际 diff。
- 纯核心 Java：编译、相关单元测试、边界和确定性测试。
- 状态机/Application：相关单元测试和 Fake/Null Backend 合同测试。
- Persistence：round-trip、golden migration、异常中断和旧格式读取。
- Minecraft Runtime/Hook：编译、相关 GameTest（若存在）和 `runClient` 手工验证。
- 资源/元数据：处理资源、打包并检查产物内路径和 Mod 加载。
- Backend API：所有 Backend 合同测试及缺失能力路径。
- Cycles 集成：RayPortal 单独加载、兼容 Cycles 加载、API 不兼容降级和至少一帧真实输出。

先运行聚焦验证，再运行较宽门槛。编译成功不等于 Mod 能启动，启动成功不等于相机 Hook 正确，出现预览图不等于离线输出已安全提交。

结果只报告为 `PASS`、`FAIL`、`KNOWN RED`、`BLOCKED` 或 `NOT RUN`。不得把未执行验证写成通过；所有仍需手工执行的步骤必须明确列出。

## 20. 资源、生成内容与依赖

- `build/`、`.gradle/`、运行目录、缓存和临时输出不是产品源码。
- `src/generated/` 下内容视为生成结果；先找到并修改权威输入，不直接手改生成文件。
- 数据生成只在任务明确需要时运行；运行后检查是否出现意外批量变化。
- 第三方源码、旧 Mod 反编译结果和 SDK 不得混入正常源码树，除非用户明确批准 vendoring 并核对许可证。
- 新依赖必须解决已证明的问题，并说明许可证、运行端、可选性、版本约束、打包影响和无依赖降级。
- 不升级 Minecraft、NeoForge、Java、Gradle 或插件版本作为其他任务的附带工作。

## 21. Git 与提交纪律

除非用户明确要求，不得暂存、提交、amend、push、切换分支、清理文件或重写历史。

获得提交授权后：

- 先检查实际 diff，再按精确路径或 hunk 暂存。
- 一个提交只包含一个可独立验证的责任、契约或阶段。
- 不混入用户或其他任务的工作。
- 不把只有接口、UI 或占位实现的功能声明为完成。
- 提交信息遵循 [Git 提交信息规范](docs/commit-conventions.md)，并使用仓库根目录 `.gitmessage` 作为语义模板。
- 所有标题使用 `<type>(<scope>): <imperative summary>`，包括 `revert`；Revert 正文使用 `Reverts: <full hash>` 标识目标。
- Level S 仅用于无语义的文档、拼写、注释或格式变更，可只保留标题。
- Level M 是其他普通提交的默认级别，不按 type 枚举例外，必须至少记录 `Why`、`Changes` 与 `Validation`。
- Level H 用于稳定契约、生命周期、持久化、线程、Minecraft Hook、Backend、画面、性能、输出安全或兼容性变化，同时记录契约、风险、手工验证和已知限制。
- 验证项只使用 `PASS`、`FAIL`、`KNOWN RED`、`BLOCKED` 或 `NOT RUN`，并记录仓库相对、可复现且已脱敏的实际命令/流程与证据；不得把未执行验证写成通过。
- 提交说明和交接必须一致，不得在 commit message 中扩大已验证范围。
- 提交后重新检查作者、正文、文件清单和工作树。

禁止使用破坏性 Git 操作来制造干净工作树。

## 22. 文档纪律

- README 记录用户可见能力、需求、限制和入口，不充当 Schema 或状态机账本。
- `docs/architecture.md` 记录规范性方向、Accepted/Provisional/Deferred 决策和阶段门槛。
- 调查文档记录来源、历史经验和风险，不自动成为实现命令。
- 当前质量状态、实测结果和已知红项应放在专门的当前基线或阶段报告中，并标明日期或提交。
- 稳定契约变化导致文档失真时，在同一阶段更新权威文档。
- 历史记录可以保留旧决定，但必须明确标记为历史，不得与当前事实混用。

## 23. 强制停止条件

出现以下任一情况时停止并报告：

- 目标文件被其他写者占用或存在无法安全拆分的重叠修改。
- 实现需要未确认的稳定契约或架构方向变化。
- 工作跨出已确认文件、层级、依赖或生命周期范围。
- 核心层必须导入 Minecraft、NeoForge 或 Cycles 才能继续。
- 生成文件、Schema 或资源的权威来源不明确。
- Mixin/Hook 目标和生命周期无法用当前版本源码确认。
- 验证被无关错误阻塞，无法判断本次变化是否正确。
- 工具产生意外批量文件、资源、格式或行尾变化。
- 实际运行证据否定了当前根因或设计假设。
- 取消、失败或关闭路径无法可靠恢复玩家、相机或世界状态。

报告必须包含已确认事实、准确阻塞点、尚未执行的工作、较小安全替代方案和需要用户决定的事项。

## 24. 完成定义

任务只有同时满足以下条件才算完成：

1. 请求的行为或调查目标实际完成，而不是只有占位代码。
2. 代码位于正确层级，依赖方向未反转。
3. 时间、身份、revision、线程和资源所有权保持明确。
4. 稳定契约及全部直接消费者一致。
5. 成功、失败、取消和恢复路径按风险得到验证。
6. 实际 diff 不包含无关内容或他人修改。
7. 生成物、临时文件和运行输出均已说明并妥善处理。
8. 文档反映当前事实，测试结果和未验证项如实报告。
9. 仍需用户执行的手工运行验证被明确列出。

优先完成一条小而完整、可测试的纵向能力，不留下隐式耦合、模糊所有权或无法恢复的生命周期。
