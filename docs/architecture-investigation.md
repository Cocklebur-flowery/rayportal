# RayPortal 基础调查与架构边界

> 本文是研究依据，不是最终设计规范。后续开发的规范性方向见 [正式架构规范](architecture.md)。
>
> 调查基线：2026-08-15。本文记录建立空白仓库时确认的事实、历史 Mod 的可复用经验和需要在实现前继续决策的边界。它不是实现承诺，也不把 `cycles-mod` 变成 RayPortal 的依赖。

## 1. 项目定位

RayPortal 的目标是把 Minema 与 Aperture 中对电影制作最有价值的能力，按 Minecraft 26.2+ / NeoForge 的现状重新设计为一个独立 Mod：

- 用可复现的时间线驱动镜头、相机和电影控制轨道。
- 在实时预览与离线逐帧输出之间复用同一套时间线求值器。
- 对游戏世界状态、相机状态和渲染完成建立显式的同步边界。
- 允许将最终的渲染工作交给另一个独立的渲染 Mod，例如 Cycles Renderer。

RayPortal 不负责实现路径追踪、降噪、景深或其他具体渲染器功能；Cycles Renderer 也不应需要了解 RayPortal 的时间线、Fixture 或编辑器数据结构。两者之间只保留可选的窄接口。

## 2. 与 Cycles Renderer 的仓库边界

| 项目 | RayPortal | Cycles Renderer |
| --- | --- | --- |
| Git 仓库 | `rayportal` | `cycles-mod` |
| 主要职责 | 时间线、相机、电影控制、确定性时间、离线调度 | 场景采集、路径追踪、采样、后处理和输出实现 |
| 对另一方的依赖 | 不依赖 Cycles | 不依赖 RayPortal |
| 协作方式 | 提交不可变 `FrameRequest`，等待显式帧完成 | 接受请求并报告 `FrameComplete` / `FrameFailed` |
| 当前阶段 | 只有空白入口、包边界和调查文档 | 保持现状，不修改 |

当前工作区中 `cycles-mod` 是已有的独立 Git 仓库；本次新建的 `rayportal` 目录会拥有自己的 Git 仓库和自己的构建配置。之后所有实现讨论默认只修改 RayPortal，除非明确提出跨仓库集成阶段。

## 3. 参考对象调查

### 3.1 Aperture：应保留的概念

Aperture 的 1.12 代码和文档显示，它的核心不是某个具体 GUI，而是“可保存的相机 Profile + 按时间运行的轨道/Modifier + 求值后写入相机”的组合：

- Camera Profile：相机设置、位置、旋转和镜头相关属性的容器。
- Fixture：一段带起止时间的可保存轨道片段，可拥有自己的时间长度、插值和行为。
- Modifier：叠加在基础相机状态上的效果，例如平滑、抖动、跟随或轨迹修改。
- Envelope / Curve：将离散关键帧求值为连续数值，并允许选择插值方式。
- Runner：按照当前时间找到活动 Fixture，推进 Fixture 时间，再合成最终相机状态。

这些概念适合作为 RayPortal 的领域模型，但需要改成与 Minecraft 26.2 生命周期解耦的纯求值模型。尤其是 `Fixture`、`Modifier` 和曲线可以保留为概念，不能直接复制旧版 Forge 代码或旧的可变相机写入路径。

### 3.2 Aperture：应放弃的耦合

- 旧版 Forge 事件、反射/ASM、McLib 和 OptiFine 等版本耦合。
- 依赖每 tick 改写客户端相机/玩家位置的隐式副作用。
- 只用 Euler 角和可变 `Position` 对象表示所有相机状态。
- 将 GUI、持久化格式、运行时相机和轨道求值揉在一起。

新的求值器应输入明确的 `TimelineTime` 和只读上下文，输出不可变 `CameraState` 与电影状态；Minecraft 适配层再决定何时、以何种生命周期应用它。

### 3.3 Minema：应保留的概念

Minema 的固定计时器、捕获时间和视频处理模块体现了一个仍然有效的原则：录制时不能用墙上时钟来决定游戏状态推进多少；游戏时间和输出帧时间必须分离。应保留：

- 固定帧率/固定时间步。
- 当前捕获帧、输出帧率和时间戳的明确关系。
- 游戏更新、渲染提交、像素读取和编码之间的阶段边界。
- 对暂停、丢帧、完成和失败状态的显式处理。

应放弃：

- 全局替换旧版 Minecraft Timer 的方式。
- ASM 注入作为核心同步机制。
- 依靠真实时间等待来“尽量赶上”输出帧率。
- 没有明确完成信号就开始下一帧的全局状态机。

## 4. 推荐的核心数据流

实时预览和离线输出应共享求值逻辑，只替换时钟和调度器：

```text
实时 tick + partial tick ─┐
                           ├─> TimelineClock ─> TimelineTime
离线 frame index + FPS ───┘                         │
                                                     v
                         Timeline / Camera / Cinematic Evaluators
                                                     │
                                                     v
                         CameraState + CinematicState
                                                     │
                                                     v
                         Minecraft World / Camera Sync
                                                     │
                                                     v
                         RendererAdapter(FrameRequest)
                                                     │
                                                     v
                         RenderBarrier / FrameComplete
                                                     │
                                      下一帧或 OutputResult
```

这里的关键点是：`TimelineTime` 先于 Minecraft tick；Minecraft tick 是运行时适配细节，不应成为时间线的规范时间单位。离线调度器必须可以根据帧索引直接计算目标时间，而不是通过等待现实时间或累加浮点误差得到目标时间。

## 5. 初步包边界

空白仓库已建立以下占位包，当前只表达边界，不包含实现：

| 包 | 责任 | 不应依赖 |
| --- | --- | --- |
| `dev.rayportal.core.time` | 精确时间、帧率、快门区间、时钟 | Minecraft、NeoForge、具体渲染器 |
| `dev.rayportal.core.timeline` | 轨道、关键帧、插值、求值 | Minecraft 客户端对象 |
| `dev.rayportal.core.camera` | 相机轨道与不可变相机状态 | 具体渲染器实现 |
| `dev.rayportal.core.cinematic` | Fixture、Modifier、Envelope 等电影控制 | Minecraft 生命周期 |
| `dev.rayportal.runtime.minecraft` | 世界、相机、tick 与确定性步进适配 | 持久化文件格式 |
| `dev.rayportal.render.api` | 请求、回执、屏障和输出结果 | Cycles 的内部类 |
| `dev.rayportal.persistence` | 有版本的项目/时间线序列化 | 渲染执行状态 |
| `dev.rayportal.editor` | 未来编辑器入口和编辑状态 | 核心求值实现细节 |

依赖方向的第一版约束应接近：

```text
core.*  <── persistence
   ^           ^
   │           └── editor
   │
runtime.minecraft ──> core.*
render.api       ──> core.time / core.camera
```

`render.api` 只定义 RayPortal 发出的稳定边界；它不应导入 Cycles 的包名，也不应把 Aperture 的 Profile 类暴露为公共 API。

## 6. 时间模型：当前推荐

### 6.1 规范时间

规范时间建议使用精确有理数时间，或等价的“整数时间刻度 + 有理数帧率”模型：

- `FrameRate = numerator / denominator`，例如 `24000/1001`。
- `FrameIndex` 是输出坐标，用于定位帧，不是唯一的时间真相。
- `TimelineTime` 由时间刻度表示，避免把每帧 `double` 累加作为状态推进方式。
- `double seconds` 只作为数学计算缓存或与 Minecraft API 交互时的边界值。
- 快门使用明确的时间区间，例如 `[t_open, t_close]`，而不是一个散落在渲染器里的“模糊量”。

帧时间至少要能表达：帧索引、时间基准、帧率、播放方向/速度和快门区间。后续确定序列化格式时还要决定时间刻度的位宽、负时间、循环和变速轨道规则。

### 6.2 Minecraft 世界时间的难点

把时间线推进到某个时间点，并不等价于让 Minecraft 世界达到同一个确定状态。实体 AI、粒子、红石、随机刻、天气、区块加载、声音和网络状态都可能依赖 tick 顺序、随机源或客户端/服务端边界。因此第一阶段不应承诺“任意世界完全可逆或完全确定”。

更安全的离线范围是：

1. 先支持单人/集成服务端，并定义 `WorldStepPolicy`。
2. 明确每个输出帧是推进零个、一个或固定数量的游戏 tick。
3. 把世界准备、区块稳定、实体更新和渲染提交分成可观察阶段。
4. 后续再讨论快照、回放或服务端协同，而不是在第一版中隐式伪造世界状态。

## 7. 渲染适配与帧屏障

RayPortal 与 Cycles（或其他渲染器）的边界建议只交换以下信息：

- `FrameRequest`：序列号、目标时间、帧索引、快门区间、相机状态、电影状态、渲染设置引用和世界修订号。
- `RenderBarrier`：渲染器已接收、世界已准备、提交成功、帧完成、输出已提交或失败。
- `FrameComplete` / `FrameFailed`：带序列号、耗时/错误类别和输出结果引用。

建议的阶段状态为：

```text
PREPARE -> WORLD_READY -> RENDER_SUBMITTED -> FRAME_COMPLETE -> OUTPUT_COMMITTED
```

状态机要能处理超时、取消、失败和重复回执。RayPortal 只依赖协议和生命周期，不依赖 Cycles 的内部资源、纹理、采样器或 Vulkan 实现。若没有可用的外部渲染器，RayPortal 仍应能完成时间线预览和调度层测试。

## 8. 实现前仍需决定的问题

这些问题会直接影响公共数据格式或运行时契约，后续应单独确认：

1. 项目文件格式：JSON、NBT、二进制，是否需要版本迁移。
2. 时间线的坐标系、旋转表示、相机内参和实体跟随语义。
3. 客户端与集成服务端如何共同推进离线世界；多人服务器是否明确不支持。
4. 第一版渲染适配是内置截图输出、事件总线，还是独立的 SPI/NeoForge capability。
5. 帧失败后的重试、取消、断点续渲染和输出文件命名规则。
6. 编辑器是先做游戏内最小控制面板，还是先做外部项目文件工具。
7. 是否需要 motion blur、变速、循环、子帧采样和多相机切换；这些会影响时间线模型。

在这些问题确认前，不应把类名、序列化字段或外部集成事件当作稳定公共 API。

## 9. 推荐实现顺序

这是用于后续讨论的阶段顺序，不代表本次已经实现：

1. 纯 Java 的时间类型、帧率和时钟测试。
2. 纯 Java 的轨道、关键帧、曲线和相机求值。
3. 不连接渲染器的离线帧计划器与屏障状态机。
4. Minecraft 客户端预览适配和最小相机应用。
5. 单人/集成服务端的显式世界步进策略。
6. 本地截图/输出适配，再定义与 Cycles 的可选桥接。
7. 项目持久化、编辑器和断点续渲染。

每个阶段都应保持 `core.*` 可在没有 Minecraft 实例和没有 Cycles 的情况下测试。

## 10. 许可证与参考来源

本仓库初始许可证为 MIT。Aperture 1.12 官方仓库的许可证是 GPLv3；Minema 1.12.2 仓库的许可证文件声明使用 Unlicense。基于这些差异，RayPortal 采用“行为调查 + 独立重写”的 clean-room 方向，不直接复制 Aperture 的源代码、资源或 GPL 实现细节。若未来需要复用任何代码、资源或协议，必须在对应阶段单独做许可证审查。

参考资料：

- [Aperture 官方仓库](https://github.com/mchorse/aperture)
- [Aperture Camera Wiki](https://github.com/mchorse/aperture/wiki/Camera)
- [Aperture 1.12 CameraProfile](https://raw.githubusercontent.com/mchorse/aperture/1.12/src/main/java/mchorse/aperture/camera/CameraProfile.java)
- [Aperture 1.12 CameraRunner](https://raw.githubusercontent.com/mchorse/aperture/1.12/src/main/java/mchorse/aperture/camera/CameraRunner.java)
- [Aperture 1.12 AbstractModifier](https://raw.githubusercontent.com/mchorse/aperture/1.12/src/main/java/mchorse/aperture/camera/modifiers/AbstractModifier.java)
- [Aperture 1.12 LICENSE](https://raw.githubusercontent.com/mchorse/aperture/1.12/LICENSE)
- [Minema 1.12.2 FixedTimer](https://raw.githubusercontent.com/mchorse/minema/1.12.2/src/main/java/info/ata4/minecraft/minema/client/engine/FixedTimer.java)
- [Minema 1.12.2 CaptureTime](https://raw.githubusercontent.com/mchorse/minema/1.12.2/src/main/java/info/ata4/minecraft/minema/client/util/CaptureTime.java)
- [Minema 1.12.2 AbstractVideoHandler](https://raw.githubusercontent.com/mchorse/minema/1.12.2/src/main/java/info/ata4/minecraft/minema/client/modules/video/AbstractVideoHandler.java)
- [Minema 1.12.2 SyncModule](https://raw.githubusercontent.com/mchorse/minema/1.12.2/src/main/java/info/ata4/minecraft/minema/client/modules/SyncModule.java)
- [Minema 1.12.2 LICENSE.md](https://raw.githubusercontent.com/mchorse/minema/1.12.2/LICENSE.md)

## 11. 本阶段明确不做的事

- 不实现时间线、相机、Modifier、录制器或渲染器。
- 不修改 `cycles-mod`，不添加跨仓库 Gradle 依赖。
- 不复制旧 Mod 的源码或旧版 Forge 注入方案。
- 不把当前包占位文件视为已经冻结的公共 API。
