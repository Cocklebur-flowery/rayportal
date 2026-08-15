# RayPortal Git 提交信息规范

> 规范版本：0.1
>
> 状态：仓库级提交规范
>
> 最后更新：2026-08-16

本文规定 RayPortal 的 Git commit message 如何表达变更目的、责任边界、验证证据和兼容性。目标不是让每个提交都写成长报告，而是让未来开发者仅查看 Git 历史，就能判断一个变更为什么存在、改变了什么、验证到了哪一步，以及哪些风险仍然开放。

本规范与仓库根目录的 [工程开发约束](../AGENTS.md) 配合使用。`.gitmessage` 是编辑器提示模板；本文是其语义来源。

## 1. 核心原则

一条好的提交信息回答四个问题：

1. 为什么需要这个变化？
2. 哪个可观察行为、责任或契约发生了变化？
3. 实际执行了哪些验证，结果是什么？
4. 还有哪些兼容性、风险或未验证项？

提交信息不是：

- `git diff --stat` 的重复抄写。
- 开发过程中的逐分钟流水账。
- 没有证据的“全部完成”“问题已彻底解决”。
- 测试报告、架构文档或 Issue 的替代品。
- 为了显得详细而保留的大量空 Section。

正文只记录理解该提交所需的信息。未使用的可选 Section 应删除。

## 2. 基本结构

完整格式如下：

```text
<type>(<scope>): <imperative summary>

Why:
- <problem, requirement, or invariant>

Changes:
- <observable change or owned responsibility>

Contracts:
- <changed or deliberately preserved contract>

Validation:
- PASS `<command>` — <what it proved>
- NOT RUN `<check>` — <exact reason>

Compatibility / Risks:
- <migration, fallback, risk, or rollback behavior>

Manual verification:
- PASS `<workflow>` — <observed runtime evidence>

Known limitations:
- <remaining limitation>

Roadmap:
- Pxx-Wyy

Refs: <issue, decision, or document>
BREAKING CHANGE: <impact and migration>
```

并非所有提交都需要全部 Section。应根据第 3 节选择最小充分级别。

## 3. 三档信息级别

### 3.1 Level S：简短提交

只保留标题。仅当以下条件全部满足时使用：

- 变更显然且范围很小。
- 不改变运行行为、公共 API、Schema、稳定 ID、依赖或生命周期。
- 不需要解释特殊验证或未验证项。
- 不涉及 Minecraft Hook、线程、文件写入、Backend 或兼容性。

适用示例：拼写修正、链接修正、纯注释修正、无语义格式修正。

```text
docs(readme): fix roadmap link label
```

如果标题无法诚实表达验证边界，就升级为 Level M。

### 3.2 Level M：标准提交

这是默认级别，适用于普通功能、修复、测试、重构和构建工作。

必须包含：

- 标题。
- `Why`。
- `Changes`。
- `Validation`。

按需包含：

- `Known limitations`。
- `Roadmap`。
- `Refs`。

```text
feat(time): add exact frame-rate primitives

Why:
- P01-W02 requires frame timing that cannot drift with wall-clock playback.

Changes:
- Add normalized rational frame rates and non-negative frame indices.
- Reject zero denominators, negative indices, and overflowing conversions.

Validation:
- PASS `./gradlew test --tests '*FrameRateTest'` — covered reduction,
  equality, invalid input, and NTSC frame-rate cases.
- NOT RUN `runClient` — the change is isolated to the pure Java time core.

Roadmap:
- P01-W02
```

### 3.3 Level H：高风险提交

以下任一条件成立时必须使用：

- 改变公共 API、Project Schema、类型 ID、配置键、枚举值或默认值。
- 改变四时钟、FramePlan、FrameTicket、revision 或状态机语义。
- 改变线程所有权、Session 生命周期、取消、恢复或输出提交。
- 修改 Minecraft Camera/World Hook、Mixin 或集成服务端推进。
- 修改 Backend、Cycles 可选加载、Pass、输出格式或设备降级。
- 增加、移除或升级依赖。
- 修复难以复现的崩溃、数据损坏、竞态或画面回归。
- 包含用户需要迁移或明确知晓的兼容性影响。

除 Level M 内容外，还必须评估并按需填写：

- `Contracts`。
- `Compatibility / Risks`。
- `Manual verification`。
- `Known limitations`。
- `BREAKING CHANGE` Footer。

若某项高风险验证未执行，Section 仍应保留并标记 `NOT RUN`，不能直接删除。

```text
fix(runtime): restore camera ownership after world changes

Why:
- Leaving a world during preview could leave the virtual camera owner active,
  allowing a late callback to reclaim the next world's camera.

Changes:
- Invalidate the preview session generation before releasing its camera lease.
- Ignore callbacks whose session and camera generations no longer match.
- Make repeated close and world-detach cleanup idempotent.

Contracts:
- Preserve the rule that only one session may own the Minecraft main camera.
- Preserve player position, rotation, input state, and the original camera.

Validation:
- PASS `./gradlew test --tests '*CameraOwnershipTest'` — covered late
  callbacks, repeated close, and generation replacement.
- PASS `./gradlew build` — compiled and packaged the runtime integration.

Compatibility / Risks:
- No Project or configuration migration is required.
- The hook remains limited to the currently supported Minecraft baseline.

Manual verification:
- PASS `./gradlew runClient` — entered preview, changed dimension, returned to
  the title screen, rejoined, and confirmed the player camera was restored.

Known limitations:
- Multiplayer camera ownership is still unsupported and rejected explicitly.

Roadmap:
- P07-W02
```

## 4. 标题规则

标题格式：

```text
<type>(<scope>): <imperative summary>
```

规则：

- 使用英文祈使语气，描述提交完成后的结果。
- 使用最窄且稳定的 scope。
- 标题只表达一个责任，不使用 `and` 拼接无关变化。
- 不以句号结尾。
- 建议不超过 72 个字符；难以压缩时优先缩小提交范围。
- 不写文件名清单、测试结果、作者名、日期或 Issue 全文。
- 不使用 `misc`、`stuff`、`changes`、`updates` 等无法表达责任的词。
- 不把尚未实现的能力写成已完成。

正确：

```text
fix(timeline): reject overlapping camera clips
test(render): cover late frame ticket completion
docs(architecture): define OSL property ownership
build(test): wire the pure Java test suite
```

不正确：

```text
update files
feat: camera and json and some fixes
fix everything
P07 changes
camera-final-v2
```

## 5. Type 词表

| Type | 用途 | 不应用于 |
| --- | --- | --- |
| `feat` | 新的用户或开发者可用能力 | 仅内部整理 |
| `fix` | 修复错误行为或回归 | 未证明问题的实验 |
| `perf` | 有测量依据且保持语义的性能改善 | 没有基线的猜测优化 |
| `refactor` | 保持外部行为的责任重组 | 同时新增能力或改变契约 |
| `test` | 增加或修正验证能力 | 用测试名掩盖生产代码变化 |
| `docs` | 只修改文档或注释 | 与代码行为同时变化的主类型 |
| `build` | Gradle、依赖、打包、生成或工具链 | 普通源码修改 |
| `ci` | 自动化构建/检查流水线 | 本地开发脚本 |
| `chore` | 仓库维护且无更准确类型 | 任意无法分类的大杂烩 |
| `revert` | 明确撤销一个已有提交 | 普通反向修改 |

`BREAKING CHANGE` 不替代 Type。破坏性功能仍使用 `feat` 或 `fix`，并在 Footer 说明影响和迁移。

## 6. Scope 词表

优先从已有责任边界选择：

| Scope | 责任 |
| --- | --- |
| `time` | FrameRate、TimelineTime、tick 和 shutter 映射 |
| `project` | Project、Sequence、稳定 ID 和 revision |
| `timeline` | Track、Clip、Keyframe、曲线、编译和求值 |
| `camera` | CameraState、Transform、镜头和约束 |
| `capture` | 录制、重采样、简化和 raw sidecar |
| `application` | Project/Preview/Recording/Render Session 编排 |
| `editor` | Command、Undo/Redo、视图模型和 UI |
| `persistence` | Codec、Schema、迁移、原子保存和 Manifest |
| `runtime` | Minecraft 生命周期和通用运行时适配 |
| `world` | Simulation Clock、freeze、step 和 readiness |
| `render` | Render API、FramePlan、Ticket 和状态机 |
| `vanilla` | Vanilla 图片捕获 Backend |
| `cycles` | 可选 Cycles 公共 API 适配 |
| `diagnostics` | 日志、状态、错误和可观测性 |
| `build` | Gradle、依赖和产物配置 |
| `repo` | 仓库级政策、模板和维护 |
| `docs` | 跨领域文档体系 |

当提交只影响一个更明确能力时，可以增加新 scope，但必须保持低基数和长期语义。不要使用临时阶段号、开发者名或文件名作为 scope。

跨两个紧密边界但仍是单一契约的提交，选择拥有该契约的一侧。例如 FrameTicket 的生产者和消费者同时调整时使用 `render`，而不是 `application-render`。

## 7. 正文 Section 语义

### 7.1 Why

说明提交存在的原因，而不是重复标题。优先描述：

- 用户可见错误。
- 架构不变量或生命周期问题。
- 路线图工作包的必要交付。
- 已确认的性能或兼容性证据。

不要写“为了优化代码”“按要求修改”这类无法帮助未来调查的信息。

### 7.2 Changes

描述行为和责任变化：

- 哪个组件现在拥有什么。
- 哪个状态转换、错误路径或恢复路径改变。
- 哪个输入以前被接受，现在被拒绝。
- 哪个输出或诊断现在可观察。

通常不逐个列出文件；只有文件身份本身是契约时才提及。

### 7.3 Contracts

明确改变或刻意保持的稳定契约，例如：

- Public API、Schema Version、稳定 ID 和枚举值。
- 四时钟、revision、FramePlan、FrameTicket 和完成屏障。
- 线程/资源所有权、close/cancel/reset 语义。
- 配置键、默认值、资源 ID 和输出命名。
- RayPortal/Cycles 依赖方向与缺失 Backend 行为。

如果高风险提交检查后确认没有契约变化，可以写：

```text
Contracts:
- Preserve Project schema v1 and all serialized type IDs.
```

“None”只在真的不存在相关稳定契约时使用。

### 7.4 Validation

每一项都使用状态、实际命令或检查以及它证明的内容：

```text
Validation:
- PASS `./gradlew test --tests '*FrameRateTest'` — verified exact mappings.
- FAIL `./gradlew test` — existing unrelated ExampleTest failure remains.
- KNOWN RED `runClient` camera detach — tracked by P07-W02.
- BLOCKED `CyclesRenderBackendTest` — compatible Cycles API is unavailable.
- NOT RUN `runClient` — documentation-only change.
```

规则：

- 只记录实际执行结果。
- `PASS build` 不等于运行时通过。
- `PASS runClient` 必须说明实际操作了什么。
- `FAIL` 不得被较宽泛的 PASS 覆盖。
- 已知红项必须命名，不能写“有一些测试失败”。
- 文档提交也应说明链接、结构或 diff 检查。

### 7.5 Compatibility / Risks

说明：迁移、旧 Project、可选依赖、平台版本、回退、设备模式和仍可能受影响的边界。

不要写没有内容的“无风险”。可以写更准确的：

```text
Compatibility / Risks:
- No persisted format or public API changes.
- Runtime validation remains limited to the current Minecraft baseline.
```

### 7.6 Manual verification

Minecraft Hook、UI、Camera、World、Backend、输出和 GPU 路径通常需要此 Section。记录用户操作和观察结果，而不只是 `runClient` 命令。

### 7.7 Known limitations

只记录本提交交付后仍然存在、且可能影响使用或下一阶段的限制。不要把未完成的主体功能降格为 limitation 后宣布提交完成。

### 7.8 Roadmap 与 Refs

路线图工作应记录唯一工作包，例如：

```text
Roadmap:
- P09-W03
```

`Refs` 可指向 Issue、架构决定或权威文档。不要引用本机路径、聊天消息或无法访问的临时日志。

## 8. 提交拆分规则

一个 commit 应代表一个可独立理解和验证的责任、生命周期、契约或路线图工作包。

通常应拆分：

- 功能实现与无关重构。
- 生产代码与独立文档体系整理。
- RayPortal 与 Cycles 两个仓库的改动。
- 公共契约与后续 Backend 实现。
- 机械生成输出与生成器本身之外的功能。
- 已验证修复与仍在探索的实验。

通常不应拆分：

- 稳定契约和必须同时更新的直接消费者。
- Schema 迁移与对应 Codec/golden fixture。
- 状态转换和证明该转换的合同测试。
- 创建资源与其必要注册元数据。

如果标题需要列出两个不相关结果，通常说明提交应该拆分。

## 9. Revert 与修复提交

Revert 应保留 Git 自动生成的目标提交信息，并在必要时补充：

```text
Revert "feat(camera): apply physical lens overrides"

Why:
- The change regressed Minecraft projection when physical lens mode was off.

Validation:
- PASS `./gradlew test --tests '*CameraProjectionTest'` — restored the
  previous default projection behavior.

Reverts: <full commit hash>
```

不要用 amend 或历史重写隐藏已经共享、已经验证或具有调查价值的失败实验，除非用户明确要求重写历史。

后续修复提交应说明它修复哪个可观察问题，不必复制前一提交的全部正文。

## 10. Cycles 风格的高风险示例

本模板未来移植到 Cycles 仓库时，应在高风险提交中明确 ABI、Backend、设备模式和运行证据：

```text
fix(pbr): bound glass texture attenuation

Why:
- Texture-driven transmission could exceed the intended material energy and
  produce unstable bright glass under scene lighting.

Changes:
- Clamp texture attenuation at the material construction boundary.
- Preserve the existing opaque and alpha-cutout material paths.

Contracts:
- Preserve native ABI layouts and Java marshalling.
- Preserve default material classification IDs.

Validation:
- PASS `<focused native smoke>` — covered textured glass energy bounds.
- PASS `<project verification gate>` — built Java and native default paths.

Compatibility / Risks:
- No ABI or persisted configuration migration.
- Visual output intentionally changes only for out-of-range glass inputs.

Manual verification:
- PASS `<Minecraft workflow>` — inspected glass in the supported GPU backend
  and confirmed opaque foliage remained unchanged.
```

Cycles 的具体命令、ABI 版本和设备矩阵必须在执行时从该仓库读取，不能从此示例复制。

## 11. 反例

### 只有“做了什么”

```text
fix(camera): update camera code
```

问题：无法知道错误是什么、保持了什么、验证了什么。

### 把测试说成事实但没有命令

```text
Validation:
- Everything works.
```

问题：无法复现，也无法区分编译、单元测试和运行时。

### 用正文掩盖混合提交

```text
feat(render): add backend features

Changes:
- Add a backend.
- Rewrite persistence.
- Rename camera packages.
- Update dependencies.
```

问题：四个独立责任不能安全回退或验证，应先拆分。

### 虚假完成

```text
feat(cycles): complete offline rendering

Known limitations:
- Output is not written yet.
- Cancellation is not implemented.
```

问题：主体完成条件缺失，不能通过 limitation 降级。

## 12. 提交前检查清单

获得用户提交授权后，提交者必须确认：

1. `git status` 中每个路径的所有者和用途都已确认。
2. Staged diff 只包含当前责任，没有用户或其他任务的修改。
3. `git diff --cached --check` 没有意外空白错误。
4. 标题 type、scope 和完成语义准确。
5. 信息级别符合实际风险。
6. Validation 只记录真实执行项，并包含失败和未执行原因。
7. 稳定契约、兼容性、手工验证和 limitation 没有被遗漏。
8. Footer 不包含虚假的 Issue、贡献者或 BREAKING CHANGE。
9. 作者/提交者身份符合用户要求。
10. 提交后重新检查 commit message、作者、文件清单和工作树。

## 13. 使用 `.gitmessage`

`.gitmessage` 中所有提示行都以 `#` 开头，不会进入最终提交正文。提交者应在提示之间填写实际内容，并删除不适用的 Section。

需要让本地 Git 编辑器自动加载模板时，可在仓库根目录显式执行：

```text
git config --local commit.template .gitmessage
```

该命令只修改当前仓库的本地 Git 配置，不应作为构建或其他任务的附带操作。自动化提交也必须遵守同一语义，即使它使用 `git commit -F` 或多条 `-m` 参数而不打开编辑器。

## 14. 最终判定

提交信息足够详细的标准，不是字数，而是未来调查者无需打开所有 diff 就能理解：原因、责任、契约和验证边界。

提交信息足够整洁的标准，是删除空 Section、避免流水账，并让每一条 bullet 都提供新的决策或证据。
