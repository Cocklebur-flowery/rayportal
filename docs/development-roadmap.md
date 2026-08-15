# RayPortal 精密开发路线图

> 路线图版本：0.1
>
> 状态：规范性实施计划
>
> 起始基线：首次提交 `8647ef8`
>
> 适用对象：人工开发者与按单工作包执行的编码模型
>
> 最后更新：2026-08-16

本文把 [正式架构规范](architecture.md) 中的 A–G 总体阶段拆解为可以独立计划、实现、验证和提交的工作包。它定义实施顺序和阶段门槛，不替代架构规范，不自动把 Provisional 决策升级为 Accepted，也不代表某项工作已经完成。

RayPortal 的长期目标不是复刻 Aperture、Minema 或 BBS，而是在 Minecraft 中建立一套能与 Cycles Renderer 深度协作的严肃电影制作系统：精确时间线、可编辑相机、可靠录制、确定性世界推进、长时间逐帧渲染、生产级输出，以及最终面向材质、灯光、World 和 OSL 参数的通用动画系统。

## 1. 路线图使用规则

### 1.1 一次只执行一个工作包

工作包 ID 使用 `Pxx-Wyy`。任何编码任务必须指定一个且仅一个当前工作包，例如 `P01-W02`。

执行者必须：

1. 完整读取仓库根目录的 `AGENTS.md`。
2. 读取本路线图中当前工作包、所在阶段和直接依赖工作包。
3. 检查当前源码、测试、配置、文档和 `git status`。
4. 验证前置工作包的产物真实存在且测试仍通过。
5. 在非小型修改前提交文件范围、稳定契约、风险和验证计划并等待确认。
6. 只实现当前工作包，不顺手开始后续工作包。
7. 检查实际 diff，报告自动验证、手工验证和未执行项。
8. 只有用户明确授权时才暂存或提交。

路线图中的“建议提交”只是边界建议，不构成 Git 授权。

### 1.2 不允许用占位实现跨越门槛

以下情况不能标记工作包完成：

- 只有接口、空类、固定返回值或未接线 UI。
- 测试只证明对象能构造，没有证明核心不变量。
- 通过 sleep、提高超时或忽略异常掩盖竞态。
- `runClient` 能启动，但目标生命周期没有实际操作。
- 后端产生预览图，但输出提交屏障没有完成。
- Cycles 存在时成功，但移除 Cycles 后 RayPortal 无法加载。
- 文档宣称支持，而代码只有实验分支或本机特例。

### 1.3 工作包完成记录

每个完成工作包应在交接中记录：

```text
Work package: Pxx-Wyy
Result: PASS | FAIL | KNOWN RED | BLOCKED
Commit: <hash or NOT COMMITTED>
Files changed: <exact paths>
Automated validation: <commands and results>
Manual validation: <steps and results>
Stable contracts affected: <none or exact contracts>
Known limitations: <explicit list>
Next eligible package: <one or more IDs>
```

不要在本路线图中维护易失真的完成勾选。当前状态以源码、测试、Git 历史和独立阶段交接为准。

## 2. 全局架构护栏

所有阶段都必须维持以下 Accepted 不变量：

1. Wall、Timeline、Simulation、Sample/Shutter 四种时钟分离。
2. 输出帧时间从 Frame Index 与 Frame Rate 直接计算，不累加浮点帧间隔。
3. 活动帧使用不可变 `FramePlan`；等待渲染时不重新求值。
4. 文件安全提交并更新 Job Manifest 后才能推进下一帧。
5. `core.*` 不依赖 Minecraft、NeoForge、Cycles、GUI 或文件 IO。
6. 编辑 Project 与运行 snapshot 分离，跨线程只传不可变 DTO。
7. 电影相机不通过移动玩家实现。
8. 离线等待不阻塞 Minecraft 客户端线程、渲染线程或集成服务端线程。
9. Project、Sequence、Track、Clip、Keyframe、Job 和 Ticket 使用稳定身份。
10. Render Backend 可选且能力驱动，不拥有 Timeline 或世界推进权。
11. RayPortal 可以依赖 Cycles 的公共离线 API，Cycles 不依赖 RayPortal。
12. 失败、取消、切换世界和关闭客户端都必须恢复宿主相机、输入和世界状态。

任何工作包若需要违反其中一项，必须停止并先进行架构变更流程。

## 3. 决策门

以下仍是 Provisional 的实现细节。指定工作包必须先用源码证据、最小 spike 和测试把它们转化为明确决定：

| 决策 ID | 内容 | 负责工作包 | 未决前禁止事项 |
| --- | --- | --- | --- |
| D01 | `TimelineTime` 的 Java 表示与溢出策略 | P01-W01 | 编写时间线、序列化时间 |
| D02 | 核心向量/Quaternion 数学表示 | P03-W01 | 让 JOML/Minecraft 类型进入核心 API |
| D03 | Project v1 JSON Codec 与文件布局 | P05-W01 | 发布可持久化 Project |
| D04 | Minecraft 相机 Hook：虚拟实体或窄 Mixin | P07-W01 | 大范围注入渲染管线 |
| D05 | 可选 Backend/Cycles 服务发现与版本协商 | P09-W01、P12-W01 | 反射字符串或硬链接可选 Mod |
| D06 | `WorldReadinessBarrier` 的实际信号 | P11-W02 | 用固定 sleep 代替世界准备 |
| D07 | 通用 Property ID、类型和绑定规则 | P14-W01 | 在核心模型中加入 OSL 专用字段 |
| D08 | 快门采样责任与 Temporal Parameter 表达 | P13-W03、P14-W05 | 用 Wall Clock 驱动运动模糊或 OSL time |

每个决定至少记录：背景、当前版本源码证据、候选方案、选择、拒绝方案、兼容性、测试和回退方式。

## 4. 发布阶梯

| 里程碑 | 完成阶段 | 用户可见能力 |
| --- | --- | --- |
| M0 Core Green | P00–P04 | 精确时间和纯 Java 相机时间线可确定求值 |
| M1 Camera Preview | P05–P07 | 可保存项目并在 Minecraft 中预览、Scrub、恢复相机 |
| M2 Camera Recording | P08 | 可录制、简化、编辑并重放通用相机运动 |
| M3 Offline Vanilla | P09–P10 | 可用 Null/Vanilla Backend 非阻塞输出图片序列 |
| M4 Deterministic Singleplayer | P11 | 集成服务端可前向单步并报告确定性边界 |
| M5 Cycles Production Beta | P12–P13 | Cycles 长帧、EXR/AOV、色彩与快门工作流形成闭环 |
| M6 Animated OSL Workflow | P14 | 时间线可驱动通用场景属性与 OSL Socket |
| M7 Production Release | P15 | 长任务恢复、兼容矩阵、性能和发布材料达到生产门槛 |

里程碑不使用日历承诺。只有退出门槛全部通过后才进入下一里程碑。

## 5. 阶段依赖图

```text
P00 工程基线
  → P01 精确时间
  → P02 Project 身份与领域骨架
  → P03 相机数学与镜头
  → P04 曲线、时间线编译与求值
  → P05 持久化
  → P06 Application Session 与编辑命令
  → P07 Minecraft 相机预览
  → P08 相机动作录制
  → P09 通用离线调度与 Null Backend
  → P10 Vanilla 图片序列
  → P11 集成服务端世界单步
  → P12 Cycles 公共 API 与可选适配
  → P13 生产渲染能力
  → P14 通用属性动画与 OSL
  → P15 生产硬化与发布
```

P08 和 P09 在 P07 后可以分别立项，但默认保持串行，先完成录制再进入离线调度。P12 受外部 Cycles/Vulkan 能力门约束；该门关闭时，可以继续强化 P00–P11，但不能伪造 Cycles 通过结果。

## 6. P00：工程与验证基线

### 阶段目标

建立所有后续纯 Java、Minecraft 和 Backend 测试共同使用的最小验证基础。不得在本阶段实现时间线或相机功能。

### P00-W01：测试框架接线

前置：首次提交存在，工作树无不明修改。

产物：

- 在当前 Gradle Java/NeoForge 配置中加入一套明确的单元测试框架。
- 建立 `src/test/java/dev/rayportal` 测试根包。
- 添加一个只验证测试任务确实执行的最小测试。
- 确认测试依赖不进入运行时 Mod 产物。

验证：发现实际 Gradle 任务；运行聚焦测试和完整测试任务；检查打包依赖。不得只用 IDE 内测试证明接线成功。

退出：命令行能稳定运行至少一个测试，失败测试能让 Gradle 返回非零状态。

建议提交：`test: establish RayPortal unit test baseline`。

### P00-W02：包边界与测试目录规范

前置：P00-W01。

产物：

- 测试包镜像生产包责任。
- 建立测试 fixture、golden data、Minecraft GameTest 和手工测试证据的目录约定。
- 增加轻量边界检查，至少能发现 `core.*` 对 Minecraft、NeoForge、Cycles、GUI 和文件 IO 的非法导入。

约束：不为边界检查引入复杂静态分析框架；先使用当前构建可验证的最小机制。

退出：故意加入一个非法核心导入时检查会失败，撤销实验后恢复通过。实验修改不得留在工作树。

### P00-W03：启动与质量基线

前置：P00-W01。

产物：

- 记录当前 Java、Minecraft、NeoForge 和 Gradle 实际来源，而不是复制旧对话版本。
- 验证 `build`、Mod 打包和 `runClient` 启动路径。
- 建立当前质量基线文档，区分 PASS、KNOWN RED、BLOCKED 和 NOT RUN。

手工验证：启动客户端、进入标题界面、确认 RayPortal 正常加载、退出无异常。若现有显卡/渲染栈阻塞，只记录准确阻塞，不修改功能绕过。

阶段退出门：测试任务、构建和当前可执行的启动 smoke 都有可重现命令与结果。

## 7. P01：精确时间核心

### 阶段目标

建立不受 Minecraft 帧率和现实耗时影响的规范时间系统，为全部时间线、录制和离线输出提供唯一基础。

### P01-W01：D01 精确时间表示决定

前置：P00 完成。

调查并验证：

- 有理数规范化、符号、零值和比较语义。
- `long` 乘法溢出以及 23.976、24、25、29.97、30、50、59.94、60 FPS 的长序列范围。
- 使用 GCD 预约分和 JDK `BigInteger` 中间计算的成本。
- 序列化时保存分子/分母的无损方式。

推荐候选：运行时值保存规范化 `long numerator / positive long denominator`，算术先约分并使用可证明安全的中间计算；无法精确容纳时明确失败，不静默转 `double`。

产物：D01 决策记录与边界测试计划。本工作包不同时实现完整时间线。

### P01-W02：FrameRate 与 FrameIndex

前置：P01-W01 已接受。

产物：

- 正分子/正分母、自动约分的 `FrameRate`。
- 非负 `long` 的 `FrameIndex`。
- 值相等、稳定字符串表达、输入校验和溢出错误。
- 测试常用整数帧率和 NTSC 有理帧率。

禁止：把 FPS 保存为 `double`；让负 Frame Index 偷偷表示 preroll。

退出：同值不同分数构造得到相等 FrameRate；非法分母和越界 Frame Index 明确失败。

### P01-W03：TimelineTime、Duration 与 Range

前置：P01-W02。

产物：

- 可表示负 preroll 的 `TimelineTime`。
- 非负 `TimelineDuration`。
- 半开 `TimeRange[startInclusive, endExclusive)`。
- 加减、比较、比例缩放、范围包含和交集操作。

测试：零、负 preroll、相邻范围、空范围、超大值、约分和溢出；不得使用浮点容差判断精确时间相等。

### P01-W04：帧映射、20 TPS 与快门

前置：P01-W03。

产物：

- `frameTime = sequenceStart + frameIndex × fps.denominator / fps.numerator`。
- TimelineTime 到完整 simulation tick 与 partial tick 的明确映射。
- 相对帧中心的 `ShutterInterval`。
- 固定 seed 的长序列随机/属性测试。

验证：至少覆盖连续百万帧无累计漂移、NTSC 帧率、多个输出帧共享同一游戏 tick、tick 边界和负 preroll。

阶段退出门：`core.time` 不导入平台类型；所有规范映射由直接计算产生；M0 时间部分全绿。

## 8. P02：Project 身份、Revision 与领域骨架

### 阶段目标

建立最小可验证的 Project/Sequence 语义，但暂不加入 GUI、文件 IO 和 Minecraft 对象。

### P02-W01：稳定 ID 与 Revision 类型

前置：P01。

产物：

- Project、Sequence、Track、Clip、Keyframe 的类型化稳定 ID。
- Project、Timeline、Camera、World、Settings revision 的独立类型。
- 明确 ID 的生成、解析、相等和显示规则。

约束：不得用名称、数组下标、对象 hash 或 HashMap 顺序作为身份。Revision 是变更身份，不是时间。

退出：不同 ID 类型不能被意外混用；稳定文本往返通过。

### P02-W02：最小 Project 与 Sequence

前置：P02-W01。

产物：

- `CinematicProject` 的项目身份、名称、根设置和 Sequence 集合。
- `Sequence` 的精确起点、FrameRate、输出范围、Track 顺序和默认 Camera 引用位置。
- 明确的创建、复制和 revision 增长语义。

禁止：在领域对象中存放 Minecraft Level、Entity、Widget、Future 或文件句柄。

### P02-W03：领域校验与内容摘要

前置：P02-W02。

产物：

- 结构化 `ValidationIssue`/`ValidationReport`，区分 warning 与 fatal。
- 重复 ID、悬空引用、非法范围和无效 FrameRate 校验。
- 与容器迭代顺序无关的规范内容摘要策略。

测试：交换无语义集合的输入顺序不改变摘要；有语义 Track 顺序变化必须改变摘要。

阶段退出门：可以在纯 Java 测试中创建、校验和比较最小 Project；无平台或持久化依赖。

## 9. P03：相机数学、坐标与物理镜头

### 阶段目标

建立后端无关、Minecraft 无关、不可变的相机状态。

### P03-W01：D02 数学表示决定

前置：P01、P02-W01。

调查：自有不可变 `Vec3d/Quaterniond` 与纯数学依赖的维护、可变性和边界成本。不得直接使用 Minecraft `Vec3` 或平台 Camera 类型。

推荐候选：核心 API 暴露 RayPortal 自有不可变值类型；平台和后端在适配层转换。Quaternion 构造后规范化，并为近零长度提供明确错误。

产物：D02 决策、坐标约定和误差容限。坐标文档必须定义 handedness、前/上轴、角度单位、Quaternion 分量顺序和组合顺序。

### P03-W02：Transform 与 Quaternion 运算

前置：P03-W01。

产物：不可变位置、Quaternion、Transform；组合、逆、旋转向量、最短路径 slerp 和有限值校验。

测试：单位旋转、180° 边界、q 与 -q 等价、连续插值、组合顺序和非有限输入。

### P03-W03：物理镜头模型

前置：P03-W02。

产物：焦距、传感器、FOV 方向、焦平面、f-stop、光圈叶片/比例/旋转、Lens Shift 和裁剪面值对象。

约束：保存物理字段作为规范数据；FOV 与焦距转换在明确传感器和 fit 模式下进行。Cycles 特有采样设置不得进入镜头模型。

### P03-W04：不可变 CameraState 与坐标合同

前置：P03-W02、P03-W03。

产物：带稳定 Camera ID、Transform、Lens 和 revision 的不可变 `CameraState`；为 Minecraft、Vanilla 和未来 Cycles 转换定义合同测试样例。

阶段退出门：纯 Java 已知相机 fixture 在往返和转换容差内稳定；核心没有 JOML/Minecraft/Cycles 泄漏。

## 10. P04：曲线、Track、编译与确定性求值

### 阶段目标

从编辑友好的关键帧数据编译出不可变、可随机 seek 的相机时间线。

### P04-W01：标量曲线基础

前置：P01。

产物：稳定 Keyframe ID、精确时间、标量值、插值类型和切线数据；至少支持 Constant、Linear 和一个可编辑平滑插值。

测试：端点、相邻段、重复时间拒绝策略、切线连续性、段外求值和非有限值。

不要一次实现 Blender 全部 Handle 类型；先冻结最小可验证曲线语义。

### P04-W02：向量、Quaternion 与镜头曲线

前置：P03、P04-W01。

产物：位置曲线、Quaternion 最短路径插值和镜头字段曲线。Euler 输入必须在编辑边界转换，不能成为运行 snapshot 的旋转真相。

退出：相同输入在随机 seek 和顺序播放中得到相同 CameraState。

### P04-W03：Camera Track、Clip 与 Cut

前置：P02、P04-W02。

产物：最小 Camera Track/Clip、source offset、正向速度、活动区间和显式 Camera Cut。

本工作包必须单独决定同 Track 重叠规则；若尚无可靠 UX，第一版拒绝重叠并给出结构化诊断，不静默选择某个 Clip。

### P04-W04：CompiledTimelineSnapshot

前置：P04-W03。

产物：

- 编辑模型校验、排序、引用解析和曲线段预计算。
- 不可变 snapshot、timeline revision 与内容摘要。
- 稳定区间索引和约束循环检测位置。
- 发布后与可变 Project 无共享可写集合。

### P04-W05：Evaluator 与差分测试

前置：P04-W04。

产物：纯函数式随机 seek 求值器，以及可选 snapshot 私有顺序游标。

验证：随机生成 Sequence，比较随机 seek 与顺序游标；相同 snapshot/time/context 必须逐字段一致或在已定义数学容差内一致。

阶段退出门：创建两点相机后可在任意精确时间求值；修改原 Project 不影响已发布 snapshot；M0 完成。

## 11. P05：Project 持久化与迁移基础

### 阶段目标

让最小 Project 可安全保存、读取和迁移，同时保持领域模型不依赖 Codec。

### P05-W01：D03 v1 Schema 与 Codec 决定

前置：P02–P04 稳定。

产物：

- `format`、`schemaVersion`、Project ID 和 feature flags 的 v1 顶层结构。
- 精确时间、稳定 ID、Quaternion、镜头和曲线的规范表示。
- JSON 库/实现选择及依赖、许可证、打包影响记录。
- 未知字段和未知较新版本的读取策略。

禁止：序列化 Java 类名、对象 hash、缓存、Session 或平台对象。

### P05-W02：Project Codec 与 round-trip

前置：P05-W01。

产物：领域对象与独立 persistence DTO/Codec 的双向转换；规范输出顺序；结构化错误路径。

验证：语义 round-trip、格式稳定性、损坏输入、重复 ID、未知类型、非法时间和非有限数值。

### P05-W03：原子保存与备份

前置：P05-W02。

产物：同目录临时文件、flush/close、重新读取校验、原子替换及失败恢复；目标路径和备份所有权明确。

测试：编码失败、临时文件失败、目标已存在、替换失败和取消；原始有效文件不得丢失。

### P05-W04：迁移与 golden fixture

前置：P05-W02。

产物：版本逐级迁移框架、至少一个模拟旧版本 fixture、较新未知版本拒绝覆盖、golden round-trip 测试。

阶段退出门：最小两点相机 Project 可保存、重载并得到相同求值结果；任何失败不破坏唯一副本。

## 12. P06：Application Session、命令与 Undo

### 阶段目标

建立编辑模型、运行 snapshot 和 UI 之间的编排层，但仍不依赖具体 Minecraft 相机 Hook。

### P06-W01：ProjectSession 与 snapshot 发布

前置：P04、P05。

产物：ProjectSession 拥有活动 Project、revision、校验、编译和最近有效 snapshot；编译失败不替换最近有效 snapshot。

约束：发布发生在明确安全边界；离线 Job 将来可以固定某个 snapshot，不跟随编辑变化。

### P06-W02：Editor Command 与 Undo/Redo

前置：P06-W01。

产物：命令接口、一次逻辑修改、Undo Entry、Redo、连续拖动合并和 revision 更新。选择与面板状态不进入 Project。

测试：创建/移动/删除关键帧，跨 Undo/Redo 后 Project、snapshot 和 revision 一致；失败命令不留下半修改状态。

### P06-W03：PreviewSession 与播放控制

前置：P06-W01。

产物：显式播放头、播放/暂停/停止、Timeline Clock 推进策略、scrub 和 snapshot 切换；使用可控 Wall Clock 只计算预览推进量，不成为项目时间真相。

退出：无 Minecraft 环境即可测试播放、暂停、seek、Project 编辑后安全切换 snapshot。

阶段退出门：Application 层可以驱动纯 Java 相机预览状态；Editor 不直接修改编译缓存。

## 13. P07：Minecraft 虚拟相机与最小预览

### 阶段目标

在 Minecraft 26.2 当前实现中显示 RayPortal CameraState，且不移动玩家并能可靠恢复宿主状态。

### P07-W01：D04 相机 Hook spike

前置：P03、P04、P06。

只读检查当前 Minecraft/NeoForge 映射与渲染调用链，定位：主 Camera 设置、culling/extract、视图矩阵、FOV、partial tick 和 Camera Entity 生命周期。

分别验证最小虚拟 Camera/Entity 与窄 Mixin 的可行性。Spike 必须回答注入时机、冲突面、第三方兼容、切换世界行为和失败回退。

产物：D04 决策和最小测试证据。实验代码不能以未接线状态留在生产路径。

### P07-W02：Camera Ownership 与恢复

前置：P07-W01。

产物：Minecraft Camera owner/lease、Session generation、进入/退出、重复 close、切换维度、断线和客户端关闭恢复路径。

测试：Fake 生命周期测试；迟到回调不能重新接管已释放 Camera。

### P07-W03：CameraState 应用与时间桥

前置：P07-W02。

产物：核心坐标到 Minecraft Camera 的适配；在 culling/extract 前应用位置、Quaternion、FOV 和裁剪语义；预览 Delta 仅驱动 PreviewSession。

禁止：传送玩家、发送移动包、在 Hook 内求值可变 Project、阻塞渲染线程。

### P07-W04：最小预览控制与诊断

前置：P07-W03。

产物：最小进入/退出、播放/暂停、逐帧和 scrub 控制；显示 TimelineTime、Frame Index、snapshot revision、Camera ID 和同步模式。

不要求完整 Timeline UI；临时开发界面必须仍通过 Application Command/Session 边界。

### P07-W05：runClient 生命周期矩阵

前置：P07-W04。

实测：

- 单人世界进入和退出电影相机。
- 播放、暂停、随机 scrub、窗口失焦和分辨率变化。
- 第一/第三人称切换策略。
- 切换维度、退出世界、返回标题、重新进入世界。
- 预览中抛出受控错误、强制取消和关闭客户端。
- 玩家位置、朝向、输入和原 Camera 均被恢复。

阶段退出门：两点相机可按任意 TimelineTime 正确显示；玩家服务端状态不变；M1 完成。

## 14. P08：通用相机动作录制

### 阶段目标

录制任何 CameraState 来源，将原始样本安全转换为可编辑、可复现的时间线 Clip。

### P08-W01：Capture Source 与 Raw Sample

前置：P03、P06、P07。

产物：通用 `CameraSampleSource`、带精确 TimelineTime 的 Raw Camera Sample、来源 ID、采样配置和 Session generation。

来源可包括玩家视角、自由相机和已求值 Camera；不得把 Minecraft Entity 写入样本格式。

### P08-W02：RecordingSession 与原始 sidecar

前置：P08-W01、P05 原子文件能力。

产物：开始/暂停/停止/取消状态机；有界内存缓冲；可恢复原始 sidecar；后台写入错误传播；取消不破坏现有 Project。

测试：长录制、写入失败、重复停止、世界切换和迟到 sample。

### P08-W03：重采样与关键帧简化

前置：P08-W02。

产物：目标采样率重采样、位置误差、Quaternion 角误差和镜头误差约束的确定性简化。

验证：固定输入与配置逐次产生相同 Keyframe；简化后任意测试点误差不超过阈值；记录 seed 和容差。

### P08-W04：平滑、预览与提交命令

前置：P08-W03。

产物：可选、非破坏性平滑；原始/处理后对比；通过单个 Editor Command 把结果提交为 Clip；一次 Undo 完整撤销。

禁止：默认覆盖原始录制；把视觉平滑当作无误差验证。

### P08-W05：runClient 录制闭环

前置：P08-W04。

实测：录制玩家视角、停止、简化、生成 Clip、重放、Undo/Redo、保存/重载后重放；比较路径和镜头误差。

阶段退出门：录制输入可恢复、输出可编辑且确定；M2 完成。

## 15. P09：Render API、离线状态机与 Null Backend

### 阶段目标

不依赖 Cycles 或 Minecraft 图片读取，先证明长时间单帧不会阻塞、不提前推进且可取消恢复。

### P09-W01：D05 通用 Backend API 与服务发现

前置：P04、P06。

产物：Backend ID/API Version、Descriptor、Capabilities、不可变 FrameRequest、Progress、Result、Error 和生命周期接口。

决定内建 Backend 与可选 Mod Backend 的注册/发现方式。请求不得包含 Timeline 编辑对象、Widget、Minecraft Entity 或 Cycles 私有类型。

### P09-W02：RenderJob、FramePlan 与 FrameTicket

前置：P09-W01。

产物：固定 snapshot/revision 的 RenderJob；直接计算的帧范围；锁存 Camera/Cinematic/World/Settings/seed 的 FramePlan；唯一 Ticket 与 attempt。

测试：活动 Job 不跟随 Project 编辑；重试复用 FramePlan 但产生新 Ticket。

### P09-W03：OfflineRenderSession 状态机

前置：P09-W02。

产物：VALIDATING、PREPARING、世界准备、求值、锁存、提交、渲染、输出提交、推进、暂停、取消、重试和失败的显式转换。

验证：所有合法与非法转换；迟到/重复 Ticket；Session generation 失效；每次 poll 有界；不使用真实 sleep。

### P09-W04：Null/Fake Backend 合同

前置：P09-W03。

产物：可控进度、虚拟一分钟帧、延迟输出提交、失败、超时、取消、设备重置和迟到回执模拟器。

退出：虚拟一分钟内 Timeline/Simulation/Camera revision 不变化，UI/状态机可继续 poll，提交完成后只推进一次。

### P09-W05：Job Manifest 与恢复

前置：P05、P09-W03。

产物：Job 配置摘要、Project/Timeline revision、Backend 版本、逐帧 attempt/状态/输出和最后安全帧；独立原子提交。

测试：进程在临时写入、文件提交后、Manifest 提交前和推进前中断的恢复矩阵。

### P09-W06：最小 Render Queue 与诊断

前置：P09-W04、P09-W05。

产物：创建、验证、开始、暂停、取消和恢复 Job 的最小入口；显示状态、Frame/Ticket、revision、Backend 阶段、耗时和最近错误。

阶段退出门：Null Backend 合同全绿；无任何平台 Backend 也可完整测试状态机。

## 16. P10：Vanilla 图片序列 Backend

### 阶段目标

用 Minecraft 自身渲染结果打通第一条真实文件输出链，证明 RayPortal 不依赖 Cycles。

### P10-W01：Framebuffer 捕获 spike

前置：P07、P09。

检查当前 Minecraft 26.2 渲染目标、截图路径、颜色格式、线程限制和 GUI/Overlay 排除方式。确定读取时机、像素所有权、垂直翻转、色彩空间和尺寸变化策略。

产物：最小一次捕获证据和明确 API 决定；实验不能绕过 FrameTicket。

### P10-W02：VanillaImageBackend

前置：P10-W01。

产物：能力描述、Job 生命周期、FrameRequest 接受、渲染线程捕获与 Output IO worker 的不可变像素 lease。

约束：渲染线程不执行 PNG 编码或磁盘写入；lease 具有明确 owner、generation 和 close。

### P10-W03：输出路径、编码与原子提交

前置：P10-W02、P09-W05。

产物：安全输出根、固定宽度帧号、临时文件、PNG 编码、原子提交、文件元数据和 Manifest 更新。

测试：路径穿越、已有文件、磁盘写入失败、编码失败、取消和分辨率变化。

### P10-W04：Vanilla 离线闭环

前置：P10-W03。

实测：静态世界、两点相机、至少两个不同 FPS 和连续帧范围；验证文件数量、帧号、分辨率、相机时间和取消恢复。

阶段退出门：图片序列连续且输出提交前不推进；客户端等待 IO 时保持响应；M3 完成。

## 17. P11：集成服务端世界冻结与前向单步

### 阶段目标

把 Simulation Clock 从普通实时 tick 中分离，在单人集成服务端内实现可诊断的前向推进。

### P11-W01：WorldStepPolicy 与安全边界

前置：P01-W04、P09、P10。

产物：REALTIME、CAMERA_ONLY_FREEZE、INTEGRATED_SERVER_STEP 等明确策略、能力校验和多人/专服拒绝路径。

UI 必须显示 Camera-only 不等于世界同步；向后 scrub 不得伪装为世界倒放。

### P11-W02：集成服务端 freeze/step spike 与 D06

前置：P11-W01。

检查当前客户端—集成服务端 tick 调用、暂停语义、任务队列、区块加载和网络回环。实现最小前向单 tick 证据。

确定 `WorldReadinessBarrier` 的可观测条件；固定 sleep 不能成为条件。

### P11-W03：World Step Controller

前置：P11-W02。

产物：目标 full tick 计算、服务端线程指令/回执、禁止倒退、Session generation、超时/取消和宿主 tick 恢复。

约束：客户端线程不直接修改服务端世界；多输出帧共享 full tick 时不重复推进。

### P11-W04：Readiness Barrier 与客户端子系统

前置：P11-W03。

产物：区块/渲染区段/场景 revision 等已确认条件的组合屏障；粒子、天气、动画、声音等客户端子系统的冻结/插值/不保证策略。

诊断必须显示每个子条件，不能只显示“等待世界”。

### P11-W05：确定性重复实验

前置：P11-W04。

实测：从固定世界和起点重复两次相同 Job，比较目标 tick、CameraState、可观测 World revision、实体位置和输出元数据。

不要求第一版控制所有 Mod 随机性；所有未控制来源必须明确报告，不能宣称像素级确定。

阶段退出门：单人前向世界 step 可重复、可取消、可恢复；多人和倒放明确不支持；M4 完成。

## 18. P12：Cycles 公共离线 API 与可选 Backend

### 阶段目标

建立 RayPortal → Cycles 的单向、版本化、能力驱动集成，使一帧可以渲染任意现实时间而不重置累积。

### 外部能力门

进入实现前必须确认：

- Cycles Mod 当前仓库和分支可构建。
- Minecraft 26.2 所需 Vulkan/渲染栈实际可运行，或具备可验证的兼容开发环境。
- Cycles 当前场景、相机、Session、Frame generation 和输出生命周期已经从源码重新确认。
- 两个仓库工作树和写入所有者明确分开。

能力门关闭时，本阶段标记 BLOCKED；不得修改 RayPortal 核心伪造完成，也不得把 Cycles 源码复制进 RayPortal。

### P12-W01：跨仓库 API 设计与版本协议

前置：P09 API 稳定，外部能力门至少允许设计验证。

产物：与 RayPortal 类型无关的 Cycles 公共离线能力：打开 Session、同步 Scene revision、提交锁存 Camera/Settings、查询进度、完成 Pass/降噪、写输出、取消和关闭。

定义 Backend API Version、能力、错误、Ticket、revision、线程和所有权；分别列出两个仓库的生产者与消费者。

### P12-W02：Cycles 仓库公共 API

前置：P12-W01 在独立计划中确认。

本工作包只能在 Cycles 仓库独立执行、验证和提交。实现窄公共 API 与自己的合同测试，不加入 RayPortal Project、Timeline、Track 或 GUI 概念。

退出：Cycles 不安装 RayPortal 也能构建和运行原有实时模式；离线 API 有独立 smoke 证据。

### P12-W03：RayPortal 可选发现与兼容降级

前置：P12-W02 已提交并有可消费 artifact/API。

产物：`integration.cycles` 内的可选发现、版本协商、能力映射和禁用原因。禁止入口静态初始化硬链接缺失类。

验证：无 Cycles、兼容 Cycles、过旧/过新 API、初始化失败四种启动路径。

### P12-W04：CyclesRenderBackend 基础映射

前置：P12-W03。

产物：CameraState、通用输出、Frame/Ticket/revision 和 Backend Settings 到 Cycles 公共 API 的映射；Cycles 特有字段保持在独立设置文档。

测试：焦距、传感器、FOV、焦平面、f-stop、Lens Shift、裁剪面和坐标约定 fixture。

### P12-W05：Scene/Camera 锁存与长帧协议

前置：P12-W04。

产物：等待目标 Scene revision、一次性提交锁存 Camera/Settings、持续查询同一 Ticket、样本/降噪/Pass 完成和迟到 generation 拒绝。

验证：虚拟或真实长帧期间不重新提交 frame ID、不推进 Timeline、不改变 Camera revision；Scene 变化只影响目标帧。

### P12-W06：Cycles 输出提交与端到端实测

前置：P12-W05。

实测至少包括：一帧、连续多帧、取消、设备错误、场景变化、目标样本、降噪、Pass、文件提交、移除 Cycles 后启动。

阶段退出门：文件安全提交后才推进；任意现实时长不破坏锁存；两个仓库提交独立；M5 的基础联动完成。

## 19. P13：生产级渲染输出与快门采样

### 阶段目标

在通用能力模型下提供严肃制作所需的 Pass、HDR、色彩、快门和批处理，不把 Cycles 私有字段塞进核心时间线。

### P13-W01：Pass、AOV 与多文件输出模型

前置：P09、P12。

产物：稳定 Pass ID、Backend 能力、请求列表、输出清单、每 Pass 文件元数据和 Manifest 恢复语义。

缺失 Pass 必须在 Job 预检失败或显式降级，不得生成看似成功的空文件。

### P13-W02：HDR/EXR 与色彩管理意图

前置：P13-W01。

产物：线性/HDR 输出意图、像素格式、通道、色彩空间和显示变换边界；具体 OCIO/Cycles 配置由 Backend 解释并版本化。

测试：能力协商、元数据、错误路径和恢复；不要把显示截图误当线性输出。

### P13-W03：D08 快门与运动采样

前置：P01-W04、P11、P12。

决定：RayPortal 提供快门区间和规范 sample time；Backend 负责采样分布；需要世界子样本时必须明确 Simulation 状态来源。

第一步只支持 Camera/Transform 可随机求值的运动模糊。世界多子帧采样仍可保持 Deferred，不能用重复 tick 或 Wall Clock 模拟。

### P13-W04：全景、立体与多相机批处理

前置：P13-W01。

按 BackendCapabilities 分别立项。每种模式必须定义 CameraState 扩展、输出身份、Pass 组合和不支持行为；不得一次提交所有模式的占位枚举。

### P13-W05：Render Preset 与预检

前置：P13-W01–P13-W04 中实际支持项。

产物：版本化通用设置、Backend 特有设置引用、输出估算、磁盘/分辨率/能力预检和可重现配置摘要。

阶段退出门：支持项具有真实输出和恢复证据；不支持项在 UI/API 中明确；M5 完整。

## 20. P14：通用属性动画、依赖求值与 OSL

### 阶段目标

把 RayPortal 从“相机时间线”扩展为可驱动对象、灯光、World、材质和 OSL Socket 的通用动画系统，形成接近 Blender Animation/Depsgraph 与 Cycles 协作方式的能力。

RayPortal 不编译或执行 OSL。OSL 源码、Shader Group、缓存和执行归 Cycles；RayPortal 只负责稳定目标、类型化参数、精确时间、依赖顺序和不可变帧/样本值。

### P14-W01：D07 Property 身份与类型系统

前置：P04、P05、P12。

产物：稳定 `PropertyTargetId`、`PropertyKey`、`ValueType`、类型化值和 Backend capability descriptor。

第一版类型建议覆盖 scalar、integer、boolean、color、vector、enum 和 asset reference；每种类型必须有范围、单位、插值能力和序列化规则。

禁止：以显示名称、数组下标、Java 反射路径或任意字符串 Map 作为稳定绑定。

### P14-W02：Property Registry 与能力发现

前置：P14-W01。

产物：对象、灯光、World、材质和 Shader 暴露可动画属性的只读 Registry；属性 owner、schema version、默认值、UI metadata 和 Backend 支持状态。

目标消失、类型变化和 Backend 缺失必须在编译/Job 预检形成结构化诊断。

### P14-W03：Property Track、Binding 与曲线

前置：P14-W02、P04 曲线。

产物：绑定稳定 Target/Property 的 Track/Clip/Keyframe；按 ValueType 限制可用插值；Project schema 与迁移。

测试：重命名显示名称不破坏绑定；目标删除、属性类型变化、未知属性和 Clip 冲突可诊断。

### P14-W04：依赖图与确定性求值

前置：P14-W03。

产物：属性依赖节点、显式边、稳定拓扑顺序、循环检测、脏标记和增量 snapshot 编译边界。

不在第一版实现任意脚本 Driver。所有节点必须纯、可审计、固定 seed，并能随机 seek。

### P14-W05：SceneParameterSnapshot 与 Sample Time

前置：P14-W04、P13-W03。

产物：Frame 中心的不可变 Scene Parameter Snapshot、独立 Material/Light/World revision，以及快门区间内可由 Backend 安全求值的 Temporal Parameter 表达。

约束：后台 Cycles worker 不回调可变 Editor Project；OSL `time` 和动画参数基于 Sample/Shutter Clock，不基于 Wall Clock。

### P14-W06：Cycles OSL Capability 与 Socket Schema

前置：Cycles 已真实支持目标 OSL 路径，P14-W05。

Cycles 仓库负责暴露：OSL 可用性、Shader/Group 稳定身份、Socket 类型/默认值/范围、编译状态和结构化错误。RayPortal 适配器只做公共 API 映射。

验证：OSL 不可用、编译失败、Socket 重命名、类型变化、缓存失效和 Scene revision 更新。

### P14-W07：属性编辑器、Dope Sheet 与曲线视图

前置：P14-W03–P14-W06。

先实现最小属性选择、关键帧插入、Dope Sheet 和类型化属性面板，再逐步增加 Graph Editor 操作。所有修改经过 Editor Command 和 Undo/Redo。

不得复制 Blender UI 层级；保留 Blender 式精确语义和可诊断工作流即可。

### P14-W08：OSL 动画端到端合同

前置：P14-W07。

实测：

- 时间线驱动至少一个材质 scalar/color Socket。
- 时间线驱动灯光或 World 属性。
- 长帧采样期间 Frame 中心参数不漂移。
- 启用快门时 Sample Time 与参数曲线一致。
- 编译错误不会破坏 Project 或上一个有效 Shader。
- 保存/重载、恢复 Job、Cycles 缺失和 API 不兼容路径正确。

阶段退出门：通用 Property 系统不依赖 OSL；OSL 只是一个能力提供者；M6 完成。

## 21. P15：生产硬化、兼容与发布

### 阶段目标

把功能闭环提升为可以承担长时间严肃项目的产品，而不是只在开发场景成功一次。

### P15-W01：性能与内存基线

前置：目标发布能力冻结。

测量：大型 Project 编译、随机 seek、长录制、关键帧简化、Render Queue、像素 lease、Manifest 增长和 UI 高频诊断。

只根据 profile 优化；优化前后使用相同 fixture 和结果比较。不得为性能破坏确定性或不可变边界。

### P15-W02：长任务与故障注入

前置：P09–P14 中目标功能。

执行可缩短但语义等价的 soak：多帧长等待、暂停/恢复、取消、磁盘满、编码失败、设备丢失、世界退出、客户端异常关闭和重新恢复。

要求首个底层错误、最后安全帧和宿主恢复状态都有证据。

### P15-W03：兼容矩阵与降级

前置：P15-W02。

矩阵至少包括：无 Cycles、兼容 Cycles、API 不兼容、OSL 不可用、不同 Backend 能力、单人世界、多人拒绝、Vulkan/设备不可用和旧 Project 迁移。

任何无法测试的组合标记 NOT RUN 或 BLOCKED，不推断通过。

### P15-W04：用户工作流与示例项目

前置：目标功能稳定。

产物：从创建 Project、相机关键帧、录制、Vanilla 输出、世界单步、Cycles Job 到 OSL 属性动画的分层用户文档和小型示例 fixture。

示例必须参与加载/迁移 smoke，避免文档随 Schema 漂移。

### P15-W05：发布门

发布前必须：

- 干净 checkout 可构建和测试。
- 当前支持的 `runClient` 工作流全部实际执行。
- 包内没有测试依赖、临时文件、缓存或本机路径。
- Project/Manifest 迁移和未知版本拒绝通过。
- Null、Vanilla 和已支持 Cycles Backend 合同通过。
- 已知限制、兼容矩阵、许可证和恢复说明完整。
- Git diff、产物身份和版本来源可追踪。

阶段退出门：所有发布门为 PASS，或发布说明明确接受命名的 KNOWN RED；M7 完成。

## 22. Post-1.0 独立立项池

以下能力不自动属于 v1。每项必须重新进行架构、数据规模、兼容和恢复设计：

- 嵌套 Sequence、复杂 NLE、Time Remap 和 Transition。
- 音频参考、波形缓存和音画同步。
- Look At、Follow、Path、Shake、Driver 和表达式系统。
- Actor、Morph、模型、动作与摄像表演工作室。
- 世界 Snapshot/replay、任意 seek 和倒放。
- 多人服务器协同与确定性控制。
- 全世界随机源治理和像素级复现声明。
- 分布式渲染、远程队列、渲染农场和资产分发。
- USD/Alembic/外部 DCC 交换。

这些能力不得通过提前扩充枚举、Schema 空字段或空接口“预留”。当真实工作开始时再建立最小完整边界。

## 23. Luna Max 单工作包提示模板

后续可以把下面模板交给执行模型，并替换工作包 ID：

```text
你正在 RayPortal 仓库根目录开发。

本次只处理工作包：Pxx-Wyy。

开始前：
1. 完整读取根目录 AGENTS.md。
2. 读取 docs/architecture.md。
3. 读取 docs/development-roadmap.md 中当前阶段、当前工作包和直接前置工作包。
4. 检查当前代码、测试、构建配置、git status 和最近提交；不要依赖旧对话推断事实。

先给出并等待确认：
- 目标。
- 预计修改/新增文件。
- 保持不动的区域。
- 必须保持的行为和稳定契约。
- 风险。
- 实际验证计划。

确认后只实现 Pxx-Wyy。不得开始后续工作包，不得修改 cycles-mod，不得提交或 push，除非我另行明确授权。

完成时报告：
- 实际变更。
- 自动与手工验证结果。
- 未执行验证及原因。
- 稳定契约、依赖、资源和兼容性影响。
- 已知限制与下一 eligible 工作包。
```

涉及 P12 或 P14-W06 的 Cycles 工作时，必须为 Cycles 仓库开启独立任务和独立提交，不能让一个工作包同时拥有两个仓库的写入。

## 24. 路线图变更规则

允许根据当前源码证据调整工作包内的类名和文件划分，但以下变化必须先更新路线图或架构决定：

- 调换阶段依赖，使平台层先于纯核心成为真相来源。
- 跳过 Null/Vanilla Backend，直接让 Cycles 成为核心测试条件。
- 将世界单步、运动模糊或 OSL 混入基础相机预览阶段。
- 改变 Project Schema、Frame 完成、Ticket、revision 或恢复语义。
- 让一个提交跨 RayPortal 与 Cycles 两个仓库。
- 将 Deferred 能力偷偷并入当前工作包。

路线图的价值在于维持可验证的因果链：精确时间先成立，纯求值再成立，Minecraft 适配随后接入，通用离线调度独立通过，最后才让 Cycles、Vulkan 和 OSL 扩展能力。任何加速都不能破坏这条因果链。
