# RayPortal 正式架构规范

> 架构版本：0.1
>
> 状态：规范性设计文档
>
> 基线：Minecraft 26.2、NeoForge 26.2、Java 25
>
> 最后更新：2026-08-15

本文定义 RayPortal 后续开发应遵守的架构方向、核心不变量、子系统边界和阶段性交付顺序。它是项目内的架构规范，不是现有实现说明；当前仓库仍然只有空白 Mod 基线。代码、配置或运行时事实与本文冲突时，必须先确认冲突并更新设计或实现，不能静默偏离。

基础调查、历史 Mod 源码链接和初步风险记录见 [architecture-investigation.md](architecture-investigation.md)。

## 1. 决策状态

本文使用三个状态标记，避免把尚未验证的实现细节过早冻结：

- **Accepted**：后续实现必须保持的架构方向或稳定不变量。改变它需要明确的架构决策记录和兼容性分析。
- **Provisional**：当前推荐方案，允许在对应实现阶段通过实验调整；调整时不得破坏 Accepted 级不变量。
- **Deferred**：已识别但不进入当前阶段的能力，不得为了“顺便支持”而扩大实现范围。

文中的 Java 类型名、包名和方法名若未明确标为公共 API，均只是概念名称。第一版实现验证完成前，不视为稳定二进制接口或序列化合同。

## 2. 执行摘要

RayPortal 是 Minecraft 内的镜头编排、时间线求值、相机动作录制和离线逐帧调度系统。它决定：

- 在项目时间的某一刻，应该使用哪台相机。
- 相机位于哪里、朝向哪里、使用什么镜头参数。
- Minecraft 世界在输出某一帧前应推进到什么模拟状态。
- 何时向渲染后端提交一帧，以及何时允许进入下一帧。
- 输出帧、渲染进度、失败、取消和断点续渲染如何管理。

RayPortal 不决定某个具体渲染器怎样路径追踪、降噪或生成 Pass。Cycles Renderer 负责根据已锁定的世界、相机和渲染设置生成最终图像；RayPortal 通过可选适配层对 Cycles 做专用映射，但 Cycles 不依赖 RayPortal 的 Project、Track、Clip 或编辑器模型。

实时预览和离线输出必须复用同一个时间线编译器与求值器。二者只在时钟、世界步进策略和渲染后端上不同。

## 3. 项目目标与非目标

### 3.1 目标

以下目标为 **Accepted**：

1. 提供独立于玩家实体的通用电影相机。
2. 提供可保存、可编辑、可随机定位的镜头时间线。
3. 支持手动关键帧和实时驾驶相机录制两种创作方式。
4. 支持实时预览、Vanilla 图片序列和可选的 Cycles 离线输出。
5. 允许某一输出帧渲染任意长的现实时间，而项目时间保持不动。
6. 在单人/集成服务端范围内提供明确的世界冻结和前向 tick 单步策略。
7. 通过显式帧票据和完成屏障保证“输出提交完成后才推进帧号”。
8. 项目文件具有版本、稳定元素 ID、迁移路径和可恢复保存流程。
9. 核心时间、曲线、相机和状态机可以在没有 Minecraft 与 Cycles 的纯 Java 环境中测试。
10. RayPortal 未安装 Cycles 时仍可进行镜头创作、预览和通用输出。

### 3.2 第一版非目标

以下范围为 **Deferred**：

- 实现路径追踪、采样器、降噪器、EXR 编码器或 Cycles 内部功能。
- 复制 Blender 的完整动画、合成、建模或视频剪辑界面。
- Blockbuster/BBS 级演员录制、Morph、模型编辑、音频工作站和场景导演功能。
- 对任意多人服务器提供确定性世界控制。
- 无快照条件下让 Minecraft 世界任意倒放或随机 seek。
- 第一版即保证粒子、随机 tick、第三方 Mod AI 和网络行为完全可复现。
- 第一版即支持运动模糊子帧、立体/全景多视图、分布式渲染或渲染农场。
- 在 Cycles 仓库中实现 RayPortal 时间线、相机编辑器或 Project 数据结构。

## 4. 不可破坏的架构不变量

以下全部为 **Accepted**：

1. **墙上时间不能驱动项目时间。** `System.nanoTime()` 只能用于超时、ETA 和性能统计。
2. **输出帧时间必须直接计算。** 不允许用浮点数逐帧累加 `1 / fps` 作为规范时间。
3. **帧只有在输出提交完成后才能推进。** “渲染看起来完成”不等价于文件已安全写入。
4. **一次离线帧必须被锁存。** 等待渲染期间，相机、项目时间、世界 revision 和后端设置不能悄悄变化。
5. **核心求值器不依赖 Minecraft、NeoForge 或 Cycles。** 平台对象只出现在适配层。
6. **运行时求值结果不可变。** 编辑器不能把正在渲染的快照原地改写。
7. **离线调度不得阻塞 Minecraft 渲染线程或集成服务端线程。** 等待通过状态机和异步回执完成。
8. **相机系统不能依靠移动玩家或发送传送命令实现。** 玩家状态与电影相机状态必须分离。
9. **Project 内元素使用稳定 ID。** 数组下标、显示名称和文件顺序不能充当持久身份。
10. **后端是能力驱动且可选的。** 核心时间线不能导入 Cycles 内部类型。
11. **世界随机定位和相机随机定位是两种不同能力。** UI 和 API 不得把二者伪装成同一保证。
12. **取消和失败必须恢复宿主状态。** 包括相机实体、暂停/冻结状态、输入控制和后端资源。

## 5. 总体分层

### 5.1 组件图

```text
┌─────────────────────────────────────────────────────────────┐
│ Editor / UI                                                 │
│ Timeline · Viewport · Properties · Recorder · Render Queue  │
└──────────────────────────────┬──────────────────────────────┘
                               │ commands / snapshots
┌──────────────────────────────v──────────────────────────────┐
│ Application / Session                                       │
│ ProjectSession · PreviewSession · RecordingSession          │
│ OfflineRenderCoordinator · JobManifest                      │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
┌──────────────v────────────────┐   ┌─────────v───────────────┐
│ Pure Core                     │   │ Persistence              │
│ Time · Timeline · Camera      │   │ Project codecs           │
│ Curves · Constraints          │   │ Migrations · Atomic save │
│ Compiled immutable snapshots  │   │ Recording sidecars       │
└──────────────┬────────────────┘   └─────────────────────────┘
               │ evaluated state
┌──────────────v───────────────────────────────────────────────┐
│ Minecraft Runtime Adapter                                   │
│ Virtual camera · Delta source · World stepping · Readiness  │
└──────────────┬───────────────────────────────────────────────┘
               │ immutable FrameRequest
┌──────────────v───────────────────────────────────────────────┐
│ Render API / Backend Registry                               │
│ Null/Test · Vanilla Capture · optional Cycles Adapter        │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 逻辑子系统

| 子系统 | 主要责任 | 禁止依赖 |
| --- | --- | --- |
| `core.time` | 精确时间、帧率、帧索引、快门区间 | Minecraft、NeoForge、渲染后端 |
| `core.timeline` | Track、Clip、Keyframe、编译和求值 | Minecraft 客户端对象、文件 IO |
| `core.camera` | 相机变换、镜头、约束和不可变状态 | Cycles 内部类、GUI |
| `core.cinematic` | 镜头切换、标记、电影控制状态 | Minecraft 生命周期 |
| `application` | Project/Preview/Record/Render 会话编排 | 具体 native ABI |
| `runtime.minecraft` | 相机应用、世界时间、生命周期 Hook | Project 文件格式、Cycles native 类型 |
| `render.api` | 后端能力、请求、票据、进度和结果 | Timeline 编辑模型 |
| `integration.cycles` | RayPortal 状态到 Cycles 公共 API 的映射 | Cycles 私有实现、RayPortal GUI |
| `capture` | 实时相机采样、重采样、简化和轨道生成 | 输出渲染器内部实现 |
| `persistence` | 编解码、迁移、原子保存、Job Manifest | 活动渲染线程状态 |
| `editor` | 用户交互、命令、选择和视图状态 | 直接修改编译后快照 |

这些名称为 **Provisional**。依赖方向和职责边界为 **Accepted**。

### 5.3 依赖规则

以下规则为 **Accepted**：

- `core.*` 只依赖 Java 标准库和明确选择的数学基础库。
- `runtime.minecraft` 将 Minecraft 对象转换为核心只读上下文，将核心结果应用回 Minecraft。
- `integration.cycles` 可以依赖 RayPortal 的 `render.api` 和 Cycles 的小型公共 API，但 Cycles 不依赖 RayPortal。
- `editor` 通过命令修改 Project，通过发布新 snapshot 影响预览；不直接改求值器缓存。
- `persistence` 保存 Project 语义，不序列化活动线程、Future、native handle 或 Minecraft 实例。
- 后端特有设置使用带后端 ID 和 schema version 的独立文档，不向核心类型添加任意 Cycles 字段。

## 6. 四时钟模型

### 6.1 时钟分类

| 时钟 | 规范来源 | 用途 | 推进条件 |
| --- | --- | --- | --- |
| Wall Clock | 单调现实时间 | ETA、超时、性能统计、日志 | 始终推进 |
| Timeline Clock | Project/Sequence | 关键帧、Clip、相机和电影状态 | 预览播放或调度器显式推进 |
| Simulation Clock | Minecraft 世界 | 实体、方块、粒子、天气和服务端逻辑 | `WorldStepPolicy` 允许 |
| Sample/Shutter Clock | 当前输出帧 | 快门区间、运动采样、子帧 | 后端在同一帧票据内使用 |

四者分离为 **Accepted**。

### 6.2 基础时间类型

概念类型如下：

```text
FrameRate(numerator, denominator)
FrameIndex(value)
TimelineTime(numerator, denominator)
TimelineDuration(numerator, denominator)
TimeRange(startInclusive, endExclusive)
ShutterInterval(openOffset, closeOffset)
```

语义为 **Accepted**，Java 内部表示为 **Provisional**。序列化必须保存精确整数分子/分母或等价的无损表示，不保存累积 `double seconds` 作为唯一真相。

约束：

- 帧率分子和分母必须为正整数并约分。
- `FrameIndex` 使用非负 `long`；Sequence 局部时间允许负 preroll。
- 时间值必须规范化符号并进行溢出检查。
- 常用运算先约分再乘，必要时使用更宽的中间表示。
- `double` 和 `float` 只允许出现在曲线数学、Minecraft API 和渲染后端边界。

### 6.3 帧到时间的映射

Sequence 起点为 `sequenceStart`，输出帧中心时间为：

```text
frameTime(n) = sequenceStart + n × fps.denominator / fps.numerator
```

不允许：

```text
time += 1.0 / fps
```

输出范围使用半开区间 `[startFrame, endFrameExclusive)`，避免最后一帧定义不清。

默认将 `frameTime(n)` 视为该帧的中心采样时刻；快门开闭相对于中心表达。这个默认值为 **Provisional**，但“快门区间是明确时间范围”是 **Accepted**。

### 6.4 时间变换

Clip 可以拥有：

- Sequence 上的开始时间与持续时间。
- Source offset。
- 有理数播放速度。
- 可选循环模式。
- 可选淡入淡出/Envelope。

第一阶段只要求正向、非零速度。反向世界模拟和任意时间重映射为 **Deferred**；纯相机 Clip 可以先支持反向与循环，因为它是随机可求值数据。

### 6.5 与 Minecraft 20 TPS 的映射

给定目标项目时间 `T` 和世界时间映射 `W(T)`：

```text
exactSimulationTicks = W(T) × 20
fullTick             = floor(exactSimulationTicks)
partialTick          = fractionalPart(exactSimulationTicks)
```

调度器只让集成服务端推进到 `fullTick`，渲染适配层使用 `partialTick` 表达两个模拟状态之间的插值。24/30/60 FPS 与 20 TPS 不要求一一对应；多个输出帧可以共享同一个完整世界 tick，但拥有不同 partial tick。

## 7. 项目与时间线领域模型

### 7.1 Project

概念结构：

```text
CinematicProject
├── ProjectMetadata
├── ProjectSettings
├── Cameras
├── Sequences
├── RenderPresets
├── BackendSettingsDocuments
└── AssetReferences
```

Project 是可编辑和可持久化的数据源。它不包含运行时 native handle、Minecraft 实体引用或活动渲染票据。

### 7.2 Sequence

一个 Sequence 至少包含：

- 稳定 `SequenceId`。
- 名称和可选说明。
- 输出帧率。
- 项目时间范围和渲染范围。
- 有序 Track 列表。
- Marker 列表。
- 默认 Camera 和 Render Preset 引用。
- 世界时间映射和 `WorldStepPolicy` 引用。

嵌套 Sequence、音频时基和复杂非线性编辑为 **Deferred**。数据模型不得阻止以后增加这些能力。

### 7.3 Track

第一版规划的 Track 类型：

| Track | 输出 |
| --- | --- |
| Camera Cut Track | 当前 Camera ID 与切换语义 |
| Transform Track | 位置、旋转、可选缩放/轨道参数 |
| Lens Track | 焦距、传感器、光圈、对焦、Shift、裁剪面 |
| Constraint Track | Look At、Follow、Path Orientation 等约束权重 |
| Modifier Track | Shake、Noise、Offset 等后处理效果 |
| World Control Track | 世界时间映射、天气或显式控制提示 |
| Render Settings Track | 通用预设引用与后端特有设置引用 |
| Marker/Event Track | 镜头标记、渲染范围、用户事件 |

Track 顺序是确定性求值顺序的一部分。显示名称不是身份；每个 Track 和 Clip 都拥有稳定 ID。

### 7.4 Clip

Clip 是 Sequence 时间范围内的可编辑片段，而不是直接操作 Minecraft 的对象。每个 Clip 至少包含：

- `ClipId`。
- `start`、`duration`、`sourceOffset`。
- 启用状态。
- 层级/优先级或所在 Track 顺序。
- 时间变换。
- 淡入淡出 Envelope。
- 类型化内容。

同一 Track 内的重叠规则为 **Provisional**：第一版优先支持“不重叠或显式交叉淡化”，禁止两个不带混合规则的 Clip 隐式争夺同一属性。

### 7.5 Keyframe 与曲线

关键帧至少包含稳定 ID、时间、值、插值类型和切线/手柄数据。支持的基础插值：

- Step：离散属性和 Camera Cut。
- Linear：标量、向量和预览。
- Cubic Hermite / Bézier：位置和标量曲线。
- SLERP：两个 Quaternion 之间的旋转。
- SQUAD 或等价 Quaternion cubic：平滑旋转路径。

Euler 角可以用于 UI 输入与显示，但不能作为核心旋转插值的唯一真相。Yaw unwrap 只属于编辑转换过程。

## 8. 相机模型

### 8.1 相机身份与 Rig

`CameraDefinition` 是 Project 中可编辑的相机定义；`CameraState` 是某个时间点的不可变求值结果。相机 Rig 可以组合基础变换、镜头、约束和 Modifier。

相机不等于 Minecraft 玩家，也不等于 Cycles Camera 对象。

### 8.2 坐标约定

内部位置使用 Minecraft 世界的双精度 `(x, y, z)` 坐标。内部旋转使用右手 Quaternion，并固定相机局部轴：

```text
right   = +X
up      = +Y
forward = -Z
```

Minecraft yaw/pitch、JOML、Vanilla Camera 和 Cycles 坐标的差异必须集中在适配器转换函数中，并通过基准方向测试验证。核心时间线不得散布 `+180°`、轴交换或符号翻转。

### 8.3 不可变 CameraState

概念字段：

```text
CameraState
├── cameraId
├── sampleTime
├── position : Vec3d
├── orientation : Quaterniond
├── projection : ProjectionState
├── lens : LensState
├── clipping : ClipPlanes
└── diagnostics : EvaluationMetadata
```

`ProjectionState` 允许透视、正交和后续全景扩展。第一版只要求透视相机完整工作。

`LensState` 的通用物理字段：

- 焦距（毫米）。
- 传感器宽度和高度（毫米）。
- Sensor fit 策略。
- 光圈 f-stop。
- 对焦距离。
- 光圈叶片数、旋转和比例（后端支持时）。
- 水平/垂直 Lens Shift。
- 近/远裁剪面。

FOV 是焦距、传感器和输出画幅的派生值；允许 UI 以 FOV 编辑，但保存时必须明确转换语义。曝光、色彩管理、采样数和降噪不属于 `CameraState`，它们属于 Render Settings。

### 8.4 相机求值顺序

求值顺序为 **Accepted**：

```text
Base Camera Definition
→ Active Transform/Lens Clips
→ Constraints
→ Ordered Modifiers
→ Validation and normalization
→ Immutable CameraState
```

约束示例：Look At、Follow Entity、Follow Path、Horizon Lock。Modifier 示例：Shake、Noise、Handheld Drift、Additive Offset。

每个约束和 Modifier 必须：

- 输入只读上下文和前一阶段状态。
- 返回新状态或写入调用方拥有的局部工作缓冲。
- 不使用全局静态临时 `Position`。
- 不访问墙上时间或无种子的随机数。
- 具有确定的错误和目标缺失策略。

### 8.5 目标缺失策略

跟随实体等约束可能在离线帧中找不到目标。策略为 **Provisional**：

- 预览默认保持最后有效状态并发出诊断。
- 离线渲染默认将帧标记为失败，不悄悄跳过。
- 用户可以为特定约束选择 Disable、Hold Last 或 Fail Frame。

### 8.6 Camera Cut

Camera Cut Track 选择活动 Camera。默认切换为 Step，不在两个镜头之间隐式插值。需要转场时应创建明确的 Blend Clip 或过渡相机。

## 9. 时间线编译与求值

### 9.1 编辑模型和运行模型分离

编辑器操作可变 `CinematicProject`。预览和离线渲染只读取不可变的 `CompiledTimelineSnapshot`。

发布流程：

```text
Edit Command
→ Mutable Project revision + 1
→ Validate
→ Compile affected Sequence/Track
→ Publish new immutable snapshot
→ Preview switches snapshot at a safe boundary
```

活动离线帧不会切换到新 snapshot。用户在渲染时编辑 Project，应提示“修改将在下一任务或显式重启后生效”。

### 9.2 编译阶段

编译器负责：

- 校验稳定 ID 和引用。
- 排序 Track、Clip 和 Keyframe。
- 建立时间区间索引。
- 预计算曲线段系数。
- 解析 Camera、Constraint 和 Preset 引用。
- 检测约束依赖环。
- 生成 revision 和内容摘要。
- 将编辑器友好数据转换为求值器友好的紧凑结构。

### 9.3 求值策略

- 随机 seek 使用二分查找或区间索引定位活动 Clip/Keyframe。
- 顺序播放允许使用 snapshot 私有游标加速，但结果不能依赖游标历史。
- 同一时间、同一 snapshot、同一只读上下文必须产生相同输出。
- 热路径避免临时集合、反射和字符串查找。
- Track 求值顺序由 Sequence 顺序和稳定 ID 解决平局，不能依赖 HashMap 迭代顺序。

相机时间线规模通常不是性能瓶颈。优先保证确定性、可测试性和编辑正确性；只有分析证据表明需要时才引入并行求值。

### 9.4 Revision

至少区分：

- Project revision。
- Compiled timeline revision。
- World/scene revision。
- Camera revision。
- Render settings revision。
- Output frame ticket/generation。

Revision 是变更身份，不是时间。它们必须单调或在 Session 内唯一，不能用对象 hash code 代替。

## 10. 通用相机动作录制

### 10.1 两种“录制”

RayPortal 必须明确区分：

1. **Camera Motion Recording**：实时采样用户驾驶的相机，生成可编辑轨道。
2. **Frame Capture / Offline Rendering**：读取已有时间线并输出图片或视频素材。

二者使用不同 Session、状态机和错误模型。

### 10.2 录制源

录制源可以是：

- RayPortal Free Camera。
- 当前 Vanilla Camera 的观察状态。
- 指定实体或 Camera Rig。
- 外部控制器或后续插件提供的 Camera Source。

采样值使用 `TimelineTime` 标记，不使用事件到达的墙上时间作为项目时间。实时录制时 Timeline Clock 可以由游戏预览时钟驱动。

### 10.3 录制处理管线

```text
Raw timestamped samples
→ Coordinate normalization
→ Gap/outlier diagnostics
→ Resampling to project rate or adaptive time grid
→ Optional non-destructive filtering
→ Error-bounded keyframe reduction
→ Tangent generation
→ New or replacement clips
```

原始采样必须可选择保留为 sidecar，方便重新处理；平滑和关键帧简化不应不可逆地覆盖唯一原始数据。

### 10.4 关键帧简化

算法方向为 **Provisional**：

- 位置使用带时间参数的递归最大误差分割，类似 Ramer–Douglas–Peucker，但误差计算针对拟合曲线而不是二维直线。
- 旋转使用 Quaternion 测地角误差，不分别比较 yaw/pitch/roll。
- 镜头参数使用各自单位和容差，例如毫米、米、f-stop 和 Shift。
- Camera Cut、用户 Marker、录制开始/结束和约束切换点必须强制保留。
- 简化后重新采样并验证最大位置、角度和镜头误差。

### 10.5 平滑与稳定

平滑作为可调 Modifier 或可撤销处理命令实现。默认不在录制时实时破坏原始轨迹。滤波器必须使用项目时间间隔，并明确端点策略；不得根据机器实际帧率改变结果。

## 11. Minecraft 26.2 运行时适配

### 11.1 运行时职责

Minecraft 适配层负责：

- 获取只读世界上下文和实体目标。
- 在正确的相机 update/extract 阶段应用 `CameraState`。
- 提供 RayPortal Free Camera 和输入控制。
- 在离线 Session 中提供受控 partial tick。
- 冻结或单步集成服务端。
- 判断区块、网络、场景桥和资源是否准备完成。
- 在结束、失败或取消时恢复原状态。

### 11.2 虚拟相机原则

电影相机不能通过持续移动玩家、清零玩家速度或发送 `/tp` 命令实现。必须保留进入 Session 前的：

- 原 Camera entity。
- 视角模式。
- FOV/选项状态。
- 输入捕获状态。
- 暂停、冻结和 tick rate 状态。

退出时幂等恢复。

### 11.3 相机应用 Hook

Minecraft 26.2 的 Camera 位置在 update 阶段由 Camera entity 对齐，随后 GameRenderer extract 世界状态。NeoForge 事件可以修改角度和 FOV，但位置接入仍需专门方案。

候选方案为 **Provisional**：

1. 客户端虚拟 Camera entity，由 `Minecraft#setCameraEntity` 驱动。
2. 对 Vanilla `Camera` 使用极窄的 Mixin accessor/invoker，在 update 后、extract 前应用位置和 Quaternion。

实现阶段必须通过 spike 选择。验收标准：

- 不移动玩家。
- 在视锥裁剪、雾、声音监听器和 Cycles 场景采集前生效。
- 与第三人称、睡眠、受伤晃动和手持物渲染的交互可配置。
- Session 结束后完整恢复。
- Mixin 只承担平台 Hook，不包含时间线业务逻辑。

### 11.4 DeltaTracker 接入

不直接复刻 Minema 的全局 Timer 替换。推荐提供 Session 范围的 `OfflineDeltaSource`，只在离线状态机锁存帧时覆盖渲染使用的 game partial tick；现实 UI delta 继续正常推进。

具体 Hook 为 **Provisional**。若必须使用 Mixin，应满足：

- 只在活动 Offline Session 生效。
- 非活动状态执行零行为变化。
- 不忙等待、不 sleep 同步线程。
- 输入时间来自 `FramePlan`，而不是全局可变静态浮点数。

### 11.5 世界准备屏障

单纯“已经调用一个 tick”不足以开始渲染。`WorldReadinessBarrier` 需要组合若干信号：

- 集成服务端已完成目标 tick。
- 客户端已处理对应数据包和计划任务。
- Camera/World revision 已发布。
- 必要区块已加载。
- Chunk mesh/Section 更新达到定义的稳定条件。
- 活动渲染后端已接收目标 scene revision。

每个信号都必须可观察、可超时并提供诊断。不得用固定 `Thread.sleep(1000)` 代替准备协议。

## 12. 世界模拟与确定性边界

### 12.1 WorldStepPolicy

规划策略：

| 策略 | 语义 | 支持范围 |
| --- | --- | --- |
| `REALTIME` | 世界按正常游戏节奏运行 | 实时预览/普通录制 |
| `CAMERA_ONLY_FREEZE` | 世界冻结，仅相机时间线变化 | 第一版静态离线渲染 |
| `INTEGRATED_SERVER_STEP` | 集成服务端按目标完整 tick 前向单步 | 后续动态离线渲染 |
| `SNAPSHOT_REPLAY` | 从快照恢复并重放到目标状态 | Deferred |

策略名称为 **Provisional**，能力边界为 **Accepted**。

### 12.2 前向世界渲染

`INTEGRATED_SERVER_STEP` 只保证从已知起点前向推进：

1. 记录起始世界 tick 和 Project 时间映射。
2. 冻结集成服务端。
3. 计算下一输出帧需要的完整目标 tick。
4. 请求推进差值 tick。
5. 等待服务端、客户端和渲染后端准备完成。
6. 使用精确 partial tick 渲染。

若用户将时间线向后拖动，相机可以立即 seek，但世界状态显示为“非同步预览”，除非重新加载起始快照。

### 12.3 客户端子系统策略

以下系统不一定与服务端 tick 自动同步，必须分别定义策略：

- 粒子。
- 动画纹理。
- 天气视觉效果。
- 声音。
- 屏幕和 HUD 动画。
- 第三方 Mod 的客户端动画。

第一版静态离线模式默认冻结或禁用非确定性视觉更新。后续按子系统增加 `FREEZE`、`STEP`、`TIMELINE_DRIVEN` 策略，不能把一个 partial tick 假定为所有系统的统一答案。

### 12.4 随机性

RayPortal 可以为自身 Noise/Shake 提供显式 seed，但不能宣称控制所有 Minecraft 和 Mod 随机源。每个离线 Job 保存 RayPortal seed；世界级完全确定性为 **Deferred**。

### 12.5 多人限制

多人服务器中 RayPortal 只能保证客户端相机和项目时间线。远端服务器继续按自己的时间运行，因此：

- 可以进行实时相机录制。
- 可以进行“当前世界状态冻结不可保证”的画面捕获。
- 不提供确定性前向单步。
- UI 必须明确标记输出不可复现风险。

### 12.6 世界安全

集成服务端单步会真实改变世界。启动动态离线 Job 前必须：

- 显示当前策略及其世界修改含义。
- 记录起始世界、维度和 tick。
- 建议用户使用专用存档或已有备份。
- 不在未授权情况下自动复制、删除或回滚世界目录。

## 13. 离线渲染任务模型

### 13.1 RenderJob

概念字段：

```text
RenderJob
├── jobId
├── projectId / projectRevision
├── sequenceId / timelineRevision
├── frameRange
├── frameRate
├── worldStepPolicy
├── backendId / backendApiVersion
├── renderPresetId
├── outputSpecification
├── retryPolicy
└── resumePolicy
```

Job 创建后保存其规范配置快照。活动 Job 不跟随编辑器中 Project 的后续变化。

### 13.2 FramePlan

每个输出帧在提交前生成并锁存：

```text
FramePlan
├── jobId
├── frameIndex
├── timelineTime
├── shutterInterval
├── targetSimulationTick / partialTick
├── cameraState
├── cinematicState
├── worldRevision
├── timelineRevision
├── renderSettingsRevision
└── deterministicSeed
```

锁存后只读。等待一分钟或一小时不会改变它。

### 13.3 Job 状态机

```text
IDLE
  → VALIDATING
  → PREPARING
  → SEEKING_WORLD
  → WAITING_WORLD_READY
  → EVALUATING
  → FRAME_LATCHED
  → SUBMITTING
  → RENDERING
  → COMMITTING_OUTPUT
  → ADVANCING
       ├── next frame → SEEKING_WORLD
       └── no frames  → COMPLETED

任意活动状态
  ├── pause request  → PAUSED
  ├── cancel request → CANCELING → CANCELED
  └── error          → RETRY_WAIT or FAILED
```

状态名称为 **Provisional**，以下转换语义为 **Accepted**：

- `FRAME_LATCHED` 后不能静默重求值同一票据。
- `RENDERING` 只等待后端回执，不推进 Timeline 或世界。
- `COMMITTING_OUTPUT` 完成前不得进入 `ADVANCING`。
- `ADVANCING` 写入 Job Manifest 后才修改当前帧索引。
- 所有等待状态每次客户端循环只做有限工作。

### 13.4 Frame Ticket

后端接受 `FrameRequest` 后返回唯一 `FrameTicket`。所有进度、完成、取消和错误回执必须带同一 ticket，并同时校验 Job ID 与 Frame Index，防止迟到的旧回执污染新帧。

### 13.5 完成定义

一帧只有同时满足以下条件才算完成：

1. 后端达到请求的质量条件。
2. 所需降噪和 Pass 已完成。
3. 输出写入临时文件成功。
4. 临时文件原子提交为最终文件。
5. 输出元数据已返回。
6. Job Manifest 已记录该帧完成。

仅仅收到一张可显示的渐进预览帧不能触发推进。

### 13.6 失败、重试与取消

- 可重试错误：暂时资源不足、后端超时、可恢复设备丢失。
- 不可重试错误：项目引用损坏、输出路径非法、版本不兼容、目标相机缺失。
- 重试同一帧必须复用同一 `FramePlan`，但使用新的 `FrameTicket` 和 attempt number。
- 取消不删除已完成输出；未提交临时文件由拥有它的输出组件清理。
- 取消和失败必须释放后端票据并恢复世界和相机状态。

### 13.7 断点续渲染

Job Manifest 与 Project 分开保存，至少记录：

- Job 规范配置摘要。
- Project/Timeline revision。
- 后端及 API 版本。
- 每帧状态、attempt、输出路径、大小和可选 checksum。
- 最后安全提交帧。

恢复时必须校验 Project revision、后端设置和现有输出。默认不覆盖不匹配文件。

## 14. 通用 Render Backend 契约

### 14.1 设计原则

Render Backend 是 **Accepted** 的扩展边界。它负责渲染和输出，不拥有 Timeline Clock，也不能自行推进帧号或 Minecraft 世界。

概念接口：

```text
RenderBackendDescriptor describe()
BackendCapabilities capabilities()
prepareJob(JobContext) -> async PreparedBackendJob
submitFrame(FrameRequest) -> async FrameTicket
queryProgress(FrameTicket) -> RenderProgress
commitOutput(FrameTicket, OutputSpecification) -> async FrameResult
cancel(FrameTicket) -> async CancelResult
closeJob() -> async/finite cleanup
```

具体 Java 签名为 **Provisional**。异步语义、票据身份和所有权为 **Accepted**。

### 14.2 FrameRequest

通用请求至少包含：

- Job/Frame/Ticket 关联信息。
- 精确项目时间和快门区间。
- 输出分辨率和像素纵横比。
- 不可变 `CameraState`。
- 不可变 `CinematicState`。
- World/Scene/Camera/Settings revision。
- 请求 Pass 列表。
- 输出颜色空间和格式意图。
- 确定性 seed。
- 后端特有设置文档引用。

请求不能包含 Timeline、Clip、GUI Widget、Minecraft Entity 或 Cycles 私有对象。

### 14.3 BackendCapabilities

能力协商至少覆盖：

- 实时预览。
- 离线最终帧。
- 取消。
- 进度和样本计数。
- 物理镜头字段。
- HDR/线性输出。
- 多 Pass。
- 后端侧降噪。
- 快门/运动模糊。
- 全景/立体输出。
- 原子文件提交。

RayPortal UI 根据能力启用选项；缺失能力必须显示为不可用，而不是静默忽略。

### 14.4 RenderProgress

进度是诊断，不是完成屏障。建议包含：

- 后端状态。
- 当前/目标样本数。
- 归一化进度（若可知）。
- 当前阶段，例如 scene sync、sampling、denoise、write。
- 已用墙上时间和预计剩余时间。
- 警告与可恢复错误。

### 14.5 Backend 特有设置

Project 保存：

```text
BackendSettingsDocument
├── backendId
├── schemaVersion
└── typed/structured payload
```

核心只识别身份和版本，不解释 payload。适配器负责校验和迁移。禁止将任意 `Map<String, Object>` 直接当作稳定公共 API。

### 14.6 基础后端

规划后端：

- `NullRenderBackend`：测试状态机、超时、失败和一分钟假渲染。
- `VanillaImageBackend`：验证相机、世界步进和图片序列，不依赖 Cycles。
- `CyclesRenderBackend`：可选高质量路径追踪后端。

Null 和 Vanilla 后端应先于 Cycles 适配完成，以证明 RayPortal 核心不依赖特定渲染器。

## 15. Cycles Renderer 专用适配

### 15.1 单向依赖

方向为 **Accepted**：

```text
RayPortal integration.cycles → Cycles public offline API
Cycles public offline API    -X→ RayPortal
```

Cycles 不读取 RayPortal Project，不解析 Track/Clip，不管理 Timeline Clock。RayPortal 未安装 Cycles 时只禁用该后端。

具体依赖机制为 **Provisional**：优先让 Cycles 在自己的仓库内发布小型公共 API/服务入口，RayPortal 以可选或 compile-only 方式编译适配器，并在运行时进行版本与能力协商。避免反射字符串协议；除非 API spike 证明没有更稳定的装载方式。

### 15.2 Cycles 公共离线能力

Cycles 未来需要暴露渲染器通用、与 RayPortal 无关的离线控制能力：

```text
openOfflineSession(settings)
syncScene(targetSceneRevision)
beginOfflineFrame(camera, settings, frameIdentity)
queryOfflineFrame(ticket)
writeOfflineOutput(ticket, outputSpec)
cancelOfflineFrame(ticket)
closeOfflineSession()
```

这些是职责描述，不是已冻结函数名。

### 15.3 一帧锁存

当前 Cycles 实时路径会在 Minecraft 世界渲染回调中持续更新 Camera 并轮询渐进结果。离线适配必须改为：

1. RayPortal 生成一个 `FramePlan`。
2. 等待 Cycles 确认目标 scene revision。
3. 只提交一次锁存 Camera/Settings revision。
4. Cycles 在同一 ticket 内持续采样。
5. Minecraft 后续 GUI 帧只查询进度，不重新提交 frameId。
6. 达到目标样本、降噪和 Pass 完成后，由 Cycles 写入输出。
7. Cycles 返回 `OutputResult`，RayPortal 再推进帧号。

### 15.4 通用与特有字段

通用 CameraState 映射：

- 位置和 Quaternion。
- 焦距/传感器/FOV。
- 焦距平面与 f-stop。
- 光圈叶片、比例与旋转。
- Lens Shift。
- 裁剪面。

Cycles 特有设置：

- 设备和 Session 类型。
- 目标/自适应采样。
- 反弹次数与过滤器。
- OptiX/OIDN/DLSS 等降噪选择。
- Pass 与 AOV。
- 线性 HDR、OCIO、输出色彩空间。
- Cycles 相机类型和全景参数。
- Seed、运动模糊和快门采样实现。

特有设置不能反向污染核心 Camera 类型。

### 15.5 完成协议

Cycles 的 `frameReady` 或可显示 generation 只代表可展示结果。离线完成必须额外确认：

- 当前 ticket 与请求 revision 一致。
- 当前样本达到任务目标或满足自适应终止。
- 请求的降噪和 Pass cache 完成。
- 无待处理 scene/camera reset。
- 文件编码和原子提交完成。

### 15.6 兼容性与降级

- 后端 ID 固定，API 版本独立于 Mod 显示版本。
- 不支持的 Camera/Lens 字段在 Job 验证阶段报错或明确降级。
- API 版本不兼容时禁用 Cycles 后端，但 RayPortal 其余功能继续工作。
- Cycles 运行时失败不能破坏 Project 文件或 Vanilla 相机恢复。

## 16. 持久化与迁移

### 16.1 Project 格式

第一版推荐可读的版本化 JSON 为 **Provisional**：

- Project、Sequence、Track、Clip 和 Keyframe 使用稳定 ID。
- 双精度数值使用无损 JSON number 或明确字符串编码策略。
- 精确时间保存整数分子/分母。
- 后端特有设置按 backend ID 隔离。
- 大型原始相机录制允许保存为压缩 sidecar，Project 只保留引用和摘要。

### 16.2 Schema

每个顶层文档必须包含：

- `format` 标识。
- `schemaVersion`。
- 创建/最后写入的 RayPortal 版本。
- Project ID。
- 可选 feature flags。

禁止序列化 Java 类全名作为类型身份。使用稳定、显式的类型 ID。

### 16.3 迁移

- 迁移按版本逐级执行。
- 读取较新未知版本时拒绝覆盖原文件。
- 未知可选字段应尽可能保留或给出明确诊断。
- 迁移前创建可恢复备份；备份策略在持久化阶段确认。
- 自动迁移必须有 golden fixture 测试。

### 16.4 原子保存

保存流程：

```text
serialize to sibling temporary file
→ flush/close
→ validate readable
→ atomic replace when supported
→ retain/recover previous version on failure
```

Project、Job Manifest 和输出帧分别拥有自己的原子提交边界。

## 17. 编辑器架构

### 17.1 模型、命令和视图分离

编辑器遵循命令式修改：

```text
User Input → Editor Command → Project Mutation → Undo Entry → Snapshot Compile
```

选择、悬停、面板展开状态和临时拖动状态属于 Editor Session，不自动进入 Project 文件。

### 17.2 主要界面

规划工作区：

- Timeline：Track、Clip、Keyframe、Marker 和播放头。
- Viewport：自由相机、构图、安全框和路径可视化。
- Properties：类型化属性和插值设置。
- Recorder：录制源、采样率、容差和平滑预览。
- Render Queue：Job、帧范围、后端、输出和进度。
- Diagnostics：当前四时钟、revision、world barrier 和 frame ticket。

第一阶段不追求 Blender 级可定制 UI；优先建立一条从创建相机、添加关键帧、预览到输出序列的完整工作流。

### 17.3 Undo/Redo

- 每次逻辑操作形成一个可撤销命令。
- 连续拖动可以合并为一个命令。
- 编译缓存不进入 Undo 栈。
- 离线 Job 使用创建时 snapshot，不因 Undo/Redo 改变活动帧。

### 17.4 Scrub 语义

播放头移动始终立即更新纯相机时间线。世界显示状态依据模式：

- Camera-only preview：只更新相机，显示世界未同步提示。
- Forward synchronized preview：只允许前向世界 step。
- Snapshot replay：Deferred。

UI 必须显示当前模式，避免用户误以为向后拖动已经倒放世界。

## 18. 线程、所有权与生命周期

### 18.1 线程角色

| 线程/执行器 | 所有权 |
| --- | --- |
| Minecraft client/render thread | UI、相机应用、客户端状态机驱动 |
| Integrated server thread | 世界 tick 和服务端状态 |
| Backend/native worker | 渲染、采样、降噪 |
| Output IO worker | 编码、写临时文件、提交输出 |
| Optional compile worker | 大型 Project snapshot 编译 |

### 18.2 规则

- 不在 client/render thread 上等待 Future、文件 IO 或一分钟渲染。
- 不从 native worker 直接修改 Minecraft 或 Editor 模型。
- 跨线程消息使用不可变 DTO 和 Session generation。
- 回调进入 client thread 前检查 Session/Job/Ticket 是否仍有效。
- close/cancel 必须幂等。
- 所有资源必须有明确拥有者；Frame 像素 lease 在限定生命周期内关闭。
- 后端错误通过结果对象传播，不能在后台线程静默吞掉。

### 18.3 Session

至少区分：

- `ProjectSession`：打开的 Project、Undo 和 snapshot。
- `PreviewSession`：播放头、当前 snapshot 和相机控制。
- `RecordingSession`：原始采样、录制源和处理配置。
- `OfflineRenderSession`：Job、World policy、Backend 和恢复状态。

同一时间只允许一个组件拥有 Minecraft 主 Camera。Session 之间的切换必须显式仲裁。

## 19. 输出与文件安全

### 19.1 输出路径

- 输出根目录由用户明确选择或使用 RayPortal 专用默认目录。
- 文件模板只允许已定义变量，如 Project、Sequence、Frame 和 Pass。
- 解析后的绝对路径必须位于输出根目录内，阻止 `..` 路径穿越。
- 默认不覆盖已有不匹配文件。
- 临时文件使用同一目标文件系统，便于原子 rename。

### 19.2 文件命名

默认使用固定宽度帧号：

```text
{sequence}/{sequence}_{frame:06}_{pass}.{ext}
```

具体模板语法为 **Provisional**。Frame Index、Sequence ID 和 Pass ID 必须能无歧义恢复。

### 19.3 预检

启动 Job 前检查：

- 后端可用性和版本。
- 输出目录可写。
- 分辨率、帧范围和 Pass 合法。
- Project 引用完整。
- 世界模式兼容。
- 估算磁盘空间并警告，但不以不可靠估算替代运行时错误处理。

## 20. 诊断与可观测性

每条离线诊断至少关联：

- Session ID。
- Job ID。
- Frame Index。
- Frame Ticket/attempt。
- Timeline/World/Scene/Camera/Settings revision。
- Backend ID 和 API 版本。

UI 需要显示：

- 当前状态机阶段。
- 项目时间、模拟 tick 和 partial tick。
- 当前/目标样本。
- 世界准备屏障各子条件。
- 当前输出文件。
- 帧耗时、平均耗时和 ETA。
- 最近一个结构化错误。

高频进度日志需节流；状态转换、失败和输出提交必须记录。

## 21. 测试体系

### 21.1 纯 Java 单元测试

- FrameRate 和有理时间约分、比较、换算、边界和溢出。
- Frame Index 到 TimelineTime 的长序列无漂移测试。
- 20 TPS 映射和 partial tick 测试。
- Clip 区间、重叠、边界和负 preroll。
- 曲线端点、切线、连续性和 Quaternion 最短路径。
- Constraint/Modifier 顺序和 seed 确定性。
- Project 编译和依赖环检测。
- 离线状态机所有合法/非法转换。
- 迟到 ticket、重试、取消和恢复。

### 21.2 属性与差分测试

- 随机 FrameRate/FrameIndex 的精确往返。
- 顺序游标求值和随机 seek 求值结果一致。
- Camera 曲线编译前后结果在容差内一致。
- 关键帧简化后最大位置/角度/镜头误差不超过配置。

### 21.3 Golden 测试

- Project JSON 与迁移 fixture。
- 已知时间点的 CameraState。
- 典型 Camera Cut、Look At、Follow 和 Shake 序列。
- Job Manifest 创建、提交和恢复。

### 21.4 Backend 合同测试

Fake/Null Backend 应模拟：

- 一帧需要一分钟但不阻塞线程。
- 渐进样本更新。
- 完成后输出延迟提交。
- 超时、失败、取消、迟到回执和设备重置。

所有后端必须通过同一套合同测试。

### 21.5 Minecraft 集成测试

- 进入/退出虚拟相机不移动玩家。
- 相机位置在 culling/extract 前生效。
- 世界冻结和单步后客户端状态正确。
- Session 失败和取消恢复原 Camera/tick 状态。
- `runClient` 中 Vanilla 图片序列帧号与相机时间一致。

### 21.6 Cycles 集成测试

- 同一 Frame Ticket 等待期间 Camera/Scene revision 不变化。
- 样本达到目标前不推进 Timeline。
- 降噪/Pass/输出提交完成后才推进。
- scene revision 改变只重置目标帧，不污染已提交帧。
- Cycles 缺失或 API 不兼容时 RayPortal 仍正常加载。

## 22. 实施路线与阶段门槛

### 阶段 A：精确时间与核心快照

范围：

- FrameRate、TimelineTime、FrameIndex、TimeRange。
- 最小 Project/Sequence/Track/Keyframe。
- 编译快照和纯 Java 测试。

完成门槛：长序列帧时间无漂移；核心包不依赖 Minecraft。

### 阶段 B：相机求值与 Vanilla 预览

范围：

- 不可变 CameraState。
- 位置、Quaternion、Lens 曲线。
- Free Camera 和相机应用 spike。
- 最小关键帧预览。

完成门槛：不移动玩家即可按任意 TimelineTime 显示正确相机。

### 阶段 C：相机动作录制

范围：

- Raw sample sidecar。
- 重采样、平滑、误差约束简化。
- 生成可编辑 Clip 和 Undo/Redo。

完成门槛：相同录制输入和配置生成相同关键帧，误差验证通过。

### 阶段 D：通用离线调度与 Vanilla 输出

范围：

- RenderJob、FramePlan、FrameTicket。
- Null/Vanilla Backend。
- 静态世界冻结。
- Job Manifest、取消和恢复。

完成门槛：Fake Backend 可让单帧等待一分钟，Timeline 不推进且 UI 保持响应；PNG 序列帧号连续。

### 阶段 E：集成服务端世界单步

范围：

- 20 TPS 映射。
- Tick freeze/step。
- WorldReadinessBarrier。
- 前向同步预览和离线输出。

完成门槛：从固定起点重复两次得到相同目标 tick、CameraState 和可观测世界 revision；已知非确定系统明确报告。

### 阶段 F：Cycles 适配

范围：

- Cycles 公共离线 API。
- RayPortal 可选适配器。
- 样本/降噪/Pass/输出完成协议。
- Cycles 后端 UI 和诊断。

完成门槛：一帧可渲染任意现实时长，期间不重置累积；文件提交后才推进下一帧；移除 Cycles 后 RayPortal 仍可启动。

### 阶段 G：高级电影能力

候选范围：

- 快门子帧和运动模糊。
- EXR 多 Pass 与 AOV。
- 全景、立体和多相机批处理。
- Snapshot/replay 世界 seek。
- 音频参考、嵌套 Sequence 和复杂时间重映射。

全部为 **Deferred**，必须逐项立项。

## 23. 历史参考的取舍

### 23.1 Aperture

保留：

- 可保存 Camera Profile 的创作思路。
- Fixture/Clip、Modifier、Envelope、Curve 和活动片段求值。
- Look、Follow、Path、Circular 等用户能理解的镜头工具。
- 时间线 scrub、预览和编辑工作流。

放弃：

- 以 Minecraft tick 作为唯一时间真相。
- 线性扫描并原地修改可变 Position 的运行结构。
- 通过移动玩家、修改 motion 和发送传送命令应用相机。
- Forge 1.12、ASM、McLib 和 OptiFine 耦合。
- Euler 作为唯一旋转状态。

### 23.2 Minema

保留：

- 固定输出帧率与游戏真实速度解耦。
- 只有上一帧可以输出时才推进捕获节奏。
- 游戏更新、读取像素和编码之间需要同步屏障。
- 图片序列和外部编码器工作流。

放弃：

- 替换全局 Minecraft Timer。
- 墙上时间决定项目帧能否推进。
- ASM 注入服务端循环和 busy wait 同步。
- 全局静态录制状态与弱完成协议。

### 23.3 BBS Mod

保留：

- 从 Fixture 向 Camera Clip/ClipContext 的演化。
- Clip converters、modifiers、overwrite 和 envelope 的分层思路。
- Camera、Film、Replay 和 Editor 之间更现代的数据组织经验。
- 大型创作工具中的 Undo、属性编辑和时间线 UX 经验。

放弃：

- 将 RayPortal 扩张为综合动画工作室。
- 继续使用整数 tick 作为所有相机时间精度。
- 可变 Camera/Position 在多个层级间传递。
- Euler 插值和大量跨功能依赖。

### 23.4 Blender/Cycles

借鉴概念：

- Project timeline 与实际渲染耗时无关。
- 物理相机和镜头参数。
- Camera Cut、Marker、渲染范围和输出序列。
- 渲染任务、Pass、色彩空间和输出提交。
- 一帧内的快门与子帧采样。

不追求复制 Blender UI 或数据结构；RayPortal 只实现 Minecraft 内完成镜头创作和可靠离线输出所需的最小系统。

## 24. 已接受、暂定与延期决策汇总

### 24.1 Accepted

- RayPortal 与 Cycles 分仓、分责、无 Cycles → RayPortal 依赖。
- 四时钟模型。
- 精确帧时间，不累加浮点帧间隔。
- 编辑 Project 与不可变运行 snapshot 分离。
- CameraState 不等于玩家实体或 Cycles Camera。
- Quaternion 核心旋转和物理镜头模型。
- 通用 Render Backend、FramePlan、FrameTicket 和输出提交屏障。
- 离线等待非阻塞，输出提交后才推进帧号。
- 第一版确定性范围优先单人/集成服务端和前向单步。
- RayPortal 未安装 Cycles 时仍完整加载并保留通用功能。

### 24.2 Provisional

- `TimelineTime` 的具体 Java 数值表示。
- Camera 位置 Hook 使用虚拟实体还是窄 Mixin。
- Project JSON 的文件拆分布局。
- 同 Track Clip 重叠和交叉淡化规则。
- Cycles 公共 API 的装载/compile-only 机制。
- WorldReadinessBarrier 的具体 Minecraft/Section 信号。
- 默认快门中心和输出模板语法。

### 24.3 Deferred

- 任意世界倒放和随机 seek。
- 多人服务器确定性单步。
- 全世界随机源控制。
- 运动模糊和多子帧世界采样。
- 音频时间线、嵌套 Sequence 和复杂 NLE。
- 演员、Morph、模型和动作录制工作室。
- 分布式渲染、渲染农场和远程队列。

## 25. 架构变更流程

以下变更必须先记录新的架构决策，再实现：

- 改变四时钟关系或帧推进条件。
- 让核心包依赖 Minecraft、NeoForge 或 Cycles。
- 改变 CameraState、Project schema、稳定 ID 或 Job Manifest 语义。
- 改变 RayPortal/Cycles 依赖方向。
- 引入世界快照、倒放或多人确定性承诺。
- 改变输出覆盖、恢复或原子提交规则。

架构决策记录应包含背景、选项、选择、兼容性、迁移、验证和回退。小型实现细节不需要形式化记录，但不得违反 Accepted 不变量。

## 26. 第一条实现主线

开始写功能时，不从完整编辑器或 Cycles 特化开始。第一条端到端主线固定为：

```text
创建一个 Sequence
→ 添加一台 Camera
→ 在两个精确时间点添加位置/旋转关键帧
→ 编译不可变 snapshot
→ 在 Vanilla 视口按任意时间预览
→ 用 Null Backend 输出一个不会提前推进的帧任务
→ 用 Vanilla Backend 输出连续图片
→ 最后接入 Cycles Backend
```

这条主线每一阶段都能独立验证，并持续证明 RayPortal 是镜头与时间的导演系统，而 Cycles 是干净的渲染桥。
