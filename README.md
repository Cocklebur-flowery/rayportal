# RayPortal

RayPortal 是面向 Minecraft 26.2+ / NeoForge 的独立镜头编排与离线渲染调度 Mod。

本仓库与 `cycles-mod` 完全分开：RayPortal 不依赖 Cycles Renderer，也不包含 Cycles 的渲染实现。未来如需配合使用，双方通过明确的渲染请求、相机状态与帧完成屏障进行可选集成。

当前仓库是空白基线，只有 NeoForge 26.2 的最小 Mod 入口、构建配置、核心包边界占位和调查文档。时间线、相机、录制和离线调度功能尚未实现。

## 构建

```text
./gradlew build
```

运行配置由 NeoForge Gradle 插件提供：

```text
./gradlew runClient
./gradlew runServer
```

## 文档

- [正式架构规范](docs/architecture.md)：后续设计与实现的规范性基线。
- [基础调查与架构边界](docs/architecture-investigation.md)：Aperture、Minema、BBS 与 Blender 工作流的调研依据。

## 当前边界

- 只在本仓库维护 RayPortal 的源码、文档和构建配置。
- 不复制或修改 `cycles-mod` 的源码、资源、构建输出或 Git 历史。
- Minema 与 Aperture 仅作为历史行为和设计取舍的参考，不直接复制其实现。
