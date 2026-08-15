# RayPortal 测试与验证目录规范

> 状态：P00-W02 建立的仓库级约定
>
> 最后更新：2026-08-16

本文定义 RayPortal 的测试代码、测试数据、Minecraft GameTest 和人工验证证据的归属。它只规定目录和责任边界，不宣称尚未实现的测试能力已经可用。

## 1. JVM 单元测试

普通 JUnit 测试放在 `src/test/java/dev/rayportal`，并镜像被测生产包的责任：

```text
src/main/java/dev/rayportal/core/time/       → src/test/java/dev/rayportal/core/time/
src/main/java/dev/rayportal/core/camera/     → src/test/java/dev/rayportal/core/camera/
src/main/java/dev/rayportal/persistence/     → src/test/java/dev/rayportal/persistence/
```

测试包名不因测试类型改成与生产责任无关的总目录。只有真正验证仓库基础设施的测试才放在 `dev.rayportal.baseline`，例如 `TestFrameworkBaselineTest`。

单元测试必须能够在没有 Minecraft 客户端、世界实例、GUI、Cycles 或 native runtime 的情况下运行。测试不应通过静态可变全局状态互相通信。

## 2. Fixture 与 golden data

测试输入和期望输出放在默认测试资源树中，并按生产责任分组：

```text
src/test/resources/dev/rayportal/<responsibility>/fixtures/
src/test/resources/dev/rayportal/<responsibility>/golden/
```

规则：

- Fixture 是测试输入；golden 是经过审阅、具有版本意义的期望结果。
- 文件名包含可读的场景或契约名称，不使用机器路径、用户名或时间戳作为身份。
- Golden 变更必须说明原因，并在提交中记录生成/比较命令和差异边界。
- `build/`、`.gradle/` 和临时输出不属于版本化测试数据。
- 测试资源不得被生产 Mod JAR 自动打包；需要运行时资源时必须另行声明责任和验证。

## 3. Minecraft GameTest 与人工证据

Minecraft GameTest 属于运行时验证，不冒充纯 JVM 单元测试。当前没有独立 GameTest source set，因此未来的 GameTest 源码暂放在运行时源码的 `dev.rayportal.gametest` 责任包；建立独立 source set 前不得把它放进 `src/test/java` 并声称 `./gradlew test` 已覆盖。

人工验证记录放在：

```text
docs/evidence/<work-package>/
```

记录应包含日期、命令或操作流程、结果状态和首个可行动错误。日志使用仓库相对路径并脱敏；大段日志留在本地或受控附件，不复制进提交正文。`runClient`、世界切换、相机恢复和渲染后端验证必须明确写出实际操作，不得用编译成功替代。

## 4. Core 包边界检查

`core.*` 只保存平台无关的领域语义。`checkCoreBoundaries` 是有意保持轻量的 import 检查，当前拒绝以下依赖：

- Minecraft、NeoForge、Cycles 名称相关类型。
- 文件、网络和 NIO channel/path IO。
- AWT、Swing、ImGui 和 LWJGL GUI/平台类型。

运行：

```text
./gradlew checkCoreBoundaries
./gradlew check
```

检查只读取 `src/main/java/dev/rayportal/core` 下的 Java 源码，不扫描生成目录、第三方源码或构建缓存。它不替代代码审查：通过全限定名、反射或资源加载绕过 import 检查仍属于违规依赖，必须在评审中拒绝。

## 5. 测试状态边界

`PASS` 只表示对应命令或流程实际通过。`FAIL`、`KNOWN RED`、`BLOCKED` 和 `NOT RUN` 必须保留具体对象和原因。JVM 单元测试通过不代表 Minecraft Hook、GameTest、`runClient` 或渲染后端通过。
